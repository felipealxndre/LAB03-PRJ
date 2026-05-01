function Exportar_Dados(caso, V_vento, heli, missao, total_comb, margem, ...
    pol2, pol3, pol4, pol5, cru2, cru3, cru4, cru5, pasta_saida)
% EXPORTAR_DADOS  Serializa os resultados da missão e dados de plotagem para JSON.
%
% Entradas:
%   caso         - Número do caso (1-4)
%   V_vento      - Velocidade do vento [kt]
%   heli         - Struct com parâmetros da aeronave
%   missao       - Array de structs com dados das 6 fases
%   total_comb   - Combustível total gasto [lb]
%   margem       - Margem de combustível (positivo = sobrou) [lb]
%   pol2..pol5   - Structs com dados do polar de cada fase
%   cru2..cru5   - Structs com dados de cruzeiro de cada fase
%   pasta_saida  - Caminho da pasta de saída (ex: 'results/CASO1')

    if ~exist(pasta_saida, 'dir')
        mkdir(pasta_saida);
    end

    dados = struct();
    dados.caso        = caso;
    dados.V_vento     = V_vento;
    dados.P_disp_hp   = heli.P_disp_hp;
    dados.total_comb  = total_comb;
    dados.margem_comb = margem;

    dados.fases_nome  = {missao.nome};
    dados.fases_vel   = [missao.vel];
    dados.fases_P_tot = [missao.P_tot];
    dados.fases_comb  = [missao.comb];

    dados.polar_F2 = pol2;
    dados.polar_F3 = pol3;
    dados.polar_F4 = pol4;
    dados.polar_F5 = pol5;

    dados.cruzeiro_F2 = cru2;
    dados.cruzeiro_F3 = cru3;
    dados.cruzeiro_F4 = cru4;
    dados.cruzeiro_F5 = cru5;

    caminho_json = fullfile(pasta_saida, 'dados.json');
    fid = fopen(caminho_json, 'w');
    fprintf(fid, '%s', jsonencode(dados));
    fclose(fid);

    fprintf('Dados exportados para %s\n', caminho_json);
end
