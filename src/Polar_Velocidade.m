function [V_tas, V_gs, Vc_v, Vy, RoC_max, Vvm, Vrm, Vc_auto, VrM] = Polar_Velocidade(W, Zp, dI, heli, RoC_m, plotar, V_a, V_v)
    % POLAR_VELOCIDADE  Constrói o envelope de performance vertical do helicóptero.
    %
    % Entradas:
    %   W      - Peso atual da aeronave [lb]
    %   Zp     - Altitude de pressão [ft]
    %   dI     - Desvio de temperatura ISA [°C]
    %   heli   - Struct com parâmetros da aeronave
    %   RoC_m  - Razão de subida comandada na missão [fpm]  (usado só no plot)
    %   plotar - Booleano: gera figuras se true
    %   V_a    - (Opcional) Velocidade alvo para extração de RoC específica [kt]
    %   V_v    - (Opcional) Velocidade do vento [kt]  (+ cauda, − proa). Padrão: 0
    %
    % Saídas:
    %   V_tas   - Vetor de velocidades aerodinâmicas varridas [kt]
    %   V_gs    - Vetor de velocidades em relação ao solo [kt]
    %   Vc_v    - Curva superior: razão de subida máxima em cada V_tas [fpm]
    %   Vy      - Velocidade de Máxima Razão de Subida [kt]
    %   RoC_max - Razão de subida máxima atingível [fpm]
    %   Vvm     - Velocidade de Mínima Razão de Descida [kt]
    %   Vrm     - Velocidade de Mínima Rampa de Descida [kt]
    %   Vc_auto - Curva inferior: razão de descida em autorotação [fpm]
    %   VrM     - Velocidade de Máxima Rampa de Subida [kt]


    %% 1. ENTRADAS OPCIONAIS
    if nargin < 8 || isempty(V_v), V_v = 0; end
    if nargin < 7,                 V_a = []; end


    %% 2. VARREDURA — PERFORMANCE VERTICAL PARA CADA VELOCIDADE
    %
    % Passo de 0.1 kt para precisão numérica.
    % tempo_min = 1 é valor fictício (apenas P_req é usada).
    V_tas   = 0 : 0.1 : 180;
    V_gs    = V_tas + V_v;

    Vc_v    = zeros(size(V_tas));   % curva superior (com potência disponível)
    Vc_auto = zeros(size(V_tas));   % curva inferior (autorotação, sem motor)

    P_disp_hp = heli.P_disp_hp;

    for k = 1:length(V_tas)
        % Calcula potência necessária para voo nivelado a esta velocidade
        [r_k, ~] = Calcular_Fase(W, inf, Zp, dI, heli, V_tas(k), 0, 1);
        Preq_hp  = r_k.P_tot / 0.7457;   % kW → hp

        % Razão de subida máxima: potência excedente converte em energia potencial
        % Vc = (P_disp - P_req) [hp] × 33000 [ft·lbf/min / hp] / W [lbf]
        Vc_v(k)    = (P_disp_hp - Preq_hp) * 33000 / W;

        % Autorotação: toda P_req vira descida (sem motor, P_disp = 0)
        Vc_auto(k) = -Preq_hp * 33000 / W;
    end


    %% 3. VELOCIDADES NOTÁVEIS

    % ── Velocidades de Razão — independem do vento ───────────────────────────
    % Vy:  pico do envelope de subida → maior razão de subida (fpm)
    % Vvm: pico do envelope de descida → menor taxa de descida em autorotação
    [RoC_max, idx_vM] = max(Vc_v);
    Vy = V_tas(idx_vM);

    [~, idx_vm] = max(Vc_auto);   % max de Vc_auto = menos negativo = menor descida
    Vvm = V_tas(idx_vm);

    % ── Velocidades de Rampa — dependem do vento ─────────────────────────────
    % gamma = Vc / V_GS = tangente do ângulo de trajetória
    % Equivale geometricamente à tangente traçada da origem (−V_vento, 0)
    % à curva Vc(V_TAS).
    gamma_subida  = Vc_v    ./ V_gs;
    gamma_descida = Vc_auto ./ V_gs;

    % Filtra V_gs ≤ 5 kt para evitar instabilidade numérica perto da origem
    gamma_subida (V_gs <= 5) = -inf;
    gamma_descida(V_gs <= 5) = -inf;

    [~, idx_rM] = max(gamma_subida);   % máxima rampa de subida (melhor ângulo de climb)
    VrM = V_tas(idx_rM);

    [~, idx_rm] = max(gamma_descida);  % mínima rampa de descida (menor ângulo de planar)
    Vrm = V_tas(idx_rm);


    %% 4. GRÁFICO (OPCIONAL)
    if ~plotar, return; end

    figure('Color', 'w', 'Name', sprintf('Polar de Velocidade | %.0f lb | %.0f ft', W, Zp));
    hold on; grid on;

    % Envelopes de subida e autorotação
    plot(V_tas, Vc_v,    'b', 'LineWidth', 2, 'DisplayName', 'Envelope de Subida (MCP)');
    plot(V_tas, Vc_auto, 'r', 'LineWidth', 2, 'DisplayName', 'Autorotação (Sem Potência)');

    % Eixos de referência
    plot([min(V_tas) - 10, max(V_tas)], [0 0],                 'k',  'HandleVisibility', 'off');
    plot([0 0], [min(Vc_auto) - 200, max(Vc_v) + 200],         'k:', 'HandleVisibility', 'off');

    % Retas de tangente (origem = −V_vento)
    plot([-V_v, VrM], [0, Vc_v(idx_rM)],    'b--', 'HandleVisibility', 'off');
    plot([-V_v, Vrm], [0, Vc_auto(idx_rm)],  'r--', 'HandleVisibility', 'off');

    % Pontos notáveis de subida
    plot(Vy,  Vc_v(idx_vM),  'b*', 'MarkerSize', 10, 'DisplayName', sprintf('Vy  = %.1f kt', Vy));
    plot(VrM, Vc_v(idx_rM),  'bo', 'MarkerFaceColor', 'b', ...
         'DisplayName', sprintf('VrM = %.1f kt', VrM));

    % Pontos notáveis de descida
    plot(Vvm, Vc_auto(idx_vm), 'r*', 'MarkerSize', 10, 'DisplayName', sprintf('Vvm = %.1f kt', Vvm));
    plot(Vrm, Vc_auto(idx_rm), 'ro', 'MarkerFaceColor', 'r', ...
         'DisplayName', sprintf('Vrm = %.1f kt', Vrm));

    % Ponto da missão (apenas em subida/descida; omitido se RoC_m == 0)
    if ~isempty(RoC_m) && RoC_m ~= 0
        plot(Vy, RoC_m, 'go', 'MarkerFaceColor', 'g', 'MarkerSize', 8, ...
             'DisplayName', 'Ponto da Missão');
    end

    xlabel('Velocidade Aerodinâmica - TAS (kt)',    'FontWeight', 'bold');
    ylabel('Razão Vertical (fpm)',                  'FontWeight', 'bold');
    title(sprintf('Polar de Velocidade | W: %.0f lb | Zp: %.0f ft | Vento: %.0f kt', W, Zp, V_v));
    legend('Location', 'northeastoutside');
    xlim([min(-V_v - 10, 0), 180]);
    ylim([min(Vc_auto) - 500, max(Vc_v) + 500]);
end
