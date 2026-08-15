# Codebook — `canais_stats.csv`

**Unidade de análise:** canal do YouTube.  
**Arquivo:** `dados/final/canais_stats.csv`  
**Formato:** CSV, UTF-8.  
**Data de coleta observada na versão atual:** 13/08/2026.

| Variável | Tipo | Descrição | Valores / formato |
|---|---|---|---|
| `channel_id` | character | Identificador único do canal no YouTube. | String; identificador atribuído pelo YouTube. |
| `titulo_canal` | character | Nome/título exibido para o canal. | Texto. |
| `data_criacao` | datetime | Data e hora de criação do canal. | ISO 8601, UTC (`YYYY-MM-DDTHH:MM:SSZ`). |
| `inscritos` | integer | Número de inscritos do canal no momento da coleta. | Inteiro. |
| `total_views` | integer | Número acumulado de visualizações do canal no momento da coleta. | Inteiro. |
| `total_videos` | integer | Número de vídeos associado ao canal no momento da coleta. | Inteiro. |
| `data_coleta` | date | Data em que as estatísticas do canal foram coletadas. | `YYYY-MM-DD`. |
| `politico` | character | Ator político associado ao canal para fins da pesquisa. | Nome do ator político. |
| `partido` | character | Partido político associado ao ator político na base. | Sigla partidária |
| `cargo` | character | Categoria do cargo/status político utilizada no estudo. | Por exemplo `Presidente`, `Ex-presidente` e `Candidato`. |

## Observações

- `channel_id` é a chave de identificação do canal.
- As métricas `inscritos`, `total_views` e `total_videos` são medidas no momento da coleta.
- `politico`, `partido` e `cargo` são variáveis de classificação da pesquisa, não campos nativos da API do YouTube.
