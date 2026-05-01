function [P_ind_kw, P_perf_kw, P_par_kw, P_sub_kw, P_misc_kw, P_motor_kw, W_final, W_comb_gasto, W_medio] = ...
    Calcular_Fase_PesoMedio(W_inicial, h_solo, Zp, delta_ISA, heli, V_kt, Vc_fpm, tempo_min)
    % CALCULAR_FASE_PESOMEDIO Aplica o método Preditor-Corretor para obter 
    % as potências e o consumo exatos utilizando o peso médio da aeronave 
    % durante a fase de voo.
    %
    % Requer a função 'Calcular_Fase' no mesmo diretório.

    %% 1. Passo Preditor
    % Estima o combustível gasto considerando que a aeronave voou o tempo 
    % todo pesando o W_inicial.
    [~, ~, ~, ~, ~, ~, ~, fuel_estimado] = Calcular_Fase(...
        W_inicial, h_solo, Zp, delta_ISA, heli, V_kt, Vc_fpm, tempo_min);

    %% 2. Cálculo do Peso Médio
    % O peso médio é o peso inicial menos metade do combustível que será gasto.
    W_medio = W_inicial - (fuel_estimado / 2);

    %% 3. Passo Corretor
    % Calcula as potências definitivas e o combustível real gasto utilizando 
    % o peso médio ao longo da fase.
    [P_ind_kw, P_perf_kw, P_par_kw, P_sub_kw, P_misc_kw, P_motor_kw, ~, W_comb_gasto] = Calcular_Fase(...
        W_medio, h_solo, Zp, delta_ISA, heli, V_kt, Vc_fpm, tempo_min);

    %% 4. Atualização do Peso Final
    % O peso final real é o peso inicial menos o combustível efetivamente gasto.
    W_final = W_inicial - W_comb_gasto;
end