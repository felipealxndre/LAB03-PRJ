function [V_mr, V_md, V_max, V_tas_out, P_tot_hp_out, P_ind_hp_out, P_perf_hp_out, P_par_hp_out, P_misc_hp_out] = Analise_Velocidades_Cruzeiro(W, Zp, delta_ISA, heli, V_vento_kt, plotar_grafico)
    % ANALISE_VELOCIDADES_CRUZEIRO  Determina as velocidades notáveis de cruzeiro
    % (VDM — Maior Alcance, VAM — Maior Autonomia, V_max) e plota as curvas.
    %
    % Entradas:
    %   W              - Peso da aeronave [lb]
    %   Zp             - Altitude de pressão [ft]
    %   delta_ISA      - Variação de temperatura ISA [°C]
    %   heli           - Struct com os parâmetros do helicóptero
    %   V_vento_kt     - (Opcional) Vento longitudinal [kt]  (+ cauda, − proa). Padrão: 0
    %   plotar_grafico - (Opcional) Booleano. Padrão: true
    %
    % Saídas:
    %   V_mr        - VDM: Velocidade de Maior Alcance (tangente à curva P/V_GS) [kt TAS]
    %   V_md        - VAM: Velocidade de Maior Autonomia (mínimo da curva P) [kt TAS]
    %   V_max       - Velocidade máxima horizontal (cruzamento P_req = P_disp) [kt TAS]
    %   V_tas_out   - Vetor de velocidades usadas na varredura [kt]
    %   P_tot_hp_out- Vetor de potência total correspondente [hp]


    %% 1. ENTRADAS OPCIONAIS
    if nargin < 5 || isempty(V_vento_kt),    V_vento_kt    = 0;    end
    if nargin < 6 || isempty(plotar_grafico), plotar_grafico = true; end


    %% 2. VARREDURA DE VELOCIDADES — VOO NIVELADO OGE
    %
    % Passo de 0.1 kt para a precisão numérica exigida no laboratório.
    % tempo_min = 1 é valor fictício (só interessa P, não consumo).
    V_tas_kt = 0 : 0.1 : 200;
    N        = length(V_tas_kt);

    P_tot_hp  = zeros(1, N);
    P_ind_hp  = zeros(1, N);
    P_perf_hp = zeros(1, N);
    P_par_hp  = zeros(1, N);
    P_misc_hp = zeros(1, N);

    kw2hp     = 1 / 0.7457;
    P_disp_hp = heli.P_disp_hp;

    for i = 1:N
        % Vc = 0 (nivelado), h_solo = inf (OGE), tempo = 1 min (fictício)
        [r_i, ~]    = Calcular_Fase(W, inf, Zp, delta_ISA, heli, V_tas_kt(i), 0, 1);
        P_tot_hp(i)  = r_i.P_tot  * kw2hp;
        P_ind_hp(i)  = r_i.P_ind  * kw2hp;
        P_perf_hp(i) = r_i.P_perf * kw2hp;
        P_par_hp(i)  = r_i.P_par  * kw2hp;
        P_misc_hp(i) = r_i.P_misc * kw2hp;
    end


    %% 3. VELOCIDADES NOTÁVEIS

    % ── VAM (V_md): mínimo da curva P(V) ─────────────────────────────────────
    % Minimiza consumo por unidade de tempo → maior autonomia.
    [P_min, idx_md] = min(P_tot_hp);
    V_md = V_tas_kt(idx_md);

    % ── VDM (V_mr): tangente à curva P(V) a partir da origem da V_GS ─────────
    % Minimiza P / V_GS, que é proporcional ao combustível por distância.
    % A origem da V_GS está em V_TAS = -V_vento (ponto de V_GS = 0).
    V_gs_kt   = V_tas_kt + V_vento_kt;
    razao_P_V = P_tot_hp ./ V_gs_kt;
    razao_P_V(V_gs_kt <= 0) = inf;   % descarta pontos com V_GS nula ou negativa

    [~, idx_mr] = min(razao_P_V);
    V_mr = V_tas_kt(idx_mr);
    P_mr = P_tot_hp(idx_mr);

    % ── V_max: cruzamento P_req = P_disp ─────────────────────────────────────
    % Busca o último ponto onde ainda há potência disponível e interpola
    % linearmente para encontrar o cruzamento exato.
    Delta_P = P_disp_hp - P_tot_hp;
    pos_idx = find(Delta_P > 0);

    if isempty(pos_idx)
        V_max = NaN;   % sem potência suficiente para voo nivelado
    else
        idx_cross = pos_idx(end);
        if idx_cross < N
            x_vals = [Delta_P(idx_cross), Delta_P(idx_cross + 1)];
            y_vals = [V_tas_kt(idx_cross), V_tas_kt(idx_cross + 1)];
            V_max  = interp1(x_vals, y_vals, 0);
        else
            V_max = V_tas_kt(end);
        end
    end


    %% 4. SAÍDAS NUMÉRICAS
    V_tas_out     = V_tas_kt;
    P_tot_hp_out  = P_tot_hp;
    P_ind_hp_out  = P_ind_hp;
    P_perf_hp_out = P_perf_hp;
    P_par_hp_out  = P_par_hp;
    P_misc_hp_out = P_misc_hp;


    %% 5. GRÁFICOS (OPCIONAL)
    if ~plotar_grafico, return; end

    % ── Figura 1: curva P(V) com VDM, VAM e V_max ────────────────────────────
    figure('Color', 'w', 'Name', sprintf('Velocidades de Cruzeiro | %.0f lb | %.0f ft', W, Zp));
    hold on; grid on;

    plot(V_tas_kt, P_tot_hp, 'k-',  'LineWidth', 2.5, 'DisplayName', 'Potência Necessária Total');
    yline(P_disp_hp, 'r-', 'LineWidth', 2, 'DisplayName', 'Potência Máx. Disponível');

    % VAM — mínimo da curva
    plot(V_md, P_min, 'bo', 'MarkerFaceColor', 'b', 'MarkerSize', 8, ...
         'DisplayName', sprintf('V_{md}/V_{AM} = %.1f kt', V_md));
    plot([V_md V_md], [0 P_min], 'b:', 'LineWidth', 1.5, 'HandleVisibility', 'off');

    % VDM — ponto de tangência
    plot(V_mr, P_mr, 'go', 'MarkerFaceColor', 'g', 'MarkerSize', 8, ...
         'DisplayName', sprintf('V_{mr}/V_{DM} = %.1f kt', V_mr));
    plot([V_mr V_mr], [0 P_mr], 'g:', 'LineWidth', 1.5, 'HandleVisibility', 'off');

    % Reta tangente: P = m · V_GS, com m = P_VDM / V_GS_VDM
    m_tangente  = P_mr / (V_mr + V_vento_kt);
    v_gs_plot   = [0, max(V_gs_kt)];
    v_tas_plot  = v_gs_plot - V_vento_kt;   % converte V_GS → V_TAS para o eixo X
    plot(v_tas_plot, m_tangente .* v_gs_plot, 'g--', 'LineWidth', 1.5, ...
         'DisplayName', 'Reta Tangente V_{DM}');

    % V_max
    if ~isnan(V_max)
        plot(V_max, P_disp_hp, 'mo', 'MarkerFaceColor', 'm', 'MarkerSize', 8, ...
             'DisplayName', sprintf('V_{max} = %.1f kt', V_max));
        plot([V_max V_max], [0 P_disp_hp], 'm:', 'LineWidth', 1.5, 'HandleVisibility', 'off');
    end

    % Marca a origem da V_GS quando há vento (V_TAS = −V_vento → V_GS = 0)
    if V_vento_kt ~= 0
        plot(-V_vento_kt, 0, 'kx', 'MarkerSize', 10, 'LineWidth', 2, ...
             'DisplayName', 'Origem V_{GS}');
    end

    xlabel('Velocidade de Avanço Verdadeira - TAS (kt)', 'FontWeight', 'bold');
    ylabel('Potência do Motor (hp)',                     'FontWeight', 'bold');
    title(sprintf('Voo Nivelado | W: %.0f lb | Zp: %.0f ft | Vento: %d kt', W, Zp, V_vento_kt));
    legend('Location', 'northwest', 'FontSize', 10);
    xlim([min(0, -V_vento_kt - 10), max(V_tas_kt(end), 160)]);
    ylim([0, P_disp_hp + 300]);

    % ── Figura 2: decomposição das componentes ────────────────────────────────
    % Os vetores já foram calculados no loop acima — nenhuma varredura extra.
    figure('Color', 'w', 'Name', sprintf('Decomposição de Potência | %.0f lb | %.0f ft', W, Zp));
    hold on; grid on;

    plot(V_tas_kt, P_ind_hp,  'g-', 'LineWidth', 2,   'DisplayName', 'Induzida');
    plot(V_tas_kt, P_perf_hp, 'c-', 'LineWidth', 2,   'DisplayName', 'Perfil');
    plot(V_tas_kt, P_par_hp,  'm-', 'LineWidth', 2,   'DisplayName', 'Parasita');
    plot(V_tas_kt, P_misc_hp, 'y-', 'LineWidth', 2,   'DisplayName', 'Miscelânea');
    plot(V_tas_kt, P_tot_hp,  'k-', 'LineWidth', 3,   'DisplayName', 'Total Necessária');
    yline(P_disp_hp, 'r-',          'LineWidth', 2,   'DisplayName', 'Disponível');

    xlabel('Velocidade de Avanço (kt)', 'FontWeight', 'bold');
    ylabel('Potência do Motor (hp)',    'FontWeight', 'bold');
    title(sprintf('Decomposição de Potência | W: %.0f lb | Zp: %.0f ft', W, Zp));
    legend('Location', 'northwest', 'FontSize', 10);
    xlim([0, 160]);
    ylim([0, P_disp_hp + 300]);
end
