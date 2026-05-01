% =========================================================================
% PRJ-91: Laboratório 3 - Simulação de Missão Completa
% Aeronave: AH-1S Cobra
% =========================================================================
clear; clc; close all;
if ~exist('results', 'dir'), mkdir('results'); end
diary('results/CASO3_resultado.txt'); diary on;

%% 1. PARÂMETROS GERAIS E DA AERONAVE
% Configuração de vento para toda a missão (Positivo = Cauda, Negativo = Proa)
V_vento = 0;                 % Velocidade do vento [kt]

% --- Pesos e Capacidades ---
heli.W_empty   = 6598;       % Peso vazio da aeronave [lb]
heli.MTOW      = 10000;      % Peso Máximo de Decolagem [lb]
heli.fuel_cap  = 1684;       % Capacidade máxima de combustível [lb]

% --- Rotor Principal ---
heli.R         = 22;         % Raio do rotor principal [ft]
heli.c         = 2.25;       % Corda média das pás [ft]
heli.b         = 2;          % Número de pás do rotor
heli.sigma     = 0.065;      % Solidez do rotor
heli.Omega_R   = 746;        % Velocidade na ponta da pá (Tip Speed) [ft/s]
heli.A         = pi*heli.R^2;% Área do disco do rotor [ft^2]

% --- Aerodinâmica / Desempenho ---
heli.Cd0       = 0.012;      % Coeficiente de arrasto de perfil das pás
heli.ki        = 1.15;       % Fator de correção da potência induzida
heli.eta_m     = 0.85;       % Eficiência mecânica da transmissão
heli.P_disp_hp = 1290;       % Potência disponível no motor [hp]
heli.P_disp_kw = heli.P_disp_hp*0.7457; % Conversão da potência para [kW]
heli.f         = 19.45;      % Área de placa plana equivalente [ft^2]
heli.SFC       = 0.458;      % Consumo Específico de Combustível [lb/hp.hr]

% --- Fuselagem ---
heli.h         = 12;         % Altura do cubo do rotor ao solo [ft]

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
Zp_2 = 2500; dT_2 = 20; Vc_sub_fpm = 2000; tempo_2 = (5000-0)/Vc_sub_fpm; 

[~,~,~, Vy_2, ~, Vvm_2, Vrm_2] = Polar_Velocidade(W_atual, Zp_2, dT_2, heli, Vc_sub_fpm, false, [], V_vento);
[VAM_2, VDM_2, ~] = Analise_Velocidades_Cruzeiro(W_atual, Zp_2, dT_2, heli, V_vento, false);

[missao(2).P_ind, missao(2).P_perf, missao(2).P_par, missao(2).P_vert, missao(2).P_misc, missao(2).P_tot, W_atual, missao(2).comb, ~] = ...
    Calcular_Fase_PesoMedio(W_atual, inf, Zp_2, dT_2, heli, Vy_2, Vc_sub_fpm, tempo_2);

missao(2).vel = Vy_2;
total_comb_gasto = total_comb_gasto + missao(2).comb;
fprintf('FASE 2: Subida   | Vy = %.1f kt | VAM = %.1f kt (≅ Vrm = %.1f kt) | VDM = %.1f kt (≅ Vvm = %.1f kt)\n', Vy_2, VAM_2, Vrm_2, VDM_2, Vvm_2);

%% FASE 3 - CRUZEIRO NA VAM
missao(3).nome = 'Nivelado na VAM';
Zp_3 = 5000; dT_3 = 20; distancia_3 = 400;

[~,~,~, Vy_3, ~, Vvm_3, Vrm_3] = Polar_Velocidade(W_atual, Zp_3, dT_3, heli, 0, false, [], V_vento);
[VAM_3, VDM_3, ~] = Analise_Velocidades_Cruzeiro(W_atual, Zp_3, dT_3, heli, V_vento, false);

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

[~,~,~, Vy_4, ~, Vvm_4, Vrm_4] = Polar_Velocidade(W_atual, Zp_4, dT_4, heli, 0, false, [], V_vento);
[VAM_4, VDM_4, ~] = Analise_Velocidades_Cruzeiro(W_atual, Zp_4, dT_4, heli, V_vento, false);

[missao(4).P_ind, missao(4).P_perf, missao(4).P_par, missao(4).P_vert, missao(4).P_misc, missao(4).P_tot, W_atual, missao(4).comb, ~] = ...
    Calcular_Fase_PesoMedio(W_atual, inf, Zp_4, dT_4, heli, VDM_4, 0, tempo_4);

missao(4).vel = VDM_4;
total_comb_gasto = total_comb_gasto + missao(4).comb;
fprintf('FASE 4: Loiter   | Vy = %.1f kt | VAM = %.1f kt (≅ Vrm = %.1f kt) | VDM = %.1f kt (≅ Vvm = %.1f kt)\n', Vy_4, VAM_4, Vrm_4, VDM_4, Vvm_4);

%% FASE 5 - DESCIDA NA Vy
missao(5).nome = 'Descida na Vy';
Zp_5 = 2500; dT_5 = 20; Vc_des_fpm = -1000;
tempo_5 = (5000-0)/abs(Vc_des_fpm);

[~,~,~, Vy_5, ~, Vvm_5, Vrm_5] = Polar_Velocidade(W_atual, Zp_5, dT_5, heli, Vc_des_fpm, false, [], V_vento);
[VAM_5, VDM_5, ~] = Analise_Velocidades_Cruzeiro(W_atual, Zp_5, dT_5, heli, V_vento, false);

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
diary off;