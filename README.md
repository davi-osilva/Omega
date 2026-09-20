# Omega

Sistema de monitoramento de risco térmico para máquinas agrícolas.

O projeto reúne um dashboard web e um aplicativo Flutter conectados à API
Omega. A API roda em AWS Lambda, acessa as leituras armazenadas no RDS
PostgreSQL e calcula o risco térmico de cada máquina.

## Componentes

- **Dashboard Flask**: exibe a frota, scores, níveis de risco, histórico e relatório em PDF.
- **API Omega**: API Gateway + Lambda + RDS PostgreSQL.
- **Aplicativo Flutter**: monitoramento de sonolência e alertas por voz para o operador.

## Dashboard

O Flask funciona como um proxy seguro: o token da API fica apenas no ambiente do servidor e nunca é enviado ao navegador.

### Executar localmente

```bash
source .venv/bin/activate
pip install -r requirements.txt

export OMEGA_API_URL="https://SEU_ID.execute-api.us-east-1.amazonaws.com"
export OMEGA_API_TOKEN="seu_token"
export OMEGA_MAQUINAS="TRATOR_001"

python app.py
```

Abra <http://127.0.0.1:5000>.

O `OMEGA_API_TOKEN` deve conter somente o token. O servidor adiciona o prefixo `Bearer` ao fazer a chamada para a API.

## Rotas da API Omega

- `GET /`: verifica o estado da API.
- `GET /telemetria`: lista máquinas com leituras.
- `GET /telemetria/{maquina_id}`: consulta leituras recentes.
- `GET /telemetria/{maquina_id}/score`: consulta scores recentes.
- `POST /telemetria`: grava uma leitura e calcula o score.
- `POST /inspecao`: grava uma inferência visual.

## Arquitetura

```text
ESP32 / Flutter → API Gateway → Lambda → RDS PostgreSQL
                                  ↑
                         Dashboard Flask
```

O dashboard não acessa o RDS diretamente. A Lambda é responsável pela conexão com o banco, autenticação e cálculo do score.

## Variáveis da Lambda

A função `omega-api` precisa configurar, no mínimo:

```text
API_TOKEN
DB_HOST
DB_NAME
DB_USER
DB_PASSWORD
DB_SSL=1
```

Não versione valores reais dessas variáveis. O banco precisa conter as tabelas `telemetria`, `score_evento` e `inspecao_visual`.

## Estrutura

```text
app.py              Backend Flask do dashboard
dashboard/          Interface web
app/                Aplicativo Flutter
como_rodar.txt      Instruções operacionais detalhadas
requirements.txt    Dependências Python
```
