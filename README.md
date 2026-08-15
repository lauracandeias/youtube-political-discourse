# YouTube Political Discourse

Repositório com os códigos e dados utilizados para a coleta, organização e preparação de bases de dados sobre discurso político no YouTube. O projeto reúne informações sobre canais de políticos, vídeos publicados, transcrições de vídeos e comentários de usuários. O projeto busca possibilitar a realização de análises de conteúdo e estudos sobre comportamento digital de lideranças políticas. 

## Objetivo

Construir bases de dados de discurso de atores políticos brasileiros no YouTube, reunindo:

- informações dos canais selecionados;
- metadados dos vídeos publicados;
- métricas de interação dos vídeos;
- transcrições do conteúdo;
- rotinas reproduzíveis de coleta, transcrição e consolidação.

O projeto está em andamento e as base de dados ainda serão expandidas.

O fluxo geral do projeto é:

**identificação dos canais → coleta de vídeos → coleta de comentários → transcrição dos vídeos → ETL e consolidação → bases finais para análise.**

## Estrutura do repositório

```text
youtube-political-discourse/
│
├── dados/
│   ├── final/
│   │   ├── canais_stats.csv
│   │   ├── videos_por_canal.csv
│   │   └── videos_transcricoes.parquet
|   |   └── comentarios.parquet*
│   │
│   └── videos_historico/
│       └── 2026-08-12-jair_bolsonaro_bootstrap.csv
│       └── 2026-08-12-lula_bootstrap.csv
│       └── 2026-08-12-renan_santos_bootstrap.csv
│       └── 2026-08-12-romeu_zema_bootstrap.csv
│       └── 2026-08-12-ronaldo_caiado_bootstrap.csv
│
├── scripts/
│   ├── 01_coleta_comentarios_bootstrap.R
│   ├── 02_coleta_comentarios_ids.R
│   ├── 03_transcrever_videos_youtube.ipynb
│   └── 04_etl_dados_youtube.R
│
├── documentos/
│   ├── codebook_canais_stats.md
│   ├── codebook_comentarios.md
│   ├── codebook_videos_por_canal.md
│   └── codebook_videos_transcricoes.md
|   └── guia_03_transcrever_videos_youtube.md
│   └── guia_criar_chave_API_youtube.pdf
│
├── .gitattributes
├── .gitignore
├── README.md
└── yt_data_collection.Rproj
```

Os scripts estão numerados de acordo com a ordem geral do fluxo de processamento.

## Bases finais

As bases disponibilizadas em `dados/final/` são:

| Arquivo | Unidade de análise | Descrição |
|---|---|---|
| `canais_stats.csv` | Canal | Estatísticas dos canais selecionados e informações de identificação do ator político |
| `videos_por_canal.csv` | Vídeo | Metadados e métricas de todos os vídeos já publicados nos canais |
| `videos_transcricoes.parquet` | Vídeo | Metadados dos vídeos combinados às respectivas transcrições |
| `comentarios.parquet` | Comentários de usuários | Comentários publicados nos vídeos selecionados |

Os codebooks dessas bases estão em `codebooks/`.

### `canais_stats.csv`

Base em nível de canal. Contém o identificador do canal, nome, data de criação, número de inscritos, visualizações totais, número de vídeos e informações sobre o ator político associado. A data de coleta indica quando as estatísticas foram consultadas.

### `videos_por_canal.csv`

Base em nível de vídeo. Reúne metadados e métricas públicas de todos os vídeos já publicados nos canais até a data da coleta, além da identificação do canal, do ator político, partido e cargo.

### `videos_transcricoes.parquet`

Base em nível de vídeo que combina os metadados dos 100 vídeos mais recentes de cada canal analisado com as suas transcrições. O ETL classifica como `erro_transcricao` os casos em que não há transcrição disponível.

### `comentarios.parquet`

A base contém os comentários de usuários coletados a partir dos 100 vídeos mais recentes de cada canal. Foram selecionados até 50 comentários por vídeo. A base final possui o total 19.334 observações (comentários) e, devido ao seu tamanho, o arquivo não é armazenado diretamente neste repositório GitHub.

A versão completa da base está disponível mediante pedido às autoras.

O codebook da base está disponível em:

`documentos/codebook_comentarios.md`

## Coleta e processamento

### 1. Coleta de comentários

`01_coleta_comentarios_bootstrap.R`

Realiza a coleta inicial de comentários dos vídeos selecionados. Para este projeto, adotou-se o limite do máximo de 50 comentários por vídeo, mas esse valor é ajustável no script.

`02_coleta_comentarios_ids.R`

Script adicional que permite coletar comentários a partir de uma lista específica de `video_id`, evitando novas consultas desnecessárias a vídeos que já foram processados e uma busca mais direcionada a vídeos específicos.

### 2. Transcrição

`03_transcrever_videos_youtube.ipynb`

Notebook utilizado para transcrever os vídeos. A transcrição é posteriormente integrada aos metadados dos vídeos pelo processo de ETL. Um guia mais detalhado desse script está em `documentos/guia_03_transcrever_videos_youtube.md`

### 3. ETL

`04_etl_dados_youtube.R`

Responsável pela consolidação e preparação das bases para análise. Entre os procedimentos estão:

- união de diferentes rodadas de coleta;
- padronização dos nomes das variáveis;
- integração de metadados e transcrições;
- exportação das bases finais em formatos adequados para análise.

## Reprodutibilidade

O projeto separa as etapas de aquisição, processamento e disponibilização dos dados. As bases históricas permitem preservar as diferentes rodadas de coleta, enquanto as bases em `dados/final/` correspondem aos produtos consolidados utilizados para análise.

Para reproduzir o processamento em R, recomenda-se uma versão recente do R/RStudio e os pacotes utilizados pelos scripts, especialmente:

```r
install.packages(c(
  "tidyverse",
  "here",
  "arrow",
  "tuber",
  "data.table"
))
```

O notebook de transcrição possui dependências próprias para processamento de vídeo/áudio e transcrição automática.

## API e credenciais

As rotinas de coleta dependem da autenticação da API do YouTube. Credenciais não devem ser armazenadas no repositório.

Quando utilizadas, as credenciais devem ser configuradas no ambiente local, por exemplo:

```text
YOUTUBE_APP_ID
YOUTUBE_APP_SECRET
```

Os nomes exatos das variáveis devem seguir a configuração adotada pelos scripts de coleta.

Caso você ainda não tenha acesso às chaves da API do YouTube necessárias, preparamos um guia em: `documentos/guia_criar_chave_API_youtube.pdf`


## Limitações

A coleta está sujeita às limitações da API do YouTube e às condições de disponibilidade dos conteúdos. Entre as principais limitações estão:

- limites de quota da API;
- vídeos removidos, privados ou indisponíveis;
- comentários removidos ou desabilitados;
- alterações posteriores nas métricas dos vídeos;
- limitações para recuperação histórica;
- falhas durante coleta ou transcrição;
- possíveis diferenças entre uma nova consulta à API e os dados originalmente coletados.

Por isso, a reprodução exata dos resultados deve utilizar, sempre que possível, os arquivos históricos e as bases finais disponibilizadas no repositório.

## Autoria

**Laura Candeias**  
**Tássia Melo**

Projeto desenvolvido no contexto de pesquisa acadêmica sobre discurso político e comportamento político no YouTube.

## Uso de inteligência artificial

Ferramentas de inteligência artificial foram utilizadas como apoio ao desenvolvimento do projeto, incluindo assistência na revisão de escrita, documentação, revisão de código e resolução de problemas técnicos.

As decisões metodológicas, as escolhas de pesquisa, os procedimentos de coleta e a validação dos dados são de responsabilidade das autoras.
