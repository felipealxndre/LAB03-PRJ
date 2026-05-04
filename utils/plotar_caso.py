"""
plotar_caso.py
Lê os arquivos dados.json gerados pelo main.m e gera os plots.

Uso:
    python3 plotar_caso.py                          # todos os casos de AH1S
    python3 plotar_caso.py 1 2 3 4                  # casos específicos de AH1S
"""

import argparse
import json
import sys
import os
import textwrap
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import matplotlib.lines as mlines

# ── Estilo global ─────────────────────────────────────────────────────────────
plt.rcParams.update({
    "font.family":      "serif",
    "font.size":        11,
    "axes.titlesize":   12,
    "axes.labelsize":   11,
    "legend.fontsize":  10,
    "xtick.labelsize":  10,
    "ytick.labelsize":  10,
    "axes.grid":        True,
    "grid.linestyle":   "--",
    "grid.alpha":       0.45,
    "grid.linewidth":   0.6,
    "axes.spines.top":  False,
    "axes.spines.right":False,
    "figure.dpi":       150,
    "savefig.dpi":      200,
    "savefig.bbox":     "tight",
})

RESULTS_DIR = "results"   # pode ser sobrescrito via --aeronave

NOME_FASE = {2: "Subida", 3: "Nivelado – VDM", 4: "Nivelado – VAM", 5: "Descida"}

# Paleta de cores consistente
COR_TOTAL  = "#1a1a1a"
COR_DISP   = "#d62728"
COR_VDM    = "#2ca02c"
COR_VAM    = "#1f77b4"
COR_VMAX   = "#9467bd"
COR_SUBIDA = "#1f77b4"
COR_AUTO   = "#d62728"

# Paleta para comparação entre casos
COR_CASOS  = ["#1f77b4", "#d62728", "#2ca02c", "#ff7f0e"]  # C1 azul, C2 vermelho, C3 verde, C4 laranja


# ── helpers ───────────────────────────────────────────────────────────────────

def carregar_json(caso: int, results_dir: str) -> dict:
    path = os.path.join(results_dir, f"CASO{caso}", "dados.json")
    if not os.path.exists(path):
        raise FileNotFoundError(
            f"Arquivo não encontrado: {path}\n"
            f"Execute primeiro o script Octave correspondente."
        )
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def arr(d, key) -> np.ndarray:
    """Extrai array do JSON (suporta [[...]] do jsonencode do Octave)."""
    v = d[key]
    if isinstance(v, list):
        if len(v) == 1 and isinstance(v[0], list):
            return np.array(v[0])
        return np.array(v)
    return np.array([v])


def salvar(fig, pasta: str, nome: str):
    os.makedirs(pasta, exist_ok=True)
    path = os.path.join(pasta, nome)
    fig.savefig(path)
    plt.close(fig)
    print(f"  → {path}")


def _vento_str(V_vento: float) -> str:
    if V_vento == 0:
        return "Sem vento"
    elif V_vento < 0:
        return f"Vento de proa  {abs(V_vento):.0f} kt"
    else:
        return f"Vento de cauda {V_vento:.0f} kt"


def _wrap_label(nome: str, width: int = 10) -> str:
    """Quebra o nome da fase em múltiplas linhas para caber nos eixos."""
    return "\n".join(textwrap.wrap(nome, width))


def _is_secant(curve: np.ndarray, V_tas: np.ndarray, idx_point: int, orig: float) -> bool:
    """
    Verifica se a reta de (orig, 0) até (V_tas[idx_point], curve[idx_point])
    cruza a curva antes do ponto, tornando-a secante.
    """
    V_point = V_tas[idx_point]
    dV = V_point - orig
    if dV == 0:
        return False
    m = curve[idx_point] / dV
    mask = (V_tas > orig) & (V_tas < V_point)
    if not mask.any():
        return False
    return bool(np.any(curve[mask] > m * (V_tas[mask] - orig)))


# ── plot: Balanço de Potência (cruzeiro) ──────────────────────────────────────

def plot_cruzeiro(dado: dict, caso: int, fase: int,
                  P_disp_hp: float, V_vento: float, pasta: str):
    V_tas = arr(dado, "V_tas")
    P_tot = arr(dado, "P_tot_hp")
    V_VDM = float(dado["VDM"])
    V_VAM = float(dado["VAM"])
    V_max = dado["V_max"]
    W     = float(dado["W"])
    Zp    = float(dado["Zp"])

    idx_VDM = int(np.argmin(np.abs(V_tas - V_VDM)))
    idx_VAM = int(np.argmin(np.abs(V_tas - V_VAM)))
    V_gs    = V_tas + V_vento

    fig, ax = plt.subplots(figsize=(10, 6))

    # Curva principal
    ax.plot(V_tas, P_tot, color=COR_TOTAL, lw=1.8, label="Potência Necessária")

    # P_disp como linha sem entrada na legenda; label escrito diretamente sobre ela
    ax.axhline(P_disp_hp, color=COR_DISP, lw=1.4, ls="--")
    ax.text(V_tas[int(len(V_tas) * 0.05)], P_disp_hp + P_disp_hp * 0.02,
            f"$P_{{disp}}$ = {P_disp_hp:.0f} hp",
            color=COR_DISP, fontsize=9.5, va="bottom")

    # VAM — ponto preenchido + linha vertical tracejada
    P_VAM = P_tot[idx_VAM]
    ax.plot(V_VAM, P_VAM, "s", color=COR_VAM, ms=5, mfc=COR_VAM, mew=1.0, zorder=5,
            label=f"$V_{{AM}}$ = {V_VAM:.1f} kt")
    ax.plot([V_VAM, V_VAM], [0, P_VAM], ":", color=COR_VAM, lw=1.0)

    # VDM — ponto preenchido + linha vertical tracejada
    P_VDM = P_tot[idx_VDM]
    ax.plot(V_VDM, P_VDM, "s", color=COR_VDM, ms=5, mfc=COR_VDM, mew=1.0, zorder=5,
            label=f"$V_{{DM}}$ = {V_VDM:.1f} kt")
    ax.plot([V_VDM, V_VDM], [0, P_VDM], ":", color=COR_VDM, lw=1.0)

    # Reta tangente — sem entrada na legenda, estende até limite do plot
    m = P_VDM / (V_VDM + V_vento)
    v_gs_max = max(V_gs[V_gs > 0]) if np.any(V_gs > 0) else float(V_tas[-1])
    v_gs_line = np.array([0.0, v_gs_max])
    ax.plot(v_gs_line - V_vento, m * v_gs_line, "--",
            color=COR_VDM, lw=1.0, zorder=2)

    # V_max — ponto preenchido
    if V_max is not None and not (isinstance(V_max, float) and np.isnan(V_max)):
        Vmax_f = float(V_max)
        ax.plot(Vmax_f, P_disp_hp, "s", color=COR_VMAX, ms=5, mfc=COR_VMAX, mew=1.0, zorder=5,
                label=f"$V_{{max}}$ = {Vmax_f:.1f} kt")
        ax.plot([Vmax_f, Vmax_f], [0, P_disp_hp], ":", color=COR_VMAX, lw=1.0)

    ax.set_xlabel("Velocidade Aerodinâmica – TAS (kt)")
    ax.set_ylabel("Potência (hp)")
    ax.legend(loc="upper left", frameon=True)
    ax.set_xlim(left=min(0, -V_vento - 10))
    ax.set_ylim(bottom=0)
    ax.yaxis.set_minor_locator(ticker.AutoMinorLocator())
    ax.xaxis.set_minor_locator(ticker.AutoMinorLocator())
    fig.tight_layout()

    nome = f"Balanco_Fase{fase}_{NOME_FASE[fase].replace(' – ', '_').replace(' ', '_')}_Zp{Zp:.0f}ft.png"
    salvar(fig, pasta, nome)


# ── plot: Polar de Velocidade ─────────────────────────────────────────────────

def plot_polar(dado: dict, caso: int, fase: int, V_vento: float, pasta: str):
    V_tas   = arr(dado, "V_tas")
    Vc_v    = arr(dado, "vZ")
    Vc_auto = arr(dado, "vZ_auto")
    Vy      = float(dado["Vy"])
    VrM     = float(dado["VrM"])
    Vvm     = float(dado["Vvm"])
    Vrm     = float(dado["Vrm"])
    Vzmax   = float(dado["Vzmax"])
    Vzmin   = float(dado.get("Vzmin", float(Vc_auto[int(np.argmax(Vc_auto))])))
    W       = float(dado["W"])
    Zp      = float(dado["Zp"])

    idx_Vy  = int(np.argmax(Vc_v))
    idx_VrM = int(np.argmin(np.abs(V_tas - VrM)))
    idx_Vvm = int(np.argmax(Vc_auto))
    idx_Vrm = int(np.argmin(np.abs(V_tas - Vrm)))

    orig       = -V_vento
    xlim_left  = min(orig - 8, -5)    # borda esquerda do eixo (= onde encosta a linha horizontal)
    secant_blue = _is_secant(Vc_v, V_tas, idx_VrM, orig)

    COR_POLAR = "#1a3a6b"

    fig, ax = plt.subplots(figsize=(10, 6))

    # ── Curvas principais: mesma cor, sólida (subida) e tracejada (autorrotação)
    ax.plot(V_tas, Vc_v,    color=COR_POLAR, lw=2.0)
    ax.plot(V_tas, Vc_auto, color=COR_POLAR, lw=1.8, ls="--")

    # Eixo horizontal y = 0
    ax.axhline(0, color="k", lw=0.9)

    # ── Linhas de referência pontilhadas (cinza) ─────────────────────────────
    Vz_min = float(Vc_auto[idx_Vvm])   # mínima descida em autorrotação

    # Vy — segmento ACIMA do eixo x: de y=0 até Vzmax + horizontal (Vz máx)
    ax.plot([Vy, Vy],          [0, Vzmax],       ":", color="gray", lw=0.9, zorder=1)
    ax.plot([xlim_left, Vy],   [Vzmax, Vzmax],   ":", color="gray", lw=0.9, zorder=1)

    # Vvm — segmento ABAIXO do eixo x: de Vz_min até y=0 + horizontal (Vz mín)
    # Se Vvm == Vy, a vertical já está desenhada acima; só falta o segmento abaixo
    ax.plot([Vvm, Vvm],        [Vz_min, 0],      ":", color="gray", lw=0.9, zorder=1)
    ax.plot([xlim_left, Vvm],  [Vz_min, Vz_min], ":", color="gray", lw=0.9, zorder=1)

    # Vrm — de Vc_auto[Vrm] (negativo) até y=0; sem referência horizontal
    ax.plot([Vrm, Vrm], [Vc_auto[idx_Vrm], 0],   ":", color="gray", lw=0.9, zorder=1)

    # Texto no eixo x indicando a origem das tangentes (abaixo do eixo, sem caixa)
    if V_vento != 0:
        ax.text(orig, 0.05 * float(Vc_auto.min()), f"$V_{{vento}}$={abs(V_vento):.0f} kt",
                color="red", fontsize=8.5, ha="center", va="top")

    # ── Retas tangentes (vermelhas) ───────────────────────────────────────────
    COR_TAN = "#d62728"   # vermelho — igual COR_AUTO
    COR_VEL = "#2ca02c"   # verde — Vy e Vvm
    V_end = float(V_tas[-1])

    m_auto = Vc_auto[idx_Vrm] / (Vrm - orig) if (Vrm - orig) != 0 else 0
    ax.plot([orig, V_end], [0, m_auto * (V_end - orig)],
            "--", color=COR_TAN, lw=1.1, zorder=2)

    if not secant_blue:
        m_sub = Vc_v[idx_VrM] / (VrM - orig) if (VrM - orig) != 0 else 0
        ax.plot([orig, V_end], [0, m_sub * (V_end - orig)],
                "--", color=COR_TAN, lw=1.1, zorder=2)

    # ── Conexão Vy ↔ Vvm ─────────────────────────────────────────────────────
    ax.plot([Vy, Vvm], [Vc_v[idx_Vy], Vz_min], "k--", lw=1.0, zorder=3)

    # ── Marcadores nos pontos característicos ────────────────────────────────
    # Vy e Vvm: verdes  |  VrM e Vrm (pontos de tangência): vermelhos
    mk_vel = dict(ms=5, mfc=COR_VEL, mew=1.0, zorder=6, color=COR_VEL)
    mk_tan = dict(ms=5, mfc=COR_TAN, mew=1.0, zorder=6, color=COR_TAN)

    ax.plot(Vy,  Vc_v[idx_Vy],    "s", label=f"$V_y$   = {Vy:.1f} kt",  **mk_vel)
    if not secant_blue:
        ax.plot(VrM, Vc_v[idx_VrM], "s", label=f"$V_{{vM}}$ = {VrM:.1f} kt", **mk_tan)
    ax.plot(Vvm, Vz_min,           "s", **mk_vel)          # sem entrada na legenda
    ax.plot(Vrm, Vc_auto[idx_Vrm], "s", label=f"$V_{{rm}}$ = {Vrm:.1f} kt",   **mk_tan)

    # ── Legenda: nomes das curvas + velocidades (+ vento se aplicável) ──────────
    h_climb  = mlines.Line2D([], [], color=COR_POLAR, lw=2.0,
                             label="Subida na PMC")
    h_auto   = mlines.Line2D([], [], color=COR_POLAR, lw=1.8, ls="--",
                             label="Descida em Autorrotação")
    h_vzmax  = mlines.Line2D([], [], color="gray", lw=0.9, ls=":",
                             label=f"$V_{{z,máx}}$ = {Vzmax:.0f} ft/min")
    h_vzmin  = mlines.Line2D([], [], color="gray", lw=0.9, ls=":",
                             label=f"$V_{{z,mín}}$ = {Vzmin:.0f} ft/min")
    extra = []
    if V_vento != 0:
        descricao = "proa" if V_vento < 0 else "cauda"
        extra = [mlines.Line2D([], [], lw=0, ms=0,
                               label=f"$V_{{vento}}$ = {abs(V_vento):.0f} kt ({descricao})")]
    handles, _ = ax.get_legend_handles_labels()
    ax.legend(handles=[h_climb, h_auto, h_vzmax, h_vzmin] + extra + handles,
              loc="upper right", frameon=True)

    ax.set_xlabel("Velocidade Verdadeira (kt)")
    ax.set_ylabel("Velocidade Vertical (ft/min)")
    ax.set_xlim(left=xlim_left)
    ax.yaxis.set_minor_locator(ticker.AutoMinorLocator())
    ax.xaxis.set_minor_locator(ticker.AutoMinorLocator())
    fig.tight_layout()

    nome = f"Polar_Fase{fase}_{NOME_FASE[fase].replace(' – ', '_').replace(' ', '_')}_Zp{Zp:.0f}ft.png"
    salvar(fig, pasta, nome)


# ── plot: Decomposição de Potência ────────────────────────────────────────────

def plot_decomposicao(dado: dict, caso: int, fase: int,
                      P_disp_hp: float, pasta: str):
    V_tas  = arr(dado, "V_tas")
    P_tot  = arr(dado, "P_tot_hp")
    P_ind  = arr(dado, "P_ind_hp")
    P_perf = arr(dado, "P_perf_hp")
    P_par  = arr(dado, "P_par_hp")
    P_misc = arr(dado, "P_misc_hp")
    W      = float(dado["W"])
    Zp     = float(dado["Zp"])

    fig, ax = plt.subplots(figsize=(10, 6))

    ax.plot(V_tas, P_ind,  color="#2ca02c", lw=1.6, label="$P_{ind}$ — Induzida")
    ax.plot(V_tas, P_perf, color="#17becf", lw=1.6, label="$P_{perf}$ — Perfil")
    ax.plot(V_tas, P_par,  color="#9467bd", lw=1.6, label="$P_{par}$ — Parasita")
    ax.plot(V_tas, P_misc, color="#bcbd22", lw=1.6, label="$P_{misc}$ — Miscelânea")
    ax.plot(V_tas, P_tot,  color=COR_TOTAL, lw=2.2, label="$P_{tot}$ — Total")
    ax.axhline(P_disp_hp, color=COR_DISP, lw=1.2, ls="--")
    ax.text(float(V_tas[int(len(V_tas) * 0.05)]), P_disp_hp + P_disp_hp * 0.02,
            f"$P_{{disp}}$ = {P_disp_hp:.0f} hp",
            color=COR_DISP, fontsize=9.5, va="bottom")

    ax.set_xlabel("Velocidade de Avanço – TAS (kt)")
    ax.set_ylabel("Potência (hp)")
    ax.legend(loc="upper left", frameon=True)
    ax.set_xlim(left=0)
    ax.set_ylim(bottom=0)
    ax.yaxis.set_minor_locator(ticker.AutoMinorLocator())
    ax.xaxis.set_minor_locator(ticker.AutoMinorLocator())
    fig.tight_layout()

    nome = f"Decomp_Fase{fase}_{NOME_FASE[fase].replace(' – ', '_').replace(' ', '_')}_Zp{Zp:.0f}ft.png"
    salvar(fig, pasta, nome)


# ── plot: Resumo da missão ─────────────────────────────────────────────────────

def plot_resumo_missao(dados: dict, caso: int, pasta: str):
    nomes   = dados["fases_nome"]
    P_tots  = np.array(dados["fases_P_tot"]).flatten()
    combs   = np.array(dados["fases_comb"]).flatten()
    P_disp  = float(dados["P_disp_hp"]) * 0.7457
    V_vento = float(dados["V_vento"])

    n      = len(nomes)
    x      = np.arange(n)
    # Quebras de linha nos nomes longos para evitar sobreposição
    labels = [f"F{i+1}\n{_wrap_label(nomes[i], 9)}" for i in range(n)]

    fig, axes = plt.subplots(1, 2, figsize=(13, 5))
    fig.suptitle(f"Caso {caso}  |  {_vento_str(V_vento)}", fontsize=11)

    ax = axes[0]
    cores = [COR_VAM if p <= P_disp else COR_DISP for p in P_tots]
    bars  = ax.bar(x, P_tots, color=cores, edgecolor="k", lw=0.7, zorder=3)
    ax.axhline(P_disp, color=COR_DISP, ls="--", lw=1.6,
               label=f"$P_{{disp}}$ = {P_disp:.0f} kW", zorder=4)
    ax.set_xticks(x)
    ax.set_xticklabels(labels, fontsize=8)
    ax.set_ylabel("Potência Total (kW)")
    ax.set_title("")
    ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.28), ncol=1, frameon=True)
    for bar, val in zip(bars, P_tots):
        ax.text(bar.get_x() + bar.get_width() / 2,
                bar.get_height() + P_disp * 0.02,
                f"{val:.0f}", ha="center", va="bottom", fontsize=8)

    ax = axes[1]
    bars = ax.bar(x, combs, color="#ff7f0e", edgecolor="k", lw=0.7, zorder=3)
    ax.set_xticks(x)
    ax.set_xticklabels(labels, fontsize=8)
    ax.set_ylabel("Combustível (lb)")
    ax.set_title("")
    total = combs.sum()
    ax.set_xlabel(f"Total consumido: {total:.1f} lb", fontsize=10)
    for bar, val in zip(bars, combs):
        ax.text(bar.get_x() + bar.get_width() / 2,
                bar.get_height() + total * 0.01,
                f"{val:.1f}", ha="center", va="bottom", fontsize=8)

    fig.tight_layout()
    salvar(fig, pasta, "Resumo_Missao.png")


# ══════════════════════════════════════════════════════════════════════════════
# GRÁFICOS DE COMPARAÇÃO (baseline = Caso 1)
# ══════════════════════════════════════════════════════════════════════════════

def _label_caso(caso: int, dados: dict) -> str:
    """Rótulo curto para legenda de comparação."""
    V_v = float(dados["V_vento"])
    vento = f"{abs(V_v):.0f} kt {'proa' if V_v < 0 else 'cauda'}" if V_v != 0 else "s/ vento"
    return f"Caso {caso} ({vento})"


def plot_comp_vdm_vento(d1: dict, d2: dict, pasta: str):
    """Gráfico #1 — Construção geométrica da VDM com e sem vento de proa.

    Plota uma única curva P_tot(V) (idêntica para C1 e C2, mesmo peso e altitude)
    e as duas retas tangentes:
        - C1 parte de (0, 0)             → toca a curva em VDM₁
        - C2 parte de (-V_vento, 0)      → toca em VDM₂ > VDM₁
    Materializa o conceito "máximo alcance em relação ao solo" via tangência.
    """
    cru1 = d1["cruzeiro_F3"]
    V_tas = arr(cru1, "V_tas")
    P_tot = arr(cru1, "P_tot_hp")
    P_disp = float(d1["P_disp_hp"])

    fig, ax = plt.subplots(figsize=(11, 6))

    # Curva única — peso e atmosfera iguais entre C1 e C2
    ax.plot(V_tas, P_tot, color="k", lw=2.2, label="$P_{tot}(V)$ — C1 e C2")

    # Tangentes e pontos VDM de cada caso
    V_end = float(V_tas[-1])
    for d, cor, caso_n in [(d1, COR_CASOS[0], 1), (d2, COR_CASOS[1], 2)]:
        V_vento = float(d["V_vento"])
        cru     = d["cruzeiro_F3"]
        V_VDM   = float(cru["VDM"])
        idx     = int(np.argmin(np.abs(V_tas - V_VDM)))
        P_VDM   = float(P_tot[idx])
        orig    = -V_vento

        m = P_VDM / (V_VDM - orig)
        ax.plot([orig, V_end], [0, m * (V_end - orig)],
                "--", color=cor, lw=1.6,
                label=f"Tangente C{caso_n} → $V_{{DM}}$ = {V_VDM:.1f} kt")

        ax.plot(V_VDM, P_VDM, "s", color=cor, ms=7, mfc=cor, mew=1.0, zorder=5)
        ax.plot([V_VDM, V_VDM], [0, P_VDM], ":", color=cor, lw=0.9)

        # Marcador da origem da tangente (circulinho branco)
        ax.plot(orig, 0, "o", color=cor, ms=7, mfc="white", mew=1.5, zorder=6)
        if V_vento != 0:
            ax.text(orig, -P_disp * 0.03,
                    f"{abs(V_vento):.0f} kt",
                    color=cor, fontsize=9, ha="center", va="top", fontweight="bold")

    # Linha P_disp
    ax.axhline(P_disp, color="gray", lw=1.2, ls="--", xmin = 0)
    ax.text(float(V_tas[5]), P_disp + P_disp * 0.02,
            f"$P_{{disp}}$ = {P_disp:.0f} hp",
            color="gray", fontsize=9.5, va="bottom")

    ax.set_xlabel("Velocidade Aerodinâmica – TAS (kt)")
    ax.set_ylabel("Potência Necessária (hp)")
    ax.legend(loc="upper left", frameon=True, fontsize=9)
    # xlim: apenas uma pequena folga à esquerda da origem mais negativa (C1 = 0)
    origs = [0.0, -float(d1["V_vento"]), -float(d2["V_vento"])]
    ax.set_xlim(left=min(min(origs) -3, 0), right=V_end)
    ax.set_ylim(bottom=-P_disp * 0.2)
    ax.yaxis.set_minor_locator(ticker.AutoMinorLocator())
    ax.xaxis.set_minor_locator(ticker.AutoMinorLocator())

    # Eixos fincados na origem (y=0 e x=0) — elimina o gap visual
    ax.spines["left"].set_position(("data", 0))
    ax.spines["bottom"].set_position(("data", 0))

    fig.tight_layout()
    salvar(fig, pasta, "Comp_VDM_Tangentes_C1vsC2.png")


def plot_comp_potencia_subida(d1: dict, d3: dict, pasta: str):
    """Gráfico #2 — Balanço de potência em subida: C1 (1000 fpm) vs C3 (2000 fpm).

    Mostra a CAUSA física da inviabilidade do Caso 3: em V = V_y, a potência
    necessária para subir a 2000 fpm excede P_disp. A curva de subida é obtida
    pela translação vertical da curva nivelada pelo termo λ_c · C_T (potência
    extra de subida = W · V_c / 33000), conforme cai da equação do inflow.

    Sombreamento cinza acima de P_disp indica região inviável.
    """
    cru   = d1["cruzeiro_F2"]              # condições de F2: 2500 ft, ~9959 lb
    V_tas = arr(cru, "V_tas")
    P_lvl = arr(cru, "P_tot_hp")
    W     = float(cru["W"])
    Vy    = float(d1["polar_F2"]["Vy"])
    P_disp = float(d1["P_disp_hp"])

    Vc1 = float(d1["Vc_sub_fpm"])
    Vc3 = float(d3["Vc_sub_fpm"])

    # Termo de subida: ΔP [hp] = W [lb] · V_c [fpm] / 33000
    dP1 = W * Vc1 / 33000.0
    dP3 = W * Vc3 / 33000.0

    # Potências em V_y
    idx_Vy   = int(np.argmin(np.abs(V_tas - Vy)))
    P_lvl_Vy = float(P_lvl[idx_Vy])
    P_C1     = P_lvl_Vy + dP1
    P_C3     = P_lvl_Vy + dP3

    margem_C1  = P_disp - P_C1           # positivo → viável
    deficit_C3 = P_C3  - P_disp          # positivo → inviável

    fig, ax = plt.subplots(figsize=(10.5, 6.5))

    # Limites do eixo Y (zoom na região de interesse, com espaço folgado acima)
    y_bot = 600
    y_top = 1700

    # Cor do sombreado (cinza com alpha 0.18 sobre branco ≈ #d9d9d9)
    COR_SOMBRA = "#d9d9d9"

    # Sombreamento da região inviável (acima de P_disp)
    ax.axhspan(P_disp, y_top, color="gray", alpha=0.18, zorder=1)
    ax.text(75, y_top - 35, "Região inviável ($P_{tot} > P_{disp}$)",
            color="gray", fontsize=11, ha="center", va="top",
            fontweight="bold", alpha=0.9)

    # Curvas P_tot(V): nivelado e as duas subidas
    ax.plot(V_tas, P_lvl,       color="#1a1a1a",   lw=1.5, zorder=3,
            label="$P_{tot}$ — voo nivelado")
    ax.plot(V_tas, P_lvl + dP1, color=COR_CASOS[0], lw=1.4, zorder=3,
            label=f"$P_{{tot}}$ — subida {Vc1:.0f} fpm (+{dP1:.0f} hp)")
    ax.plot(V_tas, P_lvl + dP3, color=COR_CASOS[2], lw=1.4, zorder=3,
            label=f"$P_{{tot}}$ — subida {Vc3:.0f} fpm (+{dP3:.0f} hp)")

    # Linha horizontal P_disp
    ax.axhline(P_disp, color="gray", lw=1.1, ls="--", zorder=2,
               label=f"$P_{{disp}}$ = {P_disp:.0f} hp")

    # Referência vertical em V_y — mesmo tom de cinza do sombreado
    ax.plot([Vy, Vy], [y_bot, y_top], ":", color=COR_SOMBRA, lw=0.9, zorder=1)

    # Pontos operacionais
    ax.plot(Vy, P_C1, "s", color=COR_CASOS[0], ms=6, mfc=COR_CASOS[0],
            mew=0.8, zorder=6)
    ax.plot(Vy, P_C3, "s", color=COR_CASOS[2], ms=6, mfc=COR_CASOS[2],
            mew=0.8, zorder=6)

    # Anotações centradas sobre V_y: C3 acima do seu ponto, C1 abaixo do seu ponto
    ax.annotate(f"C3 em $V_y$: {P_C3:.0f} hp\ndéficit = {deficit_C3:.0f} hp (INVIÁVEL)",
                xy=(Vy, P_C3), xytext=(Vy, P_C3 + 130),
                fontsize=10, color=COR_CASOS[2], ha="center", va="bottom",
                fontweight="bold",
                arrowprops=dict(arrowstyle="->", color=COR_CASOS[2], lw=0.9))
    ax.annotate(f"C1 em $V_y$: {P_C1:.0f} hp\nmargem = {margem_C1:.0f} hp",
                xy=(Vy, P_C1), xytext=(Vy, P_C1 - 130),
                fontsize=10, color=COR_CASOS[0], ha="center", va="top",
                arrowprops=dict(arrowstyle="->", color=COR_CASOS[0], lw=0.9))

    # Rótulo de V_y logo acima do piso do eixo
    ax.text(Vy, y_bot + 15, f"$V_y$ = {Vy:.0f} kt",
            fontsize=9, color="gray", ha="center", va="bottom")

    ax.set_xlabel("Velocidade Aerodinâmica – TAS (kt)")
    ax.set_ylabel("Potência (hp)")
    ax.legend(loc="lower left", frameon=True, fontsize=9)
    ax.set_xlim(0, 150)
    ax.set_ylim(y_bot, y_top)
    ax.yaxis.set_minor_locator(ticker.AutoMinorLocator())
    ax.xaxis.set_minor_locator(ticker.AutoMinorLocator())
    fig.tight_layout()
    salvar(fig, pasta, "Comp_Potencia_Subida_C1vsC3.png")


def plot_comp_decomp_vdm(d1: dict, d2: dict, pasta: str):
    """Decomposição da potência em VDM₁ (C1) vs VDM₂ (C2) — barras empilhadas.

    Mostra quais componentes dominam o aumento de potência quando o vento de
    proa desloca a VDM para uma velocidade maior:
        - P_par ∝ V³ sobe fortemente
        - P_ind ∝ 1/V cai (parcialmente compensa)
        - P_perf e P_misc sobem levemente
    """
    HP2KW = 0.7457
    comp_keys   = ["P_ind_hp", "P_perf_hp", "P_par_hp", "P_misc_hp"]
    comp_labels = ["$P_{ind}$ — Induzida", "$P_{perf}$ — Perfil",
                   "$P_{par}$ — Parasita",  "$P_{misc}$ — Miscelânea"]
    comp_cores  = ["#2ca02c",  "#17becf",   "#9467bd",   "#bcbd22"]

    valores = {}
    VDM_d   = {}
    for d, caso_n in [(d1, 1), (d2, 2)]:
        cru   = d["cruzeiro_F3"]
        V_tas = arr(cru, "V_tas")
        V_VDM = float(cru["VDM"])
        idx   = int(np.argmin(np.abs(V_tas - V_VDM)))
        valores[caso_n] = [float(arr(cru, k)[idx]) * HP2KW for k in comp_keys]
        VDM_d[caso_n] = V_VDM

    P_totais = [sum(valores[c]) for c in (1, 2)]

    x    = np.arange(2)
    cats = [f"Caso 1 – s/ vento\n$V_{{DM,1}}$ = {VDM_d[1]:.1f} kt",
            f"Caso 2 – 15 kt proa\n$V_{{DM,2}}$ = {VDM_d[2]:.1f} kt"]

    fig, ax = plt.subplots(figsize=(7, 6))

    bottom = [0.0, 0.0]
    for lbl, cor, ki in zip(comp_labels, comp_cores, range(len(comp_keys))):
        alturas = [valores[1][ki], valores[2][ki]]
        ax.bar(x, alturas, 0.45, bottom=bottom,
               color=cor, edgecolor="k", lw=0.5, label=lbl)
        # Valor dentro da fatia (se grande o suficiente)
        for i, h in enumerate(alturas):
            if h > max(P_totais) * 0.04:
                ax.text(x[i], bottom[i] + h / 2, f"{h:.0f}",
                        ha="center", va="center", fontsize=9, color="white",
                        fontweight="bold")
        bottom = [bottom[i] + alturas[i] for i in range(2)]

    # P_total acima de cada barra
    for i, ptot in enumerate(P_totais):
        ax.text(x[i], ptot + max(P_totais) * 0.02,
                f"$P_{{tot}}$ = {ptot:.0f} kW",
                ha="center", va="bottom", fontsize=10, fontweight="bold")

    # Delta total entre os dois casos
    dP    = P_totais[1] - P_totais[0]
    dP_pc = 100 * dP / P_totais[0]
    ax.annotate(f"Δ = {dP:+.0f} kW ({dP_pc:+.1f}%)",
                xy=(1, P_totais[1] * 0.97),
                xytext=(0.5, P_totais[1] * 1.12),
                fontsize=10, color="gray", ha="center",
                arrowprops=dict(arrowstyle="->", color="gray", lw=0.7))

    ax.set_xticks(x)
    ax.set_xticklabels(cats, fontsize=10)
    ax.set_ylabel("Potência (kW)")
    ax.set_ylim(bottom=0, top=max(P_totais) * 1.28)
    ax.legend(loc="upper right", frameon=True, fontsize=9)
    ax.yaxis.set_minor_locator(ticker.AutoMinorLocator())
    fig.tight_layout()
    salvar(fig, pasta, "Comp_Decomp_VDM_C1vsC2.png")


def gerar_comparacoes(todos_dados: dict, results_dir: str):
    """Gera os gráficos de comparação entre casos."""
    pasta = os.path.join(results_dir, "comparacoes")
    print(f"\n=== Gráficos de Comparação ===")

    # Comparação #1 e #2 — C1 vs C2 (efeito do vento sobre a VDM)
    if 1 in todos_dados and 2 in todos_dados:
        plot_comp_vdm_vento(todos_dados[1], todos_dados[2], pasta)
        plot_comp_decomp_vdm(todos_dados[1], todos_dados[2], pasta)
    else:
        print("  (C1+C2 necessários para comparações de vento — pulando)")

    # Comparação #3 — C1 vs C3 (balanço de potência em subida)
    if 1 in todos_dados and 3 in todos_dados:
        plot_comp_potencia_subida(todos_dados[1], todos_dados[3], pasta)
    else:
        print("  (C1+C3 necessários para comparação de subida — pulando)")

    print(f"  Comparações salvas em {pasta}/")


# ── main ──────────────────────────────────────────────────────────────────────

def plotar_caso(caso: int, results_dir: str = RESULTS_DIR):
    print(f"\n=== Plotando Caso {caso} ===")
    dados     = carregar_json(caso, results_dir)
    V_vento   = float(dados["V_vento"])
    P_disp_hp = float(dados["P_disp_hp"])
    pasta     = os.path.join(results_dir, f"CASO{caso}")

    for fase in [2, 3, 4, 5]:
        print(f"  Fase {fase} – {NOME_FASE[fase]}")
        plot_polar(        dados[f"polar_F{fase}"],    caso, fase, V_vento, pasta)
        plot_cruzeiro(     dados[f"cruzeiro_F{fase}"], caso, fase, P_disp_hp, V_vento, pasta)
        plot_decomposicao( dados[f"cruzeiro_F{fase}"], caso, fase, P_disp_hp, pasta)

    plot_resumo_missao(dados, caso, pasta)
    print(f"  13 gráficos salvos em {pasta}/")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Gera plots a partir dos dados.json exportados pelo Octave."
    )
    parser.add_argument(
        "--aeronave", "-a",
        default="AH1S",
        help="Subpasta dentro de results/ (padrão: AH1S).",
    )
    parser.add_argument(
        "casos", nargs="*", type=int,
        help="Números dos casos a plotar. Omitir → plota todos disponíveis.",
    )
    args = parser.parse_args()

    RESULTS_DIR = os.path.join("results", args.aeronave)

    if args.casos:
        casos = args.casos
    else:
        if not os.path.isdir(RESULTS_DIR):
            print(f"Pasta não encontrada: {RESULTS_DIR}")
            sys.exit(1)
        casos = sorted([
            int(d.replace("CASO", ""))
            for d in os.listdir(RESULTS_DIR)
            if d.startswith("CASO") and
               os.path.isfile(os.path.join(RESULTS_DIR, d, "dados.json"))
        ])
        if not casos:
            print(f"Nenhum dados.json encontrado em {RESULTS_DIR}/CASO*/")
            sys.exit(1)

    todos_dados = {}
    for caso in casos:
        plotar_caso(caso, RESULTS_DIR)
        todos_dados[caso] = carregar_json(caso, RESULTS_DIR)

    # Gráficos de comparação apenas se houver mais de um caso disponível
    if len(todos_dados) > 1:
        gerar_comparacoes(todos_dados, RESULTS_DIR)

    print("\nConcluído!")
