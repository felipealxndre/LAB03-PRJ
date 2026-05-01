function Plot_Curvas_Potencia(W, Zp, delta_ISA, heli)
    % PLOT_CURVAS_POTENCIA Gera o gráfico completo de decomposição das 
    % potências necessárias (Induzida, Perfil, Parasita, Miscelânea e Total) 
    % em função da velocidade de avanço, simulando voo nivelado (OGE).
    %
    % Entradas:
    %   W         - Peso da aeronave [lb]
    %   Zp        - Altitude de pressão [ft]
    %   delta_ISA - Variação de temperatura ISA [°C]
    %   heli      - Struct com os parâmetros do helicóptero

    %% 1. Inicialização
    % Vetor de velocidades de 0 a 160 kt (como no slide de referência)
    V_kt = 0:1:250; 
    N = length(V_kt);
    
    % Vetores para armazenar cada tipo de potência
    P_ind_hp  = zeros(1, N);
    P_perf_hp = zeros(1, N);
    P_par_hp  = zeros(1, N);
    P_misc_hp = zeros(1, N);
    P_tot_hp  = zeros(1, N);
    
    % Fator de conversão de kW para HP (1 HP = 0.7457 kW)
    kw2hp = 1 / 0.7457; 

    %% 2. Varredura de Velocidades em Voo Nivelado
    fprintf('Calculando as componentes de potência para o gráfico...\n');
    
    for i = 1:N
        % Chama a sua função para Voo Nivelado (Vc = 0) e OGE (h_solo = inf)
        [r, ~] = Calcular_Fase(W, inf, Zp, delta_ISA, heli, V_kt(i), 0, 1);

        % Armazena e converte os resultados para HP
        P_ind_hp(i)  = r.P_ind  * kw2hp;
        P_perf_hp(i) = r.P_perf * kw2hp;
        P_par_hp(i)  = r.P_par  * kw2hp;
        P_misc_hp(i) = r.P_misc * kw2hp;
        P_tot_hp(i)  = r.P_tot  * kw2hp;
    end
    
    %% 3. Potência Disponível
    if isfield(heli, 'P_disp_hp')
        P_disp = heli.P_disp_hp;
    else
        P_disp = heli.P_disp_kw * kw2hp;
    end

    %% 4. Geração do Gráfico (Idêntico ao do Slide)
    figure('Color', 'w', 'Name', 'Curvas de Potência do Helicóptero');
    hold on; grid on;
    
    % Plota as parcelas individuais
    plot(V_kt, P_ind_hp, 'g-', 'LineWidth', 2, 'DisplayName', 'Induzida');
    plot(V_kt, P_perf_hp, 'c-', 'LineWidth', 2, 'DisplayName', 'Perfil');
    plot(V_kt, P_par_hp, 'm-', 'LineWidth', 2, 'DisplayName', 'Parasita');
    plot(V_kt, P_misc_hp, 'y-', 'LineWidth', 2, 'DisplayName', 'Miscelânea');
    
    % Plota a Potência Total (A curva clássica em formato de "U")
    plot(V_kt, P_tot_hp, 'k-', 'LineWidth', 3, 'DisplayName', 'Total Necessária');
    
    % Plota a Potência Disponível (Linha horizontal)
    yline(P_disp, 'r-', 'LineWidth', 2, 'DisplayName', 'Disponível');
    
    % Estética do Gráfico
    xlabel('Velocidade de Avanço (kt)', 'FontWeight', 'bold');
    ylabel('Potência do Motor (hp)', 'FontWeight', 'bold');
    title(sprintf('Decomposição de Potência (Peso: %.0f lb | Zp: %.0f ft)', W, Zp));
    
    % Configuração da Legenda
    legend('Location', 'northwest', 'FontSize', 10);
    xlim([0 160]);
    ylim([0 max(P_disp + 500, max(P_tot_hp) + 200)]);
    
    fprintf('  -> Gráfico gerado com sucesso!\n');
end