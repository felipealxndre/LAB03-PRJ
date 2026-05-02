function [V_tas, V_gs, vZ, Vy, Vzmax, Vvm, Vrm, vZ_auto, VrM] = Polar_Velocidade(W, Zp, dI, heli, RoC_m, plotar, V_a, V_v)
    % POLAR_VELOCIDADE  Constrói o envelope de performance vertical do helicóptero.
    %
    % Entradas:
    %   W      - Peso atual da aeronave [lb]
    %   Zp     - Altitude de pressão [ft]
    %   dI     - Desvio de temperatura ISA [°C]
    %   heli   - Struct com parâmetros da aeronave
    %   RoC_m  - Razão de subida comandada na missão [fpm]  (usado só no plot)
    %   plotar - Booleano: gera figuras se true
    %   V_a    - (Opcional) Velocidade alvo para extração de vZ específico [kt]
    %   V_v    - (Opcional) Velocidade do vento [kt]  (+ cauda, − proa). Padrão: 0
    %
    % Saídas:
    %   V_tas   - Vetor de velocidades aerodinâmicas varridas [kt]
    %   V_gs    - Vetor de velocidades em relação ao solo [kt]
    %   vZ      - Curva superior: razão de subida máxima (PEM - PN)/mg [fpm]   (Eq. 2.16)
    %   Vy      - Velocidade de Máxima Razão de Subida [kt]
    %   Vzmax   - Razão de subida máxima atingível [fpm]
    %   Vvm     - Velocidade de Mínima Razão de Descida [kt]
    %   Vrm     - Velocidade de Mínima Rampa de Descida [kt]
    %   vZ_auto - Curva inferior: razão de descida em autorotação [fpm]
    %   VrM     - Velocidade de Máxima Rampa de Subida [kt]


    %% Entradas opcionais
    if nargin < 8 || isempty(V_v), V_v = 0; end % se não for passado, assume vento nulo
    if nargin < 7,                 V_a = []; end % se não for passado, assume velocidade alvo nula


    %% Varredura - performance vertical para cada velocidade
    V_tas   = 0 : 0.1 : 180;  % passo de 0.1 kt para precisão numérica
    V_gs    = V_tas + V_v;    % velocidade solo (TAS + vento)
    vZ      = zeros(size(V_tas));   % curva superior (com PEM disponível)
    vZ_auto = zeros(size(V_tas));   % curva inferior (autorotação — sem motor)
    P_disp_hp = heli.P_disp_hp;
    
    for k = 1:length(V_tas)

        % Potência necessária para voo nivelado a esta velocidade
        [r_k, ~] = Calcular_Fase(W, inf, Zp, dI, heli, V_tas(k), 0, 1);
        P_tot_hp = r_k.P_tot / 0.7457;   % kW → hp

        % Excedente de potência vira altitude:
        vZ(k)      = (P_disp_hp - P_tot_hp) * 33000 / W;   % fpm

        % Autorotação: PEM = 0 (sem motor); toda a potência necessária vira descida
        vZ_auto(k) = -P_tot_hp * 33000 / W;   % fpm
    end


    %% Velocidades notáveis

    % Velocidades de Razão — independem do vento
    % Vy:  pico de vZ → máxima razão de subida (Vzmax)
    % Vvm: pico de vZ_auto → menor taxa de descida em autorotação
    [Vzmax, idx_Vy] = max(vZ);
    Vy = V_tas(idx_Vy);

    [~, idx_Vvm] = max(vZ_auto);   % max de vZ_auto = menos negativo = menor descida
    Vvm = V_tas(idx_Vvm);

    % Velocidades de Rampa — dependem do vento
    % γ = vZ / V_gs = tangente do ângulo de trajetória sobre o solo.
    % Geometricamente: tangente traçada da origem (−V_vento, 0) à curva vZ(V_tas).
    gama_s = vZ      ./ V_gs;   % ângulo de subida
    gama_d = vZ_auto ./ V_gs;   % ângulo de descida (autorotação)

    % Filtra V_gs ≤ 5 kt para evitar instabilidade numérica perto da origem
    gama_s(V_gs <= 5) = -inf;
    gama_d(V_gs <= 5) = -inf;

    [~, idx_VrM] = max(gama_s);   % máxima rampa de subida (melhor ângulo de climb)
    VrM = V_tas(idx_VrM);

    [~, idx_Vrm] = max(gama_d);   % mínima rampa de descida (menor ângulo de planar)
    Vrm = V_tas(idx_Vrm);


    %% Gráfico
    if ~plotar, return; end

    figure('Color', 'w', 'Name', sprintf('Polar de Velocidade | %.0f lb | %.0f ft', W, Zp));
    hold on; grid on;

    % Envelopes de subida e autorotação
    plot(V_tas, vZ,      'b', 'LineWidth', 2, 'DisplayName', 'Envelope de Subida (PEM)');
    plot(V_tas, vZ_auto, 'r', 'LineWidth', 2, 'DisplayName', 'Autorotação (PN, sem motor)');

    % Eixos de referência
    plot([min(V_tas) - 10, max(V_tas)], [0 0],                       'k',  'HandleVisibility', 'off');
    plot([0 0],             [min(vZ_auto) - 200, max(vZ) + 200],      'k:', 'HandleVisibility', 'off');

    % Retas de rampa (tangente a partir da origem = −V_vento)
    plot([-V_v, VrM], [0, vZ(idx_VrM)],      'b--', 'HandleVisibility', 'off');
    plot([-V_v, Vrm], [0, vZ_auto(idx_Vrm)], 'r--', 'HandleVisibility', 'off');

    % Pontos notáveis — subida
    plot(Vy,  vZ(idx_Vy),  'b*', 'MarkerSize', 10, 'DisplayName', sprintf('Vy  = %.1f kt  (Vzmax = %.0f fpm)', Vy, Vzmax));
    plot(VrM, vZ(idx_VrM), 'bo', 'MarkerFaceColor', 'b', ...
         'DisplayName', sprintf('VrM = %.1f kt', VrM));

    % Pontos notáveis — descida
    plot(Vvm, vZ_auto(idx_Vvm), 'r*', 'MarkerSize', 10, 'DisplayName', sprintf('Vvm = %.1f kt', Vvm));
    plot(Vrm, vZ_auto(idx_Vrm), 'ro', 'MarkerFaceColor', 'r', ...
         'DisplayName', sprintf('Vrm = %.1f kt', Vrm));

    % Ponto da missão (apenas em subida/descida; omitido se RoC_m == 0)
    if ~isempty(RoC_m) && RoC_m ~= 0
        plot(Vy, RoC_m, 'go', 'MarkerFaceColor', 'g', 'MarkerSize', 8, ...
             'DisplayName', 'Ponto da Missão');
    end

    xlabel('Velocidade Aerodinâmica - TAS (kt)', 'FontWeight', 'bold');
    ylabel('vZ — Razão Vertical (fpm)',           'FontWeight', 'bold');
    title(sprintf('Polar de Velocidade | W: %.0f lb | Zp: %.0f ft | Vento: %.0f kt', W, Zp, V_v));
    legend('Location', 'northeastoutside');
    xlim([min(-V_v - 10, 0), 180]);
    ylim([min(vZ_auto) - 500, max(vZ) + 500]);
end
