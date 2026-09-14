import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:mediapipe_face_mesh/mediapipe_face_mesh.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cameras = await availableCameras();

  runApp(
    OmegaApp(cameras: cameras),
  );
}

// ============================================================
// CORES
// ============================================================

const Color omegaBlue = Color(0xFF2563EB);
const Color omegaBlueLight = Color(0xFF60A5FA);
const Color omegaBackground = Color(0xFF08111C);
const Color omegaSurface = Color(0xFF101C2A);
const Color omegaSurfaceLight = Color(0xFF17283A);
const Color omegaText = Color(0xFFF3F6F8);
const Color omegaTextSecondary = Color(0xFF8FA1B2);

const Color statusGreen = Color(0xFF35A866);
const Color statusYellow = Color(0xFFF2B84B);
const Color statusOrange = Color(0xFFF47B20);
const Color statusRed = Color(0xFFE05252);

// ============================================================
// CONSTANTES DA DETECÇÃO
// Baseadas no detector Python do projeto
// ============================================================

// Olho esquerdo
const List<int> olhoEsq = [
  362,
  385,
  387,
  263,
  373,
  380,
];

// Olho direito
const List<int> olhoDir = [
  33,
  160,
  158,
  133,
  153,
  144,
];

// Boca
const List<int> boca = [
  78,
  81,
  13,
  311,
  308,
  402,
  14,
  178,
];

// Pose
const int narizYaw = 1;
const int cantoOlhoEsqYaw = 263;
const int cantoOlhoDirYaw = 33;

// Limiares
const double earFechado = 0.20;
const double earFechadoForte = 0.17;

const double fechamentoProlongadoSeg = 1.0;
const double fechamentoCriticoSeg = 2.0;

const double perclosAtencao = 0.15;
const double perclosAlerta = 0.30;

const int piscadasAlta = 25;

const double marBocejo = 0.60;
const double bocejoMinSeg = 0.8;

const double diferencaLarguraOlhosLimiar = 0.35;
const double yawPoseDificil = 0.55;

// Janela usada pelo PERCLOS
const double janelaPerclosSeg = 30.0;

// ============================================================
// APP
// ============================================================

class OmegaApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const OmegaApp({
    super.key,
    required this.cameras,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Omega',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: omegaBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: omegaBlue,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Arial',
        useMaterial3: true,
      ),
      home: OmegaHome(
        cameras: cameras,
      ),
    );
  }
}

// ============================================================
// HOME
// ============================================================

class OmegaHome extends StatefulWidget {
  final List<CameraDescription> cameras;

  const OmegaHome({
    super.key,
    required this.cameras,
  });

  @override
  State<OmegaHome> createState() => _OmegaHomeState();
}

class _OmegaHomeState extends State<OmegaHome> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: [
          const MachinePage(),
          MonitoringPage(
            cameras: widget.cameras,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        backgroundColor: omegaSurface,
        indicatorColor: omegaBlue.withOpacity(0.18),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.agriculture_outlined),
            selectedIcon: Icon(Icons.agriculture),
            label: 'Máquina',
          ),
          NavigationDestination(
            icon: Icon(Icons.visibility_outlined),
            selectedIcon: Icon(Icons.visibility),
            label: 'Monitoramento',
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HEADER DO OPERADOR
// ============================================================

class OperatorHeader extends StatelessWidget {
  const OperatorHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: omegaSurfaceLight,
            border: Border.all(
              color: Colors.white10,
            ),
          ),
          child: const Icon(
            Icons.person_outline,
            color: omegaTextSecondary,
            size: 25,
          ),
        ),

        const SizedBox(width: 12),

        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OPERADOR',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.3,
                color: omegaTextSecondary,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'João da Silva',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: omegaText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// PÁGINA DA MÁQUINA
// ============================================================

class MachinePage extends StatelessWidget {
  const MachinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const OperatorHeader(),

            const SizedBox(height: 24),

            // ------------------------------------------------
            // RISCO OPERACIONAL
            // ------------------------------------------------

            const Text(
              'RISCO OPERACIONAL',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: omegaTextSecondary,
              ),
            ),

            const SizedBox(height: 11),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: omegaSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white10,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: omegaBlue.withOpacity(0.10),
                          border: Border.all(
                            color: omegaBlue.withOpacity(0.35),
                            width: 2,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            '—',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: omegaText,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      const Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SCORE DE RISCO',
                              style: TextStyle(
                                fontSize: 10,
                                color: omegaTextSecondary,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Aguardando dados',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: omegaText,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Análise operacional em tempo real',
                              style: TextStyle(
                                fontSize: 11,
                                color: omegaTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'BAIXO',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: omegaTextSecondary,
                        ),
                      ),
                      Text(
                        'ALTO',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: omegaTextSecondary,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Row(
                    children: [
                      Expanded(
                        child: _RiskFactor(
                          icon: Icons.thermostat_outlined,
                          title: 'TEMPERATURA',
                          value: '—',
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: _RiskFactor(
                          icon: Icons.water_drop_outlined,
                          title: 'UMIDADE',
                          value: '—',
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: _RiskFactor(
                          icon: Icons.visibility_outlined,
                          title: 'ATENÇÃO',
                          value: '—',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 22),

            // ------------------------------------------------
            // TELEMETRIA
            // ------------------------------------------------

            const Text(
              'TELEMETRIA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: omegaTextSecondary,
              ),
            ),

            const SizedBox(height: 11),

            Row(
              children: [
                Expanded(
                  child: _TelemetryCard(
                    icon: Icons.thermostat_outlined,
                    title: 'TEMPERATURA',
                    value: '—',
                    unit: '°C',
                  ),
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: _TelemetryCard(
                    icon: Icons.water_drop_outlined,
                    title: 'UMIDADE',
                    value: '—',
                    unit: '%',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MONITORAMENTO
// ============================================================

class MonitoringPage extends StatefulWidget {
  final List<CameraDescription> cameras;

  const MonitoringPage({
    super.key,
    required this.cameras,
  });

  @override
  State<MonitoringPage> createState() => _MonitoringPageState();
}

class _MonitoringPageState extends State<MonitoringPage>
    with WidgetsBindingObserver {

  CameraController? _cameraController;

  FaceDetectorProcessor? _faceDetector;
  FaceMeshProcessor? _faceMesh;

  FaceMeshInferencePipeline? _pipeline;
  FaceMeshInferenceStreamProcessor? _streamProcessor;

  StreamController<FaceMeshNv21Image>? _frameController;
  StreamSubscription<FaceMeshInferenceResult>? _inferenceSubscription;

  bool _cameraActive = false;
  bool _processingFrame = false;
  bool _initializing = false;

  String? _error;

  // Resultados
  double? _ear;
  double? _mar;
  double? _perclos;
  double? _drowsinessScore;

  int _blinksPerMinute = 0;
  int _yawnsPerMinute = 0;

  String _status = 'Monitoramento parado';

  // ==========================================================
  // HISTÓRICO TEMPORAL
  // ==========================================================

  final List<_EyeSample> _eyeHistory = [];

  final List<DateTime> _blinkTimes = [];

  final List<DateTime> _yawnTimes = [];

  DateTime? _eyesClosedSince;

  DateTime? _yawnStarted;

  DateTime? _lastBlinkTime;

  DateTime? _lastYawnTime;

  // Controle para não processar frames demais
  DateTime? _lastInferenceTime;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _stopMonitoring();

    super.dispose();
  }

  // ==========================================================
  // INICIALIZA MEDIA PIPE
  // ==========================================================

  Future<void> _initializeMediaPipe() async {
    if (_faceMesh != null && _faceDetector != null) {
      return;
    }

    _faceDetector = await FaceDetectorProcessor.create(
      model: FaceDetectionModel.shortRange,
      delegate: FaceMeshDelegate.xnnpack,
      maxResults: 1,
      roiScaleY: 1.7,
      roiShiftY: -0.2,
    );

    _faceMesh = await FaceMeshProcessor.create(
      model: FaceMeshModel.v2,
      enableIris: true,
      delegate: FaceMeshDelegate.xnnpack,
    );

    _pipeline = FaceMeshInferencePipeline(
      detector: _faceDetector!,
      mesh: _faceMesh!,
      landmarkSmoothing: const LandmarkSmoothingOptions(),
    );

    _streamProcessor = FaceMeshInferenceStreamProcessor(
      _pipeline!,
    );
  }

  // ==========================================================
  // INICIA MONITORAMENTO
  // ==========================================================

  Future<void> _startMonitoring() async {
    if (_initializing || _cameraActive) {
      return;
    }

    if (widget.cameras.isEmpty) {
      setState(() {
        _error = 'Nenhuma câmera encontrada.';
      });
      return;
    }

    setState(() {
      _initializing = true;
      _error = null;
    });

    try {
      await _initializeMediaPipe();

      final frontCamera = widget.cameras.firstWhere(
        (camera) =>
            camera.lensDirection ==
            CameraLensDirection.front,
        orElse: () => widget.cameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      _cameraController = controller;

      await controller.initialize();

      await _startInferenceStream();

      await controller.startImageStream(
        _handleCameraFrame,
      );

      _resetDetectionHistory();

      if (mounted) {
        setState(() {
          _cameraActive = true;
          _status = 'Monitoramento ativo';
        });
      }
    } catch (e) {
      await _stopMonitoring();

      if (mounted) {
        setState(() {
          _error = 'Erro ao iniciar câmera: $e';
          _status = 'Erro no monitoramento';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }
    }
  }

  // ==========================================================
  // STREAM DO MEDIAPIPE
  // ==========================================================

  Future<void> _startInferenceStream() async {
    await _inferenceSubscription?.cancel();

    await _frameController?.close();

    _frameController =
        StreamController<FaceMeshNv21Image>();

    _inferenceSubscription =
        _streamProcessor!
            .processNv21(
              _frameController!.stream,
              runMeshResolver: (_) => true,
              rotationDegrees:
                  _cameraController!
                      .description
                      .sensorOrientation,
              mirrorHorizontal: true,
            )
            .listen(
              _handleInferenceResult,
              onError: _handleInferenceError,
            );
  }

  // ==========================================================
  // RECEBE FRAME DA CÂMERA
  // ==========================================================

  void _handleCameraFrame(CameraImage image) {
    if (!_cameraActive) {
      return;
    }

    if (_processingFrame) {
      return;
    }

    final now = DateTime.now();

    // Aproximadamente 15 FPS de análise.
    if (_lastInferenceTime != null &&
        now.difference(_lastInferenceTime!)
                .inMilliseconds <
            66) {
      return;
    }

    _lastInferenceTime = now;

    try {
      if (image.format.group !=
          ImageFormatGroup.yuv420) {
        return;
      }

      if (image.planes.length < 3) {
        return;
      }

      final yPlane = FaceMeshImagePlane(
        bytes: image.planes[0].bytes,
        bytesPerRow: image.planes[0].bytesPerRow,
        bytesPerPixel:
            image.planes[0].bytesPerPixel,
      );

      final uPlane = FaceMeshImagePlane(
        bytes: image.planes[1].bytes,
        bytesPerRow: image.planes[1].bytesPerRow,
        bytesPerPixel:
            image.planes[1].bytesPerPixel,
      );

      final vPlane = FaceMeshImagePlane(
        bytes: image.planes[2].bytes,
        bytesPerRow: image.planes[2].bytesPerRow,
        bytesPerPixel:
            image.planes[2].bytesPerPixel,
      );

      final nv21 =
          FaceMeshNv21Image.tryFromYuv420Planes(
        width: image.width,
        height: image.height,
        yPlane: yPlane,
        uPlane: uPlane,
        vPlane: vPlane,
      );

      if (nv21 == null) {
        return;
      }

      if (_frameController == null ||
          _frameController!.isClosed) {
        return;
      }

      _processingFrame = true;

      _frameController!.add(nv21);
    } catch (e) {
      _processingFrame = false;

      if (mounted) {
        setState(() {
          _error = '$e';
        });
      }
    }
  }

  // ==========================================================
  // RESULTADO DO MEDIAPIPE
  // ==========================================================

  void _handleInferenceResult(
    FaceMeshInferenceResult result,
  ) {
    _processingFrame = false;

    final mesh = result.meshResult;

    if (mesh == null ||
        mesh.landmarks.length < 468) {
      if (mounted) {
        setState(() {
          _status = 'Rosto não identificado';
        });
      }

      return;
    }

    _processLandmarks(mesh);
  }

  void _handleInferenceError(Object error) {
    _processingFrame = false;

    if (mounted) {
      setState(() {
        _error = 'MediaPipe: $error';
      });
    }
  }

  // ==========================================================
  // PROCESSAMENTO DOS LANDMARKS
  // ==========================================================

  void _processLandmarks(FaceMeshResult result) {
    final landmarks = result.landmarks;

    final leftEar = _calculateEar(
      landmarks,
      olhoEsq,
    );

    final rightEar = _calculateEar(
      landmarks,
      olhoDir,
    );

    final ear =
        (leftEar + rightEar) / 2.0;

    final mar =
        _calculateMar(
          landmarks,
        );

    final yaw =
        _calculateYaw(
          landmarks,
        );

    final now = DateTime.now();

    _registerEyeState(
      now,
      ear,
    );

    _registerBlink(
      now,
      ear,
    );

    _registerYawn(
      now,
      mar,
    );

    final perclos =
        _calculatePerclos(now);

    _removeOldEvents(now);

    final score =
        _calculateDrowsinessScore(
      perclos: perclos,
      closingDuration:
          _currentClosingDuration(now),
      blinksPerMinute:
          _blinksPerMinute,
      yawnsPerMinute:
          _yawnsPerMinute,
    );

    final status =
        _classifyScore(score);

    if (mounted) {
      setState(() {
        _ear = ear;
        _mar = mar;
        _perclos = perclos;
        _drowsinessScore = score;

        _status =
            yaw.abs() > yawPoseDificil
                ? 'Ajuste a posição do rosto'
                : status;
      });
    }
  }

  // ==========================================================
  // EAR
  // ==========================================================

  double _calculateEar(
    List<FaceMeshLandmark> landmarks,
    List<int> indices,
  ) {
    final points = indices
        .map(
          (index) => landmarks[index],
        )
        .toList();

    final p1 = points[0];
    final p2 = points[1];
    final p3 = points[2];
    final p4 = points[3];
    final p5 = points[4];
    final p6 = points[5];

    final vertical1 =
        _distance(p2, p6);

    final vertical2 =
        _distance(p3, p5);

    final horizontal =
        _distance(p1, p4);

    if (horizontal <= 0) {
      return 0;
    }

    return (
      vertical1 + vertical2
    ) / (
      2 * horizontal
    );
  }

  // ==========================================================
  // MAR
  // ==========================================================

  double _calculateMar(
    List<FaceMeshLandmark> landmarks,
  ) {
    final points = boca
        .map(
          (index) => landmarks[index],
        )
        .toList();

    final p1 = points[0];
    final p2 = points[1];
    final p3 = points[2];
    final p4 = points[3];
    final p5 = points[4];
    final p6 = points[5];
    final p7 = points[6];
    final p8 = points[7];

    final horizontal =
        _distance(p1, p4);

    if (horizontal <= 0) {
      return 0;
    }

    final vertical1 =
        _distance(p2, p8);

    final vertical2 =
        _distance(p3, p7);

    final vertical3 =
        _distance(p5, p6);

    return (
      vertical1 +
      vertical2 +
      vertical3
    ) / (
      3 * horizontal
    );
  }

  // ==========================================================
  // YAW
  // ==========================================================

  double _calculateYaw(
    List<FaceMeshLandmark> landmarks,
  ) {
    final nariz =
        landmarks[narizYaw];

    final olhoEsq =
        landmarks[cantoOlhoEsqYaw];

    final olhoDir =
        landmarks[cantoOlhoDirYaw];

    final xMin =
        math.min(
          olhoEsq.x,
          olhoDir.x,
        );

    final xMax =
        math.max(
          olhoEsq.x,
          olhoDir.x,
        );

    final eyeWidth =
        xMax - xMin;

    if (eyeWidth <= 0) {
      return 0;
    }

    final centerEyes =
        (xMin + xMax) / 2;

    return (
      nariz.x - centerEyes
    ) / eyeWidth;
  }

  // ==========================================================
  // DISTÂNCIA
  // ==========================================================

  double _distance(
    FaceMeshLandmark a,
    FaceMeshLandmark b,
  ) {
    final dx = a.x - b.x;
    final dy = a.y - b.y;

    return math.sqrt(
      dx * dx + dy * dy,
    );
  }

  // ==========================================================
  // HISTÓRICO DOS OLHOS
  // ==========================================================

  void _registerEyeState(
    DateTime now,
    double ear,
  ) {
    _eyeHistory.add(
      _EyeSample(
        time: now,
        closed:
            ear <= earFechado,
      ),
    );

    final limit =
        now.subtract(
      const Duration(
        seconds: 30,
      ),
    );

    _eyeHistory.removeWhere(
      (sample) =>
          sample.time.isBefore(limit),
    );

    if (ear <= earFechado) {
      _eyesClosedSince ??= now;
    } else {
      _eyesClosedSince = null;
    }
  }

  // ==========================================================
  // PISCADAS
  // ==========================================================

  void _registerBlink(
    DateTime now,
    double ear,
  ) {
    final closed =
        ear <= earFechado;

    if (!closed &&
        _eyesClosedSince != null) {
      final duration =
          now.difference(
            _eyesClosedSince!,
          );

      // Uma piscada normal:
      // fechamento menor que 1 segundo.
      if (duration.inMilliseconds >= 80 &&
          duration.inMilliseconds <
              1000) {

        if (_lastBlinkTime == null ||
            now
                    .difference(
                      _lastBlinkTime!,
                    )
                    .inMilliseconds >
                250) {
          _blinkTimes.add(now);
          _lastBlinkTime = now;
        }
      }

      _eyesClosedSince = null;
    }

    _removeOldEvents(now);
  }

  // ==========================================================
  // BOCEJO
  // ==========================================================

  void _registerYawn(
    DateTime now,
    double mar,
  ) {
    if (mar >= marBocejo) {
      _yawnStarted ??= now;
      return;
    }

    if (_yawnStarted == null) {
      return;
    }

    final duration =
        now.difference(
          _yawnStarted!,
        );

    if (duration.inMilliseconds >=
            bocejoMinSeg * 1000 &&
        (_lastYawnTime == null ||
            now
                    .difference(
                      _lastYawnTime!,
                    )
                    .inMilliseconds >
                1500)) {
      _yawnTimes.add(now);
      _lastYawnTime = now;
    }

    _yawnStarted = null;

    _removeOldEvents(now);
  }

  // ==========================================================
  // PERCLOS
  // ==========================================================

  double _calculatePerclos(
    DateTime now,
  ) {
    final limit =
        now.subtract(
      const Duration(
        seconds: 30,
      ),
    );

    final recent =
        _eyeHistory.where(
      (sample) =>
          sample.time.isAfter(limit),
    );

    int total = 0;
    int closed = 0;

    for (final sample in recent) {
      total++;

      if (sample.closed) {
        closed++;
      }
    }

    if (total == 0) {
      return 0;
    }

    return closed / total;
  }

  // ==========================================================
  // TEMPO DE FECHAMENTO
  // ==========================================================

  double _currentClosingDuration(
    DateTime now,
  ) {
    if (_eyesClosedSince == null) {
      return 0;
    }

    return now
            .difference(
              _eyesClosedSince!,
            )
            .inMilliseconds /
        1000.0;
  }

  // ==========================================================
  // EVENTOS POR MINUTO
  // ==========================================================

  void _removeOldEvents(
    DateTime now,
  ) {
    final limit =
        now.subtract(
      const Duration(
        minutes: 1,
      ),
    );

    _blinkTimes.removeWhere(
      (time) => time.isBefore(limit),
    );

    _yawnTimes.removeWhere(
      (time) => time.isBefore(limit),
    );

    _blinksPerMinute =
        _blinkTimes.length;

    _yawnsPerMinute =
        _yawnTimes.length;
  }

  // ==========================================================
  // SCORE
  // ==========================================================

  double _calculateDrowsinessScore({
    required double perclos,
    required double closingDuration,
    required int blinksPerMinute,
    required int yawnsPerMinute,
  }) {
    double score = 0;

    // --------------------------------------------------------
    // PERCLOS
    // --------------------------------------------------------

    if (perclos >= perclosAlerta) {
      score += 55;
    } else if (perclos >= perclosAtencao) {
      final proportion =
          (perclos - perclosAtencao) /
          (perclosAlerta - perclosAtencao);

      score +=
          20 +
          35 *
              proportion.clamp(
                0.0,
                1.0,
              );
    }

    // --------------------------------------------------------
    // FECHAMENTO PROLONGADO
    // --------------------------------------------------------

    if (closingDuration >=
        fechamentoCriticoSeg) {
      score += 40;
    } else if (closingDuration >=
        fechamentoProlongadoSeg) {
      final proportion =
          (closingDuration -
                  fechamentoProlongadoSeg) /
              (fechamentoCriticoSeg -
                  fechamentoProlongadoSeg);

      score +=
          20 +
          20 *
              proportion.clamp(
                0.0,
                1.0,
              );
    }

    // --------------------------------------------------------
    // PISCADAS
    // --------------------------------------------------------

    if (blinksPerMinute >=
        piscadasAlta) {
      score += 10;
    } else if (blinksPerMinute >= 18) {
      score += 5;
    }

    // --------------------------------------------------------
    // BOCEJOS
    // --------------------------------------------------------

    if (yawnsPerMinute >= 3) {
      score += 15;
    } else if (yawnsPerMinute >= 1) {
      score += 7;
    }

    return score.clamp(
      0,
      100,
    );
  }

  // ==========================================================
  // CLASSIFICAÇÃO
  // ==========================================================

  String _classifyScore(
    double score,
  ) {
    if (score >= 60) {
      return 'ALERTA';
    }

    if (score >= 30) {
      return 'ATENÇÃO';
    }

    return 'NORMAL';
  }

  // ==========================================================
  // RESET
  // ==========================================================

  void _resetDetectionHistory() {
    _eyeHistory.clear();
    _blinkTimes.clear();
    _yawnTimes.clear();

    _eyesClosedSince = null;
    _yawnStarted = null;

    _lastBlinkTime = null;
    _lastYawnTime = null;
    _lastInferenceTime = null;

    _ear = null;
    _mar = null;
    _perclos = null;
    _drowsinessScore = null;

    _blinksPerMinute = 0;
    _yawnsPerMinute = 0;
  }

  // ==========================================================
  // PARA MONITORAMENTO
  // ==========================================================

  Future<void> _stopMonitoring() async {
    try {
      final controller =
          _cameraController;

      if (controller != null &&
          controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {}

    try {
      await _inferenceSubscription?.cancel();
    } catch (_) {}

    _inferenceSubscription = null;

    try {
      await _frameController?.close();
    } catch (_) {}

    _frameController = null;

    try {
      await _cameraController?.dispose();
    } catch (_) {}

    _cameraController = null;

    try {
      _faceDetector?.close();
    } catch (_) {}

    try {
      _faceMesh?.close();
    } catch (_) {}

    _faceDetector = null;
    _faceMesh = null;
    _pipeline = null;
    _streamProcessor = null;

    _cameraActive = false;
    _processingFrame = false;
  }

  // ==========================================================
  // UI
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    final score =
        _drowsinessScore;

    final attention =
        score == null
            ? null
            : (100 - score)
                .clamp(0, 100);

    return SafeArea(
      child: SingleChildScrollView(
        padding:
            const EdgeInsets.fromLTRB(
          22,
          18,
          22,
          30,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'Atenção em tempo real.',
              style: TextStyle(
                fontSize: 31,
                height: 1.15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.7,
                color: omegaText,
              ),
            ),

            const SizedBox(height: 9),

            const Text(
              'Use a câmera frontal para monitorar '
              'sinais de sonolência.',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: omegaTextSecondary,
              ),
            ),

            const SizedBox(height: 28),

            // ------------------------------------------------
            // CÂMERA
            // ------------------------------------------------

            Container(
              height: 280,
              width: double.infinity,
              clipBehavior:
                  Clip.antiAlias,
              decoration: BoxDecoration(
                color:
                    const Color(0xFF050A0F),
                borderRadius:
                    BorderRadius.circular(22),
                border: Border.all(
                  color: Colors.white10,
                ),
              ),
              child:
                  _cameraController != null &&
                          _cameraController!
                              .value
                              .isInitialized
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            CameraPreview(
                              _cameraController!,
                            ),

                            Positioned(
                              top: 15,
                              left: 15,
                              child:
                                  _CameraStatus(
                                active:
                                    _cameraActive,
                              ),
                            ),

                            if (_drowsinessScore !=
                                null)
                              Positioned(
                                left: 15,
                                right: 15,
                                bottom: 15,
                                child:
                                    _LiveStatusOverlay(
                                  status:
                                      _status,
                                  score:
                                      _drowsinessScore!,
                                ),
                              ),
                          ],
                        )
                      : Stack(
                          children: [
                            const Center(
                              child: Icon(
                                Icons
                                    .videocam_outlined,
                                size: 58,
                                color:
                                    Colors.white24,
                              ),
                            ),

                            Positioned(
                              top: 15,
                              left: 15,
                              child:
                                  _CameraStatus(
                                active:
                                    false,
                              ),
                            ),

                            if (_error != null)
                              Positioned(
                                left: 15,
                                right: 15,
                                bottom: 15,
                                child:
                                    Container(
                                  padding:
                                      const EdgeInsets
                                          .all(12),
                                  decoration:
                                      BoxDecoration(
                                    color:
                                        Colors.black54,
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      12,
                                    ),
                                  ),
                                  child: Text(
                                    _error!,
                                    style:
                                        const TextStyle(
                                      fontSize: 11,
                                      color:
                                          Colors.white70,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
            ),

            const SizedBox(height: 20),

            // ------------------------------------------------
            // STATUS
            // ------------------------------------------------

            Container(
              padding:
                  const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: omegaSurface,
                borderRadius:
                    BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white10,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 45,
                    height: 45,
                    decoration:
                        BoxDecoration(
                      color: _statusColor(
                        _status,
                      ).withOpacity(0.12),
                      borderRadius:
                          BorderRadius.circular(
                        13,
                      ),
                    ),
                    child: Icon(
                      Icons
                          .monitor_heart_outlined,
                      color: _statusColor(
                        _status,
                      ),
                    ),
                  ),

                  const SizedBox(width: 13),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'STATUS',
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                omegaTextSecondary,
                            fontWeight:
                                FontWeight.bold,
                            letterSpacing:
                                1.2,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Text(
                          _status,
                          style:
                              const TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.w600,
                            color:
                                omegaText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // ------------------------------------------------
            // MÉTRICAS
            // ------------------------------------------------

            Row(
              children: [
                Expanded(
                  child: _Metric(
                    icon: Icons
                        .remove_red_eye_outlined,
                    title: 'ATENÇÃO',
                    value:
                        attention == null
                            ? '—'
                            : '${attention.toStringAsFixed(0)}%',
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _Metric(
                    icon: Icons
                        .bedtime_outlined,
                    title: 'SONOLÊNCIA',
                    value:
                        score == null
                            ? '—'
                            : '${score.toStringAsFixed(0)}%',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _Metric(
                    icon: Icons
                        .visibility_outlined,
                    title: 'PERCLOS',
                    value:
                        _perclos == null
                            ? '—'
                            : '${(_perclos! * 100).toStringAsFixed(1)}%',
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _Metric(
                    icon: Icons
                        .airline_seat_recline_normal,
                    title: 'BOCEJOS/MIN',
                    value:
                        '$_yawnsPerMinute',
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // ------------------------------------------------
            // BOTÃO
            // ------------------------------------------------

            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed:
                    _initializing
                        ? null
                        : _cameraActive
                            ? _stopMonitoring
                            : _startMonitoring,
                icon: Icon(
                  _cameraActive
                      ? Icons.stop
                      : Icons
                          .camera_alt_outlined,
                ),
                label: Text(
                  _initializing
                      ? 'INICIALIZANDO...'
                      : _cameraActive
                          ? 'PARAR MONITORAMENTO'
                          : 'INICIAR MONITORAMENTO',
                  style:
                      const TextStyle(
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w800,
                    letterSpacing:
                        0.6,
                  ),
                ),
                style:
                    FilledButton.styleFrom(
                  backgroundColor:
                      _cameraActive
                          ? statusRed
                          : omegaBlue,
                  foregroundColor:
                      Colors.white,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      15,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // ------------------------------------------------
            // DETECÇÃO
            // ------------------------------------------------

            Container(
              padding:
                  const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: omegaSurface,
                borderRadius:
                    BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white10,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DETECÇÃO',
                    style: TextStyle(
                      fontSize: 10,
                      color: omegaBlueLight,
                      fontWeight:
                          FontWeight.bold,
                      letterSpacing: 1.4,
                    ),
                  ),

                  const SizedBox(height: 7),

                  const Text(
                    'O OMEGA analisa os olhos e a boca '
                    'do operador em tempo real para '
                    'identificar sinais de sonolência.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color:
                          omegaTextSecondary,
                    ),
                  ),

                  if (_ear != null) ...[
                    const SizedBox(height: 14),

                    Row(
                      children: [
                        _DetectionChip(
                          label: 'EAR',
                          value:
                              _ear!.toStringAsFixed(
                            2,
                          ),
                        ),

                        const SizedBox(width: 8),

                        _DetectionChip(
                          label: 'MAR',
                          value:
                              _mar!.toStringAsFixed(
                            2,
                          ),
                        ),

                        const SizedBox(width: 8),

                        _DetectionChip(
                          label: 'PISCADAS',
                          value:
                              '$_blinksPerMinute/min',
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(
    String status,
  ) {
    switch (status) {
      case 'ALERTA':
        return statusRed;

      case 'ATENÇÃO':
        return statusYellow;

      case 'Rosto não identificado':
        return statusOrange;

      case 'NORMAL':
        return statusGreen;

      default:
        return omegaBlueLight;
    }
  }
}

// ============================================================
// AMOSTRA DOS OLHOS
// ============================================================

class _EyeSample {
  final DateTime time;
  final bool closed;

  const _EyeSample({
    required this.time,
    required this.closed,
  });
}

// ============================================================
// STATUS DA CÂMERA
// ============================================================

class _CameraStatus extends StatelessWidget {
  final bool active;

  const _CameraStatus({
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius:
            BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            Icons.circle,
            color:
                active
                    ? statusGreen
                    : Colors.white38,
            size: 8,
          ),

          const SizedBox(width: 7),

          Text(
            active
                ? 'MONITORANDO'
                : 'CÂMERA',
            style:
                const TextStyle(
              fontSize: 9,
              fontWeight:
                  FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// OVERLAY DO STATUS
// ============================================================

class _LiveStatusOverlay
    extends StatelessWidget {
  final String status;
  final double score;

  const _LiveStatusOverlay({
    required this.status,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    Color color;

    switch (status) {
      case 'ALERTA':
        color = statusRed;
        break;

      case 'ATENÇÃO':
        color = statusYellow;
        break;

      default:
        color = statusGreen;
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              status,
              style:
                  const TextStyle(
                fontSize: 12,
                fontWeight:
                    FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),

          Text(
            '${score.toStringAsFixed(0)}%',
            style:
                const TextStyle(
              fontSize: 12,
              fontWeight:
                  FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CHIP DE DETECÇÃO
// ============================================================

class _DetectionChip
    extends StatelessWidget {
  final String label;
  final String value;

  const _DetectionChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color:
              omegaSurfaceLight
                  .withOpacity(0.45),
          borderRadius:
              BorderRadius.circular(11),
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style:
                  const TextStyle(
                fontSize: 8,
                fontWeight:
                    FontWeight.bold,
                letterSpacing: 0.6,
                color:
                    omegaTextSecondary,
              ),
            ),

            const SizedBox(height: 3),

            Text(
              value,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                fontSize: 12,
                fontWeight:
                    FontWeight.w700,
                color: omegaText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// FATOR DE RISCO
// ============================================================

class _RiskFactor
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _RiskFactor({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color:
            omegaSurfaceLight
                .withOpacity(0.45),
        borderRadius:
            BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color:
                omegaTextSecondary,
          ),

          const SizedBox(height: 9),

          Text(
            title,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style:
                const TextStyle(
              fontSize: 8,
              fontWeight:
                  FontWeight.bold,
              letterSpacing: 0.5,
              color:
                  omegaTextSecondary,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            value,
            style:
                const TextStyle(
              fontSize: 15,
              fontWeight:
                  FontWeight.w700,
              color: omegaText,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CARD DE TELEMETRIA
// ============================================================

class _TelemetryCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String unit;

  const _TelemetryCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: omegaSurface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white10,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 21,
            color:
                omegaTextSecondary,
          ),

          const SizedBox(height: 14),

          Text(
            title,
            style:
                const TextStyle(
              fontSize: 9,
              color:
                  omegaTextSecondary,
              fontWeight:
                  FontWeight.bold,
              letterSpacing: 1,
            ),
          ),

          const SizedBox(height: 5),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style:
                    const TextStyle(
                  fontSize: 25,
                  fontWeight:
                      FontWeight.w700,
                  color: omegaText,
                ),
              ),

              const SizedBox(width: 3),

              Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 3,
                ),
                child: Text(
                  unit,
                  style:
                      const TextStyle(
                    fontSize: 11,
                    color:
                        omegaTextSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MÉTRICA
// ============================================================

class _Metric
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _Metric({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color:
            omegaSurfaceLight
                .withOpacity(0.55),
        borderRadius:
            BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color:
                omegaTextSecondary,
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 8,
                    color:
                        omegaTextSecondary,
                    fontWeight:
                        FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  style:
                      const TextStyle(
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                    color: omegaText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
