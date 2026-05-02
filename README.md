# PRJ-91 — Laboratório 3: Requisito de Missão
### Helicóptero AH-1S Cobra · ISA+20 · Sistema Imperial

---

## Estrutura do Projeto

```
LAB 03/
├── main.m                        # Ponto de entrada — define os casos e executa a missão
├── README.md
│
├── src/                          # Núcleo da simulação
│   ├── Calcular_Fase.m           # Potências e consumo por fase (preditor-corretor opcional)
│   ├── Analise_Velocidades_Cruzeiro.m  # Curva P(V): VDM, VAM, V_max e decomposição
│   ├── Polar_Velocidade.m        # Polar vertical: Vy, Vvm, Vrm
│   ├── analisar_fase.m           # Orquestrador: Polar + Cruzeiro → VDM, VAM, Vy  ¹
│   └── atribui_fase.m            # Monta struct de missão por fase  ¹
│
├── utils/                        # Utilitários genéricos de suporte
│   ├── ISA.m                     # Modelo de Atmosfera Padrão Internacional
│   ├── Exportar_Resultados.m     # Gera resultado.txt e dados.json por caso
│   └── plotar_caso.py            # Gera os gráficos PNG a partir de dados.json
│
├── config/
│   ├── heli_params.json          # Parâmetros do AH-1S Cobra
│   └── heli_params_alphaone.json # Parâmetros do AlphaOne
│
└── results/AH1S/
    └── CASO{1..4}/
        ├── resultado.txt         # Tabela de potências, velocidades e consumo
        ├── dados.json            # Dados numéricos serializados
        ├── Balanco_Fase{2..5}_*.png  # Curva P(V) com VDM/VAM e decomposição
        └── Polar_Fase{2..5}_*.png    # Polar de velocidade vertical
```
> ¹ `analisar_fase` e `atribui_fase` existem como arquivos separados em `src/` para compatibilidade com Octave.
> No MATLAB, estão definidas como *local functions* diretamente em `main.m`.

### Descrição dos módulos

| Arquivo | Responsabilidade |
|---|---|
| `main.m` | Define aeronáve, casos e parâmetros; executa as 6 fases em sequência |
| `src/Calcular_Fase.m` | Resolve o iterativo de Glauert, calcula todos os $C_P$; flag `usar_peso_medio` ativa o preditor-corretor |
| `src/Analise_Velocidades_Cruzeiro.m` | Varre 0–200 kt; calcula VDM (tangente) e VAM (mínimo); plota P(V) e decomposição |
| `src/Polar_Velocidade.m` | Constrói a polar vertical; determina Vy, Vvm e Vrm |
| `utils/ISA.m` | Calcula $\rho$, $T$ e $P$ para qualquer altitude-pressão com desvio $\Delta T_\text{ISA}$ |
| `utils/Exportar_Resultados.m` | Formata e grava `resultado.txt` e `dados.json` por caso |
| `utils/plotar_caso.py` | Lê `dados.json` e gera os gráficos PNG em `results/` |

---

## Missão Analisada

A missão completa é composta por seis fases, todas a ISA+20 °C:

| # | Fase | Condição |
|---|---|---|
| 1 | Pairado IGE | 5 min · $Z_p = 0$ ft · $h = 6$ ft acima do solo |
| 2 | Subida na $V_y$ | $V_c = 1000$ fpm · $0 \to 5000$ ft (Caso 3: 2000 fpm) |
| 3 | Nivelado na VDM | Distância de 400 NM · $Z_p = 5000$ ft (Caso 4: 440 NM) |
| 4 | Nivelado na VAM | 30 min de reserva · $Z_p = 5000$ ft |
| 5 | Descida na $V_y$ | $V_c = -1000$ fpm · $5000 \to 0$ ft |
| 6 | Pairado IGE | 5 min · $Z_p = 0$ ft · $h = 6$ ft |

**Quatro casos** parametrizam vento, distância e razão de subida:

| Caso | Vento (kt) | Distância (NM) | $V_c$ subida (fpm) |
|---|---|---|---|
| 1 | 0 | 400 | 1 000 |
| 2 | −15 (proa) | 400 | 1 000 |
| 3 | 0 | 400 | 2 000 |
| 4 | 0 | 440 | 1 000 |

---

## Metodologia

### 1. Atmosfera ISA com desvio de temperatura

Para uma altitude-pressão $Z_p$ (ft) e desvio $\Delta T_\text{ISA}$:

$$T_\text{std} = T_0 + L \cdot Z_{p,m}, \qquad T_\text{real} = T_\text{std} + \Delta T_\text{ISA}$$

$$P = P_0 \left(\frac{T_\text{std}}{T_0}\right)^{-g/(LR)}, \qquad \sigma_\rho = \frac{P/P_0}{T_\text{real}/T_0}, \qquad \rho = \rho_0 \cdot \sigma_\rho$$

onde $T_0 = 288{,}15$ K, $P_0 = 101\,325$ Pa, $\rho_0 = 0{,}0023769$ slug/ft³, $L = -0{,}0065$ K/m.

---

### 2. Coeficiente de potência total

Para o caso mais geral (subida com velocidade de avanço):

$$\boxed{C_P = k_i \frac{C_T^2}{2\sqrt{\mu^2 + (\lambda_c + \lambda_i)^2}} + \frac{\sigma C_{d0}}{8}(1 + 4{,}65\,\mu^2) + \frac{1}{2}\frac{f}{A}\mu^3 + C_{P_\text{misc}} + \lambda_c C_T}$$

com:

$$\mu = \frac{V_\text{TAS}}{\Omega R}, \quad \lambda_c = \frac{V_c}{\Omega R}, \quad C_T = \frac{W}{\rho A (\Omega R)^2}$$

A **potência dimensional** é obtida por:

$$P = \rho\,A\,(\Omega R)^3\,C_P$$

---

### 3. Velocidade induzida — iterativo de Glauert

A velocidade induzida $\lambda_i$ é resolvida iterativamente pela equação implícita de Glauert:

$$\lambda_i = \frac{C_T/2}{\sqrt{\mu^2 + (\lambda_c^\text{ind} + \lambda_i)^2}}$$

> **Nota — descida:** conforme o enunciado, despreza-se a variação da potência induzida com a razão de descida; usa-se $\lambda_c^\text{ind} = 0$ no iterativo enquanto o termo $\lambda_c C_T$ real (negativo) é mantido no $C_P$ total.

---

### 4. Potência de miscelânea e eficiência mecânica

$$\eta_m = \frac{P_{eR}}{P_{eM}} \implies C_{P_\text{misc}} = \left(\frac{1}{\eta_m} - 1\right) C_{P_\text{rotor}}, \quad C_{P_\text{motor}} = \frac{C_{P_\text{rotor}}}{\eta_m}$$

---

### 5. Correção de efeito solo (IGE)

Para voo pairado a baixa altura ($V < 1$ kt e $h$ finita), aplica-se a correção de Prouty sobre a potência induzida. O fator de redução $k_\text{IGE}$ é interpolado da curva experimental (razão $z/D$) por um polinômio de grau 4 ajustado aos dados tabelados:

$$C_{P_\text{ind}}^\text{IGE} = C_{P_\text{ind}}^\text{OGE} \cdot k_\text{IGE}\!\left(\frac{z}{D}\right)$$

onde $z = h_\text{solo} + h_\text{rotor}$ e $D = 2R$.

---

### 6. Preditor-corretor de peso médio

O consumo de combustível em cada fase é calculado pelo método preditor-corretor para contabilizar a variação de peso durante a fase. Este método está integrado diretamente em `Calcular_Fase` e é ativado pelo nono parâmetro opcional `usar_peso_medio = true` — mantendo a interface simples (peso fixo, sem o flag) para contextos que não requerem precisão extra (e.g., geração de polares):

$$W_\text{final}^* = W_\text{ini} - \Delta W\bigl(W_\text{ini}\bigr) \quad \text{(Preditor)}$$

$$W_\text{med} = \frac{W_\text{ini} + W_\text{final}^*}{2} \quad \text{(Peso médio)}$$

$$W_\text{final} = W_\text{ini} - \Delta W\bigl(W_\text{med}\bigr) \quad \text{(Corretor)}$$

O consumo por fase é:

$$\Delta W_\text{comb} = \text{SFC} \times P_\text{motor}\bigl(W_\text{med}\bigr) \times \Delta t$$

---

### 7. Velocidade de Distância Máxima (VDM)

A VDM maximiza a distância para dado combustível. Geometricamente, é o ponto de tangência da reta que parte da **origem da velocidade-solo** ($V_{GS} = 0$, ou seja, $V_\text{TAS} = -V_\text{vento}$) à curva $P(V_\text{TAS})$:

$$\text{VDM} = \arg\min_{V} \frac{P(V)}{V + V_\text{vento}}$$

O tempo de F3 usa a velocidade-solo: $t_3 = d / V_{GS} = d / (V_\text{DM} + V_\text{vento})$.

---

### 8. Velocidade de Autonomia Máxima (VAM)

A VAM minimiza o consumo por unidade de tempo, correspondendo ao mínimo da curva de potência necessária:

$$\text{VAM} = \arg\min_{V} P(V)$$

---

## Resultados

### Tabela-resumo dos 4 casos

| Caso | Vento | Dist. | $V_c$ sub. | Comb. gasto (lb) | Margem (lb) | Potência | Combustível |
|---|---|---|---|---|---|---|---|
| 1 | 0 kt | 400 NM | 1 000 fpm | 1 554,13 | +129,87 | ✅ | ✅ |
| 2 | −15 kt | 400 NM | 1 000 fpm | 1 735,22 | −51,22 | ✅ | ❌ |
| 3 | 0 kt | 400 NM | 2 000 fpm | 1 541,86 | +142,14 | ❌ | ✅ |
| 4 | 0 kt | 440 NM | 1 000 fpm | 1 675,98 | +8,02 | ✅ | ✅ |

> **Caso 2** — O vento de proa de 15 kt aumenta o tempo de cruzeiro em F3 (VDM de 400 NM com $V_{GS}$ reduzida), tornando o combustível insuficiente.  
> **Caso 3** — A razão de subida de 2 000 fpm exige potência superior à disponível (1 290 hp), inviabilizando a fase de subida.

---

### Balanço de potência — Caso 1, Fase 3 (Nivelado na VDM, 5 000 ft)

![Balanço de potência F3 — CASO 1](results/AH1S/CASO1/Balanco_Fase3_Nivelado_VDM_Zp5000ft.png)

A reta tangente partindo da origem toca a curva de potência total no ponto de **VDM = 115,9 kt** (sem vento). O ponto de mínimo da curva, em **VAM ≈ 70,3 kt**, é destacado separadamente e utilizado na Fase 4.

---

### Polar de velocidade — Caso 1, Fase 2 (Subida na $V_y$, 2 500 ft)

![Polar de velocidade F2 — CASO 1](results/AH1S/CASO1/Polar_Fase2_Subida_Zp2500ft.png)

A polar mostra a curva de máxima razão de subida (envelope superior) e a curva de autorotação (envelope inferior). A velocidade $V_y = 72{,}9$ kt corresponde ao pico do envelope superior.

---

## Dependências

- **MATLAB** ≥ R2020a  **ou**  **GNU Octave** ≥ 6.0
- Nenhuma toolbox adicional é requerida

## Execução

**MATLAB** (a partir da raiz do projeto):
```matlab
main
```

**Octave** (a partir da raiz do projeto):
```bash
octave --no-gui --eval "run('main.m')"
```

Os resultados são gravados em `results/AH1S/CASO{1..4}/resultado.txt` e `dados.json`.
Para gerar os gráficos PNG após a simulação:
```bash
python3 utils/plotar_caso.py --aeronave AH1S
```
