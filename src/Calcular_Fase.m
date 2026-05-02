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

    if nargin < 9, usar_peso_medio = false; end

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

    V_fps  = V_kt    * 1.68781;   % kt → ft/s
    Vc_fps = Vc_fpm  / 60;        % ft/min → ft/s


    %% 2. VELOCIDADE INDUZIDA — ITERATIVO DE GLAUERT
    %
    % Tratamento especial para descida:
    % O enunciado exige despresar a variação de vi com Vc negativo.
    % Usa-se Vc_fps_ind = 0 apenas no iterativo (lambda_c_ind),
    % mas o termo real de subida/descida (lambda_c) é mantido no CP total.
    Vc_fps_ind = Vc_fps;
    if Vc_fpm < 0
        Vc_fps_ind = 0;
    end

    mu           = V_fps            / heli.Omega_R;
    lambda_c     = Vc_fps           / heli.Omega_R;   % lambda_c real (positivo = subida)
    lambda_c_ind = Vc_fps_ind       / heli.Omega_R;   % lambda_c para o iterativo

    % Velocidade induzida de pairado ideal (v_h), usada como chute inicial
    v_h = sqrt(W / (2 * rho * heli.A));

    % Iteração de ponto fixo: vi = v_h² / sqrt(mu² + (lambda_c_ind + vi)²)
    v_i  = v_h;
    erro = 1;
    while erro > 0.001
        v_i_novo = v_h^2 / sqrt(V_fps^2 + (Vc_fps_ind + v_i)^2);
        erro     = abs(v_i_novo - v_i);
        v_i      = v_i_novo;
    end
    lambda_i = v_i / heli.Omega_R;


    %% 3. COEFICIENTE DE TRAÇÃO
    Ct = W / (rho * heli.A * heli.Omega_R^2);


    %% 4. COEFICIENTES DE POTÊNCIA

    % ── Potência Induzida (OGE base) ─────────────────────────────────────────
    CP_ind = (heli.ki * Ct^2) / (2 * sqrt(mu^2 + (lambda_c_ind + lambda_i)^2));

    % ── Correção de Efeito Solo (IGE) — Método de Prouty ────────────────────
    % Aplica-se somente em pairado (V < 1 kt) com altura de solo finita.
    % O fator k_IGE(z/D) é interpolado por polinômio de grau 4 ajustado
    % aos dados experimentais de Prouty (razão z/D vs redução de P_ind).
    if V_kt < 1 && ~isinf(h_solo)
        D       = 2 * heli.R;
        x_razao = (h_solo + heli.h) / D;   % z/D: altura normalizada pelo diâmetro

        if x_razao < 1   % efeito solo significativo apenas até z/D < 1
            x_dados = [0.4302, 0.5169, 0.5656, 0.6083, 0.6701, 0.7093, 0.8185, 0.8945, 1.1558];
            y_dados = [0.8429, 0.8880, 0.9105, 0.9255, 0.9421, 0.9481, 0.9646, 0.9721, 0.9826];
            p_ige   = polyfit(x_dados, y_dados, 4);
            k_IGE   = polyval(p_ige, x_razao);

            CP_ind  = CP_ind * k_IGE;   % k_IGE < 1 → reduz potência induzida
        end
    end

    % ── Perfil, Parasita e Subida/Descida ────────────────────────────────────
    % sigma * Cd0 / 8 * (1 + 4.65 mu²): arrasto de perfil das pás (Lock)
    CP_perf = (heli.sigma * heli.Cd0 / 8) * (1 + 4.65 * mu^2);

    % (f/A) * mu³ / 2: arrasto parasita da fuselagem (análogo ao CD0 de asa fixa)
    CP_par  = (0.5 * heli.f / heli.A) * mu^3;

    % lambda_c * Ct: trabalho contra a gravidade (positivo = sobe, negativo = desce)
    CP_sub  = lambda_c * Ct;

    % ── Balanço Motor (inclui perdas mecânicas) ───────────────────────────────
    % CP_RP:    potência total entregue ao rotor principal
    % CP_misc:  perdas para acessórios e rotor de cauda  (η_m < 1)
    % CP_motor: potência que o motor deve fornecer = CP_RP / η_m
    CP_RP    = CP_ind + CP_perf + CP_par + CP_sub;
    CP_misc  = (1/heli.eta_m - 1) * CP_RP;
    CP_motor = CP_RP / heli.eta_m;


    %% 5. CONVERSÃO PARA kW E MONTAGEM DA STRUCT DE SAÍDA
    %
    % Cadeia de unidades:
    %   Fator * CP  →  [slug/ft³ · ft² · (ft/s)³ · adim] = ft·lbf/s
    %   ÷ 550       →  hp   (1 hp = 550 ft·lbf/s)
    %   × 0.7457    →  kW   (1 hp = 0.7457 kW)
    Fator = rho * heli.A * heli.Omega_R^3;
    hp2kw = 0.7457;
    conv  = Fator / 550 * hp2kw;

    potencias.P_ind  = CP_ind   * conv;
    potencias.P_perf = CP_perf  * conv;
    potencias.P_par  = CP_par   * conv;
    potencias.P_vert = CP_sub   * conv;   % negativo em descida
    potencias.P_misc = CP_misc  * conv;
    potencias.P_tot  = CP_motor * conv;


    %% 6. CONSUMO DE COMBUSTÍVEL
    %
    % SFC [lb/hp/h] × P_motor [hp] = fluxo [lb/h]
    % Convertendo P_motor de volta para hp antes de aplicar o SFC:
    P_motor_hp    = CP_motor * Fator / 550;
    fluxo_lb_hr   = P_motor_hp * heli.SFC;
    W_final       = W - fluxo_lb_hr * (tempo_min / 60);
end
