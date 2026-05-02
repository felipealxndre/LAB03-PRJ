function [polar, cruzeiro, Vy, VDM, VAM, Vvm, Vrm] = analisar_fase(W, Zp, dT, heli, Vc_fpm, V_vento, plotar)
    % ANALISAR_FASE  Orquestra a análise de desempenho de uma fase de voo.
    %
    % Calcula a polar de velocidades (performance vertical) e o balanço de
    % potência de cruzeiro, retornando structs compactos e velocidades notáveis.
    %
    % Entradas:
    %   W        - Peso atual [lb]
    %   Zp       - Altitude de pressão [ft]
    %   dT       - Desvio ISA [°C]
    %   heli     - Struct com parâmetros da aeronave
    %   Vc_fpm   - Razão de subida/descida comandada [fpm]
    %   V_vento  - Velocidade do vento [kt]  (+ cauda, − proa)
    %   plotar   - Booleano: gera figuras se true
    %
    % Saídas:
    %   polar    - Struct: W, Zp, V_tas, vZ, vZ_auto e velocidades notáveis da polar
    %   cruzeiro - Struct: W, Zp, VDM, VAM, V_max, V_tas, P_tot e componentes
    %   Vy       - Velocidade de Máxima Razão de Subida [kt]
    %   VDM      - Velocidade de Distância Máxima [kt]
    %   VAM      - Velocidade de Máxima Autonomia [kt]
    %   Vvm      - Velocidade de Mínima Razão de Descida [kt]
    %   Vrm      - Velocidade de Mínima Rampa de Descida [kt]


    % ── Polar de Velocidades ──────────────────────────────────────────────────
    [V_pol, ~, vZ, Vy, Vzmax, Vvm, Vrm, vZ_auto, VrM] = ...
        Polar_Velocidade(W, Zp, dT, heli, Vc_fpm, plotar, [], V_vento);

    % ── Balanço de Potência de Cruzeiro ──────────────────────────────────────
    [VDM, VAM, V_max, V_tas, P_tot_hp, P_ind, P_perf, P_par, P_misc] = ...
        Analise_Velocidades_Cruzeiro(W, Zp, dT, heli, V_vento, plotar);

    % ── Montagem das structs de saída ─────────────────────────────────────────
    polar = struct('W', W, 'Zp', Zp, 'dT', dT, ...
                   'V_tas',   V_pol,   ...
                   'vZ',      vZ,      ...
                   'vZ_auto', vZ_auto, ...
                   'Vy',      Vy,      ...
                   'Vzmax',   Vzmax,   ...
                   'VrM',     VrM,     ...
                   'Vvm',     Vvm,     ...
                   'Vrm',     Vrm);

    cruzeiro = struct('W', W, 'Zp', Zp,                               ...
                      'V_tas',     V_tas,    'P_tot_hp',  P_tot_hp,  ...
                      'P_ind_hp',  P_ind,    'P_perf_hp', P_perf,    ...
                      'P_par_hp',  P_par,    'P_misc_hp', P_misc,    ...
                      'VDM', VDM, 'VAM', VAM, 'V_max', V_max);
end
