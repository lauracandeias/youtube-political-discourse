# Codebook — `comentarios.parquet`

**Unidade de análise:** comentário em vídeo do YouTube.  
**Arquivo:** `dados/final/comentarios.parquet`  
**Formato:** Apache Parquet.

A base reúne os comentários coletados nos vídeos selecionados para a pesquisa. Cada linha corresponde a um comentário e contém informações de identificação do vídeo, classificação do ator político associado, data de publicação, texto do comentário, número de curtidas e data da coleta.

## Dicionário de variáveis

| Variável | Tipo | Descrição | Valores / formato |
|---|---|---|---|
| `comentario_id` | character | Identificador único do comentário no YouTube. | String. |
| `video_id` | character | Identificador do vídeo ao qual o comentário está associado. | String. |
| `politico` | character | Ator político associado ao canal/vídeo em que o comentário foi publicado. | Nome do ator político, por exemplo `Lula`. |
| `data_publicacao_comentario` | datetime | Data e hora de publicação do comentário. | Timestamp; na coleta observada, formato `YYYY-MM-DD HH:MM:SS`. |
| `texto` | character | Conteúdo textual do comentário. | Texto livre; pode conter emojis, abreviações, links, pontuação e outros elementos produzidos pelo usuário. |
| `curtidas_comentario` | integer | Número de curtidas recebidas pelo comentário no momento da coleta. | Inteiro. |
| `data_coleta` | date | Data em que o comentário foi coletado. | `YYYY-MM-DD`. |

## Chaves e relacionamentos

- `comentario_id` funciona como identificador do comentário e deve ser único na base consolidada.
- `video_id` permite relacionar os comentários à base `videos_por_canal.csv` e à base `videos_transcricoes.parquet`.

## Métricas de interação

`curtidas_comentario` representa o número de curtidas observado no momento da coleta. Essa medida pode mudar posteriormente, portanto não deve ser interpretada como uma medida fixa do desempenho do comentário.

## Texto dos comentários e privacidade

- identificadores dos autores não fazem parte da base final.

## Relação com as demais bases

A estrutura relacional do conjunto de dados pode ser representada da seguinte forma:

```text
canais_stats.csv
      │
      │ channel_id
      ▼
videos_por_canal.csv
      │
      │ video_id
      ├──────────────────────┐
      ▼                      ▼
videos_transcricoes.parquet  comentarios.parquet
                             │
                             │ comentario_id
                             ▼
                       comentário individual
```

`video_id` é a principal chave de ligação entre vídeos, transcrições e comentários.

## Observação sobre a disponibilização

Como `comentarios.parquet` é uma base muito grande, o arquivo não está disponibilizado no GitHub.

