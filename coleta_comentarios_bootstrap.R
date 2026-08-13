# ============================================================================
# BOOTSTRAP SIMPLIFICADO: Com limites de vídeos coletados por canal
#
# Este script coleta APENAS:
# - 100 vídeos mais recentes de cada canal
# - Comentários desses 100 vídeos
#
# ============================================================================

if(require(tuber) == F) install.packages("tuber"); require(tuber)
if(require(tidyverse) == F) install.packages("tidyverse"); require(tidyverse)
if(require(data.table) == F) install.packages("data.table"); require(data.table)

# ===========================================================================
# SETUP
# ===========================================================================

CONFIG <- list(
  pasta_dados = "dados",
  pasta_videos = "dados/videos_historico",
  pasta_comentarios = "dados/comentarios",
  pasta_metadata = "dados/metadata",
  arquivo_ids_conhecidos = "dados/deduplicacao/videos_ids_conhecidos.csv",
  arquivo_log = "dados/metadata/coleta_log.csv",
  max_videos_por_canal = 100,      
  max_comentarios_por_video = 50,
  data_minima = "2018-01-01",
  pausa_entre_videos = 1.0        
)

# Autenticação

#file.remove(".httr-oauth") # caso exista algum erro de OAuth, remover e rodar novamente

file.edit("~/.Renviron")

readRenviron("~/.Renviron")

yt_oauth(
  app_id     = Sys.getenv("YOUTUBE_APP_ID"),
  app_secret = Sys.getenv("YOUTUBE_APP_SECRET")#,
                          #remove_old_oauth = TRUE
  )

# Criar pastas
for (pasta in c(CONFIG$pasta_videos, CONFIG$pasta_comentarios, 
                CONFIG$pasta_metadata, dirname(CONFIG$arquivo_ids_conhecidos))) {
  dir.create(pasta, recursive = TRUE, showWarnings = FALSE)
}

# ===========================================================================
# FUNÇÕES AUXILIARES
# ===========================================================================

log_message <- function(msg) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  msg_completo <- paste0("[", timestamp, "] ", msg)
  message(msg_completo)
  invisible(msg_completo)
}

registrar_coleta <- function(
    canal,
    n_videos,
    n_comentarios,
    quota_gasta,
    status = "sucesso"
) {
  
  novo_registro <- tibble(
    timestamp = Sys.time(),
    data = Sys.Date(),
    canal = canal,
    novos_videos = n_videos,
    comentarios_coletados = n_comentarios,
    quota_gasta = quota_gasta,
    status = status
  )
  
  # if (file.exists(CONFIG$arquivo_log)) {
  #   log_anterior <- fread(CONFIG$arquivo_log)
  #   novo_registro <- bind_rows(log_anterior, novo_registro)
  # }
  
  if (file.exists(CONFIG$arquivo_log)) {
    
    log_anterior <- fread(CONFIG$arquivo_log) |>
      as_tibble() |>
      mutate(
        data = as.Date(data),
        timestamp = as.POSIXct(timestamp)
      )
    
    novo_registro <- bind_rows(log_anterior, novo_registro)
  }
  
  fwrite(novo_registro, CONFIG$arquivo_log, bom = FALSE)
  invisible(NULL)
}

data_para_string <- function(data = Sys.Date()) {
  format(data, "%Y-%m-%d")
}

# ===========================================================================
# FASE 1: COLETAR 100 VÍDEOS MAIS RECENTES
# ===========================================================================

coletar_100_videos <- function(channel_id, politico) {
  
  log_message(paste0("→ Coletando 100 vídeos mais recentes de: ", politico))
  
  # Obter playlist de uploads
  canal <- tryCatch(
    list_channel_resources(
      filter = c(channel_id = channel_id),
      part = "contentDetails",
      simplify = FALSE
    ),
    error = function(e) {
      log_message(paste0("❌ Erro ao acessar canal: ", e$message))
      return(NULL)
    }
  )
  
  if (is.null(canal)) return(NULL)
  
  playlist_id <- canal$items[[1]]$contentDetails$relatedPlaylists$uploads
  
  # Coletar apenas primeiros 100 vídeos
  ids_coletados <- character()
  token <- NULL
  pagina_num <- 0
  
  # Parar depois de coletar 100 vídeos
  repeat {
    pagina_num <- pagina_num + 1
    
    pagina <- tryCatch(
      get_playlist_items(
        filter = c(playlist_id = playlist_id),
        max_results = 100,
        page_token = token,
        simplify = FALSE
      ),
      error = function(e) {
        log_message(paste0("❌ Erro na página ", pagina_num, ": ", e$message))
        return(NULL)
      }
    )
    
    if (is.null(pagina)) return(NULL)
    
    ids_pagina <- vapply(
      pagina$items,
      \(x) x$contentDetails$videoId,
      character(1)
    )
    
    ids_coletados <- c(ids_coletados, ids_pagina)
    
    log_message(paste0("  Página ", pagina_num, ": ", length(ids_pagina), " vídeos (total: ", 
                       length(ids_coletados), ")"))
    
    # ✅ PARAR AQUI: já temos 50
    if (length(ids_coletados) >= CONFIG$max_videos_por_canal) {
      ids_coletados <- ids_coletados[1:CONFIG$max_videos_por_canal]
      log_message(paste0("  ✓ Coletados ", length(ids_coletados), " vídeos. Parando."))
      break
    }
    
    token <- pagina$nextPageToken
    if (is.null(token)) {
      log_message(paste0("  ✓ Fim do canal. Total: ", length(ids_coletados), " vídeos"))
      break
    }
  }
  
  if (length(ids_coletados) == 0) {
    log_message("  ❌ Nenhum vídeo encontrado!")
    return(NULL)
  }
  
  # Buscar detalhes
  log_message(paste0("  Buscando detalhes de ", length(ids_coletados), " vídeos..."))
  
  lotes <- split(ids_coletados, ceiling(seq_along(ids_coletados) / 50))
  
  dados <- map_dfr(lotes, function(x) {
    get_video_details(
      video_ids = x,
      part = c("snippet", "statistics"),
      simplify = TRUE
    )
  })
  
  # Colunas que esperamos receber da API
  colunas_esperadas <- c(
    "statistics_viewCount",
    "statistics_likeCount",
    "statistics_commentCount",
    "snippet_description"
  )
  
  # Se alguma estiver ausente, cria preenchida com NA
  for (col in colunas_esperadas) {
    if (!col %in% names(dados)) {
      dados[[col]] <- NA_character_
      log_message(paste("⚠️ Coluna ausente criada:", col))
    }
  }
  
  dados |>
    transmute(
      video_id = id,
      titulo = snippet_title,
      data_publicacao = as.POSIXct(
        snippet_publishedAt,
        format = "%Y-%m-%dT%H:%M:%SZ",
        tz = "UTC"
      ),
      descricao = snippet_description,
      visualizacoes = as.numeric(statistics_viewCount),
      curtidas = as.numeric(statistics_likeCount),
      comentarios = as.numeric(statistics_commentCount),
      channel_id = snippet_channelId,
      channel_title = snippet_channelTitle,
      url = paste0("https://www.youtube.com/watch?v=", id),
      data_coleta = Sys.Date()
    )
  
  # names(dados)
  # 
  # glimpse(dados)
}

# ===========================================================================
# FASE 2: COLETAR COMENTÁRIOS (COM RATE LIMITING)
# ===========================================================================

coletar_comentarios_video <- function(
    video_id,
    politico,
    max_comentarios = CONFIG$max_comentarios_por_video,
    pausa_segundos = CONFIG$pausa_entre_videos
) {
  
  # Pausa ANTES de fazer requisição (rate limiting preventivo)
  Sys.sleep(pausa_segundos)
  
  comentarios <- tryCatch(
    get_all_comments(video_id = video_id),
    error = function(e) {
      msg <- conditionMessage(e)
      
      # Rate limiting
      if (grepl("429|too.many|High request", msg, ignore.case = TRUE)) {
        log_message(paste0("⚠️  Rate limit. Aguardando 60s..."))
        Sys.sleep(60)
        return(NULL)
      }
      
      # Quota esgotada
      if (grepl("quota", msg, ignore.case = TRUE)) {
        stop(
          structure(
            list(message = msg),
            class = c("youtube_quota_error", "error", "condition")
          )
        )
      }
      
      return(NULL)
    }
  )
  
  if (is.null(comentarios) || nrow(comentarios) == 0) {
    return(NULL)
  }
  
  comentarios |>
    as_tibble() |>
    slice_head(n = max_comentarios) |>
    transmute(
      comment_id = id,
      video_id = videoId,
      politico = politico,
      author = authorDisplayName,
      published_at = as.character(publishedAt),
      # ✅ Encoding UTF-8 nativo do R
      text = enc2utf8(textOriginal),
      likes = as.integer(likeCount),
      data_coleta = as.Date(Sys.Date())
    ) |>
    distinct(comment_id, .keep_all = TRUE)
}

# ===========================================================================
# BOOTSTRAP PRINCIPAL (SIMPLIFICADO)
# ===========================================================================

bootstrap_coleta <- function(canais_df) {
  
  log_message("═══════════════════════════════════════════════════════════")
  log_message("BOOTSTRAP SIMPLIFICADO (100 vídeos × N canais)")
  log_message(paste0("Data: ", Sys.Date(), " | Hora: ", format(Sys.time(), "%H:%M:%S")))
  log_message("═══════════════════════════════════════════════════════════")
  
  videos_todos <- NULL
  total_comentarios <- 0
  quota_total <- 0
  
  # FASE 1: Coletar vídeos
  log_message("\n📹 FASE 1: Coletando vídeos...")
  
  for (i in seq_len(nrow(canais_df))) {
    linha <- canais_df[i, ]
    
    log_message(paste0("\n[", i, "/", nrow(canais_df), "] ", linha$politico))
    
    videos_canal <- coletar_100_videos(
      channel_id = linha$channel_id,
      politico = linha$politico
    )
    
    if (!is.null(videos_canal)) {
      videos_canal <- videos_canal |>
        mutate(
          politico = linha$politico,
          partido = linha$partido,
          cargo = linha$cargo
        )
      
      videos_todos <- bind_rows(videos_todos, videos_canal)
      
      # Salvar snapshot
      nome_arquivo <- paste0(
        CONFIG$pasta_videos, "/",
        data_para_string(), "_",
        tolower(gsub(" ", "_", linha$politico)),
        "_bootstrap.csv"
      )
      write_csv(videos_canal, nome_arquivo)
      log_message(paste0("  ✓ Snapshot: ", basename(nome_arquivo)))
    }
  }
  
  if (is.null(videos_todos)) {
    log_message("❌ Nenhum vídeo coletado!")
    return(invisible(NULL))
  }
  
  log_message(paste0("\n✅ FASE 1 OK: ", nrow(videos_todos), " vídeos coletados"))
  
  # FASE 2: Coletar comentários
  log_message("\n💬 FASE 2: Coletando comentários...")
  
  arquivo_comentarios <- paste0(
    CONFIG$pasta_comentarios, "/",
    data_para_string(),
    "_comentarios_bootstrap.csv"
  )
  
  buffer <- list()
  n_comentarios_total <- 0
  
  pb <- txtProgressBar(
    min = 0,
    max = nrow(videos_todos),
    style = 3
  )
  
  for (i in seq_len(nrow(videos_todos))) {
    linha <- videos_todos[i, ]
    
    res <- tryCatch(
      coletar_comentarios_video(
        video_id = linha$video_id,
        politico = linha$politico
      ),
      youtube_quota_error = function(e) {
        log_message("\n❌ QUOTA ESGOTADA!")
        if (length(buffer) > 0) {
          novo <- bind_rows(buffer) |>
            distinct(comment_id, .keep_all = TRUE) |>
            mutate(data_coleta = as.Date(data_coleta))
          fwrite(novo, arquivo_comentarios, bom = FALSE)
          log_message(paste0("Comentários salvos até agora: ", nrow(novo)))
        }
        stop(e)
      }
    )
    
    if (!is.null(res)) {
      buffer[[length(buffer) + 1]] <- res
      n_comentarios_total <- n_comentarios_total + nrow(res)
    }
    
    # Salvar a cada 10 vídeos
    if (i %% 10 == 0) {
      if (length(buffer) > 0) {
        novo <- bind_rows(buffer) |>
          distinct(comment_id, .keep_all = TRUE) |>
          mutate(data_coleta = as.Date(data_coleta))
        
        if (file.exists(arquivo_comentarios)) {
          antigo <- fread(
            arquivo_comentarios,
            encoding = "UTF-8",
            colClasses = list(character = c("published_at", "data_coleta"))
          ) |>
            as_tibble() |>
            mutate(data_coleta = as.Date(data_coleta))
          
          novo <- bind_rows(antigo, novo) |>
            distinct(comment_id, .keep_all = TRUE)
        }
        
        fwrite(novo, arquivo_comentarios, bom = FALSE)
        buffer <- list()
      }
    }
    
    setTxtProgressBar(pb, i)
  }
  
  # Salvar resto
  if (length(buffer) > 0) {
    novo <- bind_rows(buffer) |>
      distinct(comment_id, .keep_all = TRUE) |>
      mutate(data_coleta = as.Date(data_coleta))
    
    if (file.exists(arquivo_comentarios)) {
      antigo <- fread(
        arquivo_comentarios,
        encoding = "UTF-8",
        colClasses = list(character = c("published_at", "data_coleta"))
      ) |>
        as_tibble() |>
        mutate(data_coleta = as.Date(data_coleta))
      
      novo <- bind_rows(antigo, novo) |>
        distinct(comment_id, .keep_all = TRUE)
    }
    
    fwrite(novo, arquivo_comentarios, bom = FALSE)
  }
  
  close(pb)
  
  log_message(paste0("\n✅ FASE 2 OK: ", n_comentarios_total, " comentários coletados"))
  
  # FASE 3: Criar arquivo de IDs conhecidos
  log_message("\n📋 FASE 3: Registrando IDs conhecidos...")
  
  ids_conhecidos <- tibble(
    video_id = unique(videos_todos$video_id)
  )
  
  fwrite(ids_conhecidos, CONFIG$arquivo_ids_conhecidos, bom = FALSE)
  
  log_message(paste0("  ✓ ", nrow(ids_conhecidos), " IDs registrados"))
  
  # FASE 4: Registrar metadata
  registrar_coleta(
    canal = "BOOTSTRAP_GERAL",
    n_videos = nrow(videos_todos),
    n_comentarios = n_comentarios_total,
    quota_gasta = 1000,  # Estimar
    status = "sucesso_bootstrap"
  )
  
  log_message("═══════════════════════════════════════════════════════════")
  log_message("✅ BOOTSTRAP CONCLUÍDO COM SUCESSO!")
  log_message(paste0("   Vídeos: ", nrow(videos_todos)))
  log_message(paste0("   Comentários: ", n_comentarios_total))
  log_message("═══════════════════════════════════════════════════════════")
  log_message("\n📌 PRÓXIMO PASSO:")
  log_message("   Rodar: coleta_diaria_completa.R (amanhã e diariamente)")
  log_message("═══════════════════════════════════════════════════════════\n")
  
  invisible(NULL)
}

# ===========================================================================
# EXECUÇÃO
# ===========================================================================

canais_politicos <- tribble(
  ~politico,          ~partido,    ~cargo,       ~channel_id,
  "Romeu Zema", "NOVO", "Candidato", "UCBY16QLJLEUEjwzc-V09tKg",
  "Ronaldo Caiado", "PSD", "Candidato", "UCAz1jGIUrdpGoC8GvRTqrTA",
  "Jair Bolsonaro",  "PL", "Ex-presidente",   "UC8hGUtfEgvvnp6IaHSAg1OQ",
  "Lula",  "PT", "Presidente",    "UCvO2BExvkAbGMsTGnEnI_Ng",
  "Renan Santos", "MISSÃO", "Candidato", "UCMLluq-qSne85Un73ToYI2w"
)

bootstrap_coleta(canais_politicos)


# Download de bases com estatísticas dos canais -----------------------------

# Estatísticas de canal (snapshot no momento da coleta) -------------------
  
  coletar_stats_canal <- function(channel_id) {
    
    info <- tryCatch(
      get_channel_stats(channel_id),
      error = function(e) {
        message("Erro no canal ", channel_id, ": ", e$message)
        return(NULL)
      }
    )
    
    if (is.null(info) || nrow(info) == 0) return(NULL)
    
    tibble(
      channel_id   = info$channel_id,
      titulo_canal = info$title,
      data_criacao = as.POSIXct(info$published_at, tz = "UTC"),
      inscritos    = info$subscriber_count,
      total_views  = info$view_count,
      total_videos = info$video_count,
      data_coleta  = Sys.Date()
    )
  }

stats_canais <- canais_politicos %>%
  pull(channel_id) %>%
  map_dfr(coletar_stats_canal) %>%
  left_join(canais_politicos %>% dplyr::select(politico, partido, cargo, channel_id),
            by = "channel_id")

write_csv(stats_canais, "dados/final/canais_stats.csv")


# Vídeos + métricas de cada canal -----------------------------------------

coletar_videos_canal <- function(channel_id, politico) {
  
  message("Coletando vídeos de: ", politico)
  
  # Playlist de uploads
  canal <- list_channel_resources(
    filter = c(channel_id = channel_id),
    part = "contentDetails",
    simplify = FALSE
  )
  
  playlist_id <- canal$items[[1]]$contentDetails$relatedPlaylists$uploads
  
  # Coleta todos os IDs dos vídeos
  ids <- character()
  token <- NULL
  
  repeat {
    
    pagina <- get_playlist_items(
      filter = c(playlist_id = playlist_id),
      max_results = 50,
      page_token = token,
      simplify = FALSE
    )
    
    ids <- c(
      ids,
      vapply(
        pagina$items,
        \(x) x$contentDetails$videoId,
        character(1)
      )
    )
    
    token <- pagina$nextPageToken
    
    if (is.null(token))
      break
  }
  
  message(length(ids), " vídeos encontrados.")
  
  # Busca detalhes em lotes de 50 vídeos
  lotes <- split(ids, ceiling(seq_along(ids) / 50))
  
  dados <- map_dfr(lotes, function(x) {
    
    get_video_details(
      video_ids = x,
      part = c("snippet", "statistics"),
      simplify = TRUE
    )
    
  })
  
  dados %>%
    transmute(
      video_id = id,
      titulo = snippet_title,
      data_publicacao = as.POSIXct(snippet_publishedAt, tz = "UTC"),
      descricao = snippet_description,
      visualizacoes = as.numeric(statistics_viewCount),
      curtidas = as.numeric(statistics_likeCount),
      comentarios = as.numeric(statistics_commentCount),
      channel_id = snippet_channelId,
      channel_title = snippet_channelTitle,
      url = paste0("https://www.youtube.com/watch?v=", id),
      politico = politico
    )
  
}

videos_todos_canais <- canais_politicos %>%
  pmap_dfr(function(politico, partido, cargo, channel_id) {
    coletar_videos_canal(channel_id, politico) %>%
      mutate(partido = partido, cargo = cargo)
  })

write_csv(videos_todos_canais, "dados/final/videos_por_canal.csv")
