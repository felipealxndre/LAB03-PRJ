function [rho, T_real, P, sigma_rho] = ISA(delta_ISA, Zp)
    % ISA  Atmosfera padrão internacional com desvio de temperatura.
    % Válido para a troposfera (até ~36.089 ft).
    %
    % Entradas:
    %   delta_ISA - desvio de temperatura [°C]
    %   Zp        - altitude de pressão [ft]
    %
    % Saídas:
    %   rho       - densidade do ar [slug/ft³]
    %   T_real    - temperatura real [K]
    %   P         - pressão atmosférica [Pa]
    %   sigma_rho - razão de densidade (ρ/ρ0)

    T0       = 288.15;      % [K]
    P0       = 101325;      % [Pa]
    rho0_imp = 0.0023769;   % [slug/ft³]
    L        = -0.0065;     % [K/m]
    g        = 9.80665;     % [m/s²]
    R        = 287.052;     % [J/(kg·K)]

    Zp_m   = Zp * 0.3048;
    T_std  = T0 + L * Zp_m;          % T padrão — entra no cálculo de P
    T_real = T_std + delta_ISA;      % T real — entra no cálculo de ρ
    P      = P0 * (T_std / T0) ^ (- g / (L * R));

    sigma_rho = (P / P0) / (T_real / T0);
    rho       = rho0_imp * sigma_rho;
end
