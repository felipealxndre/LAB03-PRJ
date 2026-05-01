% =========================================================================
% PRJ-91: Laboratório 3 - Simulação de Missão Completa
% Aeronave: AH-1S Cobra
% =========================================================================
clear; clc; close all;
pasta_caso = 'results/CASO2';
if ~exist(pasta_caso, 'dir'), mkdir(pasta_caso); end
diary(fullfile(pasta_caso, 'resultado.txt')); diary on;

%% 1. PARÂMETROS GERAIS E DA AERONAVE
% Configuração de vento para toda a missão (Positivo = Cauda, Negativo = Proa)
V_vento = -15;                 % Velocidade do vento [kt]

% --- Pesos e Capacidades ---
heli = jsondecode(fileread('heli_params.json'));
heli.A         = pi * heli.R^2;
heli.P_disp_kw = heli.P_disp_hp * 0.7457;

%% 2. INICIALIZAÇÃO DA ESTRUTURA DA MISSÃO
% Criando um Array de Structs para armazenar os dados de forma conectada
missao = repmat(struct('nome', '', 'P_ind', 0, 'P_perf', 0, 'P_par', 0, ...
                       'P_vert', 0, 'P_misc', 0, 'P_tot', 0, 'vel', 0, 'comb', 0), 1, 6);

W_atual = heli.MTOW;         % Peso inicial de decolagem [lb]
total_comb_gasto = 0;        % Acumulador de consumo total [lb]

fprintf('=========================================================\n');
fprintf('           SIMULAÇÃO DE MISSÃO - AH-1S COBRA\n');
fprintf('=========================================================\n');
fprintf('Vento Considerado: %.2f kt\n', V_vento);
fprintf('=========================================================\n\n');

%% FASE 1 - PAIRADO INICIAL IGE
missao(1).nome = 'Pairado IGE';
Zp_1 = 0; dT_1 = 20; h_solo_1 = 6; tempo_1 = 5;

% A saída da função já alimenta diretamente a estrutura da fase 1
[missao(1).P_ind, missao(1).P_perf, missao(1).P_par, missao(1).P_vert, missao(1).P_misc, missao(1).P_tot, W_atual, missao(1).comb] = ...
    Calcular_Fase(W_atual, h_solo_1, Zp_1, dT_1, heli, 0, 0, tempo_1);

missao(1).vel = 0;
total_comb_gasto = total_comb_gasto + missao(1).comb;
fprintf('FASE 1: Pairado Inicial IGE Concluída.\n');

%% FASE 2 - SUBIDA NA Vy
missao(2).nome = 'Subida na Vy';
Zp_2 = 2500; dT_2 = 20; Vc_sub_fpm = 1000; tempo_2 = (5000-0)/Vc_sub_fpm; 

W_f2 = W_atual;
[V_pol_2, ~, Vc_v_2, Vy_2, ~, Vvm_2, Vrm_2, Vc_auto_2, VrM_2] = Polar_Velocidade(W_atual, Zp_2, dT_2, heli, Vc_sub_fpm, false, [], V_vento);
[VAM_2, VDM_2, V_max_2, V_cru_2, P_cru_2] = Analise_Velocidades_Cruzeiro(W_atual, Zp_2, dT_2, heli, V_vento, false);

[missao(2).P_ind, missao(2).P_perf, missao(2).P_par, missao(2).P_vert, missao(2).P_misc, missao(2).P_tot, W_atual, missao(2).comb, ~] = ...
    Calcular_Fase_PesoMedio(W_atual, inf, Zp_2, dT_2, heli, Vy_2, Vc_sub_fpm, tempo_2);

missao(2).vel = Vy_2;
total_comb_gasto = total_comb_gasto + missao(2).comb;
fprintf('FASE 2: Subida   | Vy = %.1f kt | VAM = %.1f kt (≅ Vrm = %.1f kt) | VDM = %.1f kt (≅ Vvm = %.1f kt)\n', Vy_2, VAM_2, Vrm_2, VDM_2, Vvm_2);

%% FASE 3 - CRUZEIRO NA VAM
missao(3).nome = 'Nivelado na VAM';
Zp_3 = 5000; dT_3 = 20; distancia_3 = 400;

W_f3 = W_atual;
[V_pol_3, ~, Vc_v_3, Vy_3, ~, Vvm_3, Vrm_3, Vc_auto_3, VrM_3] = Polar_Velocidade(W_atual, Zp_3, dT_3, heli, 0, false, [], V_vento);
[VAM_3, VDM_3, V_max_3, V_cru_3, P_cru_3] = Analise_Velocidades_Cruzeiro(W_atual, Zp_3, dT_3, heli, V_vento, false);

V_mr_gs = VAM_3 + V_vento; 
tempo_3 = (distancia_3/V_mr_gs)*60; 

[missao(3).P_ind, missao(3).P_perf, missao(3).P_par, missao(3).P_vert, missao(3).P_misc, missao(3).P_tot, W_atual, missao(3).comb, ~] = ...
    Calcular_Fase_PesoMedio(W_atual, inf, Zp_3, dT_3, heli, VAM_3, 0, tempo_3);

missao(3).vel = VAM_3;
total_comb_gasto = total_comb_gasto + missao(3).comb;
fprintf('FASE 3: Cruzeiro | Vy = %.1f kt | VAM = %.1f kt (≅ Vrm = %.1f kt) | VDM = %.1f kt (≅ Vvm = %.1f kt)\n', Vy_3, VAM_3, Vrm_3, VDM_3, Vvm_3);

%% FASE 4 - LOITER / RESERVA NA VDM
missao(4).nome = 'Nivelado na VDM';
Zp_4 = 5000; dT_4 = 20; tempo_4 = 30;

W_f4 = W_atual;
[V_pol_4, ~, Vc_v_4, Vy_4, ~, Vvm_4, Vrm_4, Vc_auto_4, VrM_4] = Polar_Velocidade(W_atual, Zp_4, dT_4, heli, 0, false, [], V_vento);
[VAM_4, VDM_4, V_max_4, V_cru_4, P_cru_4] = Analise_Velocidades_Cruzeiro(W_atual, Zp_4, dT_4, heli, V_vento, false);

[missao(4).P_ind, missao(4).P_perf, missao(4).P_par, missao(4).P_vert, missao(4).P_misc, missao(4).P_tot, W_atual, missao(4).comb, ~] = ...
    Calcular_Fase_PesoMedio(W_atual, inf, Zp_4, dT_4, heli, VDM_4, 0, tempo_4);

missao(4).vel = VDM_4;
total_comb_gasto = total_comb_gasto + missao(4).comb;
fprintf('FASE 4: Loiter   | Vy = %.1f kt | VAM = %.1f kt (≅ Vrm = %.1f kt) | VDM = %.1f kt (≅ Vvm = %.1f kt)\n', Vy_4, VAM_4, Vrm_4, VDM_4, Vvm_4);

%% FASE 5 - DESCIDA NA Vy
missao(5).nome = 'Descida na Vy';
Zp_5 = 2500; dT_5 = 20; Vc_des_fpm = -1000;
tempo_5 = (5000-0)/abs(Vc_des_fpm);

W_f5 = W_atual;
[V_pol_5, ~, Vc_v_5, Vy_5, ~, Vvm_5, Vrm_5, Vc_auto_5, VrM_5] = Polar_Velocidade(W_atual, Zp_5, dT_5, heli, Vc_des_fpm, false, [], V_vento);
[VAM_5, VDM_5, V_max_5, V_cru_5, P_cru_5] = Analise_Velocidades_Cruzeiro(W_atual, Zp_5, dT_5, heli, V_vento, false);

[missao(5).P_ind, missao(5).P_perf, missao(5).P_par, missao(5).P_vert, missao(5).P_misc, missao(5).P_tot, W_atual, missao(5).comb, ~] = ...
    Calcular_Fase_PesoMedio(W_atual, inf, Zp_5, dT_5, heli, Vy_5, Vc_des_fpm, tempo_5);

missao(5).vel = Vy_5;
total_comb_gasto = total_comb_gasto + missao(5).comb;
fprintf('FASE 5: Descida  | Vy = %.1f kt | VAM = %.1f kt (≅ Vrm = %.1f kt) | VDM = %.1f kt (≅ Vvm = %.1f kt)\n', Vy_5, VAM_5, Vrm_5, VDM_5, Vvm_5);

%% FASE 6 - PAIRADO FINAL
missao(6).nome = 'Pairado IGE';
Zp_6 = 0; dT_6 = 20; h_solo_6 = 6; tempo_6 = 5;

[missao(6).P_ind, missao(6).P_perf, missao(6).P_par, missao(6).P_vert, missao(6).P_misc, missao(6).P_tot, W_atual, missao(6).comb, ~] = ...
    Calcular_Fase_PesoMedio(W_atual, h_solo_6, Zp_6, dT_6, heli, 0, 0, tempo_6);

missao(6).vel = 0;
total_comb_gasto = total_comb_gasto + missao(6).comb;
fprintf('FASE 6: Pairado Final IGE Concluída.\n\n');

%% TABELA FINAL DE RESULTADOS E VERIFICAÇÃO DE MISSÃO
fprintf('========================================================================================================================\n');
fprintf('                                          TABELA RESUMO DE DESEMPENHO E CONSUMO\n');
fprintf('========================================================================================================================\n');
fprintf('Fase | Nome                 | Induzida| Perfil  | Parasita| Misc.   | Subida  | Descida | Total   | Veloc.  | Consumo \n');
fprintf('     |                      | (kW)    | (kW)    | (kW)    | (kW)    | (kW)    | (kW)    | (kW)    | (kt)    | (lb)    \n');
fprintf('------------------------------------------------------------------------------------------------------------------------\n');

for i = 1:6
    % Formatação da Subida/Descida baseada no campo 'P_vert' da estrutura
    if missao(i).P_vert >= 0
        P_sub_str = sprintf('%7.2f', missao(i).P_vert);
        P_des_str = '   -   ';
    else
        P_sub_str = '   -   ';
        P_des_str = sprintf('%7.2f', abs(missao(i).P_vert));
    end
    
    % Imprimindo diretamente dos campos da estrutura
    fprintf('  %d  | %-20s | %7.2f | %7.2f | %7.2f | %7.2f | %s | %s | %7.2f | %7.1f | %7.2f\n', ...
        i, missao(i).nome, missao(i).P_ind, missao(i).P_perf, missao(i).P_par, missao(i).P_misc, ...
        P_sub_str, P_des_str, missao(i).P_tot, missao(i).vel, missao(i).comb);
end

fprintf('------------------------------------------------------------------------------------------------------------------------\n');
fprintf('                                                                                      | TOTAL GASTO (lb): | %7.2f\n', total_comb_gasto);
fprintf('========================================================================================================================\n\n');

%% VERIFICAÇÕES DE MISSÃO
margem = heli.fuel_cap - total_comb_gasto;

% Extraindo todas as potências totais da estrutura de uma vez e comparando
pot_falha = find([missao.P_tot] > heli.P_disp_kw);

if isempty(pot_falha)
    disp('VERIFICAÇÃO DE POTÊNCIA: OK - Há potência disponível para todas as fases da missão.');
else
    disp('VERIFICAÇÃO DE POTÊNCIA: FALHA - Potência requerida excedeu a disponível em uma ou mais fases.');
end

if margem >= 0
    fprintf('VERIFICAÇÃO DE COMBUSTÍVEL: OK - Missão cumprida. Sobraram %.2f lb nos tanques.\n', margem);
else
    fprintf('VERIFICAÇÃO DE COMBUSTÍVEL: FALHA - Combustível insuficiente (faltaram %.2f lb).\n', abs(margem));
end

%% EXPORTAR DADOS PARA PYTHON
pol2 = struct('W', W_f2, 'Zp', Zp_2, 'dT', dT_2, 'V_tas', V_pol_2, 'Vc_v', Vc_v_2, 'Vc_auto', Vc_auto_2, 'Vy', Vy_2, 'VrM', VrM_2, 'Vvm', Vvm_2, 'Vrm', Vrm_2);
pol3 = struct('W', W_f3, 'Zp', Zp_3, 'dT', dT_3, 'V_tas', V_pol_3, 'Vc_v', Vc_v_3, 'Vc_auto', Vc_auto_3, 'Vy', Vy_3, 'VrM', VrM_3, 'Vvm', Vvm_3, 'Vrm', Vrm_3);
pol4 = struct('W', W_f4, 'Zp', Zp_4, 'dT', dT_4, 'V_tas', V_pol_4, 'Vc_v', Vc_v_4, 'Vc_auto', Vc_auto_4, 'Vy', Vy_4, 'VrM', VrM_4, 'Vvm', Vvm_4, 'Vrm', Vrm_4);
pol5 = struct('W', W_f5, 'Zp', Zp_5, 'dT', dT_5, 'V_tas', V_pol_5, 'Vc_v', Vc_v_5, 'Vc_auto', Vc_auto_5, 'Vy', Vy_5, 'VrM', VrM_5, 'Vvm', Vvm_5, 'Vrm', Vrm_5);
cru2 = struct('W', W_f2, 'Zp', Zp_2, 'V_tas', V_cru_2, 'P_tot_hp', P_cru_2, 'V_mr', VAM_2, 'V_md', VDM_2, 'V_max', V_max_2);
cru3 = struct('W', W_f3, 'Zp', Zp_3, 'V_tas', V_cru_3, 'P_tot_hp', P_cru_3, 'V_mr', VAM_3, 'V_md', VDM_3, 'V_max', V_max_3);
cru4 = struct('W', W_f4, 'Zp', Zp_4, 'V_tas', V_cru_4, 'P_tot_hp', P_cru_4, 'V_mr', VAM_4, 'V_md', VDM_4, 'V_max', V_max_4);
cru5 = struct('W', W_f5, 'Zp', Zp_5, 'V_tas', V_cru_5, 'P_tot_hp', P_cru_5, 'V_mr', VAM_5, 'V_md', VDM_5, 'V_max', V_max_5);
Exportar_Dados(2, V_vento, heli, missao, total_comb_gasto, margem, pol2, pol3, pol4, pol5, cru2, cru3, cru4, cru5, pasta_caso);
diary off;