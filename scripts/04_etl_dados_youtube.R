# ============================================================================
# SCRIPT DE ETL DAS BASES PARA DISPONIBILIZAR PUBLICAMENTE
# AUTORAS: LAURA CANDEIAS E TÁSSIA MELO
# ============================================================================

if(require(tidyverse) == F) install.packages("tidyverse"); require(tidyverse)
if(require(here) == F) install.packages("here"); require(here)
if(require(arrow) == F) install.packages("arrow"); require(arrow)

# Unindo as bases ---------------------------------------------------------

## Comentários

comentarios1 <- read_csv(here("dados/comentarios/2026-08-04_comentarios_bootstrap.csv"),
                            locale = locale(encoding = "UTF-8")
                          )

comentarios2 <- read_csv(here("dados/comentarios/2026-08-05_comentarios_bootstrap.csv"),
                         locale = locale(encoding = "UTF-8")
                         )

comentarios3 <- read_csv(here("dados/comentarios/2026-08-11_comentarios_bootstrap.csv"),
                         locale = locale(encoding = "UTF-8")
)

comentarios4 <- read_csv(here("dados/comentarios/2026-08-12_comentarios_bootstrap.csv"),
                         locale = locale(encoding = "UTF-8")
)

comentarios5 <- read_csv(here("dados/comentarios/2026-08-13_comentarios_custom.csv"),
                         locale = locale(encoding = "UTF-8")
)

# unindo todas as coletas de comentários dos vídeos

todos_comentarios <- bind_rows(comentarios1, comentarios2, comentarios3, comentarios4, comentarios5) |> 
  select(-author) |>  # omitindo o usuário
  distinct(comment_id, .keep_all = T) |>  # removendo possíveis duplicatas 
  rename(texto = text,
         comentario_id = comment_id,
         data_publicacao_comentario = published_at,
         curtidas_comentario = likes)

# Salvando base de comentários 

write_parquet(
  todos_comentarios,
  here("dados/final/todos_comentarios.parquet")
)

## Metadados dos vídeos

# unindo os 100 vídeos coletados de cada canal 

metadados_lula <- read_csv(here("dados/videos_historico/2026-08-12_lula_bootstrap.csv"),
                         locale = locale(encoding = "UTF-8")
)

metadados_jair <- read_csv(here("dados/videos_historico/2026-08-12_jair_bolsonaro_bootstrap.csv"),
                           locale = locale(encoding = "UTF-8")
)

metadados_renan <- read_csv(here("dados/videos_historico/2026-08-12_renan_santos_bootstrap.csv"),
                           locale = locale(encoding = "UTF-8")
)

metadados_zema <- read_csv(here("dados/videos_historico/2026-08-12_romeu_zema_bootstrap.csv"),
                            locale = locale(encoding = "UTF-8")
)

metadados_caiado <- read_csv(here("dados/videos_historico/2026-08-12_ronaldo_caiado_bootstrap.csv"),
                           locale = locale(encoding = "UTF-8")
)

todos_metadados <- bind_rows(metadados_lula, 
                             metadados_jair, 
                             metadados_renan, 
                             metadados_zema,
                             metadados_caiado)


# carregando a base de transcrições (construída com o script em python)

transcricoes <- read.csv(here("transcricoes_completo.csv"))


# Metadados dos vídeos + Transcrições -------------------------------------

# unindo os metadados com as transcrições 

videos_completo <- todos_metadados |>  
  left_join(transcricoes, by = c("video_id", "titulo", "url")) |> 
  select(-id, -tentativas, -erro_mensagem, -data_processamento) |> 
  mutate(
    status = case_when(
      is.na(transcricao) ~ "erro_transcricao",
      TRUE ~ status
    )
  ) |> 
  rename(titulo_canal = channel_title,
         id_canal = channel_id)

# Salvando a base final dos vídeos com transcrições + metadados

write_parquet(
  videos_completo,
  here("dados/final/videos_transcricoes.parquet")
)



