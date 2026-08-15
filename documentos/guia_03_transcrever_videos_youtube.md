# Guia para os script — `03_transcrever_videos_youtube.ipynb`

## 1. Visão geral

O notebook `03_transcrever_videos_youtube.ipynb` implementa a etapa de **transcrição automática dos vídeos do YouTube** utilizados no projeto.

O pipeline realiza quatro tarefas principais:

1. lê uma lista de URLs de vídeos;
2. baixa o áudio dos vídeos usando `yt-dlp`;
3. transcreve o áudio usando o modelo Whisper;
4. armazena os resultados em um banco de dados SQLite.

---

## 2. Ambiente de execução

O notebook foi estruturado para execução no **Google Colab**.

A primeira etapa monta o Google Drive:

```python
from google.colab import drive
drive.mount('/content/drive')
```

O projeto utiliza uma pasta específica no Drive:

```text
/content/drive/My Drive/youtube_transcriber
```

Essa pasta concentra os arquivos persistentes utilizados pelo pipeline.

A estrutura esperada é:

```text
youtube_transcriber/
├── urls.txt
├── cookies.txt
├── transcricoes.db
└── transcriber.log
```

Os arquivos `transcricoes.db` e `transcriber.log` são criados/atualizados pelo próprio notebook.

---

## 3. Dependências

O notebook instala diretamente no Google Colab:

```bash
pip install -q -U yt-dlp openai-whisper
apt-get -qq install ffmpeg
```

As principais ferramentas utilizadas são:

| Ferramenta | Função |
|---|---|
| `yt-dlp` | Download do áudio dos vídeos do YouTube |
| `openai-whisper` | Transcrição automática da fala |
| `FFmpeg` | Conversão do áudio para MP3 |
| `SQLite` | Armazenamento persistente das transcrições |
| `pandas` | Leitura e manipulação dos resultados |
| `tqdm` | Barra de progresso |
| `logging` | Registro de eventos e erros |

O notebook também importa `matplotlib` e `seaborn`.

---

## 4. Configurações

As principais configurações são definidas no início do notebook:

```python
DRIVE_PATH = '/content/drive/My Drive/youtube_transcriber'
DB_PATH = f'{DRIVE_PATH}/transcricoes.db'
URLS_FILE = f'{DRIVE_PATH}/urls.txt'
COOKIES_PATH = f'{DRIVE_PATH}/cookies.txt'

WHISPER_MODEL = 'base'
BATCH_SIZE = 100
MAX_TENTATIVAS = 3
DELAY_MIN = 5
DELAY_MAX = 15
```

### 4.1 `DRIVE_PATH`

Define a pasta principal utilizada no Google Drive.

### 4.2 `DB_PATH`

Define o local do banco SQLite:

```text
transcricoes.db
```

### 4.3 `URLS_FILE`

Define o arquivo que contém as URLs dos vídeos a serem processados. As urls foram obtidas após o processamento dos vídeos no script `01_coleta_comentarios_bootstrap.R`:

```text
urls.txt
```

### 4.4 `COOKIES_PATH`

Define o arquivo opcional com cookies do YouTube:

```text
cookies.txt
```

Os cookies são utilizados quando o arquivo existe.

### 4.5 `WHISPER_MODEL`

Define o modelo Whisper utilizado:

```python
WHISPER_MODEL = 'base'
```

### 4.6 `MAX_TENTATIVAS`

Define o número máximo de tentativas para o download de cada vídeo:

```python
MAX_TENTATIVAS = 3
```

### 4.7 `DELAY_MIN` e `DELAY_MAX`

Definem o intervalo aleatório de espera antes da primeira tentativa de download:

```python
DELAY_MIN = 5
DELAY_MAX = 15
```

---

## 5. Arquivo `urls.txt`

Os vídeos são fornecidos por meio do arquivo:

```text
urls.txt
```

Cada linha representa uma URL.

O notebook ignora:

- linhas vazias;
- linhas iniciadas por `#`.

Exemplo:

```text
https://www.youtube.com/watch?v=XXXXXXXXXXX
https://youtu.be/YYYYYYYYYYY

# vídeo comentado
https://www.youtube.com/watch?v=ZZZZZZZZZZZ
```

A função responsável por carregar o arquivo é:

```python
def carregar_urls():
```

Ela retorna uma lista contendo apenas as URLs válidas no sentido de estarem presentes no arquivo e não serem comentários/linhas vazias.

---

## 6. Identificação dos vídeos

A função:

```python
def extrair_video_id(url):
```

extrai o identificador do vídeo (`video_id`) a partir da URL.

O notebook reconhece os formatos:

```text
https://www.youtube.com/watch?v=VIDEO_ID
```

e

```text
https://youtu.be/VIDEO_ID
```

O `video_id` é fundamental porque funciona como identificador do vídeo no banco de dados.

---

## 7. Controle de vídeos processados

Um dos componentes mais importantes do notebook é o mecanismo de checkpoint.

A função:

```python
def get_nao_processados(urls):
```

consulta o banco SQLite:

```sql
SELECT video_id FROM transcricoes
```

e cria um conjunto com os vídeos que já possuem registro.

Em seguida, compara os `video_id` das URLs fornecidas em `urls.txt` com os IDs existentes no banco.

Somente vídeos ainda não registrados são enviados para processamento.

### Fluxo

```text
urls.txt
   │
   ▼
extrair_video_id()
   │
   ▼
consultar transcricoes.db
   │
   ├── já existe → não processa novamente
   │
   └── não existe → entra na fila
```

Isso permite interromper o notebook e retomá-lo posteriormente sem começar novamente do zero.

---

## 8. Banco de dados SQLite

O banco é criado pela função:

```python
def criar_banco():
```

O notebook cria a tabela:

```text
transcricoes
```

com a seguinte estrutura:

| Campo | Tipo | Descrição |
|---|---|---|
| `id` | INTEGER | Identificador interno autoincremental |
| `video_id` | TEXT | Identificador do vídeo no YouTube |
| `url` | TEXT | URL do vídeo |
| `titulo` | TEXT | Título do vídeo |
| `duracao_segundos` | INTEGER | Duração do vídeo em segundos |
| `transcricao` | TEXT | Texto produzido pelo Whisper |
| `idioma` | TEXT | Idioma retornado pelo processo de transcrição |
| `status` | TEXT | Situação do processamento |
| `data_processamento` | TIMESTAMP | Data/hora do processamento |
| `erro_mensagem` | TEXT | Mensagem de erro, quando registrada |
| `tentativas` | INTEGER | Número de tentativas de download |

A estrutura SQL é:

```sql
CREATE TABLE IF NOT EXISTS transcricoes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    video_id TEXT UNIQUE NOT NULL,
    url TEXT NOT NULL,
    titulo TEXT,
    duracao_segundos INTEGER,
    transcricao TEXT,
    idioma TEXT,
    status TEXT,
    data_processamento TIMESTAMP,
    erro_mensagem TEXT,
    tentativas INTEGER DEFAULT 0
)
```

### Restrição de unicidade

O campo:

```text
video_id
```

é definido como `UNIQUE`.

Isso impede que o mesmo vídeo seja registrado mais de uma vez na tabela.

---

## 9. Download do áudio

A função:

```python
def baixar_audio_com_retry(url, video_id):
```

é responsável pelo download.

O `yt-dlp` é configurado para obter:

```python
'format': 'bestaudio/best'
```

e converter o resultado para MP3 utilizando FFmpeg:

```python
'postprocessors': [{
    'key': 'FFmpegExtractAudio',
    'preferredcodec': 'mp3',
    'preferredquality': '128',
}]
```

O áudio é armazenado temporariamente em:

```text
/tmp/{video_id}.mp3
```

Além do áudio, o `yt-dlp` recupera:

- duração do vídeo;
- título do vídeo.

Essas informações são posteriormente armazenadas no banco.

---

## 10. Sistema de retry

O download possui dois mecanismos de repetição.

### 10.1 Retry externo

O notebook define:

```python
MAX_TENTATIVAS = 3
```

O loop externo tenta realizar o download até três vezes.

### 10.2 Backoff entre tentativas

A primeira tentativa utiliza um atraso aleatório entre 5 e 15 segundos.

Nas tentativas seguintes, o código utiliza:

```python
tempo_espera = (2 ** tentativa) * 10
```

Assim, os intervalos são:

```text
1ª tentativa → 5–15 segundos aleatórios

2ª tentativa → 20 segundos

3ª tentativa → 40 segundos
```

Além disso, o `yt-dlp` possui:

```python
'retries': 3
```

para suas próprias tentativas internas.

### 10.3 Espera após sucesso

Após um download bem-sucedido, o notebook espera entre 2 e 5 segundos:

```python
time.sleep(random.uniform(2, 5))
```

---

## 11. Cookies do YouTube

O notebook verifica se existe:

```text
cookies.txt
```

por meio de:

```python
usar_cookies = os.path.exists(COOKIES_PATH)
```

Quando o arquivo está disponível, ele é passado ao `yt-dlp`:

```python
ydl_opts['cookiefile'] = COOKIES_PATH
```

Isso permite utilizar cookies para situações em que o YouTube exige autenticação.

---

## 12. Tratamento de erros de download

Quando o download falha, o notebook registra a mensagem de erro.

Alguns erros recebem mensagens específicas.

### `Sign in to confirm`

O notebook sugere:

- utilizar cookies do YouTube;
- aumentar `DELAY_MAX`.

### `Video unavailable`

O notebook sugere verificar se o vídeo:

- foi removido;
- está privado;
- está indisponível.

Se todas as tentativas falharem, a função retorna:

```python
None, None, None
```

e o vídeo é registrado no banco como:

```text
status = erro_download
```

---

## 13. Transcrição com Whisper

A função:

```python
def transcrever_audio(caminho):
```

carrega o modelo:

```python
model = whisper.load_model(WHISPER_MODEL)
```

e executa:

```python
resultado = model.transcribe(
    caminho,
    language="pt",
    verbose=False,
    fp16=True
)
```

O idioma é explicitamente definido como:

```text
pt
```

A função retorna:

```python
resultado.get('text', '')
resultado.get('language', 'pt')
```

ou seja:

1. texto da transcrição;
2. idioma retornado pelo Whisper.

### Modelo utilizado

A configuração atual é:

```python
WHISPER_MODEL = 'base'
```

Portanto, o pipeline utiliza o modelo `base`.

---

## 14. Armazenamento dos resultados

A função:

```python
def salvar_no_banco(...):
```

grava cada resultado individualmente.

A operação utilizada é:

```sql
INSERT OR REPLACE
```

Isso permite inserir um novo registro ou substituir um registro existente com o mesmo `video_id`.

Os principais status utilizados pelo pipeline são:

```text
sucesso
erro_download
erro_transcricao
```

### Sucesso

Quando o áudio é baixado e o Whisper retorna uma transcrição:

```text
status = sucesso
```

### Erro de download

Quando todas as tentativas de download falham:

```text
status = erro_download
```

### Erro de transcrição

Quando o áudio foi baixado, mas a transcrição não foi produzida:

```text
status = erro_transcricao
```

---

## 15. Remoção dos arquivos temporários

Depois da transcrição, a função:

```python
def limpar_audio(caminho):
```

remove o arquivo MP3 temporário.

O áudio é utilizado como um artefato intermediário:

```text
YouTube
   ↓
MP3 temporário
   ↓
Whisper
   ↓
transcrição
   ↓
MP3 removido
```
---

## 16. Loop principal

A função:

```python
def processar_videos(urls_restantes):
```

controla o processamento de todos os vídeos ainda pendentes.

Para cada URL, o pipeline executa:

```text
1. extrair video_id
        ↓
2. baixar áudio
        ↓
3. recuperar título e duração
        ↓
4. transcrever áudio
        ↓
5. remover MP3 temporário
        ↓
6. salvar resultado no SQLite
```

Caso o download falhe:

```text
download → erro_download → próximo vídeo
```

Caso a transcrição falhe:

```text
download → transcrição → erro_transcricao → próximo vídeo
```

Caso tudo funcione:

```text
download → transcrição → sucesso
```

---

## 17. Interrupção manual

O loop possui tratamento para:

```python
KeyboardInterrupt
```

Isso permite interromper a execução manualmente.

---

## 18. Execução completa

A execução principal ocorre no bloco:

```python
if __name__ == "__main__":
```

A ordem é:

```text
1. Mostrar configurações
        ↓
2. Criar/verificar banco
        ↓
3. Carregar URLs
        ↓
4. Identificar URLs ainda não processadas
        ↓
5. Processar vídeos restantes
```

Em termos de funções:

```python
criar_banco()

todas_urls = carregar_urls()

urls_restantes = get_nao_processados(todas_urls)

processar_videos(urls_restantes)
```

Se nenhum vídeo estiver pendente, o notebook informa:

```text
Todos os vídeos já foram processados!
```

---

## 19. Logs

O notebook utiliza a biblioteca `logging`.

O arquivo de log é:

```text
transcriber.log
```

Ele é armazenado na mesma pasta principal do Google Drive.

O log registra informações como:

- início do processamento;
- URLs carregadas;
- utilização de cookies;
- tentativas de download;
- tempo de espera;
- sucesso ou falha do download;
- erros de transcrição;
- sugestões para determinados erros.

Além do arquivo, as mensagens também são exibidas no console do Colab.

---

## 20. Estatísticas do processamento

Ao final da execução, o notebook apresenta:

```text
ESTATÍSTICAS FINAIS

Sucesso: X
Erros: Y
Duração total: Z horas
Banco de dados: ...
Log: ...
```

Isso permite acompanhar rapidamente o resultado de uma rodada de processamento.

---

## 21. Consulta do banco

Após o processamento, o notebook abre o banco com:

```python
conn = sqlite3.connect(db_path)
```

e carrega a tabela inteira com:

```python
df = pd.read_sql_query(
    "SELECT * FROM transcricoes",
    conn
)
```

O objeto `df` passa então a conter as transcrições em um `DataFrame` do pandas.

O notebook também apresenta:

- número de linhas;
- número de colunas;
- nome das variáveis;
- tipo de cada variável;
- quantidade de valores não nulos.

---

## 22. Exportação para CSV

O banco pode ser exportado para CSV:

```python
df.to_csv(
    'transcricoes_completo.csv',
    index=False
)
```

No Google Colab, o arquivo é então disponibilizado para download:

```python
from google.colab import files

files.download('transcricoes_completo.csv')
```

O CSV é uma etapa de exportação. No fluxo geral do projeto, os dados são posteriormente tratados e consolidados pelo script de ETL.

---

## 23. Relação com o ETL

O notebook de transcrição não é a etapa final de organização dos dados.

Seu produto principal é:

```text
transcricoes.db
```

A etapa seguinte do projeto utiliza esses dados para produzir as bases finais.

O fluxo geral é:

```text
COLETA
│
├── vídeos
└── comentários
       │
       ▼
TRANSCRIÇÃO
03_transcrever_videos_youtube.ipynb
       │
       ├── yt-dlp
       ├── FFmpeg
       ├── Whisper
       └── SQLite
       │
       ▼
ETL
04_etl_dados_youtube.R
       │
       ▼
BASES FINAIS
dados/final/
```

A base de transcrições é posteriormente integrada aos metadados dos vídeos durante o processo de ETL.

---

## 24. Arquivos produzidos

Durante o funcionamento, o pipeline utiliza/produz:

| Arquivo | Função |
|---|---|
| `urls.txt` | Lista de vídeos a serem processados |
| `cookies.txt` | Cookies opcionais para autenticação no YouTube |
| `transcricoes.db` | Banco SQLite com os resultados |
| `transcriber.log` | Registro de eventos e erros |
| `transcricoes_completo.csv` | Exportação da tabela SQLite para CSV |
| `/tmp/{video_id}.mp3` | Arquivo de áudio temporário |

---

## 25. Estrutura do banco de transcrições

A estrutura lógica pode ser resumida como:

```text
transcricoes
│
├── id
├── video_id
├── url
├── titulo
├── duracao_segundos
├── transcricao
├── idioma
├── status
├── data_processamento
├── erro_mensagem
└── tentativas
```

O campo mais importante para relacionar essa tabela às demais bases do projeto é:

```text
video_id
```

Ele permite conectar uma transcrição aos metadados correspondentes do vídeo.

---

## 26. Limitações do pipeline

A transcrição automática está sujeita a erros decorrentes das características do áudio e do modelo.

Entre os possíveis problemas estão:

- erros de reconhecimento de palavras;
- nomes próprios incorretos;
- siglas reconhecidas incorretamente;
- dificuldade com ruído;
- sobreposição de vozes;
- problemas em trechos de baixa qualidade;
- vídeos indisponíveis;
- falhas temporárias de download;
- necessidade de autenticação pelo YouTube.

A variável `transcricao` deve, portanto, ser interpretada como **transcrição automática não revisada**.

---

## 28. Resumo do pipeline

```text
                 urls.txt
                    │
                    ▼
             carregar_urls()
                    │
                    ▼
          extrair_video_id()
                    │
                    ▼
        get_nao_processados()
                    │
                    ▼
       ┌──────────────────────┐
       │ baixar_audio_com_retry│
       └──────────┬───────────┘
                  │
          ┌───────┴───────┐
          │               │
        erro            sucesso
          │               │
          ▼               ▼
   erro_download   transcrever_audio()
                          │
                   ┌──────┴──────┐
                   │             │
                 erro          sucesso
                   │             │
                   ▼             ▼
           erro_transcricao   sucesso
                   │             │
                   └──────┬──────┘
                          ▼
                  salvar_no_banco()
                          │
                          ▼
                   limpar_audio()
```



