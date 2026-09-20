import io
import os
from datetime import datetime, timezone
from functools import lru_cache
from typing import Any
from urllib.parse import quote, urljoin

import requests
from flask import Flask, jsonify, request, send_from_directory, send_file
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas


app = Flask(__name__, static_folder="dashboard", static_url_path="")

REQUEST_TIMEOUT = float(os.getenv("OMEGA_TIMEOUT", "12"))
API_URL = (os.getenv("OMEGA_API_URL") or os.getenv("OMEGA_URL") or "").rstrip("/")
API_TOKEN = os.getenv("OMEGA_API_TOKEN") or os.getenv("OMEGA_TOKEN") or ""
MACHINE_IDS = tuple(
    item.strip() for item in (os.getenv("OMEGA_MAQUINAS") or "").split(",") if item.strip()
)


class OmegaError(RuntimeError):
    """Erro controlado ao consultar a API Omega."""


def _headers() -> dict[str, str]:
    headers = {"Accept": "application/json"}
    if API_TOKEN:
        token = API_TOKEN.strip()
        if token.lower().startswith("bearer "):
            token = token[7:].strip()
        headers["Authorization"] = f"Bearer {token}"
    return headers


def _omega_url(path: str) -> str:
    if not API_URL:
        raise OmegaError("OMEGA_API_URL não está configurada.")
    return urljoin(f"{API_URL}/", path.lstrip("/"))


def _get_json(path: str, params: dict[str, Any] | None = None) -> Any:
    try:
        response = requests.get(
            _omega_url(path),
            headers=_headers(),
            params=params,
            timeout=REQUEST_TIMEOUT,
        )
        if not response.ok:
            detalhe = response.text.strip().replace("\n", " ")
            if len(detalhe) > 300:
                detalhe = detalhe[:300] + "..."
            sufixo = f" — {detalhe}" if detalhe else ""
            raise OmegaError(f"API Omega respondeu HTTP {response.status_code}{sufixo}")
        return response.json()
    except requests.RequestException as exc:
        raise OmegaError(f"Não foi possível ler a API Omega: {exc}") from exc
    except ValueError as exc:
        raise OmegaError("A API Omega retornou uma resposta inválida.") from exc


def _unwrap(payload: Any, *keys: str) -> Any:
    if not isinstance(payload, dict):
        return payload
    for key in keys:
        value = payload.get(key)
        if value is not None:
            return value
    return payload


def _first(item: dict[str, Any], *keys: str, default: Any = None) -> Any:
    for key in keys:
        if key in item and item[key] is not None:
            return item[key]
    return default


def _number(value: Any) -> float | None:
    if value is None or value == "":
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _level(score: float | None, value: Any = None) -> str | None:
    if value:
        normalized = str(value).upper()
        aliases = {"BAIXO": "VERDE", "MEDIO": "AMARELO", "MÉDIO": "AMARELO", "ALTO": "VERMELHO"}
        return aliases.get(normalized, normalized)
    if score is None:
        return None
    if score >= 70:
        return "VERMELHO"
    if score >= 40:
        return "AMARELO"
    return "VERDE"


def _factors(item: dict[str, Any]) -> list[dict[str, Any]]:
    raw = _first(item, "fatores_json", "fatores", "factors", default=[])
    if isinstance(raw, str):
        return []
    if not isinstance(raw, list):
        return []
    return [factor for factor in raw if isinstance(factor, dict)]


def _normalize_reading(item: Any, machine_id: str | None = None) -> dict[str, Any]:
    item = item if isinstance(item, dict) else {}
    score = _number(_first(item, "score", "risk_score", "pontuacao"))
    machine = _first(item, "maquina_id", "machine_id", "maquina", "machine", default=machine_id)
    return {
        "maquina_id": str(machine) if machine is not None else "—",
        "temperatura": _number(_first(item, "temperatura", "temperature", "temp")),
        "temperatura_base": _number(_first(item, "temperatura_base", "baseline_temperature")),
        "umidade_pct": _number(_first(item, "umidade_pct", "umidade", "humidity")),
        "score": score,
        "nivel": _level(score, _first(item, "nivel", "level", "risco", "risk_level")),
        "data_hora": _first(item, "data_hora", "timestamp", "created_at", "updated_at", "data"),
        "fatores_json": _factors(item),
        "versao_regra": _first(item, "versao_regra", "versao", "model_version", default="omega-score"),
    }


def _readings_from_payload(payload: Any, machine_id: str | None = None) -> list[dict[str, Any]]:
    values = _unwrap(payload, "registros", "leituras", "telemetria", "data", "items")
    if isinstance(values, dict):
        values = [values]
    if not isinstance(values, list):
        return []
    return [_normalize_reading(value, machine_id) for value in values]


@lru_cache(maxsize=1)
def _configured_machine_ids() -> tuple[str, ...]:
    return MACHINE_IDS


def _latest_by_machine() -> dict[str, dict[str, Any]]:
    payload = _get_json("/telemetria")
    values = _unwrap(payload, "maquinas", "data", "items")
    if isinstance(values, dict):
        values = [values]

    machine_ids = []
    readings = []
    for value in values if isinstance(values, list) else []:
        if isinstance(value, str):
            machine_ids.append(value)
        else:
            readings.extend(_readings_from_payload([value]))

    latest: dict[str, dict[str, Any]] = {}
    for reading in readings:
        machine_id = reading["maquina_id"]
        if machine_id != "—":
            latest[machine_id] = reading

    # A API Omega retorna apenas IDs em GET /telemetria; o score fica em
    # GET /telemetria/{maquina_id}/score.
    for machine_id in dict.fromkeys(machine_ids + list(latest) + list(_configured_machine_ids())):
        if latest.get(machine_id, {}).get("score") is not None:
            continue
        try:
            history = _history(machine_id, 1)
        except OmegaError:
            continue
        if history:
            merged = {**latest.get(machine_id, {}), **history[0]}
            latest[machine_id] = merged
    return latest


def _history(machine_id: str, limit: int) -> list[dict[str, Any]]:
    encoded = quote(machine_id, safe="")
    for path in (f"/telemetria/{encoded}/score", f"/telemetria/{encoded}"):
        try:
            return _readings_from_payload(_get_json(path, {"limit": limit}), machine_id)
        except OmegaError:
            continue
    raise OmegaError(f"Não foi possível ler o histórico de {machine_id}.")


def _error(message: str, status: int = 503):
    return jsonify({"erro": message}), status


@app.get("/")
def index():
    return send_from_directory(app.static_folder, "index.html")


@app.get("/api/status")
def status():
    return jsonify({
        "api_configurada": bool(API_URL),
        "token_configurado": bool(API_TOKEN),
        "modelo_termico": bool(API_URL),
        "maquinas_configuradas": len(MACHINE_IDS),
    })


@app.get("/api/painel")
def painel():
    try:
        latest = _latest_by_machine()
        for machine_id in _configured_machine_ids() if not latest else ():
            latest.setdefault(machine_id, _normalize_reading({}, machine_id))
        machines = list(latest.values())
        counts = {"VERDE": 0, "AMARELO": 0, "VERMELHO": 0}
        for machine in machines:
            if machine["nivel"] in counts:
                counts[machine["nivel"]] += 1
        return jsonify({
            "resumo": {
                "total": len(machines),
                "verde": counts["VERDE"],
                "amarelo": counts["AMARELO"],
                "vermelho": counts["VERMELHO"],
                "sem_dados": sum(1 for machine in machines if machine["score"] is None),
            },
            "maquinas": machines,
        })
    except OmegaError as exc:
        return _error(str(exc))


@app.get("/api/score/<path:machine_id>")
def score(machine_id: str):
    try:
        limit = min(max(request.args.get("limit", 24, type=int), 1), 200)
        return jsonify({"registros": _history(machine_id, limit)})
    except OmegaError as exc:
        return _error(str(exc))


@app.post("/gerar-pdf")
def gerar_pdf():
    data = request.get_json(silent=True) or {}
    output = io.BytesIO()
    pdf = canvas.Canvas(output, pagesize=A4)
    width, height = A4
    pdf.setTitle("Relatório Omega")
    pdf.setFont("Helvetica-Bold", 18)
    pdf.drawString(48, height - 60, "Relatório Omega · risco térmico")
    pdf.setFont("Helvetica", 11)
    lines = [
        ("Máquina", data.get("maquina_id", "—")),
        ("Score", data.get("score", "—")),
        ("Nível", data.get("nivel", "—")),
        ("Temperatura", data.get("temperatura", "—")),
        ("Umidade", data.get("umidade_pct", "—")),
        ("Gerado em", datetime.now(timezone.utc).astimezone().strftime("%d/%m/%Y %H:%M")),
    ]
    y = height - 105
    for label, value in lines:
        pdf.drawString(48, y, f"{label}: {value}")
        y -= 22
    pdf.setFont("Helvetica-Bold", 12)
    pdf.drawString(48, y - 10, "Composição do score")
    pdf.setFont("Helvetica", 11)
    y -= 35
    for factor in data.get("fatores", []):
        if isinstance(factor, dict):
            name = factor.get("fator", "fator")
            contribution = factor.get("contribuicao", 0)
            pdf.drawString(60, y, f"{name}: {float(contribution) * 100:.1f} pts")
            y -= 18
    pdf.save()
    output.seek(0)
    filename = f"relatorio_omega_{data.get('maquina_id', 'maquina')}.pdf"
    return send_file(output, as_attachment=True, download_name=filename, mimetype="application/pdf")


if __name__ == "__main__":
    app.run(host=os.getenv("FLASK_HOST", "127.0.0.1"), port=int(os.getenv("PORT", "5000")), debug=False)