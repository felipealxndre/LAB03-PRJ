function [rho, T_real, P, sigma_rho] = ISA(delta_ISA, Zp)
    % ISA Calcula as propriedades da atmosfera com desvio de temperatura
    % Válido para a Troposfera (até ~36.089 ft)
    %
    % Entradas:
    %   Zp        - Altitude de pressão [ft]
    %   delta_ISA - Desvio de temperatura (Delta T) em relação à ISA [°C ou K]
    %
    % Saídas:
    %   rho       - Densidade do ar real [slugs/ft^3] (Sistema Imperial)
    %   T_real    - Temperatura real do ar [K]
    %   P         - Pressão atmosférica [Pa]
    %   sigma_rho - Razão de densidade (rho / rho0)

    %% Constantes Padrão no Nível do Mar
    T0 = 288.15;            % Temperatura [K]
    P0 = 101325;            % Pressão [Pa]
    rho0_imp = 0.0023769;   % Densidade [slugs/ft^3]
    
    % Constantes físicas
    L = -0.0065;            % Gradiente térmico negativo [K/m]
    g = 9.80665;            % Aceleração da gravidade [m/s^2]
    R = 287.052;            % Constante dos gases para o ar [J/(kg.K)]

    %% Cálculos
    % Conversão da altitude de ft para metros
    Zp_m = Zp * 0.3048;

    % 1. Temperatura Padrão (T_std) - Usada para calcular a Pressão
    T_std = T0 + L * Zp_m;

    % 2. Temperatura Real (T_real) - Usada para calcular a Densidade
    T_real = T_std + delta_ISA;

    % 3. Pressão Atmosférica (P)
    P = P0 * (T_std / T0) ^ (- g / (L * R));

    % 4. Razões Adimensionais
    delta_p = P / P0;               % Razão de pressão
    theta_real = T_real / T0;       % Razão de temperatura real

    % 5. Razão de Densidade Real (sigma_rho)
    % Pela lei dos gases ideais: rho = P / (R * T) -> sigma = delta / theta
    sigma_rho = delta_p / theta_real;

    % 6. Densidade final convertida para o Sistema Imperial
    rho = rho0_imp * sigma_rho;
end