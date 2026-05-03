% PRJ-91 — Laboratório 3: simulação da missão completa
clear; clc; close all;

addpath(fullfile(fileparts(mfilename('fullpath')), 'src'));
addpath(fullfile(fileparts(mfilename('fullpath')), 'utils'));

% AH-1S Cobra
heli         = jsondecode(fileread(fullfile(fileparts(mfilename('fullpath')), 'config', 'heli_params.json')));
output_base  = fullfile(fileparts(mfilename('fullpath')), 'results', 'AH1S');
fase3_VDM    = true;    % true: F3 = VDM, F4 = VAM;  false: inverte
tempo_loiter = 30;      % [min]
casos = [ ...           %  id | V_vento(kt) | dist(NM) | Vc_sub(fpm)
    1,    0,   400,  1000 ; ...
    2,  -15,   400,  1000 ; ...
    3,    0,   400,  2000 ; ...
    4,    0,   440,  1000 ];

heli.A         = pi * heli.R^2;
heli.P_disp_kw = heli.P_disp_hp * 0.7457;
plotar         = true;   % gera e salva figuras MATLAB em results/

dT = 20;   % desvio ISA [°C]

for k = 1 : size(casos, 1)

    caso        = casos(k, 1);
    V_vento     = casos(k, 2);
    distancia_3 = casos(k, 3);
    Vc_sub_fpm  = casos(k, 4);

    output_folder = fullfile(output_base, sprintf('CASO%d', caso));
    fprintf('\n======================================================\n');
    fprintf(' CASO %d  (vento=%d kt | dist=%d NM | Vc_sub=%d fpm)\n', ...
            caso, V_vento, distancia_3, Vc_sub_fpm);
    fprintf('======================================================\n');

    missao = repmat(struct('nome','','P_ind',0,'P_perf',0,'P_par',0, ...
                           'P_vert',0,'P_misc',0,'P_tot',0,'vel',0,'comb',0), 1, 6);
    W_atual          = heli.MTOW;
    total_comb_gasto = 0;
    polar    = [];
    cruzeiro = [];

    % Fase 1 — pairado inicial IGE
    W_antes = W_atual;
    [potencias, W_atual] = Calcular_Fase(W_atual, 6, 0, dT, heli, 0, 0, 5);
    missao(1)        = atribui_fase('Pairado IGE', 0, potencias, W_antes - W_atual);
    total_comb_gasto = total_comb_gasto + missao(1).comb;

    % Fase 2 — subida na Vy (0 → 5000 ft)
    Zp_2    = 2500;
    tempo_2 = 5000 / Vc_sub_fpm;

    [polar(2), cruzeiro(2), Vy_2, ~, ~, ~, ~] = ...
        analisar_fase(W_atual, Zp_2, dT, heli, Vc_sub_fpm, V_vento, plotar, output_folder, 'F2');

    W_antes = W_atual;
    [potencias, W_atual] = Calcular_Fase(W_atual, inf, Zp_2, dT, heli, Vy_2, Vc_sub_fpm, tempo_2, true);
    missao(2)        = atribui_fase('Subida na Vy', Vy_2, potencias, W_antes - W_atual);
    total_comb_gasto = total_comb_gasto + missao(2).comb;

    % Fases 3 e 4 — cruzeiro + loiter
    if fase3_VDM
        [polar(3), cruzeiro(3), ~, V_f3, ~, ~, ~] = ...
            analisar_fase(W_atual, 5000, dT, heli, 0, V_vento, plotar, output_folder, 'F3');
        nome_f3 = 'Nivelado na VDM';
        nome_f4 = 'Nivelado na VAM';
    else
        [polar(3), cruzeiro(3), ~, ~, V_f3, ~, ~] = ...
            analisar_fase(W_atual, 5000, dT, heli, 0, V_vento, plotar, output_folder, 'F3');
        nome_f3 = 'Nivelado na VAM';
        nome_f4 = 'Nivelado na VDM';
    end

    V_gs_3  = V_f3 + V_vento;
    tempo_3 = (distancia_3 / V_gs_3) * 60;

    W_antes = W_atual;
    [potencias, W_atual] = Calcular_Fase(W_atual, inf, 5000, dT, heli, V_f3, 0, tempo_3, true);
    missao(3)        = atribui_fase(nome_f3, V_f3, potencias, W_antes - W_atual);
    total_comb_gasto = total_comb_gasto + missao(3).comb;

    % F4 é recalculada após F3 para usar o peso já reduzido pelo cruzeiro
    if fase3_VDM
        [polar(4), cruzeiro(4), ~, ~, V_f4, ~, ~] = ...
            analisar_fase(W_atual, 5000, dT, heli, 0, V_vento, plotar, output_folder, 'F4');
    else
        [polar(4), cruzeiro(4), ~, V_f4, ~, ~, ~] = ...
            analisar_fase(W_atual, 5000, dT, heli, 0, V_vento, plotar, output_folder, 'F4');
    end

    W_antes = W_atual;
    [potencias, W_atual] = Calcular_Fase(W_atual, inf, 5000, dT, heli, V_f4, 0, tempo_loiter, true);
    missao(4)        = atribui_fase(nome_f4, V_f4, potencias, W_antes - W_atual);
    total_comb_gasto = total_comb_gasto + missao(4).comb;

    % Fase 5 — descida na Vy (5000 → 0 ft a 1000 fpm)
    Zp_5    = 2500;
    tempo_5 = 5000 / 1000;

    [polar(5), cruzeiro(5), Vy_5, ~, ~, ~, ~] = ...
        analisar_fase(W_atual, Zp_5, dT, heli, -1000, V_vento, plotar, output_folder, 'F5');

    W_antes = W_atual;
    [potencias, W_atual] = Calcular_Fase(W_atual, inf, Zp_5, dT, heli, Vy_5, -1000, tempo_5, true);
    missao(5)        = atribui_fase('Descida na Vy', Vy_5, potencias, W_antes - W_atual);
    total_comb_gasto = total_comb_gasto + missao(5).comb;

    % Fase 6 — pairado final IGE
    W_antes = W_atual;
    [potencias, W_atual] = Calcular_Fase(W_atual, 6, 0, dT, heli, 0, 0, 5, true);
    missao(6)        = atribui_fase('Pairado IGE', 0, potencias, W_antes - W_atual);
    total_comb_gasto = total_comb_gasto + missao(6).comb;

    params = struct('Vc_sub_fpm', Vc_sub_fpm, 'distancia_NM', distancia_3);
    Exportar_Resultados(caso, V_vento, heli, missao, total_comb_gasto, polar, cruzeiro, output_folder, params);
    close all;
end

fprintf('\nTodos os casos concluídos.\n');
