function [potencias, W_final] = Calcular_Fase(W, h_solo, Zp, delta_ISA, heli, V_kt, Vc_fpm, tempo_min)
    % CALCULAR_FASE Função universal para calcular desempenho e consumo em
    % qualquer fase de voo do helicóptero (Pairado, Cruzeiro, Subida ou Descida).
    %
    % Entradas:
    %   W, h_solo, Zp, delta_ISA, heli, V_kt, Vc_fpm, tempo_min
    %
    % Saídas:
    %   potencias - struct com potências [kW]: P_ind, P_perf, P_par, P_vert, P_misc, P_tot
    %   W_final  - Peso atualizado ao fim da fase [lb]  →  comb = W - W_final

    %% 1. Propriedades Atmosféricas e Inicialização
    [rho, ~, ~, ~] = ISA(delta_ISA, Zp);
   
    V_fps = V_kt * 1.68781; % Conversão kt para ft/s
    Vc_fps = Vc_fpm / 60;   % Conversão ft/min para ft/s
    
    % --- TRATAMENTO PARA DESCIDA ---
    % O laboratório exige desprezar a variação da potência induzida com a razão de descida.
    Vc_fps_ind = Vc_fps;
    if Vc_fpm < 0
        Vc_fps_ind = 0; % Assume Vc = 0 APENAS para o iterativo da velocidade induzida
    end
    
    mu = V_fps / heli.Omega_R;
    lambda_c = Vc_fps / heli.Omega_R;           % Usado na potência real de subida/descida
    lambda_c_ind = Vc_fps_ind / heli.Omega_R;   % Usado apenas no cálculo da potência induzida
    
    % Velocidade induzida ideal de pairado (v_h)
    v_h = sqrt(W / (2 * rho * heli.A)); 
    
    % --- Iterativo para a Velocidade Induzida (vi) via Glauert ---
    v_i = v_h; 
    erro = 1;
    while erro > 0.001
        % O cálculo iterativo usa Vc_fps_ind (que será zero se for descida)
        v_i_novo = v_h^2 / sqrt(V_fps^2 + (Vc_fps_ind + v_i)^2);
        erro = abs(v_i_novo - v_i);
        v_i = v_i_novo;
    end
    lambda_i = v_i / heli.Omega_R;
     
    %% 2. Cálculo dos Coeficientes de Potência
    Ct = W / (rho * heli.A * heli.Omega_R^2);
    
    % Potência Induzida Base (OGE)
    CP_ind = (heli.ki * Ct^2) / (2 * sqrt(mu^2 + (lambda_c_ind + lambda_i)^2)); 
    
    % --- CORREÇÃO DE EFEITO SOLO (IGE) ---
    % Aplica-se apenas se o helicóptero estiver a pairar (Vx < 1 kt) e h_solo não for infinito
    if V_kt < 1 && ~isinf(h_solo)
        D = 2 * heli.R;
        x_razao = (h_solo + heli.h) / D; 
        
        if x_razao < 1 % Ocorre efeito solo
            x_dados = [0.4302, 0.5169, 0.5656, 0.6083, 0.6701, 0.7093, 0.8185, 0.8945, 1.1558];
            y_dados = [0.8429, 0.8880, 0.9105, 0.9255, 0.9421, 0.9481, 0.9646, 0.9721, 0.9826];
            p_ige = polyfit(x_dados, y_dados, 4);
            y_corr = polyval(p_ige, x_razao);
            
            CP_ind = CP_ind * y_corr; % Reduz a potência induzida conforme curva de efeito solo
        end
    end
    
    % Demais Potências Aerodinâmicas
    CP_perf = (heli.sigma * heli.Cd0 / 8) * (1 + 4.65 * mu^2); % Perfil
    CP_par = (0.5 * heli.f / heli.A) * mu^3;                   % Parasita
    CP_sub = lambda_c * Ct;                                    % Subida/Descida (Usa a razão real Vc)
    
    % Balanço no Rotor e no Motor (incluindo a subida/descida real)
    CP_RP = CP_ind + CP_perf + CP_par + CP_sub; 
    CP_misc = (1/heli.eta_m - 1) * CP_RP;       
    CP_motor = CP_RP / heli.eta_m;              
    
    %% 3. Saída das Potências em kW
    Fator = rho * heli.A * heli.Omega_R^3;
    hp2kw = 0.7457;

    potencias.P_ind  = (Fator * CP_ind   / 550) * hp2kw;
    potencias.P_perf = (Fator * CP_perf  / 550) * hp2kw;
    potencias.P_par  = (Fator * CP_par   / 550) * hp2kw;
    potencias.P_vert = (Fator * CP_sub   / 550) * hp2kw;
    potencias.P_misc = (Fator * CP_misc  / 550) * hp2kw;
    potencias.P_tot  = (Fator * CP_motor / 550) * hp2kw;

    %% 4. Consumo de Combustível e Atualização de Peso
    fluxo_comb_lb_hr = (Fator * CP_motor / 550) * heli.SFC;
    W_final = W - fluxo_comb_lb_hr * (tempo_min / 60);
end