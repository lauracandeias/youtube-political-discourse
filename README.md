# YouTube Political Discourse

Este repositório reúne os códigos, dados e procedimentos utilizados para a **coleta, organização e processamento de dados políticos do YouTube**, com foco na análise do discurso político produzido por atores políticos e nas interações dos usuários na plataforma.

O projeto contempla a coleta de **metadados de vídeos, comentários e transcrições**, além de rotinas de tratamento e consolidação das bases para análise.

> **Fluxo geral:** identificação dos canais → coleta de vídeos → coleta de comentários → transcrição dos vídeos → tratamento e consolidação das bases → disponibilização dos dados finais.

## Objetivo

O objetivo deste projeto é construir uma base de dados sistemática sobre o discurso político no YouTube, permitindo analisar tanto o conteúdo publicado por atores políticos quanto as reações dos usuários na seção de comentários.

A estrutura foi desenvolvida para facilitar a **reprodutibilidade da coleta e do processamento**, mantendo separados os scripts de aquisição, processamento e os dados resultantes.

## Dados

O projeto trabalha principalmente com três tipos de informação:

* **Metadados dos vídeos:** informações sobre os vídeos publicados pelos canais selecionados;
* **Comentários:** comentários associados aos vídeos coletados;
* **Transcrições:** texto transcrito do conteúdo audiovisual dos vídeos.

As bases são organizadas em diferentes etapas de processamento, desde os arquivos resultantes das coletas até as bases finais utilizadas para análise.

## Estrutura

```text
youtube-political-discourse/
│
├── dados/
│   ├── final/                    # Bases finais processadas
│   └── videos_historico/         # Metadados e histórico de vídeos
│
├── coleta_comentarios_bootstrap.R
│                                 # Coleta inicial de comentários
│
├── coleta_comentarios_ids.R
│                                 # Coleta de comentários a partir de
│                                 # video_ids específicos
│
├── etl_dados_youtube.R           # ETL e consolidação das bases
│
├── transcrever_videos_youtube.ipynb
│                                 # Transcrição dos vídeos
│
├── transcricoes_completo.csv     # Transcrições processadas
│
├── yt_data_collection.Rproj      # Projeto R
│
├── .gitignore
└── README.md
```

A estrutura atual do repositório contém os scripts de coleta e processamento e as pastas de dados utilizadas pelo projeto.

## Fluxo de processamento

### 1. Coleta de vídeos e metadados

A primeira etapa consiste na identificação dos vídeos publicados pelos canais selecionados e na coleta de seus respectivos metadados.

Os metadados são utilizados como base para as etapas posteriores, especialmente para a identificação dos vídeos dos quais serão coletados comentários e transcrições.

Os arquivos relacionados ao histórico de vídeos são armazenados em:

```text
dados/videos_historico/
```

### 2. Coleta de comentários

A coleta de comentários é realizada por meio dos scripts:

```text
coleta_comentarios_bootstrap.R
coleta_comentarios_ids.R
```

O primeiro script é utilizado para as coletas iniciais de comentários.

O segundo permite realizar coletas direcionadas a partir de um conjunto específico de `video_id`, reduzindo o consumo desnecessário da quota da API do YouTube. O script recebe os IDs dos vídeos e coleta exclusivamente os comentários associados a eles.

As coletas são armazenadas em:

```text
dados/comentarios/
```

Os arquivos de comentários são identificados pela data da coleta, permitindo manter um histórico das diferentes rodadas.

### 3. Transcrição dos vídeos

As transcrições são produzidas por meio do notebook:

```text
transcrever_videos_youtube.ipynb
```

O notebook realiza o processamento dos vídeos e gera as transcrições utilizadas nas etapas posteriores da pesquisa.

As transcrições processadas são armazenadas na base:

```text
transcricoes_completo.csv
```

### 4. ETL e consolidação

O script:

```text
etl_dados_youtube.R
```

é responsável pela consolidação e preparação das bases para disponibilização e análise.

Entre os procedimentos realizados estão:

* leitura das diferentes rodadas de coleta;
* união das bases;
* remoção de informações de identificação dos autores dos comentários;
* remoção de comentários duplicados;
* organização das variáveis;
* consolidação das bases finais;
* exportação dos dados em formatos apropriados para análise.

Por exemplo, as diferentes rodadas de comentários são combinadas e os registros são deduplicados utilizando `comment_id`.

## Como reproduzir

### Requisitos

Para executar as etapas de tratamento dos dados em R, recomenda-se utilizar uma versão recente do R e do RStudio.

Os principais pacotes utilizados incluem:

```r
install.packages(c(
  "tidyverse",
  "here",
  "arrow",
  "tuber",
  "data.table"
))
```

O notebook de transcrição possui dependências próprias relacionadas ao processamento de áudio e ao modelo de transcrição.

### 1. Configuração da API do YouTube

As rotinas de coleta utilizam autenticação da API do YouTube.

As credenciais devem ser armazenadas como variáveis de ambiente e **não devem ser incluídas no repositório**.

Por exemplo:

```text
YOUTUBE_APP_ID
YOUTUBE_APP_SECRET
```

O script de coleta recupera essas credenciais a partir do ambiente local.

### 2. Coletar comentários

Depois de configurar a autenticação, execute:

```r
source("coleta_comentarios_bootstrap.R")
```

ou, para uma coleta direcionada a vídeos específicos:

```r
source("coleta_comentarios_ids.R")
```

Os arquivos gerados devem ser armazenados em:

```text
dados/comentarios/
```

### 3. Transcrever vídeos

Abra:

```text
transcrever_videos_youtube.ipynb
```

e execute as células do notebook conforme as configurações definidas para a rodada de processamento.

### 4. Executar o ETL

Após a conclusão das coletas, execute:

```r
source("etl_dados_youtube.R")
```

O script irá consolidar as diferentes rodadas de coleta e produzir as bases finais.

## Organização das bases

As bases são organizadas segundo o estágio de processamento:

| Diretório                   | Conteúdo                                              |
| --------------------------- | ----------------------------------------------------- |
| `dados/videos_historico/`   | Metadados e histórico dos vídeos                      |
| `dados/final/`              | Bases finais processadas                              |
| `dados/comentarios/`        | Arquivos resultantes das diferentes rodadas de coleta |
| `transcricoes_completo.csv` | Base consolidada de transcrições                      |

## Controle de duplicidades

A consolidação dos comentários utiliza o identificador único `comment_id` para evitar que o mesmo comentário seja incorporado mais de uma vez quando diferentes rodadas de coleta se sobrepõem.

```r
distinct(comment_id, .keep_all = TRUE)
```

Essa estratégia permite combinar diferentes rodadas de coleta sem duplicar observações.

## Privacidade e dados

Os dados coletados do YouTube podem conter informações potencialmente identificáveis.

Por esse motivo, informações desnecessárias para a análise devem ser removidas antes da disponibilização pública das bases.

Em particular, o processo de ETL atualmente remove a variável referente ao autor do comentário:

```r
select(-author)
```

Credenciais de API, arquivos de configuração locais, logs e outros arquivos que contenham informações sensíveis **não devem ser versionados no Git**.

## Reprodutibilidade

O projeto busca manter uma separação entre:

1. **dados brutos**, provenientes das APIs e demais fontes;
2. **scripts de coleta**, responsáveis pela aquisição;
3. **scripts de processamento**, responsáveis pelo tratamento e consolidação;
4. **dados finais**, utilizados nas análises.

As diferentes rodadas de coleta são identificadas por data. Isso permite preservar o histórico do processo e reconstruir a origem dos dados utilizados em cada etapa.

## Limitações

A coleta de dados do YouTube está sujeita às limitações da API e às condições de disponibilidade dos conteúdos na plataforma.

Entre as principais limitações estão:

* limites de quota da API;
* disponibilidade dos vídeos e comentários;
* comentários removidos ou desabilitados;
* alterações posteriores no conteúdo publicado;
* limitações na recuperação histórica de determinados dados;
* eventuais falhas durante a coleta ou transcrição.

Por isso, uma reprodução exata dos resultados pode exigir o uso dos mesmos arquivos coletados e versionados para determinada etapa, e não necessariamente uma nova consulta à API.

## Autoria

**Laura Candeias**
**Tássia Melo**

Este projeto foi desenvolvido no contexto de pesquisa acadêmica sobre discurso político e comportamento político no YouTube.

## Inteligência Artificial

Ferramentas de inteligência artificial foram utilizadas como apoio ao desenvolvimento do projeto, incluindo assistência na escrita e revisão de código, documentação e resolução de problemas técnicos.

A estrutura metodológica, as decisões de pesquisa, os procedimentos de coleta e o processamento final dos dados são de responsabilidade das autoras e devem ser revisados e validados antes da utilização dos resultados.

## Citação

Se você utilizar este código ou os dados produzidos por este projeto, recomenda-se citar o repositório:

> Candeias, Laura; Melo, Tássia. *YouTube Political Discourse*. GitHub. Disponível em: https://github.com/lauracandeias/youtube-political-discourse.

## Licença

A licença do projeto deverá ser definida de acordo com as condições de disponibilização dos códigos e dos dados.

---

**Repositório:**
https://github.com/lauracandeias/youtube-political-discourse

