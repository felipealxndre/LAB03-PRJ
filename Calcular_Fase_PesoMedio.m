function [potencias, W_final] = Calcular_Fase_PesoMedio(W_inicial, h_solo, Zp, delta_ISA, heli, V_kt, Vc_fpm, tempo_min)
    % CALCULAR_FASE_PESOMEDIO Aplica o método Preditor-Corretor para obter
    % as potências exatas utilizando o peso médio da aeronave.
    %
    % Saídas:
    %   potencias - struct com potências [kW]: P_ind, P_perf, P_par, P_vert, P_misc, P_tot
    %   W_final - Peso atualizado ao fim da fase [lb]  →  comb = W_inicial - W_final

    % --- Preditor: estima W_final com peso inicial ---
    [~, W_pred] = Calcular_Fase(W_inicial, h_solo, Zp, delta_ISA, heli, V_kt, Vc_fpm, tempo_min);

    % --- Peso médio na fase ---
    W_medio = (W_inicial + W_pred) / 2;

    % --- Corretor: recalcula potências e W_final no peso médio ---
    [potencias, W_final_medio] = Calcular_Fase(W_medio, h_solo, Zp, delta_ISA, heli, V_kt, Vc_fpm, tempo_min);

    % --- Atualização do peso final usando o consumo corrigido ---
    W_final = W_inicial - (W_medio - W_final_medio);
end
