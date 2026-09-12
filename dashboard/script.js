const ROTULO_NIVEL = { VERDE: "Baixo", AMARELO: "Médio", VERMELHO: "Alto" };
const CLASSE_TAG = { VERDE: "risk-low", AMARELO: "risk-med", VERMELHO: "risk-high" };
const CLASSE_BARRA = { VERDE: "baixo", AMARELO: "medio", VERMELHO: "alto" };
const TITULOS = {
  frota: ["Frota", "Estado atual"],
  maquina: ["Máquina", "Cálculo e histórico"],
};
const HISTORICO_LIMITE = 24;

let maquinaFoco = null;

function formatarData(iso) {
  if (!iso) return "sem leitura";
  const data = new Date(iso);
  if (Number.isNaN(data.getTime())) return iso;
  return data.toLocaleString("pt-BR", { dateStyle: "short", timeStyle: "short" });
}

function tagDeNivel(nivel) {
  if (!nivel) return `<span class="tag"><span class="mini-dot"></span>sem dados</span>`;
  return `<span class="tag ${CLASSE_TAG[nivel] || ""}"><span class="mini-dot"></span>${ROTULO_NIVEL[nivel] || nivel}</span>`;
}

function barraScore(score, nivel) {
  const pct = Math.max(0, Math.min(100, Number(score) || 0));
  return `<div class="score-cell"><span class="score-num">${score != null ? score : "—"}</span><span class="score-bar ${CLASSE_BARRA[nivel] || ""}"><i style="width:${pct}%"></i></span></div>`;
}

async function buscarJson(url, opcoes) {
  const resposta = await fetch(url, opcoes);
  const corpo = await resposta.json().catch(() => ({}));
  if (!resposta.ok) throw new Error(corpo.erro || `Erro HTTP ${resposta.status}`);
  return corpo;
}

function irPara(rota) {
  document.querySelectorAll("[data-route]").forEach((item) => {
    item.classList.toggle("active", item.dataset.route === rota);
  });
  document.querySelectorAll(".page").forEach((pagina) => {
    pagina.classList.toggle("active", pagina.dataset.page === rota);
  });
  const titulo = TITULOS[rota];
  if (titulo) {
    document.getElementById("crumb").textContent = titulo[0];
    document.getElementById("pageTitle").textContent = titulo[1];
  }
  fecharMenu();

  // Garante que o gráfico calcule o tamanho certo ao abrir a aba "Máquina"
  if (rota === "maquina" && window._historico) {
    setTimeout(() => {
      desenharSpark(document.getElementById("spark-score"), window._historico);
    }, 50);
  }
}

function fecharMenu() {
  document.getElementById("sidebar")?.classList.remove("open");
  document.getElementById("sidebar-backdrop")?.classList.remove("show");
}

async function carregarPainel() {
  const pontoApi = document.getElementById("dot-api");
  const pontoModelo = document.getElementById("dot-modelo");
  const pill = document.getElementById("status-pill");

  try {
    const status = await buscarJson("/api/status");
    window._status = status;
    pontoApi?.classList.add("online");
    pontoModelo?.classList.toggle("online", !!status.modelo_termico);
    if (pill) pill.textContent = "Online";
  } catch (erro) {
    pontoApi?.classList.remove("online");
    pontoModelo?.classList.remove("online");
    if (pill) pill.textContent = "Offline";
    console.error(erro);
  }

  let painel;
  try {
    painel = await buscarJson("/api/painel");
  } catch (erro) {
    document.getElementById("ranking-body").innerHTML =
      `<tr><td colspan="5" class="empty-state">${erro.message}</td></tr>`;
    return;
  }

  window._painel = painel;
  const r = painel.resumo || {};
  document.getElementById("kpi-total").textContent = r.total ?? "—";
  document.getElementById("kpi-vermelho").textContent = r.vermelho ?? "—";
  document.getElementById("kpi-amarelo").textContent = r.amarelo ?? "—";
  document.getElementById("kpi-ok").textContent = r.verde ?? "—";
  document.getElementById("kpi-ok-sub").textContent =
    `${r.verde || 0} baixo · ${r.sem_dados || 0} sem leitura`;
  preencherRanking(painel.maquinas);
  preencherDistribuicao(r);
  preencherSelect(painel.maquinas);

  const escolhida =
    painel.maquinas.find((m) => m.maquina_id === maquinaFoco) || painel.maquinas[0];
  maquinaFoco = escolhida ? escolhida.maquina_id : null;
  preencherCabecalho(escolhida);
  await carregarHistorico(maquinaFoco);

  const selo = document.getElementById("badge-atualizado");
  if (selo) selo.textContent = new Date().toLocaleTimeString("pt-BR");
}

function preencherRanking(maquinas) {
  const corpo = document.getElementById("ranking-body");
  if (!maquinas.length) {
    corpo.innerHTML = `<tr><td colspan="5" class="empty-state">Nenhuma máquina cadastrada.</td></tr>`;
    return;
  }
  const ordenadas = [...maquinas].sort((a, b) => (b.score || -1) - (a.score || -1));
  corpo.innerHTML = ordenadas
    .map(
      (m) => `<tr data-maquina="${m.maquina_id}">
        <td>${m.maquina_id}</td>
        <td>${m.temperatura != null ? m.temperatura.toFixed(1) + " °C" : "—"}</td>
        <td>${barraScore(m.score, m.nivel)}</td>
        <td>${tagDeNivel(m.nivel)}</td>
        <td>${formatarData(m.data_hora)}</td>
      </tr>`
    )
    .join("");
}

function preencherSelect(maquinas) {
  const sel = document.getElementById("select-maquina");
  if (!sel) return;
  sel.innerHTML = maquinas
    .map((m) => `<option value="${m.maquina_id}">${m.maquina_id}</option>`)
    .join("");
  if (maquinaFoco) sel.value = maquinaFoco;
}

function preencherDistribuicao(resumo) {
  const lista = document.getElementById("dist-list");
  const donut = document.getElementById("dist-donut");
  const totalEl = document.getElementById("dist-total");
  const labelEl = document.getElementById("dist-label");
  if (!lista || !resumo) return;

  const total = resumo.total || 0;
  const denom = Math.max(1, total);
  const faixas = [
    { nome: "Alto", n: resumo.vermelho || 0, tom: "high", cor: "var(--red)" },
    { nome: "Médio", n: resumo.amarelo || 0, tom: "med", cor: "var(--yellow)" },
    { nome: "Baixo", n: resumo.verde || 0, tom: "low", cor: "var(--green)" },
    { nome: "Sem dados", n: resumo.sem_dados || 0, tom: "mute", cor: "rgba(234, 240, 255, .28)" },
  ].map((f) => ({ ...f, pct: Math.round((f.n / denom) * 100) }));

  window._distSelecionada = null;

  const mostrarTotal = () => {
    window._distSelecionada = null;
    if (totalEl) totalEl.textContent = total;
    if (labelEl) labelEl.textContent = "Total";
    lista.querySelectorAll(".dist-item").forEach((el) => el.classList.remove("active"));
  };

  const mostrarFaixa = (idx) => {
    const f = faixas[idx];
    if (!f || !f.n) {
      mostrarTotal();
      return;
    }
    window._distSelecionada = idx;
    if (totalEl) totalEl.textContent = `${f.pct}%`;
    if (labelEl) labelEl.textContent = f.nome;
    lista.querySelectorAll(".dist-item").forEach((el, i) => {
      el.classList.toggle("active", i === idx);
    });
  };

  let acc = 0;
  const partes = [];
  for (const f of faixas) {
    const ini = (acc / denom) * 100;
    acc += f.n;
    const fim = (acc / denom) * 100;
    f.ini = ini;
    f.fim = fim;
    partes.push(`${f.cor} ${ini}% ${fim}%`);
  }

  if (donut) {
    donut.style.background = total
      ? `conic-gradient(${partes.join(", ")})`
      : "rgba(255,255,255,.08)";
    donut.onclick = (ev) => {
      const rect = donut.getBoundingClientRect();
      const cx = rect.left + rect.width / 2;
      const cy = rect.top + rect.height / 2;
      const dx = ev.clientX - cx;
      const dy = ev.clientY - cy;
      const raio = Math.hypot(dx, dy);
      const raioExt = rect.width / 2;
      const raioInt = raioExt * 0.56;
      if (raio < raioInt || raio > raioExt) {
        mostrarTotal();
        return;
      }
      let deg = (Math.atan2(dx, -dy) * 180) / Math.PI;
      if (deg < 0) deg += 360;
      const pctAng = (deg / 360) * 100;
      const idx = faixas.findIndex((f) => pctAng >= f.ini && pctAng < (f.fim === 100 ? 100.0001 : f.fim));
      if (idx < 0 || window._distSelecionada === idx) mostrarTotal();
      else mostrarFaixa(idx);
    };
  }

  lista.innerHTML = faixas
    .map(
      (f, idx) => `<button type="button" class="dist-item" data-idx="${idx}">
        <span class="dist-dot ${f.tom}" aria-hidden="true"></span>
        <span class="dist-name">${f.nome}</span>
        <span class="dist-val">${f.n}</span>
      </button>`
    )
    .join("");

  lista.querySelectorAll(".dist-item").forEach((btn) => {
    btn.addEventListener("click", () => {
      const idx = Number(btn.dataset.idx);
      if (window._distSelecionada === idx) mostrarTotal();
      else mostrarFaixa(idx);
    });
  });

  mostrarTotal();
}

function preencherCabecalho(maquina) {
  const data = document.getElementById("detalhe-data");
  const tag = document.getElementById("detalhe-tag");
  const score = document.getElementById("detalhe-score");
  const meter = document.getElementById("score-meter");
  if (!maquina) {
    if (data) data.textContent = "Nenhuma máquina";
    return;
  }
  if (data) data.textContent = `Última leitura: ${formatarData(maquina.data_hora)}`;
  if (tag) tag.innerHTML = tagDeNivel(maquina.nivel);
  if (score) {
    score.textContent = maquina.score != null ? `${maquina.score}` : "—";
    score.classList.remove("risk-alto", "risk-medio", "risk-baixo");
    if (maquina.nivel === "VERMELHO") score.classList.add("risk-alto");
    else if (maquina.nivel === "AMARELO") score.classList.add("risk-medio");
    else if (maquina.nivel === "VERDE") score.classList.add("risk-baixo");
  }
  if (meter) meter.style.left = `${Math.max(0, Math.min(100, maquina.score || 0))}%`;
}

function tomFator(nome) {
  const n = String(nome || "").toLowerCase();
  if (n.includes("termico") || n.includes("temperatura")) return "high";
  if (n.includes("clima")) return "med";
  return "low";
}

function rotuloFator(nome) {
  const mapa = {
    modelo_termico: "Modelo térmico",
    temperatura: "Temperatura",
    operacao: "Operação",
    clima: "Clima",
    tendencia: "Tendência",
  };
  return mapa[nome] || nome;
}

function fatoresHtml(fatores) {
  if (!fatores?.length) {
    return `<p class="section-sub">Ainda sem score. O ESP32 precisa enviar leituras.</p>`;
  }
  return fatores
    .map((f) => {
      const pts = 100 * f.contribuicao;
      return `<div class="fator-row">
        <div class="fator-head"><span>${rotuloFator(f.fator)}</span><strong>${pts.toFixed(1)} pts</strong></div>
        <div class="dist-track"><div class="dist-fill ${tomFator(f.fator)}" style="width:${Math.min(100, pts)}%"></div></div>
      </div>`;
    })
    .join("");
}

function linhasHistorico(registros) {
  if (!registros.length) {
    return `<tr><td colspan="5" class="empty-state">Nenhuma leitura ainda.</td></tr>`;
  }
  return registros
    .map((r) => {
      const temp = r.temperatura == null ? "—" : `${Number(r.temperatura).toFixed(1)} °C`;
      const umid = r.umidade_pct == null ? "—" : `${Number(r.umidade_pct).toFixed(0)}%`;
      return `<tr>
        <td>${temp}</td>
        <td>${umid}</td>
        <td>${barraScore(r.score, r.nivel)}</td>
        <td>${tagDeNivel(r.nivel)}</td>
        <td>${formatarData(r.data_hora)}</td>
      </tr>`;
    })
    .join("");
}

function horaCurta(iso) {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  return d.toLocaleTimeString("pt-BR", { hour: "2-digit", minute: "2-digit" });
}

function desenharSpark(el, registros) {
  if (!el) return;
  const serie = [...registros].reverse();
  if (!serie.length) {
    el.innerHTML = `<p class="empty-state">Sem pontos para o gráfico.</p>`;
    return;
  }

  const rect = el.getBoundingClientRect();
  const w = Math.max(720, Math.round(rect.width) || 720);
  const h = 280;
  const left = 48;
  const right = 16;
  const top = 16;
  const bottom = 36;
  const plotW = w - left - right;
  const plotH = h - top - bottom;
  const yDe = (v) => top + plotH - (v / 100) * plotH;
  const xDe = (i) =>
    left + (serie.length === 1 ? plotW / 2 : (i * plotW) / (serie.length - 1));

  const pts = serie.map((r, i) => `${xDe(i).toFixed(1)},${yDe(Number(r.score) || 0).toFixed(1)}`);
  const linha = pts.join(" ");
  const area = `${left},${yDe(0).toFixed(1)} ${linha} ${xDe(serie.length - 1).toFixed(1)},${yDe(0).toFixed(1)}`;

  const grades = [0, 25, 40, 50, 70, 75, 100]
    .map((v) => {
      const y = yDe(v);
      const cor = v === 40 || v === 70 ? "rgba(255,255,255,.28)" : "rgba(255,255,255,.10)";
      return `<line x1="${left}" y1="${y}" x2="${w - right}" y2="${y}" stroke="${cor}" stroke-width="1"/>
        <text x="${left - 8}" y="${y + 4}" text-anchor="end" fill="rgba(234,240,255,.55)" font-size="11">${v}</text>`;
    })
    .join("");

  const faixaVerde = `<rect x="${left}" y="${yDe(40)}" width="${plotW}" height="${yDe(0) - yDe(40)}" fill="rgba(38,215,163,.08)"/>`;
  const faixaAmarelo = `<rect x="${left}" y="${yDe(70)}" width="${plotW}" height="${yDe(40) - yDe(70)}" fill="rgba(255,204,51,.08)"/>`;
  const faixaVermelho = `<rect x="${left}" y="${yDe(100)}" width="${plotW}" height="${yDe(70) - yDe(100)}" fill="rgba(255,77,109,.08)"/>`;

  const indices = [0, Math.floor((serie.length - 1) / 2), serie.length - 1]
    .filter((v, i, a) => a.indexOf(v) === i);
  const labelsX = indices
    .map((i) => `<text x="${xDe(i)}" y="${h - 10}" text-anchor="middle" fill="rgba(234,240,255,.55)" font-size="11">${horaCurta(serie[i].data_hora)}</text>`)
    .join("");

  const pontos = serie
    .map((r, i) => {
      const s = Number(r.score) || 0;
      const cor = s >= 70 ? "#FF4D6D" : s >= 40 ? "#FFCC33" : "#26D7A3";
      return `<circle cx="${xDe(i)}" cy="${yDe(s)}" r="3.5" fill="${cor}"/>`;
    })
    .join("");

  el.innerHTML = `<svg viewBox="0 0 ${w} ${h}" preserveAspectRatio="xMidYMid meet" role="img" aria-label="Score de 0 a 100 no tempo">
    ${faixaVermelho}${faixaAmarelo}${faixaVerde}
    ${grades}
    <polygon points="${area}" fill="url(#fillScore)" opacity=".9"/>
    <polyline fill="none" stroke="#2AA9FF" stroke-width="2.5" stroke-linejoin="round" stroke-linecap="round" points="${linha}"/>
    ${pontos}
    ${labelsX}
    <defs>
      <linearGradient id="fillScore" x1="0" y1="0" x2="0" y2="1">
        <stop offset="0" stop-color="#2AA9FF" stop-opacity=".28"/>
        <stop offset="1" stop-color="#2AA9FF" stop-opacity="0"/>
      </linearGradient>
    </defs>
  </svg>`;
}

async function carregarHistorico(maquinaId) {
  const corpo = document.getElementById("historico-body");
  const fatoresEl = document.getElementById("detalhe-fatores");
  const meta = document.getElementById("analise-meta");
  if (!maquinaId) {
    if (corpo) corpo.innerHTML = linhasHistorico([]);
    if (fatoresEl) fatoresEl.innerHTML = fatoresHtml([]);
    return;
  }
  try {
    const historico = await buscarJson(
      `/api/score/${encodeURIComponent(maquinaId)}?limit=${HISTORICO_LIMITE}`
    );
    const registros = historico.registros || [];
    window._historico = registros;
    if (corpo) corpo.innerHTML = linhasHistorico(registros);
    desenharSpark(document.getElementById("spark-score"), registros);
    const ultimo = registros[0];
    if (fatoresEl) fatoresEl.innerHTML = fatoresHtml(ultimo?.fatores_json);
    if (meta) {
      meta.textContent = ultimo
        ? `${ultimo.versao_regra || "omega-score"} · ${formatarData(ultimo.data_hora)}`
        : "Sem cálculo ainda";
    }
    if (ultimo) {
      const score = document.getElementById("detalhe-score");
      const tag = document.getElementById("detalhe-tag");
      const meter = document.getElementById("score-meter");
      if (score) score.textContent = ultimo.score;
      if (tag) tag.innerHTML = tagDeNivel(ultimo.nivel);
      if (meter) meter.style.left = `${Math.max(0, Math.min(100, ultimo.score || 0))}%`;
    }
  } catch (erro) {
    if (corpo) corpo.innerHTML = `<tr><td colspan="5" class="empty-state">${erro.message}</td></tr>`;
  }
}

function focarMaquina(id, abrir = false) {
  maquinaFoco = id;
  const sel = document.getElementById("select-maquina");
  if (sel && id) sel.value = id;
  const maquina = (window._painel?.maquinas || []).find((m) => m.maquina_id === id);
  preencherCabecalho(maquina);
  carregarHistorico(id);
  if (abrir) irPara("maquina");
}

document.querySelectorAll("[data-route]").forEach((link) => {
  link.addEventListener("click", (evento) => {
    evento.preventDefault();
    irPara(link.dataset.route);
  });
});

document.getElementById("ranking-body")?.addEventListener("click", (evento) => {
  const linha = evento.target.closest("tr[data-maquina]");
  if (linha) focarMaquina(linha.dataset.maquina, true);
});

document.getElementById("select-maquina")?.addEventListener("change", (evento) => {
  focarMaquina(evento.target.value);
});

document.getElementById("btn-atualizar")?.addEventListener("click", () => carregarPainel());
document.getElementById("menu-btn")?.addEventListener("click", () => {
  document.getElementById("sidebar")?.classList.toggle("open");
  document.getElementById("sidebar-backdrop")?.classList.toggle("show");
});
document.getElementById("sidebar-backdrop")?.addEventListener("click", fecharMenu);

document.getElementById("btn-export-csv")?.addEventListener("click", () => {
  const maquinas = window._painel?.maquinas || [];
  const linhas = ["maquina_id,temperatura,score,nivel,data_hora"];
  maquinas.forEach((m) => {
    linhas.push([m.maquina_id, m.temperatura, m.score, m.nivel, m.data_hora].map((v) => v ?? "").join(","));
  });
  const blob = new Blob([linhas.join("\n")], { type: "text/csv;charset=utf-8" });
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = "frota_omega.csv";
  a.click();
  URL.revokeObjectURL(url);
});

document.getElementById("btn-export-pdf")?.addEventListener("click", async () => {
  const msg = document.getElementById("relatorio-msg");
  const ultimo = (window._historico || [])[0];
  if (!ultimo) {
    if (msg) msg.textContent = "Sem score para exportar.";
    return;
  }
  try {
    const resposta = await fetch("/gerar-pdf", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        maquina_id: ultimo.maquina_id,
        score: ultimo.score,
        nivel: ultimo.nivel,
        temperatura: ultimo.temperatura,
        temperatura_base: ultimo.temperatura_base,
        umidade_pct: ultimo.umidade_pct,
        fatores: ultimo.fatores_json || [],
        modelo_termico: window._status?.modelo_termico,
      }),
    });
    if (!resposta.ok) throw new Error("Falha ao gerar PDF.");
    const arquivo = await resposta.blob();
    const url = window.URL.createObjectURL(arquivo);
    const link = document.createElement("a");
    link.href = url;
    link.download = `relatorio_omega_${ultimo.maquina_id}.pdf`;
    link.click();
    window.URL.revokeObjectURL(url);
    if (msg) msg.textContent = "PDF baixado.";
  } catch (erro) {
    if (msg) msg.textContent = erro.message;
  }
});

carregarPainel();

// Inicializa os ícones do Lucide
lucide.createIcons();
