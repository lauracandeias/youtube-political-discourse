# Codebook — `videos_transcricoes.parquet`

**Unidade de análise:** vídeo do YouTube.  
**Arquivo:** `dados/final/videos_transcricoes.parquet`  
**Formato:** Apache Parquet.

A base resulta da integração dos metadados dos vídeos com as informações produzidas no processo de transcrição. O ETL realiza a junção por `video_id`, `titulo` e `url`.

| Variável | Tipo | Descrição | Valores / formato |
|---|---|---|---|
| `video_id` | character | Identificador único do vídeo no YouTube. | String. |
| `titulo` | character | Título do vídeo. | Texto. |
| `data_publicacao` | datetime | Data e hora de publicação do vídeo. | ISO 8601 / timestamp. |
| `descricao` | character | Descrição do vídeo. | Texto; pode estar ausente. |
| `visualizacoes` | integer | Número de visualizações observado na coleta dos metadados. | Inteiro. |
| `curtidas` | integer | Número de curtidas observado na coleta. | Inteiro; pode estar ausente. |
| `comentarios` | integer | Número de comentários observado na coleta. | Inteiro; pode estar ausente. |
| `id_canal` | character | Identificador do canal que publicou o vídeo. | String |
| `titulo_canal` | character | Nome do canal que publicou o vídeo. | Texto |
| `url` | character | URL do vídeo no YouTube. | URL. |
| `data_coleta` | date | Data da coleta dos metadados do vídeo. | `YYYY-MM-DD`, quando presente na origem. |
| `politico` | character | Ator político associado ao vídeo. | Nome do ator político. |
| `partido` | character | Partido político associado ao ator político. | Sigla partidária. |
| `cargo` | character | Categoria do cargo/status político utilizada na pesquisa. | Categorias inseridas manualmente. |
| `duracao_segundos` | integer | Duração do vídeo em segundos, quando disponível no processo de transcrição. | Inteiro. |
| `transcricao` | character | Texto resultante da transcrição automática do conteúdo audiovisual. | Texto; pode estar ausente. |
| `idioma` | character | Idioma identificado/registrado no processo de transcrição. | Código ou rótulo de idioma utilizado pelo processo. |
| `status` | character | Situação do processamento da transcrição. | Status produzido pelo pipeline; `erro_transcricao` é atribuído pelo ETL quando `transcricao` está ausente. |

## Observações metodológicas

- O ETL combina os metadados dos vídeos com a base de transcrições por `video_id`, `titulo` e `url`.
- A transcrição é texto processado automaticamente e pode conter erros de reconhecimento de fala, especialmente em nomes próprios, siglas, ruídos e trechos com baixa qualidade de áudio.