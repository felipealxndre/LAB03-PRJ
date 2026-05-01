function [V_mr, V_md, V_max, V_tas_out, P_tot_hp_out] = Analise_Velocidades_Cruzeiro(W, Zp, delta_ISA, heli, V_vento_kt, plotar_grafico)
    % ANALISE_VELOCIDADES_CRUZEIRO Calcula e plota as velocidades notáveis 
    % de cruzeiro (Máximo Alcance, Máxima Autonomia e Máxima Horizontal)
    %
    % Entradas:
    %   W              - Peso da aeronave [lb]
    %   Zp             - Altitude de pressão [ft]
    %   delta_ISA      - Variação de temperatura ISA [°C]
    %   heli           - Struct com os parâmetros do helicóptero
    %   V_vento_kt     - (Opcional) Vento (+ Cauda, - Proa). Padrão: 0
    %   plotar_grafico - (Opcional) Booleano. Padrão: true
    %
    % Saídas:
    %   V_mr  - Velocidade de Maior Alcance (Maximum Range) [kt TAS]
    %   V_md  - Velocidade de Máxima Autonomia (Maximum Endurance) [kt TAS]
    %   V_max - Velocidade Máxima Horizontal [kt TAS]

    %% 1. Tratamento de Inputs Opcionais
    if nargin < 5 || isempty(V_vento_kt)
        V_vento_kt = 0; 
    end
    if nargin < 6 || isempty(plotar_grafico)
        plotar_grafico = true; 
    end

    %% 2. Inicialização e Varredura
    % Passo de 0.1 kt para a precisão exigida no laboratório
    V_tas_kt = 0:0.1:200; 
    N = length(V_tas_kt);
    P_tot_hp = zeros(1, N);
    
    kw2hp = 1 / 0.7457; 
    P_disp_hp = heli.P_disp_hp;

    for i = 1:N
        % Chama a função Calcular_Fase para Voo Nivelado (Vc = 0) e OGE (h = inf)
        [~, ~, ~, ~, ~, P_mot_kw, ~, ~] = Calcular_Fase(W, inf, Zp, delta_ISA, heli, V_tas_kt(i), 0, 1);
        P_tot_hp(i) = P_mot_kw * kw2hp;
    end

    %% 3. Cálculos das Velocidades Notáveis

    % --- V_md (Máxima Autonomia) ---
    % Ponto de menor potência necessária (fundo da bacia)
    [P_min, idx_md] = min(P_tot_hp);
    V_md = V_tas_kt(idx_md);

    % --- V_mr (Maior Alcance) ---
    % Razão entre Potência e Ground Speed (tangente a partir da origem)
    V_gs_kt = V_tas_kt + V_vento_kt;
    razao_P_V = P_tot_hp ./ V_gs_kt;
    razao_P_V(V_gs_kt <= 0) = inf; % Ignora velocidades negativas em relação ao solo
    
    [~, idx_mr] = min(razao_P_V);
    V_mr = V_tas_kt(idx_mr);
    P_mr = P_tot_hp(idx_mr);

    % --- V_max (Máxima Horizontal) ---
    % Cruzamento entre Potência Necessária e Potência Disponível
    Delta_P = P_disp_hp - P_tot_hp;
    pos_idx = find(Delta_P > 0); % Índices onde ainda há potência de sobra
    
    if isempty(pos_idx)
        V_max = NaN; % Não consegue voar nivelado nessas condições
    else
        idx_cross = pos_idx(end); % Último ponto antes da potência faltar (alta velocidade)
        if idx_cross < N
            % Interpolação linear para achar o ponto exato do cruzamento (Delta_P = 0)
            x_vals = [Delta_P(idx_cross), Delta_P(idx_cross+1)];
            y_vals = [V_tas_kt(idx_cross), V_tas_kt(idx_cross+1)];
            V_max = interp1(x_vals, y_vals, 0);
        else
            V_max = V_tas_kt(end);
        end
    end

    %% 4. Geração do Gráfico (Opcional)
    V_tas_out = V_tas_kt;
    P_tot_hp_out = P_tot_hp;
    if plotar_grafico
        figure('Color', 'w', 'Name', sprintf('Velocidades de Cruzeiro | %.0f lb | %0.f ft', W, Zp));
        hold on; grid on;
        
        % Linhas principais
        plot(V_tas_kt, P_tot_hp, 'k-', 'LineWidth', 2.5, 'DisplayName', 'Potência Necessária Total');
        yline(P_disp_hp, 'r-', 'LineWidth', 2, 'DisplayName', 'Potência Máx. Disponível');
        
        % Marcadores V_md (Autonomia)
        plot(V_md, P_min, 'bo', 'MarkerFaceColor', 'b', 'MarkerSize', 8, 'DisplayName', sprintf('V_{md}/V_{DM} = %.1f kt', V_md));
        plot([V_md V_md], [0 P_min], 'b:', 'LineWidth', 1.5, 'HandleVisibility', 'off');
        
        % Marcadores V_mr (Alcance) e Reta Tangente
        plot(V_mr, P_mr, 'go', 'MarkerFaceColor', 'g', 'MarkerSize', 8, 'DisplayName', sprintf('V_{mr}/V_{AM} = %.1f kt', V_mr));
        plot([V_mr V_mr], [0 P_mr], 'g:', 'LineWidth', 1.5, 'HandleVisibility', 'off');
        
        % Construção geométrica da reta tangente (P = m * V_gs)
        m_tangente = P_mr / (V_mr + V_vento_kt);
        v_gs_plot = [0, max(V_gs_kt)]; % Eixo GS da origem até o máximo
        v_tas_plot = v_gs_plot - V_vento_kt; % Convertendo de volta para TAS para plotar no mesmo eixo
        p_tangente_plot = m_tangente .* v_gs_plot;
        plot(v_tas_plot, p_tangente_plot, 'g--', 'LineWidth', 1.5, 'DisplayName', 'Reta Tangente V_{AM}');
        
        % Marcadores V_max (Velocidade Máxima)
        if ~isnan(V_max)
            plot(V_max, P_disp_hp, 'mo', 'MarkerFaceColor', 'm', 'MarkerSize', 8, 'DisplayName', sprintf('V_{max} = %.1f kt', V_max));
            plot([V_max V_max], [0 P_disp_hp], 'm:', 'LineWidth', 1.5, 'HandleVisibility', 'off');
        end

        % Estética e verificação de vento
        if V_vento_kt ~= 0
            % Marca a origem da velocidade aerodinâmica no eixo x (-V_vento)
            plot(-V_vento_kt, 0, 'kx', 'MarkerSize', 10, 'LineWidth', 2, 'DisplayName', 'Origem V_{GS}');
        end
        
        xlabel('Velocidade de Avanço Verdadeira - TAS (kt)', 'FontWeight', 'bold');
        ylabel('Potência do Motor (hp)', 'FontWeight', 'bold');
        title(sprintf('Voo Nivelado | W: %.0f lb | Zp: %.0f ft | Vento: %d kt', W, Zp, V_vento_kt));
        legend('Location', 'northwest', 'FontSize', 10);
        
        % Limites do gráfico adaptativos
        xlim_min = min(0, -V_vento_kt - 10); % Expande o X se a origem GS for negativa
        xlim([xlim_min max(V_tas_kt(end), 160)]);
        ylim([0 P_disp_hp + 300]);
    end
end