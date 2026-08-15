# Codebook — `videos_por_canal.csv`

**Unidade de análise:** vídeo do YouTube.  
**Arquivo:** `dados/final/videos_por_canal.csv`  
**Formato:** CSV, UTF-8.

| Variável | Tipo | Descrição | Valores / formato |
|---|---|---|---|
| `video_id` | character | Identificador único do vídeo no YouTube. | String; identificador do vídeo. |
| `titulo` | character | Título do vídeo. | Texto. |
| `data_publicacao` | datetime | Data e hora de publicação do vídeo. | ISO 8601, UTC (`YYYY-MM-DDTHH:MM:SSZ`). |
| `descricao` | character | Descrição fornecida pelo canal para o vídeo. | Texto; pode estar ausente. |
| `visualizacoes` | integer | Número de visualizações registrado no momento da coleta. | Inteiro. |
| `curtidas` | integer | Número de curtidas registrado no momento da coleta. | Inteiro; pode estar ausente. |
| `comentarios` | integer | Número de comentários registrado no momento da coleta. | Inteiro; pode estar ausente. |
| `channel_id` | character | Identificador do canal que publicou o vídeo. | String; corresponde ao `channel_id` da base de canais. |
| `channel_title` | character | Nome do canal associado ao vídeo. | Texto. |
| `url` | character | URL do vídeo no YouTube. | URL no formato `https://www.youtube.com/watch?v=...`. |
| `politico` | character | Ator político associado ao canal/vídeo na pesquisa. | Nome do ator político. |
| `partido` | character | Partido político associado ao ator político. | Sigla partidária. |
| `cargo` | character | Categoria do cargo/status político utilizada na pesquisa. | Categorias definidas pelo estudo. |

## Chaves e relacionamentos

- `video_id` identifica o vídeo e deve ser único dentro da base de vídeos, salvo eventuais repetições decorrentes de diferentes rodadas de coleta.
- `channel_id` permite relacionar cada vídeo à base `canais_stats.csv`.
- `politico`, `partido` e `cargo` são variáveis de classificação da pesquisa e acompanham o vídeo a partir do canal/ator político selecionado.

## Interpretação das métricas

`visualizacoes`, `curtidas` e `comentarios` representam contagens observadas no momento da coleta. Como essas métricas podem continuar mudando após a coleta, elas devem ser interpretadas como fotografias do desempenho do vídeo naquele momento.
