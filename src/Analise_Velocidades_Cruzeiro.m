function [VDM, VAM, V_max, V_tas_out, P_tot_hp_out, P_ind_hp_out, P_perf_hp_out, P_par_hp_out, P_misc_hp_out] = Analise_Velocidades_Cruzeiro(W, Zp, delta_ISA, heli, V_vento_kt, plotar_grafico)
    % ANALISE_VELOCIDADES_CRUZEIRO  Calcula velocidades notáveis de cruzeiro
    % e gera curvas de potência (balanço + decomposição).
    %
    % Entradas:
    %   W             - Peso atual [lb]
    %   Zp            - Altitude de pressão [ft]
    %   delta_ISA     - Desvio ISA [°C]
    %   heli          - Struct com parâmetros da aeronave
    %   V_vento_kt    - Vento (+ cauda, − proa) [kt]
    %   plotar_grafico- Booleano: gera figuras se true
    %
    % Saídas:
    %   VDM              - Velocidade de Distância Máxima [kt]  (máximo alcance)
    %   VAM              - Velocidade de Máxima Autonomia [kt]  (mínima P_tot)
    %   V_max            - Velocidade máxima de voo nivelado [kt]
    %   V_tas_out        - Vetor TAS varrido [kt]
    %   P_tot_hp_out     - Curva de potência necessária total [hp]
    %   P_ind_hp_out, P_perf_hp_out, P_par_hp_out, P_misc_hp_out
    %                    - Componentes de potência [hp]


    %% 1. POTÊNCIA DISPONÍVEL DO MOTOR (PEM)
    P_disp_hp = heli.P_disp_hp;


    %% 2. VARREDURA DE VELOCIDADES — VOO NIVELADO OGE
    %
    % Passo de 0.1 kt → melhor resolução na localização de mínimos e tangentes.
    % Vc_fpm = 0 (nivelado); tempo_min = 1 é fictício — só P_tot interessa.
    V_tas_kt  = 1 : 0.1 : 200;
    n         = length(V_tas_kt);

    P_tot_hp  = zeros(1, n);
    P_ind_hp  = zeros(1, n);
    P_perf_hp = zeros(1, n);
    P_par_hp  = zeros(1, n);
    P_misc_hp = zeros(1, n);

    for k = 1:n
        [r_k, ~]   = Calcular_Fase(W, inf, Zp, delta_ISA, heli, V_tas_kt(k), 0, 1);
        P_tot_hp(k) = r_k.P_tot  / 0.7457;
        P_ind_hp(k) = r_k.P_ind  / 0.7457;
        P_perf_hp(k)= r_k.P_perf / 0.7457;
        P_par_hp(k) = r_k.P_par  / 0.7457;
        P_misc_hp(k)= r_k.P_misc / 0.7457;
    end


    %% 3. VELOCIDADES NOTÁVEIS

    % ── VAM — Velocidade de Máxima Autonomia ─────────────────────────────────
    % Mínimo de P_tot → mínimo consumo instantâneo → aeronave voa mais tempo.
    % Eq. 2.14: Ci = Ce · P_tot  →  máxima autonomia quando P_tot é mínima.
    [P_tot_min, idx_VAM] = min(P_tot_hp);
    VAM                  = V_tas_kt(idx_VAM);

    % ── VDM — Velocidade de Distância Máxima ─────────────────────────────────
    % Máximo de V_GS/P_tot → tangente da reta que parte de (−V_vento, 0) e toca
    % a curva P_tot(V_tas). Geometricamente: mínima inclinação P_tot/V_GS.
    % Eq. 2.15: distância ∝ V_GS/P_tot  →  máximo alcance quando V_GS/P_tot é máximo.
    V_gs_kt   = V_tas_kt + V_vento_kt;
    PN_por_VG = P_tot_hp ./ max(V_gs_kt, 0.1);   % evita divisão por zero

    [~, idx_VDM] = min(PN_por_VG);
    VDM          = V_tas_kt(idx_VDM);
    P_tot_VDM    = P_tot_hp(idx_VDM);

    % ── V_max — Velocidade Máxima de Voo Nivelado ────────────────────────────
    % Maior velocidade onde P_tot ≤ P_disp.  Interpolação linear para precisão.
    delta_P   = P_disp_hp - P_tot_hp;   % margem de potência; > 0 → voo possível
    idx_cross = find(delta_P(1:end-1) >= 0 & delta_P(2:end) < 0, 1, 'last');
    if isempty(idx_cross)
        V_max = V_tas_kt(end);
    else
        V_max = interp1(delta_P(idx_cross:idx_cross+1), ...
                        V_tas_kt(idx_cross:idx_cross+1), 0);
    end


    %% 4. SAÍDAS NUMÉRICAS
    V_tas_out    = V_tas_kt;
    P_tot_hp_out = P_tot_hp;
    P_ind_hp_out = P_ind_hp;
    P_perf_hp_out= P_perf_hp;
    P_par_hp_out = P_par_hp;
    P_misc_hp_out= P_misc_hp;


    %% 5. GRÁFICOS (OPCIONAL)
    if ~plotar_grafico, return; end

    % ── Figura 1: Balanço de Potência P(V) ───────────────────────────────────
    figure('Color', 'w', 'Name', sprintf('Balanço de Potência | %.0f lb | %.0f ft', W, Zp));
    hold on; grid on;

    plot(V_tas_kt, P_tot_hp, 'b-', 'LineWidth', 2, 'DisplayName', 'P_{tot} — Necessária');
    yline(P_disp_hp,         'r-', 'LineWidth', 2, 'DisplayName', 'P_{disp} — Disponível');

    % Reta tangente para VDM (parte de −V_vento no eixo V)
    x_tang = [-V_vento_kt, VDM];
    y_tang = [0, P_tot_VDM];
    plot(x_tang, y_tang, 'g--', 'LineWidth', 1.5, 'DisplayName', 'Reta Tangente V_{DM}');

    % Marcadores das velocidades notáveis
    plot(VDM, P_tot_VDM, 'g^', 'MarkerFaceColor', 'g', 'MarkerSize', 8, ...
         'DisplayName', sprintf('VDM = %.1f kt | P_{tot} = %.1f hp', VDM, P_tot_VDM));
    plot(VAM, P_tot_min, 'mv', 'MarkerFaceColor', 'm', 'MarkerSize', 8, ...
         'DisplayName', sprintf('VAM = %.1f kt | P_{tot} = %.1f hp', VAM, P_tot_min));
    plot(V_max, P_disp_hp, 'rs', 'MarkerFaceColor', 'r', 'MarkerSize', 8, ...
         'DisplayName', sprintf('Vmax = %.1f kt', V_max));

    xlabel('Velocidade Aerodinâmica - TAS (kt)', 'FontWeight', 'bold');
    ylabel('Potência (hp)',                       'FontWeight', 'bold');
    title(sprintf('Balanço de Potência | W: %.0f lb | Zp: %.0f ft | Vento: %.0f kt', W, Zp, V_vento_kt));
    legend('Location', 'northeastoutside');
    xlim([0 200]);
    ylim([0, P_disp_hp * 1.15]);

    % ── Figura 2: Decomposição de Potência ───────────────────────────────────
    % Os vetores já foram calculados no loop acima — nenhuma varredura extra.
    figure('Color', 'w', 'Name', sprintf('Decomposição de Potência | %.0f lb | %.0f ft', W, Zp));
    hold on; grid on;

    plot(V_tas_kt, P_ind_hp,  'g-',  'LineWidth', 2, 'DisplayName', 'P_{ind} — Induzida');
    plot(V_tas_kt, P_perf_hp, 'c-',  'LineWidth', 2, 'DisplayName', 'P_{perf} — Perfil');
    plot(V_tas_kt, P_par_hp,  'm-',  'LineWidth', 2, 'DisplayName', 'P_{par} — Parasita');
    plot(V_tas_kt, P_misc_hp, 'y-',  'LineWidth', 2, 'DisplayName', 'P_{misc} — Miscelânea');
    plot(V_tas_kt, P_tot_hp,  'k-',  'LineWidth', 3, 'DisplayName', 'P_{tot} — Total Necessária');
    yline(P_disp_hp,          'r--', 'LineWidth', 2, 'DisplayName', 'P_{disp} — Disponível');

    xlabel('Velocidade Aerodinâmica - TAS (kt)', 'FontWeight', 'bold');
    ylabel('Potência (hp)',                       'FontWeight', 'bold');
    title(sprintf('Decomposição de Potência | W: %.0f lb | Zp: %.0f ft', W, Zp));
    legend('Location', 'northeastoutside');
    xlim([0 200]);
    ylim([0, P_disp_hp * 1.15]);
end
