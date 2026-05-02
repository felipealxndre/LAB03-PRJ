% =========================================================================
% PRJ-91: Laboratório 3 - Simulação de Missão Completa
% =========================================================================
clear; clc; close all;

% Adiciona src/ e utils/ ao path
addpath(fullfile(fileparts(mfilename('fullpath')), 'src'));
addpath(fullfile(fileparts(mfilename('fullpath')), 'utils'));


% ── AH-1S Cobra ──────────────────────────────────────────────────────────
heli         = jsondecode(fileread(fullfile(fileparts(mfilename('fullpath')), 'config', 'heli_params.json')));
output_base  = fullfile(fileparts(mfilename('fullpath')), 'results', 'AH1S');
fase3_VDM    = true;    % F3 = cruzeiro na VDM, F4 = loiter na VAM
tempo_loiter = 30;      % [min] duração da fase de loiter/reserva
casos = [ ...           %  id | V_vento(kt) | dist(NM) | Vc_sub(fpm)
    1,    0,   400,  1000 ; ...
    2,  -15,   400,  1000 ; ...
    3,    0,   400,  2000 ; ...
    4,    0,   440,  1000 ];

% ── AlphaOne ─────────────────────────────────────────────────────────────
% heli         = jsondecode(fileread(fullfile(fileparts(mfilename('fullpath')), 'config', 'heli_params_alphaone.json')));
% output_base  = fullfile(fileparts(mfilename('fullpath')), 'results', 'AlphaOne');
% fase3_VDM    = true;    % F3 = cruzeiro na VDM, F4 = loiter na VAM
% tempo_loiter = 20;      % [min]
% casos = [ ...
%     1,    0,  300,  1000 ; ...
%     2,  -20,  300,  1000 ];

heli.A         = pi * heli.R^2;
heli.P_disp_kw = heli.P_disp_hp * 0.7457;
plotar         = false;   % true → gera figuras no MATLAB; false → só exporta dados

dT = 20;   % [°C] Desvio ISA

%% LOOP PRINCIPAL - todos os 4 casos
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
    polar            = struct([]);
    cruzeiro         = struct([]);


    

    % FASE 1 - PAIRADO INICIAL IGE ------------------------------------------
    W_antes = W_atual;
    [potencias, W_atual] = Calcular_Fase(W_atual, 6, 0, dT, heli, 0, 0, 5);
    missao(1)        = atribui_fase('Pairado IGE', 0, potencias, W_antes - W_atual);
    total_comb_gasto = total_comb_gasto + missao(1).comb;




    % FASE 2 - SUBIDA NA Vy --------------------------------------------------
    Zp_2    = 2500;   % altitude média (0 → 5000 ft)
    tempo_2 = 5000 / Vc_sub_fpm;

    [polar(2), cruzeiro(2), Vy_2, ~, ~, ~, ~] = ...
        analisar_fase(W_atual, Zp_2, dT, heli, Vc_sub_fpm, V_vento, plotar);

    W_antes = W_atual;
    [potencias, W_atual] = Calcular_Fase(W_atual, inf, Zp_2, dT, heli, Vy_2, Vc_sub_fpm, tempo_2, true);
    missao(2)        = atribui_fase('Subida na Vy', Vy_2, potencias, W_antes - W_atual);
    total_comb_gasto = total_comb_gasto + missao(2).comb;



    % FASES 3 + 4 - CRUZEIRO + LOITER ---------------------------------------
    % analisar_fase retorna [polar, cruzeiro, Vy, VDM, VAM, Vvm, Vrm]
    %   4.º saída = VDM — velocidade de MAIOR ALCANCE  (Distância Máxima)
    %   5.º saída = VAM — velocidade de MAIOR AUTONOMIA (Autonomia Máxima)
    if fase3_VDM
        % AlphaOne: F3 = distância na VDM, F4 = loiter na VAM
        [polar(3), cruzeiro(3), ~, V_f3, ~, ~, ~] = ...
            analisar_fase(W_atual, 5000, dT, heli, 0, V_vento, plotar);
        nome_f3 = 'Nivelado na VDM';

        [polar(4), cruzeiro(4), ~, ~, V_f4, ~, ~] = ...
            analisar_fase(W_atual, 5000, dT, heli, 0, V_vento, plotar);  % será recalculado após F3
        nome_f4 = 'Nivelado na VAM';
    else
        % F3 = cruzeiro na VAM, F4 = loiter na VDM  (missão com fases invertidas)
        [polar(3), cruzeiro(3), ~, ~, V_f3, ~, ~] = ...
            analisar_fase(W_atual, 5000, dT, heli, 0, V_vento, plotar);
        nome_f3 = 'Nivelado na VAM';

        [polar(4), cruzeiro(4), ~, V_f4, ~, ~, ~] = ...
            analisar_fase(W_atual, 5000, dT, heli, 0, V_vento, plotar);  % será recalculado após F3
        nome_f4 = 'Nivelado na VDM';
    end

    V_gs_3  = V_f3 + V_vento;
    tempo_3 = (distancia_3 / V_gs_3) * 60;

    W_antes = W_atual;
    [potencias, W_atual] = Calcular_Fase(W_atual, inf, 5000, dT, heli, V_f3, 0, tempo_3, true);
    missao(3)        = atribui_fase(nome_f3, V_f3, potencias, W_antes - W_atual);
    total_comb_gasto = total_comb_gasto + missao(3).comb;

    % Recalcula V_f4 com o peso atualizado após F3
    if fase3_VDM
        [polar(4), cruzeiro(4), ~, ~, V_f4, ~, ~] = ...
            analisar_fase(W_atual, 5000, dT, heli, 0, V_vento, plotar);
    else
        [polar(4), cruzeiro(4), ~, V_f4, ~, ~, ~] = ...
            analisar_fase(W_atual, 5000, dT, heli, 0, V_vento, plotar);
    end

    W_antes = W_atual;
    [potencias, W_atual] = Calcular_Fase(W_atual, inf, 5000, dT, heli, V_f4, 0, tempo_loiter, true);
    missao(4)        = atribui_fase(nome_f4, V_f4, potencias, W_antes - W_atual);
    total_comb_gasto = total_comb_gasto + missao(4).comb;




    % FASE 5 - DESCIDA NA Vy ------------------------------------------------
    Zp_5    = 2500;
    tempo_5 = 5000 / 1000;   % 5000 ft a 1000 fpm

    [polar(5), cruzeiro(5), Vy_5, ~, ~, ~, ~] = ...
        analisar_fase(W_atual, Zp_5, dT, heli, -1000, V_vento, plotar);

    W_antes = W_atual;
    [potencias, W_atual] = Calcular_Fase(W_atual, inf, Zp_5, dT, heli, Vy_5, -1000, tempo_5, true);
    missao(5)        = atribui_fase('Descida na Vy', Vy_5, potencias, W_antes - W_atual);
    total_comb_gasto = total_comb_gasto + missao(5).comb;


    

    % FASE 6 - PAIRADO FINAL IGE --------------------------------------------
    W_antes = W_atual;
    [potencias, W_atual] = Calcular_Fase(W_atual, 6, 0, dT, heli, 0, 0, 5, true);
    missao(6)        = atribui_fase('Pairado IGE', 0, potencias, W_antes - W_atual);
    total_comb_gasto = total_comb_gasto + missao(6).comb;

    

    %% EXPORTAÇÃO
    Exportar_Resultados(caso, V_vento, heli, missao, total_comb_gasto, polar, cruzeiro, output_folder);
end

fprintf('\nTodos os casos concluídos.\n');

