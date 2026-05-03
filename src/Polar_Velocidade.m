function [V_tas, V_gs, vZ, Vy, Vzmax, Vvm, Vrm, vZ_auto, VrM] = Polar_Velocidade(W, Zp, dI, heli, RoC_m, plotar, V_a, V_v, pasta_fig, fase_label)
    % POLAR_VELOCIDADE  Envelope de desempenho vertical: curva de subida na PMC
    % e curva de autorrotação, com as velocidades notáveis correspondentes.
    %
    % Entradas:
    %   W, Zp, dI, heli - estado e configuração da aeronave
    %   RoC_m           - razão de subida da missão [fpm]  (só para marcar o ponto no plot)
    %   plotar          - gera figura em MATLAB se true
    %   V_a             - (opcional) velocidade-alvo para sinalização
    %   V_v             - (opcional) vento [kt]  (+ cauda, − proa; padrão 0)
    %
    % Saídas:
    %   V_tas, V_gs              TAS e velocidade-solo varridas [kt]
    %   vZ, vZ_auto              razões vertical para subida e autorrotação [fpm]
    %   Vy, Vzmax                máxima razão de subida e valor no pico
    %   Vvm, Vrm, VrM            velocidades notáveis de razão e rampa

    if nargin < 10, fase_label = ''; end
    if nargin < 9,  pasta_fig  = ''; end
    if nargin < 8 || isempty(V_v), V_v = 0;  end
    if nargin < 7,                 V_a = []; end

    V_tas   = 0 : 0.1 : 180;
    V_gs    = V_tas + V_v;
    vZ      = zeros(size(V_tas));
    vZ_auto = zeros(size(V_tas));
    P_disp_hp = heli.P_disp_hp;

    for k = 1:length(V_tas)
        [r_k, ~] = Calcular_Fase(W, inf, Zp, dI, heli, V_tas(k), 0, 1);
        P_tot_hp = r_k.P_tot / 0.7457;
        vZ(k)      = (P_disp_hp - P_tot_hp) * 33000 / W;   % excesso de potência → fpm
        vZ_auto(k) = -P_tot_hp              * 33000 / W;   % autorrotação: motor a 0
    end

    % Velocidades de razão (não dependem do vento)
    [Vzmax, idx_Vy]  = max(vZ);
    Vy               = V_tas(idx_Vy);
    [~,     idx_Vvm] = max(vZ_auto);      % max = menos negativo = menor descida
    Vvm              = V_tas(idx_Vvm);

    % Velocidades de rampa (γ = vZ / V_gs): tangente à curva a partir de
    % (−V_vento, 0). V_gs ≤ 5 kt é filtrado para evitar explosão numérica
    % perto da origem das tangentes.
    gama_s = vZ      ./ V_gs;
    gama_d = vZ_auto ./ V_gs;
    gama_s(V_gs <= 5) = -inf;
    gama_d(V_gs <= 5) = -inf;

    [~, idx_VrM] = max(gama_s);
    VrM          = V_tas(idx_VrM);
    [~, idx_Vrm] = max(gama_d);
    Vrm          = V_tas(idx_Vrm);

    if ~plotar, return; end

    fig = figure('Color', 'w', 'Name', sprintf('Polar de Velocidade | %.0f lb | %.0f ft', W, Zp));
    hold on; grid on;
    plot(V_tas, vZ,      'b', 'LineWidth', 2, 'DisplayName', 'Envelope de Subida (PMC)');
    plot(V_tas, vZ_auto, 'r', 'LineWidth', 2, 'DisplayName', 'Autorrotação (sem motor)');

    plot([min(V_tas) - 10, max(V_tas)], [0 0],                      'k',  'HandleVisibility', 'off');
    plot([0 0],             [min(vZ_auto) - 200, max(vZ) + 200],     'k:', 'HandleVisibility', 'off');

    plot([-V_v, VrM], [0, vZ(idx_VrM)],      'b--', 'HandleVisibility', 'off');
    plot([-V_v, Vrm], [0, vZ_auto(idx_Vrm)], 'r--', 'HandleVisibility', 'off');

    plot(Vy,  vZ(idx_Vy),       'b*', 'MarkerSize', 10, ...
         'DisplayName', sprintf('Vy  = %.1f kt  (Vzmax = %.0f fpm)', Vy, Vzmax));
    plot(VrM, vZ(idx_VrM),      'bo', 'MarkerFaceColor', 'b', ...
         'DisplayName', sprintf('VrM = %.1f kt', VrM));
    plot(Vvm, vZ_auto(idx_Vvm), 'r*', 'MarkerSize', 10, ...
         'DisplayName', sprintf('Vvm = %.1f kt', Vvm));
    plot(Vrm, vZ_auto(idx_Vrm), 'ro', 'MarkerFaceColor', 'r', ...
         'DisplayName', sprintf('Vrm = %.1f kt', Vrm));

    if ~isempty(RoC_m) && RoC_m ~= 0
        plot(Vy, RoC_m, 'go', 'MarkerFaceColor', 'g', 'MarkerSize', 8, ...
             'DisplayName', 'Ponto da Missão');
    end

    xlabel('Velocidade Aerodinâmica - TAS (kt)', 'FontWeight', 'bold');
    ylabel('vZ — Razão Vertical (fpm)',          'FontWeight', 'bold');
    title(sprintf('Polar de Velocidade | W: %.0f lb | Zp: %.0f ft | Vento: %.0f kt', W, Zp, V_v));
    legend('Location', 'northeastoutside');
    xlim([min(-V_v - 10, 0), 180]);
    ylim([min(vZ_auto) - 500, max(vZ) + 500]);

    if ~isempty(pasta_fig) && ~isempty(fase_label)
        if ~exist(pasta_fig, 'dir'), mkdir(pasta_fig); end
        saveas(fig, fullfile(pasta_fig, sprintf('Polar_%s.png', fase_label)));
    end
end
