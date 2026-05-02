function [polar, cruzeiro, Vy, VDM, VAM, Vvm, Vrm] = analisar_fase(W, Zp, dT, heli, Vc_fpm, V_vento, plotar)
    % ANALISAR_FASE  Orquestra a análise de desempenho de uma fase de voo.
    %
    % Entradas:
    %   W        - Peso da aeronave [lb]
    %   Zp       - Altitude de pressão [ft]
    %   dT       - Desvio de temperatura ISA [°C]
    %   heli     - Struct com parâmetros da aeronave
    %   Vc_fpm   - Razão de subida/descida comandada [fpm]  (0 = nivelado)
    %   V_vento  - Componente longitudinal do vento [kt]  (+ cauda, - proa)
    %   plotar   - Booleano: gera figuras se true
    %
    % Saídas:
    %   polar    - Struct com a curva polar de velocidade vertical
    %   cruzeiro - Struct com a curva de potência em cruzeiro
    %   Vy       - Velocidade de Máxima Razão de Subida [kt]
    %   VDM      - Velocidade de Distância Máxima (maior alcance) [kt]
    %   VAM      - Velocidade de Autonomia Máxima (maior autonomia) [kt]
    %   Vvm      - Velocidade de Mínima Razão de Descida [kt]
    %   Vrm      - Velocidade de Mínima Rampa de Descida [kt]

    [V_pol, ~, Vc_v, Vy, ~, Vvm, Vrm, Vc_auto, VrM] = ...
        Polar_Velocidade(W, Zp, dT, heli, Vc_fpm, plotar, [], V_vento);

    % V_mr = tangente à curva P/V = Maior Alcance = VDM
    % V_md = mínimo da curva de potência = Maior Autonomia = VAM
    [VDM, VAM, V_max, V_cru, P_cru] = ...
        Analise_Velocidades_Cruzeiro(W, Zp, dT, heli, V_vento, plotar);

    polar = struct('W', W, 'Zp', Zp, 'dT', dT, ...
                   'V_tas', V_pol, 'Vc_v', Vc_v, 'Vc_auto', Vc_auto, ...
                   'Vy', Vy, 'VrM', VrM, 'Vvm', Vvm, 'Vrm', Vrm);

    cruzeiro = struct('W', W, 'Zp', Zp, ...
                      'V_tas', V_cru, 'P_tot_hp', P_cru, ...
                      'V_mr', VDM, 'V_md', VAM, 'V_max', V_max);
end
