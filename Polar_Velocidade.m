function [V_tas, V_gs, Vc_v, Vy, RoC_max, Vvm, Vrm, Vc_auto, VrM] = Polar_Velocidade(W, Zp, dI, heli, RoC_m, plotar, V_a, V_v)
    % POLAR_VELOCIDADE - Gera o envelope de performance vertical do helicóptero.
    %
    % INPUTS:
    %   W       : Peso atual da aeronave [lb]
    %   Zp      : Altitude de pressão da fase [ft]
    %   dI      : Desvio de temperatura em relação ao padrão (Delta ISA) [°C]
    %   heli    : Struct contendo os parâmetros geométricos e de motor da aeronave
    %   RoC_m   : Razão de subida (ou descida) comandada na missão [fpm]
    %   plotar  : Booleano (true/false) para gerar o gráfico
    %   V_a     : Velocidade aerodinâmica alvo para extração de RoC específica [kt]
    %   V_v     : Velocidade do vento (Positivo = Cauda, Negativo = Proa) [kt]
    %
    % OUTPUTS:
    %   V_tas   : Vetor de velocidades aerodinâmicas (True Airspeed) [kt]
    %   V_gs    : Vetor de velocidades em relação ao solo (Ground Speed) [kt]
    %   Vc_v    : Vetor da curva superior (Máxima Razão de Subida) [fpm]
    %   Vy      : Velocidade de Melhor Razão de Subida (escalar) [kt]
    %   RoC_max : Razão de subida máxima atingível (escalar) [fpm]
    %   Vvm     : Velocidade de Mínima Razão de Descida (escalar) [kt]
    %   Vrm     : Velocidade de Mínima Rampa de Descida (escalar) [kt]

    %% 1. INICIALIZAÇÃO E TRATAMENTO DE INPUTS
    if nargin < 8 || isempty(V_v), V_v = 0; end
    if nargin < 7, V_a = []; end
    
    % Passo de 0.1 kt para a precisão exigida no laboratório
    V_tas = 0:0.1:180;             
    V_gs  = V_tas + V_v;           % Ground Speed considerando o vento [kt]
    Vc_v  = zeros(size(V_tas));    % Curva Superior: Subida Máxima (Com Potência)
    Vc_auto = zeros(size(V_tas));  % Curva Inferior: Autorotação (Sem Potência)
    
    P_disp_hp = heli.P_disp_hp;    % Limite de potência contínua (MCP) [hp]

    %% 2. VARREDURA DE PERFORMANCE AERODINÂMICA
    for k = 1:length(V_tas)
        % Calcula a potência necessária para voo nivelado (Vc = 0)
        [r_k, ~] = Calcular_Fase(W, inf, Zp, dI, heli, V_tas(k), 0, 1);
        Preq_hp = r_k.P_tot / 0.7457;

        % Curva Superior (Subida): Vc = (Pot_Sobra * 33000) / W
        Vc_v(k) = ((P_disp_hp - Preq_hp) * 33000) / W;

        % Curva Inferior (Descida/Autorotação): Vc = -(Pot_Req * 33000) / W
        Vc_auto(k) = -(Preq_hp * 33000) / W;
    end

    %% 3. DETERMINAÇÃO DAS VELOCIDADES NOTÁVEIS
    
    % --- Velocidades de Razão (Imunes ao vento) ---
    [RoC_max, idx_vM] = max(Vc_v); 
    Vy = V_tas(idx_vM);           % Velocidade de Máxima Razão de Subida (Vy)
    
    [RoC_min_des, idx_vm] = max(Vc_auto); 
    Vvm = V_tas(idx_vm);          % Velocidade de Mínima Razão de Descida

    % --- Velocidades de Rampa (Influenciadas pelo vento) ---
    % Calculadas pela tangente que parte da origem aerodinâmica (-V_vento, 0)
    gamma_subida  = Vc_v ./ (V_tas + V_v);
    gamma_descida = Vc_auto ./ (V_tas + V_v);

    % Filtro para evitar instabilidades na origem (V_gs próximo de zero)
    gamma_subida(V_gs <= 5) = -inf; 
    gamma_descida(V_gs <= 5) = -inf;

    [~, idx_rM] = max(gamma_subida);  VrM = V_tas(idx_rM); % Máxima Rampa de Subida
    [~, idx_rm] = max(gamma_descida); Vrm = V_tas(idx_rm); % Mínima Rampa de Descida

    %% 4. PLOTAGEM GEOMÉTRICA
    if plotar
        figure('Color','w', 'Name', sprintf('Polar de Velocidade | %.0f lb | %0.f ft', W, Zp));
        hold on; grid on;
        
        % Plot das Curvas de Performance
        plot(V_tas, Vc_v, 'b', 'LineWidth', 2, 'DisplayName', 'Envelope de Subida (MCP)');
        plot(V_tas, Vc_auto, 'r', 'LineWidth', 2, 'DisplayName', 'Autorotação (Sem Potência)');
        
        % Linhas de Referência
        plot([min(V_tas)-10, max(V_tas)], [0 0], 'k', 'HandleVisibility', 'off');
        plot([0 0], [min(Vc_auto)-200, max(Vc_v)+200], 'k:', 'HandleVisibility', 'off');
        
        % Plot das Tangentes de Rampa
        plot([-V_v, VrM], [0, Vc_v(idx_rM)], 'b--', 'HandleVisibility', 'off');
        plot([-V_v, Vrm], [0, Vc_auto(idx_rm)], 'r--', 'HandleVisibility', 'off');
        
        % Marcadores de Subida (VvM e VrM)
        plot(Vy, RoC_max, 'b*', 'MarkerSize', 10, 'DisplayName', sprintf('Vy = %.1f kt', Vy));
        plot(VrM, Vc_v(idx_rM), 'bo', 'MarkerFaceColor', 'b', 'DisplayName', sprintf('VrM = %.1f kt', VrM));
        
        % Marcadores de Descida (Vvm e Vrm)
        plot(Vvm, RoC_min_des, 'r*', 'MarkerSize', 10, 'DisplayName', sprintf('Vvm = %.1f kt', Vvm));
        plot(Vrm, Vc_auto(idx_rm), 'ro', 'MarkerFaceColor', 'r', 'DisplayName', sprintf('Vrm = %.1f kt', Vrm));

        % Ponto da Missão Atual
        if ~isempty(RoC_m) && RoC_m ~= 0
            plot(Vy, RoC_m, 'go', 'MarkerFaceColor', 'g', 'MarkerSize', 8, 'DisplayName', 'Ponto da Missão');
        end

        % Estética e Legendas
        xlabel('Velocidade Aerodinâmica - TAS (kt)', 'FontWeight', 'bold');
        ylabel('Razão Vertical (fpm)', 'FontWeight', 'bold');
        title(sprintf('Polar de Velocidade | W: %.0f lb | Zp: %.0f ft | Vento: %.0f kt', W, Zp, V_v));
        legend('Location', 'northeastoutside');
        
        % Ajuste do eixo para mostrar a "origem do vento"
        xlim([min(-V_v - 10, 0), 180]);
        ylim([min(Vc_auto)-500, max(Vc_v)+500]);
    end
end