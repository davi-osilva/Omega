"""
DETECCAO DE SONOLENCIA - PROJETO SOMPO

Arquitetura:

    CAMERA / VIDEO
          |
          v
    FACE LANDMARKER
          |
          | falhou
          v
    FACE MESH FALLBACK
          |
          v
    EAR + BLINK + MAR + YAW
          |
          v
    ANALISE TEMPORAL
          |
          +--> Fechamento prolongado
          |
          +--> PERCLOS
          |
          +--> Piscadas
          |
          +--> Bocejo
          |
          v
    SCORE DE SONOLENCIA
          |
          +--> NORMAL
          +--> ATENCAO
          +--> ALERTA

IMPORTANTE:
- Sonolencia NAO e decidida por um unico frame.
- O sistema utiliza historico temporal.
- Yaw e utilizado como indicador de qualidade/pose,
  e nao como prova de sonolencia.
"""

import os
import sys
import time
import math
import urllib.request
from pathlib import Path
from collections import deque

import cv2
import mediapipe as mp


# ============================================================
# CONFIGURACAO GERAL
# ============================================================

# Camera padrao
CAMERA_ID = 0

# Resolucao desejada
CAMERA_WIDTH = 1280
CAMERA_HEIGHT = 720

# Modelo Face Landmarker
MODEL_PATH = Path(__file__).parent / "face_landmarker.task"

MODEL_URL = (
    "https://storage.googleapis.com/"
    "mediapipe-models/face_landmarker/"
    "face_landmarker/float16/1/face_landmarker.task"
)

# ============================================================
# LIMIARES DE OLHO
# ============================================================

# EAR abaixo disso e considerado fechamento forte
EAR_FECHADO = 0.20

# EAR abaixo disso e fechamento muito forte
EAR_FECHADO_FORTE = 0.17

# Blendshape de piscada
BLINK_LIMIAR = 0.50

# Blendshape muito forte
BLINK_FORTE = 0.70

# ============================================================
# LIMIARES DE SONOLENCIA
# ============================================================

# Tempo minimo de olhos fechados para caracterizar
# um fechamento prolongado.
FECHAMENTO_PROLONGADO_SEG = 1.0

# Fechamento muito prolongado
FECHAMENTO_CRITICO_SEG = 2.0

# Janela utilizada para PERCLOS.
# Para desenvolvimento/teste, 30 segundos e pratico.
PERCLOS_JANELA_SEG = 30.0

# PERCLOS de atencao
PERCLOS_ATENCAO = 0.15

# PERCLOS de alerta
PERCLOS_ALERTA = 0.30

# Quantidade de piscadas por minuto considerada elevada.
PISCADAS_ALTA = 25

# ============================================================
# MAR
# ============================================================

MAR_LIMIAR = 0.60

# Tempo de boca aberta para considerar possivel bocejo
BOCEJO_MIN_SEG = 0.8


# ============================================================
# POSE / QUALIDADE
# ============================================================

# Diferenca relativa entre largura dos olhos.
# Se for muito grande, um dos olhos pode estar
# distorcido pela pose.
DIFERENCA_LARGURA_OLHOS_LIMIAR = 0.35

# Yaw nao gera alerta sozinho.
# Ele serve para informar que a pose esta dificil.
YAW_POSE_DIFICIL = 0.55

# Margem usada no fallback de recorte
MARGEM_RECORTE = 0.60


# ============================================================
# LANDMARKS
# ============================================================

OLHO_ESQ = [
    362,
    385,
    387,
    263,
    373,
    380,
]

OLHO_DIR = [
    33,
    160,
    158,
    133,
    153,
    144,
]

BOCA = [
    78,
    81,
    13,
    311,
    308,
    402,
    14,
    178,
]

NARIZ_YAW = 1
CANTO_OLHO_ESQ_YAW = 263
CANTO_OLHO_DIR_YAW = 33


# ============================================================
# FUNCOES GEOMETRICAS
# ============================================================

def distancia(p1, p2):
    dx = p1[0] - p2[0]
    dy = p1[1] - p2[1]

    return math.sqrt(
        dx * dx + dy * dy
    )


def ponto_landmark(
    landmark,
    largura,
    altura
):
    x = int(
        landmark.x * largura
    )

    y = int(
        landmark.y * altura
    )

    return x, y


def calcular_ear(
    landmarks,
    indices,
    largura,
    altura
):
    pontos = [
        ponto_landmark(
            landmarks[i],
            largura,
            altura
        )
        for i in indices
    ]

    p1, p2, p3, p4, p5, p6 = pontos

    vertical_1 = distancia(
        p2,
        p6
    )

    vertical_2 = distancia(
        p3,
        p5
    )

    horizontal = distancia(
        p1,
        p4
    )

    if horizontal <= 0:
        return 0.0, 0.0

    ear = (
        vertical_1 +
        vertical_2
    ) / (
        2.0 * horizontal
    )

    return ear, horizontal


def calcular_mar(
    landmarks,
    largura,
    altura
):
    pontos = [
        ponto_landmark(
            landmarks[i],
            largura,
            altura
        )
        for i in BOCA
    ]

    p1, p2, p3, p4, p5, p6, p7, p8 = pontos

    horizontal = distancia(
        p1,
        p4
    )

    if horizontal <= 0:
        return 0.0

    vertical_1 = distancia(
        p2,
        p8
    )

    vertical_2 = distancia(
        p3,
        p7
    )

    vertical_3 = distancia(
        p5,
        p6
    )

    return (
        vertical_1 +
        vertical_2 +
        vertical_3
    ) / (
        3.0 * horizontal
    )


def calcular_yaw(
    landmarks,
    largura,
    altura
):
    nariz = ponto_landmark(
        landmarks[NARIZ_YAW],
        largura,
        altura
    )

    olho_esq = ponto_landmark(
        landmarks[CANTO_OLHO_ESQ_YAW],
        largura,
        altura
    )

    olho_dir = ponto_landmark(
        landmarks[CANTO_OLHO_DIR_YAW],
        largura,
        altura
    )

    x_min = min(
        olho_esq[0],
        olho_dir[0]
    )

    x_max = max(
        olho_esq[0],
        olho_dir[0]
    )

    largura_olhos = x_max - x_min

    if largura_olhos <= 0:
        return 0.0

    centro = (
        x_min +
        x_max
    ) / 2.0

    return (
        nariz[0] - centro
    ) / largura_olhos


# ============================================================
# MODELO FACE LANDMARKER
# ============================================================

def baixar_modelo():
    if MODEL_PATH.exists():
        return True

    print(
        "[INFO] Modelo Face Landmarker nao encontrado."
    )

    print(
        "[INFO] Baixando modelo..."
    )

    try:
        urllib.request.urlretrieve(
            MODEL_URL,
            MODEL_PATH
        )

        print(
            "[OK] Modelo baixado."
        )

        return True

    except Exception as e:
        print(
            f"[ERRO] Falha ao baixar modelo: {e}"
        )

        return False


def criar_face_landmarker():
    if not baixar_modelo():
        return None

    try:
        BaseOptions = mp.tasks.BaseOptions
        FaceLandmarker = (
            mp.tasks.vision.FaceLandmarker
        )
        FaceLandmarkerOptions = (
            mp.tasks.vision.FaceLandmarkerOptions
        )
        RunningMode = (
            mp.tasks.vision.RunningMode
        )

        options = FaceLandmarkerOptions(
            base_options=BaseOptions(
                model_asset_path=str(
                    MODEL_PATH
                )
            ),

            running_mode=RunningMode.IMAGE,

            num_faces=1,

            min_face_detection_confidence=0.15,

            min_face_presence_confidence=0.15,

            min_tracking_confidence=0.15,

            output_face_blendshapes=True,

            output_facial_transformation_matrixes=False,
        )

        landmarker = (
            FaceLandmarker.create_from_options(
                options
            )
        )

        print(
            "[OK] Face Landmarker inicializado."
        )

        return landmarker

    except Exception as e:
        print(
            f"[ERRO] Nao foi possivel criar Face Landmarker: {e}"
        )

        return None


def rodar_landmarker(
    landmarker,
    frame
):
    if landmarker is None:
        return None

    try:
        rgb = cv2.cvtColor(
            frame,
            cv2.COLOR_BGR2RGB
        )

        imagem_mp = mp.Image(
            image_format=mp.ImageFormat.SRGB,
            data=rgb
        )

        resultado = landmarker.detect(
            imagem_mp
        )

        if (
            resultado.face_landmarks
            and len(resultado.face_landmarks) > 0
        ):
            return resultado

    except Exception:
        pass

    return None


# ============================================================
# FACE MESH FALLBACK
# ============================================================

def criar_face_mesh():
    return mp.solutions.face_mesh.FaceMesh(
        static_image_mode=True,
        max_num_faces=1,
        refine_landmarks=True,

        min_detection_confidence=0.15,

        min_tracking_confidence=0.15
    )


def rodar_face_mesh(
    face_mesh,
    frame
):
    try:
        rgb = cv2.cvtColor(
            frame,
            cv2.COLOR_BGR2RGB
        )

        resultado = face_mesh.process(
            rgb
        )

        if resultado.multi_face_landmarks:
            return resultado

    except Exception:
        pass

    return None


# ============================================================
# DETECCAO / RECORTE
# ============================================================

def achar_bbox_rosto(frame):
    """
    Usa Face Detection para tentar encontrar
    uma caixa aproximada do rosto.

    Serve apenas como estrategia de recuperacao.
    """

    try:
        detector = (
            mp.solutions.face_detection.FaceDetection(
                model_selection=1,
                min_detection_confidence=0.15
            )
        )

        rgb = cv2.cvtColor(
            frame,
            cv2.COLOR_BGR2RGB
        )

        resultado = detector.process(
            rgb
        )

        detector.close()

        if not resultado.detections:
            return None

        altura, largura = frame.shape[:2]

        melhor = None
        maior_area = 0

        for deteccao in resultado.detections:

            bbox = (
                deteccao.location_data
                .relative_bounding_box
            )

            x = int(
                bbox.xmin * largura
            )

            y = int(
                bbox.ymin * altura
            )

            w = int(
                bbox.width * largura
            )

            h = int(
                bbox.height * altura
            )

            x = max(0, x)
            y = max(0, y)

            w = min(
                w,
                largura - x
            )

            h = min(
                h,
                altura - y
            )

            area = w * h

            if area > maior_area:

                maior_area = area

                melhor = (
                    x,
                    y,
                    w,
                    h
                )

        return melhor

    except Exception:
        return None


def criar_recorte(
    frame,
    bbox
):
    if bbox is None:
        return None, None

    x, y, w, h = bbox

    altura, largura = frame.shape[:2]

    margem_x = int(
        w * MARGEM_RECORTE
    )

    margem_y = int(
        h * MARGEM_RECORTE
    )

    x1 = max(
        0,
        x - margem_x
    )

    y1 = max(
        0,
        y - margem_y
    )

    x2 = min(
        largura,
        x + w + margem_x
    )

    y2 = min(
        altura,
        y + h + margem_y
    )

    if x2 <= x1 or y2 <= y1:
        return None, None

    crop = frame[
        y1:y2,
        x1:x2
    ]

    if crop.size == 0:
        return None, None

    crop = cv2.resize(
        crop,
        None,
        fx=2.0,
        fy=2.0,
        interpolation=cv2.INTER_CUBIC
    )

    info = {
        "x": x1,
        "y": y1,
        "escala": 2.0,
    }

    return crop, info


# ============================================================
# CONVERSAO DE LANDMARKS DO CROP
# ============================================================

def converter_crop_para_original(
    landmarks,
    crop,
    info,
    largura_original,
    altura_original
):
    if info is None:
        return landmarks

    crop_h, crop_w = crop.shape[:2]

    x_offset = info["x"]
    y_offset = info["y"]
    escala = info["escala"]

    novos = []

    class Landmark:
        pass

    for lm in landmarks:

        crop_x = (
            lm.x *
            crop_w
        )

        crop_y = (
            lm.y *
            crop_h
        )

        original_crop_x = (
            crop_x /
            escala
        )

        original_crop_y = (
            crop_y /
            escala
        )

        original_x = (
            x_offset +
            original_crop_x
        )

        original_y = (
            y_offset +
            original_crop_y
        )

        novo = Landmark()

        novo.x = (
            original_x /
            largura_original
        )

        novo.y = (
            original_y /
            altura_original
        )

        novo.z = getattr(
            lm,
            "z",
            0.0
        )

        novos.append(
            novo
        )

    return novos


# ============================================================
# DETECCAO COMPLETA DO ROSTO
# ============================================================

def detectar_rosto(
    landmarker,
    face_mesh,
    frame
):
    """
    Ordem:

    1. Face Landmarker no frame inteiro
    2. Face Landmarker no recorte
    3. Face Mesh no frame inteiro
    4. Face Mesh no recorte
    """

    altura, largura = frame.shape[:2]

    # --------------------------------------------------------
    # FACE LANDMARKER - FRAME INTEIRO
    # --------------------------------------------------------

    resultado = rodar_landmarker(
        landmarker,
        frame
    )

    if resultado is not None:

        landmarks = (
            resultado.face_landmarks[0]
        )

        blendshapes = extrair_blendshapes(
            resultado
        )

        return {
            "landmarks": landmarks,
            "blendshapes": blendshapes,
            "modo": "LANDMARKER",
            "crop": False,
        }

    # --------------------------------------------------------
    # RECORTE
    # --------------------------------------------------------

    bbox = achar_bbox_rosto(
        frame
    )

    if bbox is not None:

        crop, info = criar_recorte(
            frame,
            bbox
        )

        if crop is not None:

            resultado = rodar_landmarker(
                landmarker,
                crop
            )

            if resultado is not None:

                landmarks = (
                    resultado.face_landmarks[0]
                )

                landmarks = (
                    converter_crop_para_original(
                        landmarks,
                        crop,
                        info,
                        largura,
                        altura
                    )
                )

                blendshapes = (
                    extrair_blendshapes(
                        resultado
                    )
                )

                return {
                    "landmarks": landmarks,
                    "blendshapes": blendshapes,
                    "modo": "LANDMARKER CROP",
                    "crop": True,
                }

    # --------------------------------------------------------
    # FACE MESH - FRAME INTEIRO
    # --------------------------------------------------------

    resultado_mesh = rodar_face_mesh(
        face_mesh,
        frame
    )

    if resultado_mesh is not None:

        landmarks = (
            resultado_mesh
            .multi_face_landmarks[0]
            .landmark
        )

        return {
            "landmarks": landmarks,
            "blendshapes": {},
            "modo": "FACE MESH FALLBACK",
            "crop": False,
        }

    # --------------------------------------------------------
    # FACE MESH - RECORTE
    # --------------------------------------------------------

    if bbox is not None:

        crop, info = criar_recorte(
            frame,
            bbox
        )

        if crop is not None:

            resultado_mesh = (
                rodar_face_mesh(
                    face_mesh,
                    crop
                )
            )

            if resultado_mesh is not None:

                landmarks = (
                    resultado_mesh
                    .multi_face_landmarks[0]
                    .landmark
                )

                landmarks = (
                    converter_crop_para_original(
                        landmarks,
                        crop,
                        info,
                        largura,
                        altura
                    )
                )

                return {
                    "landmarks": landmarks,
                    "blendshapes": {},
                    "modo": "FACE MESH CROP",
                    "crop": True,
                }

    return None


# ============================================================
# BLENDSHAPES
# ============================================================

def extrair_blendshapes(resultado):

    blendshapes = {}

    if resultado is None:
        return blendshapes

    if not resultado.face_blendshapes:
        return blendshapes

    for categoria in resultado.face_blendshapes[0]:

        nome = categoria.category_name

        score = categoria.score

        blendshapes[nome] = score

    return blendshapes


# ============================================================
# ANALISE DOS OLHOS
# ============================================================

def analisar_olhos(
    ear_esq,
    ear_dir,
    largura_esq,
    largura_dir,
    blendshapes
):
    """
    Nao usa simplesmente a media dos dois olhos.

    Se um olho estiver geometricamente muito diferente
    do outro, usamos o olho com maior largura horizontal,
    pois ele tende a estar mais visivel.

    O BLINK e usado como evidencia adicional.

    IMPORTANTE:
    nenhum frame sozinho gera sonolencia.
    """

    if largura_esq <= 0:
        largura_esq = 1

    if largura_dir <= 0:
        largura_dir = 1

    diferenca = (
        abs(
            largura_esq -
            largura_dir
        )
        /
        max(
            largura_esq,
            largura_dir
        )
    )

    if (
        diferenca >
        DIFERENCA_LARGURA_OLHOS_LIMIAR
    ):

        if largura_esq >= largura_dir:

            ear = ear_esq
            olho_usado = "ESQ"

            blink = blendshapes.get(
                "eyeBlinkLeft"
            )

        else:

            ear = ear_dir
            olho_usado = "DIR"

            blink = blendshapes.get(
                "eyeBlinkRight"
            )

    else:

        ear = (
            ear_esq +
            ear_dir
        ) / 2.0

        olho_usado = "MEDIO"

        blink_esq = blendshapes.get(
            "eyeBlinkLeft"
        )

        blink_dir = blendshapes.get(
            "eyeBlinkRight"
        )

        if blink_esq is None:
            blink_esq = 0.0

        if blink_dir is None:
            blink_dir = 0.0

        blink = max(
            blink_esq,
            blink_dir
        )

    if blink is None:
        blink = 0.0

    fechado_ear = (
        ear <
        EAR_FECHADO
    )

    fechado_forte = (
        ear <
        EAR_FECHADO_FORTE
    )

    blink_detectado = (
        blink >=
        BLINK_LIMIAR
    )

    blink_forte = (
        blink >=
        BLINK_FORTE
    )

    # Evidencia combinada.
    #
    # EAR muito baixo sozinho:
    # forte evidencia de olho fechado.
    #
    # EAR normal + blink muito forte:
    # pode ser uma falha do EAR.
    #
    # EAR limiar + blink:
    # reforca a decisao.

    if fechado_forte:

        fechado = True
        evidencia = "EAR FORTE"

    elif fechado_ear and blink_detectado:

        fechado = True
        evidencia = "EAR + BLINK"

    elif blink_forte:

        fechado = True
        evidencia = "BLINK"

    else:

        fechado = False
        evidencia = "ABERTO"

    return {
        "ear": ear,
        "fechado": fechado,
        "fechado_forte": fechado_forte,
        "blink": blink,
        "evidencia": evidencia,
        "olho_usado": olho_usado,
        "diferenca": diferenca,
    }


# ============================================================
# HISTORICO TEMPORAL
# ============================================================

class HistoricoSonolencia:

    def __init__(self):

        # Cada elemento:
        #
        # (timestamp, olho_fechado)
        #
        self.olhos = deque()

        # Inicio do fechamento atual
        self.inicio_fechamento = None

        # Ultimo timestamp
        self.ultimo_tempo = None

        # Piscadas detectadas
        self.piscadas = deque()

        # Estado anterior
        self.ultimo_fechado = False

        # Inicio de boca aberta
        self.inicio_boca = None

        # Contador de bocejos
        self.bocejos = deque()

    def atualizar(
        self,
        timestamp,
        olho_fechado,
        boca_aberta
    ):
        """
        Atualiza historico temporal.
        """

        # ----------------------------------------------------
        # OLHOS
        # ----------------------------------------------------

        self.olhos.append(
            (
                timestamp,
                olho_fechado
            )
        )

        # Remove dados antigos
        limite = (
            timestamp -
            PERCLOS_JANELA_SEG
        )

        while (
            self.olhos
            and
            self.olhos[0][0] <
            limite
        ):
            self.olhos.popleft()

        # ----------------------------------------------------
        # TRANSICAO ABERTO -> FECHADO
        # ----------------------------------------------------

        if (
            olho_fechado
            and
            not self.ultimo_fechado
        ):

            self.inicio_fechamento = (
                timestamp
            )

        # ----------------------------------------------------
        # TRANSICAO FECHADO -> ABERTO
        # ----------------------------------------------------

        if (
            not olho_fechado
            and
            self.ultimo_fechado
        ):

            if self.inicio_fechamento is not None:

                duracao = (
                    timestamp -
                    self.inicio_fechamento
                )

                # Uma piscada e um fechamento curto.
                if (
                    duracao >= 0.05
                    and
                    duracao < 1.0
                ):

                    self.piscadas.append(
                        timestamp
                    )

            self.inicio_fechamento = None

        self.ultimo_fechado = (
            olho_fechado
        )

        # ----------------------------------------------------
        # BOCA
        # ----------------------------------------------------

        if boca_aberta:

            if self.inicio_boca is None:

                self.inicio_boca = (
                    timestamp
                )

        else:

            if self.inicio_boca is not None:

                duracao_boca = (
                    timestamp -
                    self.inicio_boca
                )

                if (
                    duracao_boca >=
                    BOCEJO_MIN_SEG
                ):

                    self.bocejos.append(
                        timestamp
                    )

                self.inicio_boca = None

        # Limpa piscadas antigas
        limite_piscadas = (
            timestamp -
            60.0
        )

        while (
            self.piscadas
            and
            self.piscadas[0] <
            limite_piscadas
        ):
            self.piscadas.popleft()

        # Limpa bocejos antigos
        limite_bocejos = (
            timestamp -
            60.0
        )

        while (
            self.bocejos
            and
            self.bocejos[0] <
            limite_bocejos
        ):
            self.bocejos.popleft()

    def calcular_perclos(self):
        """
        PERCLOS:

            tempo com olhos fechados
            ------------------------
               tempo observado
        """

        if len(self.olhos) < 2:
            return 0.0

        primeiro_tempo = (
            self.olhos[0][0]
        )

        ultimo_tempo = (
            self.olhos[-1][0]
        )

        duracao = (
            ultimo_tempo -
            primeiro_tempo
        )

        if duracao <= 0:
            return 0.0

        fechados = 0.0
        total = 0.0

        anterior_tempo = None
        anterior_estado = False

        for timestamp, fechado in self.olhos:

            if anterior_tempo is not None:

                intervalo = (
                    timestamp -
                    anterior_tempo
                )

                total += intervalo

                if anterior_estado:
                    fechados += intervalo

            anterior_tempo = timestamp
            anterior_estado = fechado

        if total <= 0:
            return 0.0

        return min(
            1.0,
            fechados / total
        )

    def duracao_fechamento(
        self,
        agora
    ):
        if self.inicio_fechamento is None:
            return 0.0

        return (
            agora -
            self.inicio_fechamento
        )

    def piscadas_por_minuto(
        self,
        agora
    ):
        limite = agora - 60.0

        quantidade = sum(
            1
            for t in self.piscadas
            if t >= limite
        )

        return quantidade

    def bocejos_por_minuto(
        self,
        agora
    ):
        limite = agora - 60.0

        quantidade = sum(
            1
            for t in self.bocejos
            if t >= limite
        )

        return quantidade


# ============================================================
# SCORE DE SONOLENCIA
# ============================================================

def calcular_score_sonolencia(
    perclos,
    fechamento,
    piscadas_min,
    bocejos_min
):
    """
    Calcula score de 0 a 100.

    Isso NAO e um modelo medico.
    E um score heuristico para o prototipo.

    Componentes:

        PERCLOS
        fechamento prolongado
        piscadas
        bocejos
    """

    score = 0.0

    # --------------------------------------------------------
    # PERCLOS
    # --------------------------------------------------------

    if perclos >= PERCLOS_ALERTA:

        score += 55.0

    elif perclos >= PERCLOS_ATENCAO:

        proporcao = (
            perclos -
            PERCLOS_ATENCAO
        ) / (
            PERCLOS_ALERTA -
            PERCLOS_ATENCAO
        )

        score += (
            20.0 +
            35.0 * proporcao
        )

    # --------------------------------------------------------
    # FECHAMENTO
    # --------------------------------------------------------

    if fechamento >= FECHAMENTO_CRITICO_SEG:

        score += 40.0

    elif fechamento >= FECHAMENTO_PROLONGADO_SEG:

        proporcao = (
            fechamento -
            FECHAMENTO_PROLONGADO_SEG
        ) / (
            FECHAMENTO_CRITICO_SEG -
            FECHAMENTO_PROLONGADO_SEG
        )

        score += (
            20.0 +
            20.0 * min(
                1.0,
                proporcao
            )
        )

    # --------------------------------------------------------
    # PISCADAS
    # --------------------------------------------------------

    if piscadas_min >= PISCADAS_ALTA:

        score += 10.0

    elif piscadas_min >= 18:

        score += 5.0

    # --------------------------------------------------------
    # BOCEJOS
    # --------------------------------------------------------

    if bocejos_min >= 3:

        score += 15.0

    elif bocejos_min >= 1:

        score += 7.0

    return min(
        100.0,
        score
    )


def classificar_score(
    score
):
    if score >= 60:
        return "ALERTA"

    if score >= 30:
        return "ATENCAO"

    return "NORMAL"


# ============================================================
# DESENHO
# ============================================================

def desenhar_landmarks(
    frame,
    landmarks
):
    altura, largura = frame.shape[:2]

    olhos = set(
        OLHO_ESQ +
        OLHO_DIR
    )

    boca = set(
        BOCA
    )

    for i, lm in enumerate(
        landmarks
    ):

        x, y = ponto_landmark(
            lm,
            largura,
            altura
        )

        if i in olhos:
            cor = (255, 0, 0)

        elif i in boca:
            cor = (0, 255, 255)

        else:
            cor = (0, 255, 0)

        cv2.circle(
            frame,
            (x, y),
            1,
            cor,
            -1
        )


def desenhar_contorno(
    frame,
    landmarks,
    indices,
    cor
):
    altura, largura = frame.shape[:2]

    pontos = []

    for i in indices:

        pontos.append(
            ponto_landmark(
                landmarks[i],
                largura,
                altura
            )
        )

    for i in range(
        len(pontos)
    ):

        cv2.line(
            frame,
            pontos[i],
            pontos[
                (i + 1)
                % len(pontos)
            ],
            cor,
            2
        )


def texto(
    frame,
    mensagem,
    posicao,
    escala=0.65,
    cor=(255, 255, 255),
    espessura=2
):
    cv2.putText(
        frame,
        mensagem,
        posicao,
        cv2.FONT_HERSHEY_SIMPLEX,
        escala,
        (0, 0, 0),
        espessura + 3,
        cv2.LINE_AA
    )

    cv2.putText(
        frame,
        mensagem,
        posicao,
        cv2.FONT_HERSHEY_SIMPLEX,
        escala,
        cor,
        espessura,
        cv2.LINE_AA
    )


# ============================================================
# INTERFACE
# ============================================================

def desenhar_painel(
    frame,
    dados
):
    x = 20
    y = 35

    texto(
        frame,
        f"Modo: {dados['modo']}",
        (x, y),
        0.55
    )

    y += 28

    texto(
        frame,
        f"EAR Esq: {dados['ear_esq']:.3f}",
        (x, y),
        0.55
    )

    y += 27

    texto(
        frame,
        f"EAR Dir: {dados['ear_dir']:.3f}",
        (x, y),
        0.55
    )

    y += 27

    texto(
        frame,
        f"EAR usado: {dados['ear']:.3f}",
        (x, y),
        0.55
    )

    y += 27

    texto(
        frame,
        f"Blink: {dados['blink']:.3f}",
        (x, y),
        0.55
    )

    y += 27

    texto(
        frame,
        f"MAR: {dados['mar']:.3f}",
        (x, y),
        0.55
    )

    y += 27

    texto(
        frame,
        f"Yaw: {dados['yaw']:.3f}",
        (x, y),
        0.55
    )

    y += 30

    texto(
        frame,
        f"PERCLOS: {dados['perclos'] * 100:.1f}%",
        (x, y),
        0.60
    )

    y += 28

    texto(
        frame,
        f"Piscadas/min: {dados['piscadas']}",
        (x, y),
        0.55
    )

    y += 28

    texto(
        frame,
        f"Bocejos/min: {dados['bocejos']}",
        (x, y),
        0.55
    )

    y += 28

    texto(
        frame,
        f"Fechamento: {dados['fechamento']:.2f}s",
        (x, y),
        0.55
    )

    y += 38

    texto(
        frame,
        f"SONOLENCIA: {dados['score']:.0f}%",
        (x, y),
        0.75,
        (0, 255, 255)
    )

    y += 38

    texto(
        frame,
        f"STATUS: {dados['status']}",
        (x, y),
        0.75,
        (
            (0, 255, 0)
            if dados["status"] == "NORMAL"
            else
            (0, 165, 255)
            if dados["status"] == "ATENCAO"
            else
            (0, 0, 255)
        )
    )

    # --------------------------------------------------------
    # INDICADORES
    # --------------------------------------------------------

    altura, largura = frame.shape[:2]

    if dados["olho_fechado"]:

        texto(
            frame,
            "OLHOS FECHADOS",
            (
                largura - 300,
                40
            ),
            0.65,
            (0, 0, 255)
        )

    if dados["pose_dificil"]:

        texto(
            frame,
            "POSE DIFICIL",
            (
                largura - 250,
                75
            ),
            0.55,
            (0, 165, 255)
        )

    if dados["bocejo"]:

        texto(
            frame,
            "POSSIVEL BOCEJO",
            (
                largura - 300,
                110
            ),
            0.55,
            (0, 255, 255)
        )


# ============================================================
# PROCESSAMENTO DE FRAME
# ============================================================

def processar_frame(
    frame,
    landmarker,
    face_mesh,
    historico
):
    resultado = detectar_rosto(
        landmarker,
        face_mesh,
        frame
    )

    agora = time.time()

    # --------------------------------------------------------
    # SEM ROSTO
    # --------------------------------------------------------

    if resultado is None:

        texto(
            frame,
            "ROSTO NAO DETECTADO",
            (20, 40),
            0.75,
            (0, 0, 255)
        )

        texto(
            frame,
            "Tentando novamente...",
            (20, 75),
            0.55
        )

        return frame

    # --------------------------------------------------------
    # LANDMARKS
    # --------------------------------------------------------

    landmarks = resultado[
        "landmarks"
    ]

    blendshapes = resultado[
        "blendshapes"
    ]

    altura, largura = frame.shape[:2]

    # --------------------------------------------------------
    # METRICAS
    # --------------------------------------------------------

    ear_esq, largura_esq = calcular_ear(
        landmarks,
        OLHO_ESQ,
        largura,
        altura
    )

    ear_dir, largura_dir = calcular_ear(
        landmarks,
        OLHO_DIR,
        largura,
        altura
    )

    mar = calcular_mar(
        landmarks,
        largura,
        altura
    )

    yaw = calcular_yaw(
        landmarks,
        largura,
        altura
    )

    olhos = analisar_olhos(
        ear_esq,
        ear_dir,
        largura_esq,
        largura_dir,
        blendshapes
    )

    olho_fechado = olhos[
        "fechado"
    ]

    blink = olhos[
        "blink"
    ]

    # --------------------------------------------------------
    # BOCA
    # --------------------------------------------------------

    boca_aberta = (
        mar >=
        MAR_LIMIAR
    )

    # --------------------------------------------------------
    # HISTORICO
    # --------------------------------------------------------

    historico.atualizar(
        agora,
        olho_fechado,
        boca_aberta
    )

    perclos = (
        historico.calcular_perclos()
    )

    fechamento = (
        historico.duracao_fechamento(
            agora
        )
    )

    piscadas = (
        historico.piscadas_por_minuto(
            agora
        )
    )

    bocejos = (
        historico.bocejos_por_minuto(
            agora
        )
    )

    # --------------------------------------------------------
    # SCORE
    # --------------------------------------------------------

    score = calcular_score_sonolencia(
        perclos,
        fechamento,
        piscadas,
        bocejos
    )

    status = classificar_score(
        score
    )

    # --------------------------------------------------------
    # DESENHO
    # --------------------------------------------------------

    desenhar_landmarks(
        frame,
        landmarks
    )

    desenhar_contorno(
        frame,
        landmarks,
        OLHO_ESQ,
        (255, 0, 0)
    )

    desenhar_contorno(
        frame,
        landmarks,
        OLHO_DIR,
        (255, 0, 0)
    )

    desenhar_contorno(
        frame,
        landmarks,
        BOCA,
        (0, 255, 255)
    )

    dados = {
        "modo": resultado["modo"],
        "ear_esq": ear_esq,
        "ear_dir": ear_dir,
        "ear": olhos["ear"],
        "blink": blink,
        "mar": mar,
        "yaw": yaw,
        "perclos": perclos,
        "piscadas": piscadas,
        "bocejos": bocejos,
        "fechamento": fechamento,
        "score": score,
        "status": status,
        "olho_fechado": olho_fechado,
        "pose_dificil": (
            abs(yaw) >
            YAW_POSE_DIFICIL
        ),
        "bocejo": (
            boca_aberta
            or
            historico.inicio_boca
            is not None
        ),
    }

    desenhar_painel(
        frame,
        dados
    )

    return frame


# ============================================================
# CAMERA
# ============================================================

def executar_camera():
    print()
    print("=" * 60)
    print("DETECCAO DE SONOLENCIA - CAMERA")
    print("=" * 60)
    print()
    print(
        "Pressione Q para sair."
    )
    print()

    landmarker = criar_face_landmarker()

    face_mesh = criar_face_mesh()

    camera = cv2.VideoCapture(
        CAMERA_ID
    )

    camera.set(
        cv2.CAP_PROP_FRAME_WIDTH,
        CAMERA_WIDTH
    )

    camera.set(
        cv2.CAP_PROP_FRAME_HEIGHT,
        CAMERA_HEIGHT
    )

    if not camera.isOpened():

        print(
            "[ERRO] Nao foi possivel abrir a camera."
        )

        face_mesh.close()

        if landmarker is not None:
            landmarker.close()

        return

    historico = (
        HistoricoSonolencia()
    )

    try:

        while True:

            sucesso, frame = (
                camera.read()
            )

            if not sucesso:

                print(
                    "[ERRO] Falha ao capturar frame."
                )

                break

            frame = processar_frame(
                frame,
                landmarker,
                face_mesh,
                historico
            )

            cv2.imshow(
                "Deteccao de Sonolencia",
                frame
            )

            tecla = (
                cv2.waitKey(1)
                & 0xFF
            )

            if tecla == ord("q"):

                break

    finally:

        camera.release()

        cv2.destroyAllWindows()

        face_mesh.close()

        if landmarker is not None:
            landmarker.close()


# ============================================================
# TESTE DE IMAGEM
# ============================================================

def executar_imagem(
    caminho
):
    print()
    print("=" * 60)
    print("TESTE DE IMAGEM")
    print("=" * 60)

    frame = cv2.imread(
        caminho
    )

    if frame is None:

        print(
            f"[ERRO] Nao foi possivel abrir: {caminho}"
        )

        return

    landmarker = criar_face_landmarker()

    face_mesh = criar_face_mesh()

    historico = (
        HistoricoSonolencia()
    )

    # Para imagem isolada nao existe historico
    # temporal suficiente para PERCLOS.
    #
    # Mesmo assim mostramos EAR / BLINK / MAR / YAW.

    frame = processar_frame(
        frame,
        landmarker,
        face_mesh,
        historico
    )

    saida = (
        "resultado_sonolencia.jpg"
    )

    cv2.imwrite(
        saida,
        frame
    )

    print()
    print(
        f"[OK] Resultado salvo em: {saida}"
    )

    cv2.imshow(
        "Resultado",
        frame
    )

    print(
        "Pressione qualquer tecla para fechar."
    )

    cv2.waitKey(0)

    cv2.destroyAllWindows()

    face_mesh.close()

    if landmarker is not None:
        landmarker.close()


# ============================================================
# MAIN
# ============================================================

def main():

    # --------------------------------------------------------
    # TESTE DE IMAGEM
    # --------------------------------------------------------

    if (
        len(sys.argv) >= 3
        and
        sys.argv[1] == "--imagem"
    ):

        executar_imagem(
            sys.argv[2]
        )

        return

    # --------------------------------------------------------
    # CAMERA
    # --------------------------------------------------------

    executar_camera()


if __name__ == "__main__":
    main()