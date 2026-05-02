function Exportar_Resultados(caso, V_vento, heli, missao, total_comb_gasto, polar, cruzeiro, pasta_saida, params)
% EXPORTAR_RESULTADOS  Salva os resultados de um caso em dois formatos:
%   - resultado.txt : tabela formatada legível para humanos
%   - dados.json    : dados estruturados para consumo do plotar_caso.py
%
% Entradas:
%   caso             - Número do caso (1-4)
%   V_vento          - Velocidade do vento [kt]
%   heli             - Struct com parâmetros da aeronave
%   missao           - Array de structs com as 6 fases
%   total_comb_gasto - Combustível total consumido [lb]
%   polar            - Array de structs (índices 2..5) do envelope vertical
%   cruzeiro         - Array de structs (índices 2..5) das curvas de cruzeiro
%   pasta_saida      - Pasta de destino (ex: 'results/CASO1')
%   params           - (opcional) Struct com Vc_sub_fpm e distancia_NM do caso

    if nargin < 9
        params = struct('Vc_sub_fpm', NaN, 'distancia_NM', NaN);
    end

    if ~exist(pasta_saida, 'dir')
        mkdir(pasta_saida);
    end

    margem = heli.fuel_cap - total_comb_gasto;

    escrever_txt(fullfile(pasta_saida, 'resultado.txt'), ...
                 caso, V_vento, heli, missao, total_comb_gasto, margem);

    escrever_json(fullfile(pasta_saida, 'dados.json'), ...
                  caso, V_vento, heli, missao, total_comb_gasto, margem, polar, cruzeiro, params);

end


% =========================================================================
% Função privada: escreve a tabela e verificações em formato texto
% =========================================================================
function escrever_txt(caminho, caso, V_vento, heli, missao, total_comb_gasto, margem)
    fid = fopen(caminho, 'w');
    if fid < 0
        error('Não foi possível abrir o arquivo: %s', caminho);
    end
    cleanup = onCleanup(@() fclose(fid));

    sep_principal = repmat('=', 1, 120);
    sep_linha     = repmat('-', 1, 120);

    %% Cabeçalho
    fprintf(fid, '=========================================================\n');
    fprintf(fid, '       SIMULAÇÃO DE MISSÃO - ALPHAONE - CASO %d\n', caso);
    fprintf(fid, '=========================================================\n');
    fprintf(fid, 'Vento Considerado: %.2f kt\n', V_vento);
    fprintf(fid, '=========================================================\n\n');

    %% Tabela
    fprintf(fid, '%s\n', sep_principal);
    fprintf(fid, '                                          TABELA RESUMO DE DESEMPENHO E CONSUMO\n');
    fprintf(fid, '%s\n', sep_principal);
    fprintf(fid, 'Fase | Nome                 | Induzida| Perfil  | Parasita| Misc.   | Subida  | Descida | Total   | Veloc.  | Consumo \n');
    fprintf(fid, '     |                      | (kW)    | (kW)    | (kW)    | (kW)    | (kW)    | (kW)    | (kW)    | (kt)    | (lb)    \n');
    fprintf(fid, '%s\n', sep_linha);

    for i = 1:numel(missao)
        if missao(i).P_vert >= 0
            P_sub_str = sprintf('%7.2f', missao(i).P_vert);
            P_des_str = '   -   ';
        else
            P_sub_str = '   -   ';
            P_des_str = sprintf('%7.2f', abs(missao(i).P_vert));
        end

        fprintf(fid, '  %d  | %-20s | %7.2f | %7.2f | %7.2f | %7.2f | %s | %s | %7.2f | %7.1f | %7.2f\n', ...
            i, missao(i).nome, missao(i).P_ind, missao(i).P_perf, missao(i).P_par, ...
            missao(i).P_misc, P_sub_str, P_des_str, missao(i).P_tot, missao(i).vel, missao(i).comb);
    end

    fprintf(fid, '%s\n', sep_linha);
    fprintf(fid, '                                                                                      | TOTAL GASTO (lb): | %7.2f\n', total_comb_gasto);
    fprintf(fid, '%s\n\n', sep_principal);

    %% Verificações
    if isempty(find([missao.P_tot] > heli.P_disp_kw, 1))
        fprintf(fid, 'VERIFICAÇÃO DE POTÊNCIA: OK - Há potência disponível para todas as fases da missão.\n');
    else
        fprintf(fid, 'VERIFICAÇÃO DE POTÊNCIA: FALHA - Potência requerida excedeu a disponível em uma ou mais fases.\n');
    end

    if margem >= 0
        fprintf(fid, 'VERIFICAÇÃO DE COMBUSTÍVEL: OK - Missão cumprida. Sobraram %.2f lb nos tanques.\n', margem);
    else
        fprintf(fid, 'VERIFICAÇÃO DE COMBUSTÍVEL: FALHA - Combustível insuficiente (faltaram %.2f lb).\n', abs(margem));
    end
end


% =========================================================================
% Função privada: serializa os dados numéricos para JSON
% =========================================================================
function escrever_json(caminho, caso, V_vento, heli, missao, total_comb_gasto, margem, polar, cruzeiro, params)
    dados = struct();
    dados.caso          = caso;
    dados.V_vento       = V_vento;
    dados.Vc_sub_fpm    = params.Vc_sub_fpm;
    dados.distancia_NM  = params.distancia_NM;
    dados.P_disp_hp     = heli.P_disp_hp;
    dados.fuel_cap      = heli.fuel_cap;
    dados.total_comb    = total_comb_gasto;
    dados.margem_comb   = margem;

    dados.fases_nome  = {missao.nome};
    dados.fases_vel   = [missao.vel];
    dados.fases_P_tot = [missao.P_tot];
    dados.fases_comb  = [missao.comb];

    for i = 2:5
        dados.(sprintf('polar_F%d', i))    = polar(i);
        dados.(sprintf('cruzeiro_F%d', i)) = cruzeiro(i);
    end


    fid = fopen(caminho, 'w');
    if fid < 0
        error('Não foi possível abrir o arquivo: %s', caminho);
    end
    cleanup = onCleanup(@() fclose(fid));

    fprintf(fid, '%s', jsonencode(dados));
end
