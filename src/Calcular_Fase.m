function [potencias, W_final] = Calcular_Fase(W, h_solo, Zp, delta_ISA, heli, V_kt, Vc_fpm, tempo_min, usar_peso_medio)
    % CALCULAR_FASE  Potências e consumo de combustível para uma fase de voo
    % (pairado, cruzeiro, subida ou descida).
    %
    % Entradas:
    %   W              - Peso atual [lb]
    %   h_solo         - Altura acima do solo [ft]  (inf → OGE)
    %   Zp             - Altitude de pressão [ft]
    %   delta_ISA      - Desvio ISA [°C]
    %   heli           - Struct com parâmetros da aeronave
    %   V_kt           - TAS [kt]
    %   Vc_fpm         - Razão de subida/descida [fpm]  (negativo → descida)
    %   tempo_min      - Duração da fase [min]
    %   usar_peso_medio- (opcional) true aplica o preditor-corretor de peso médio
    %
    % Saídas:
    %   potencias - struct com P_ind, P_perf, P_par, P_vert, P_misc, P_tot [kW]
    %   W_final   - Peso ao final da fase [lb]

    if ~exist('usar_peso_medio', 'var') || isempty(usar_peso_medio)
        usar_peso_medio = false;
    end

    % Preditor-corretor de peso médio: uma passagem a peso fixo para estimar
    % W_final, e outra ao peso médio para refinar o consumo. Usado só em fases
    % longas (cruzeiro), onde ΔW/W deixa de ser desprezível.
    if usar_peso_medio
        [~, W_pred]            = Calcular_Fase(W, h_solo, Zp, delta_ISA, heli, V_kt, Vc_fpm, tempo_min, false);
        W_medio                = (W + W_pred) / 2;
        [potencias, W_med_fin] = Calcular_Fase(W_medio, h_solo, Zp, delta_ISA, heli, V_kt, Vc_fpm, tempo_min, false);
        W_final = W - (W_medio - W_med_fin);
        return
    end

    [rho, ~, ~, ~] = ISA(delta_ISA, Zp);
    V_fps  = V_kt   * 1.68781;
    Vc_fps = Vc_fpm / 60;

    % Velocidade induzida (Glauert). Em descida, o enunciado pede que λc seja
    % ignorado no iterativo; o termo real fica só no balanço de CP, adiante.
    lambda_c_iter = Vc_fps / heli.Omega_R;
    if Vc_fpm < 0
        lambda_c_iter = 0;
    end

    mu       = V_fps  / heli.Omega_R;
    lambda_c = Vc_fps / heli.Omega_R;

    v_h  = sqrt(W / (2 * rho * heli.A));
    v_i  = v_h;
    erro = 1;
    while erro > 0.001
        v_i_novo = v_h^2 / sqrt(V_fps^2 + (lambda_c_iter * heli.Omega_R + v_i)^2);
        erro     = abs(v_i_novo - v_i);
        v_i      = v_i_novo;
    end
    lambda_i = v_i / heli.Omega_R;

    CT = W / (rho * heli.A * heli.Omega_R^2);

    % Coeficientes de potência
    CP_ind    = (heli.ki * CT^2) / (2 * sqrt(mu^2 + (lambda_c_iter + lambda_i)^2));
    CP_perf   = (heli.sigma * heli.Cd0 / 8) * (1 + 4.65 * mu^2);
    CP_par    = (0.5 * heli.f / heli.A) * mu^3;
    CP_subida = lambda_c * CT;

    % Correção de efeito solo (Prouty): polinômio de grau 4 sobre z/D,
    % ajustado aos 9 pontos tabelados. Só tem efeito em pairado (V < 1 kt)
    % e z/D < 1; acima disso, o rotor já está OGE para efeitos práticos.
    if V_kt < 1 && ~isinf(h_solo)
        zD = (h_solo + heli.h) / (2 * heli.R);
        if zD < 1
            x_dados = [0.4302, 0.5169, 0.5656, 0.6083, 0.6701, 0.7093, 0.8185, 0.8945, 1.1558];
            y_dados = [0.8429, 0.8880, 0.9105, 0.9255, 0.9421, 0.9481, 0.9646, 0.9721, 0.9826];
            k_IGE   = polyval(polyfit(x_dados, y_dados, 4), zD);
            k_IGE   = max(0.0, min(k_IGE, 1.0));
            CP_ind  = CP_ind * k_IGE;
        end
    end

    CP_R     = CP_ind + CP_perf + CP_par + CP_subida;
    CP_misc  = (1/heli.eta_m - 1) * CP_R;
    CP_motor = CP_R / heli.eta_m;

    % CP → hp → kW  (ρA(ΩR)³ · CP em ft·lbf/s; /550 = hp; ·0.7457 = kW)
    rho_A_OmR3 = rho * heli.A * heli.Omega_R^3;
    conv       = rho_A_OmR3 / 550 * 0.7457;

    potencias.P_ind  = CP_ind    * conv;
    potencias.P_perf = CP_perf   * conv;
    potencias.P_par  = CP_par    * conv;
    potencias.P_vert = CP_subida * conv;
    potencias.P_misc = CP_misc   * conv;
    potencias.P_tot  = CP_motor  * conv;

    PEM_hp  = CP_motor * rho_A_OmR3 / 550;
    W_final = W - PEM_hp * heli.SFC * (tempo_min / 60);
end
