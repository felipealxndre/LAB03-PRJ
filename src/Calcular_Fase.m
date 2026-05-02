function [potencias, W_final] = Calcular_Fase(W, h_solo, Zp, delta_ISA, heli, V_kt, Vc_fpm, tempo_min, usar_peso_medio)
    % CALCULAR_FASE  Calcula desempenho e consumo para qualquer fase de voo
    % (Pairado, Cruzeiro, Subida ou Descida).
    %
    % Entradas:
    %   W              - Peso atual da aeronave [lb]
    %   h_solo         - Altura acima do solo [ft]  (inf = OGE)
    %   Zp             - Altitude de pressão [ft]
    %   delta_ISA      - Desvio de temperatura ISA [°C]
    %   heli           - Struct com parâmetros da aeronave
    %   V_kt           - Velocidade de avanço [kt]
    %   Vc_fpm         - Razão de subida/descida [fpm]  (negativo = descida)
    %   tempo_min      - Duração da fase [min]
    %   usar_peso_medio- (opcional, padrão false)
    %       true  → aplica preditor-corretor de peso médio (recomendado para
    %               fases longas onde ΔW/W ≳ 5%, ex.: cruzeiro de centenas de NM)
    %       false → cálculo a peso fixo — suficiente para fases curtas
    %               (pairado, subida, descida) onde ΔW/W ≲ 1%
    %
    % Saídas:
    %   potencias - struct com potências [kW]: P_ind, P_perf, P_par, P_vert, P_misc, P_tot
    %   W_final   - Peso ao fim da fase [lb]  →  comb = W - W_final

    if ~exist('usar_peso_medio', 'var') || isempty(usar_peso_medio)
        usar_peso_medio = false;
    end

    % =========================================================================
    % PREDITOR-CORRETOR DE PESO MÉDIO
    %
    % Quando a fase consome uma fração significativa do peso total, calcular
    % tudo no peso inicial superestima o consumo — a aeronave vai ficando mais
    % leve e mais eficiente ao longo da fase.
    %
    % O método resolve isso em duas passagens recursivas:
    %   1. Preditor : roda a peso fixo (W_ini) para estimar W_final
    %   2. Corretor : roda a peso médio (W_ini + W_pred) / 2 e projeta W_final
    % =========================================================================
    if usar_peso_medio
        [~, W_pred]            = Calcular_Fase(W, h_solo, Zp, delta_ISA, heli, V_kt, Vc_fpm, tempo_min, false);
        W_medio                = (W + W_pred) / 2;
        [potencias, W_med_fin] = Calcular_Fase(W_medio, h_solo, Zp, delta_ISA, heli, V_kt, Vc_fpm, tempo_min, false);
        W_final = W - (W_medio - W_med_fin);
        return
    end


    %% 1. ATMOSFERA E CONVERSÃO DE UNIDADES
    [rho, ~, ~, ~] = ISA(delta_ISA, Zp);

    V_fps  = V_kt   * 1.68781;   % kt → ft/s
    Vc_fps = Vc_fpm / 60;        % ft/min → ft/s


    %% 2. VELOCIDADE INDUZIDA — ITERATIVO DE GLAUERT
    %
    % Tratamento especial para descida:
    % O enunciado exige desprezar a variação de λi com Vc negativo.
    % Usa-se lambda_c_iter = 0 apenas no iterativo (Eq. 2.9),
    % mas o termo real de subida/descida (lambda_c) é mantido no CP total.
    lambda_c_iter = Vc_fps / heli.Omega_R;
    if Vc_fpm < 0
        lambda_c_iter = 0;
    end

    mu       = V_fps  / heli.Omega_R;   % razão de avanço μ = V / (ΩR)
    lambda_c = Vc_fps / heli.Omega_R;   % inflow de subida λc = Vc / (ΩR)

    % Velocidade induzida de pairado ideal (v_h), usada como chute inicial
    v_h = sqrt(W / (2 * rho * heli.A));

    % Iteração de ponto fixo: λi = (CT/2) / sqrt(μ² + (λc_iter + λi)²)
    v_i  = v_h;
    erro = 1;
    while erro > 0.001
        v_i_novo = v_h^2 / sqrt(V_fps^2 + (lambda_c_iter * heli.Omega_R + v_i)^2);
        erro     = abs(v_i_novo - v_i);
        v_i      = v_i_novo;
    end
    lambda_i = v_i / heli.Omega_R;   % λi = vi / (ΩR)


    %% 3. COEFICIENTE DE TRAÇÃO
    CT = W / (rho * heli.A * heli.Omega_R^2);   % CT = W / (ρ A (ΩR)²)


    %% 4. COEFICIENTES DE POTÊNCIA  (Equações 2.1 e 2.6 do relatório)

    % ── Potência Induzida (OGE base) ─────────────────────────────────────────
    % Eq. 2.1: ki · CT² / (2 · sqrt(μ² + (λc_iter + λi)²))
    CP_ind = (heli.ki * CT^2) / (2 * sqrt(mu^2 + (lambda_c_iter + lambda_i)^2));

    % ── Correção de Efeito Solo (IGE) — Método de Prouty ────────────────────
    % Aplica-se somente em pairado (V < 1 kt) com altura de solo finita.
    % O fator k_IGE(z/D) é interpolado por polinômio de grau 4 ajustado
    % aos dados experimentais de Prouty: V1,IGE/V1,OGE em função de z/D.
    if V_kt < 1 && ~isinf(h_solo)
        D       = 2 * heli.R;
        zD      = (h_solo + heli.h) / D;   % z/D: altura normalizada pelo diâmetro

        if zD < 1   % efeito solo significativo apenas até z/D < 1
            x_dados = [0.4302, 0.5169, 0.5656, 0.6083, 0.6701, 0.7093, 0.8185, 0.8945, 1.1558];
            y_dados = [0.8429, 0.8880, 0.9105, 0.9255, 0.9421, 0.9481, 0.9646, 0.9721, 0.9826];
            p_ige   = polyfit(x_dados, y_dados, 4);
            k_IGE   = polyval(p_ige, zD);

            k_IGE  = max(0.0, min(k_IGE, 1.0));   % limites físicos obrigatórios
            CP_ind = CP_ind * k_IGE;
        end
    end

    % ── Perfil, Parasita ──────────────────────────────────────────────────────
    % Eq. 2.1: σ·Cd0/8·(1 + 4,65·μ²) — arrasto de perfil das pás
    CP_perf = (heli.sigma * heli.Cd0 / 8) * (1 + 4.65 * mu^2);

    % Eq. 2.1: (1/2)·(f/A)·μ³ — arrasto parasita da fuselagem
    CP_par  = (0.5 * heli.f / heli.A) * mu^3;

    % ── Subida / Descida ──────────────────────────────────────────────────────
    % Eq. 2.8 / 2.11: CPsubida = λc · CT   (negativo em descida → recupera potência)
    CP_subida = lambda_c * CT;

    % ── Balanço Motor  (Equações 2.3 a 2.5) ──────────────────────────────────
    % CP_R:     potência total entregue ao rotor principal
    % CP_misc:  perdas para acessórios e rotor de cauda  (ηm < 1)
    % CP_motor: potência que o motor deve fornecer = CP_R / ηm  (= CP da Eq. 2.2)
    CP_R     = CP_ind + CP_perf + CP_par + CP_subida;
    CP_misc  = (1/heli.eta_m - 1) * CP_R;
    CP_motor = CP_R / heli.eta_m;


    %% 5. CONVERSÃO PARA kW E MONTAGEM DA STRUCT DE SAÍDA
    %
    % Cadeia de unidades (Eq. 2.2):
    %   ρ · A · (ΩR)³ · CP  →  [slug/ft³ · ft² · (ft/s)³] = ft·lbf/s
    %   ÷ 550               →  hp   (1 hp = 550 ft·lbf/s)
    %   × 0.7457            →  kW   (1 hp = 0.7457 kW)
    rho_A_OmR3 = rho * heli.A * heli.Omega_R^3;
    hp2kw      = 0.7457;
    conv       = rho_A_OmR3 / 550 * hp2kw;

    potencias.P_ind  = CP_ind    * conv;
    potencias.P_perf = CP_perf   * conv;
    potencias.P_par  = CP_par    * conv;
    potencias.P_vert = CP_subida * conv;   % negativo em descida
    potencias.P_misc = CP_misc   * conv;
    potencias.P_tot  = CP_motor  * conv;


    %% 6. CONSUMO DE COMBUSTÍVEL
    %
    % SFC [lb/hp/h] × PEM [hp] = fluxo [lb/h]
    PEM_hp  = CP_motor * rho_A_OmR3 / 550;   % Potência do motor em hp (PeM do relatório)
    W_final = W - PEM_hp * heli.SFC * (tempo_min / 60);
end
