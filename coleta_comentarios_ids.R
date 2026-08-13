# ============================================================================
# COLETA DE COMENTÁRIOS COM VIDEO_IDs FORNECIDOS
#
# Este script coleta APENAS comentários de vídeos específicos
#    - Você fornece um vetor de video_ids
#    - Script coleta comentários desses vídeos
#    - O objetivo é gastar menos quota
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
  pasta_comentarios = "dados/comentarios",
  pasta_metadata = "dados/metadata",
  arquivo_log = "dados/metadata/coleta_log.csv",
  max_comentarios_por_video = 50,
  pausa_entre_videos = 1.0        
)

# Autenticação
# file.remove(".httr-oauth") # caso exista algum erro de OAuth, remover e rodar novamente

file.edit("~/.Renviron")

readRenviron("~/.Renviron")

yt_oauth(
  app_id     = Sys.getenv("YOUTUBE_APP_ID"),
  app_secret = Sys.getenv("YOUTUBE_APP_SECRET")
)

# Criar pastas
for (pasta in c(CONFIG$pasta_comentarios, CONFIG$pasta_metadata)) {
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
# COLETAR COMENTÁRIOS (COM RATE LIMITING)
# ===========================================================================

coletar_comentarios_video <- function(
    video_id,
    politico = NA_character_,
    max_comentarios = CONFIG$max_comentarios_por_video,
    pausa_segundos = CONFIG$pausa_entre_videos
) {
  
  # Pausa ANTES de fazer requisição
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
      text = enc2utf8(textOriginal),
      likes = as.integer(likeCount),
      data_coleta = as.Date(Sys.Date())
    ) |>
    distinct(comment_id, .keep_all = TRUE)
}

# ===========================================================================
# FUNÇÃO PRINCIPAL: COLETAR DE VIDEO_IDs FORNECIDOS
# ===========================================================================

coletar_comentarios_por_ids <- function(
    video_ids,
    politico = "SEM_POLITICO",
    salvar_arquivo = TRUE
) {
  
  # Validação
  if (length(video_ids) == 0) {
    log_message("❌ Erro: Nenhum video_id fornecido!")
    return(invisible(NULL))
  }
  
  # Se for character simples, transformar em data.frame
  if (is.character(video_ids) && length(video_ids) > 0) {
    video_ids <- tibble(video_id = video_ids, politico = politico)
  } else if (is.data.frame(video_ids) || is.tibble(video_ids)) {
    # Se já for data.frame, verificar se tem as colunas
    if (!"video_id" %in% names(video_ids)) {
      stop("Data.frame deve ter coluna 'video_id'")
    }
    if (!"politico" %in% names(video_ids)) {
      video_ids$politico <- politico
    }
  } else {
    stop("video_ids deve ser um vetor character ou um data.frame/tibble")
  }
  
  log_message("═══════════════════════════════════════════════════════════")
  log_message(paste0("COLETA DE COMENTÁRIOS POR VIDEO_IDs"))
  log_message(paste0("Data: ", Sys.Date(), " | Hora: ", format(Sys.time(), "%H:%M:%S")))
  log_message(paste0("Total de vídeos: ", nrow(video_ids)))
  log_message("═══════════════════════════════════════════════════════════\n")
  
  # Preparar arquivo de saída
  arquivo_comentarios <- paste0(
    CONFIG$pasta_comentarios, "/",
    data_para_string(),
    "_comentarios_custom.csv"
  )
  
  buffer <- list()
  n_comentarios_total <- 0
  n_videos_processados <- 0
  
  pb <- txtProgressBar(
    min = 0,
    max = nrow(video_ids),
    style = 3
  )
  
  # Loop principal
  for (i in seq_len(nrow(video_ids))) {
    linha <- video_ids[i, ]
    vid <- linha$video_id
    pol <- linha$politico
    
    res <- tryCatch(
      coletar_comentarios_video(
        video_id = vid,
        politico = pol
      ),
      youtube_quota_error = function(e) {
        log_message("\n❌ QUOTA ESGOTADA!")
        if (length(buffer) > 0 && salvar_arquivo) {
          novo <- bind_rows(buffer) |>
            distinct(comment_id, .keep_all = TRUE) |>
            mutate(data_coleta = as.Date(data_coleta))
          fwrite(novo, arquivo_comentarios, bom = FALSE)
          log_message(paste0("✓ Comentários salvos até agora: ", nrow(novo)))
        }
        stop(e)
      }
    )
    
    if (!is.null(res)) {
      buffer[[length(buffer) + 1]] <- res
      n_comentarios_total <- n_comentarios_total + nrow(res)
      n_videos_processados <- n_videos_processados + 1
      log_message(paste0("  [", i, "/", nrow(video_ids), "] Video: ", vid, " → ", nrow(res), " comentários"))
    } else {
      log_message(paste0("  [", i, "/", nrow(video_ids), "] Video: ", vid, " → Sem comentários"))
    }
    
    # Salvar a cada 10 vídeos
    if (i %% 10 == 0 && salvar_arquivo) {
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
        log_message(paste0("  → Checkpoint: ", nrow(novo), " comentários salvos até aqui\n"))
      }
    }
    
    setTxtProgressBar(pb, i)
  }
  
  # Salvar resto
  if (length(buffer) > 0 && salvar_arquivo) {
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
  
  log_message(paste0("\n✅ COLETA CONCLUÍDA!"))
  log_message(paste0("   Vídeos processados: ", n_videos_processados, "/", nrow(video_ids)))
  log_message(paste0("   Comentários coletados: ", n_comentarios_total))
  if (salvar_arquivo) {
    log_message(paste0("   Arquivo: ", arquivo_comentarios))
  }
  log_message("═══════════════════════════════════════════════════════════\n")
  
  # Registrar
  registrar_coleta(
    canal = paste0("CUSTOM_", nrow(video_ids), "_IDs"),
    n_videos = nrow(video_ids),
    n_comentarios = n_comentarios_total,
    quota_gasta = nrow(video_ids) * 2,  # estimar
    status = "sucesso_custom"
  )
  
  invisible(list(
    n_videos = nrow(video_ids),
    n_comentarios = n_comentarios_total,
    arquivo = arquivo_comentarios
  ))
}

# ===========================================================================
# Aplicando
# ===========================================================================

# Data.frame com video_ids e políticos
# -------------------------------------------

coletar_comentarios_por_ids(ids_faltantes) # base de dados com coluna de "video_id"

