---
name: media-upload
description: |
  **UNIVERSAL TRIGGER**: Use when user wants to UPLOAD/SAVE/ATTACH/SHARE images or media files to S3.
  **AUTO-TRIGGER**: Activate AUTOMATICALLY after taking screenshots with Playwright MCP.

  Common patterns:
  - "upload/save/attach/share [file] to s3"
  - "get/fetch public link for [image]"
  - "show/list/display recent uploads"
  - "сделай скриншот и сохрани" (screenshot + upload)
  - "открой сайт и сделай скриншот" (implies upload)

  📸 **Screenshots** (AUTO-ACTIVATE after Playwright screenshot):
  - After `browser_take_screenshot` → automatically offer to upload
  - "upload screenshot", "save screenshot", "attach screenshot"
  - "загрузи скриншот", "приложи скриншот", "сохрани скриншот"
  - "сделай скриншот [сайта]" → take screenshot + upload to S3

  🖼️ **Images**:
  - "upload/save/attach image/picture/photo"
  - "share png/jpg/gif", "get link for image"

  📦 **Batch**:
  - "upload all png from ./folder/"
  - "загрузи все картинки"

  📜 **History**:
  - "show/list recent uploads"
  - "покажи загрузки"

  TRIGGERS: upload, save, attach, share, get link, show uploads, list uploads,
  screenshot, image, picture, photo, png, jpg, gif, webp, svg, pdf,
  s3, bucket, cdn, minio, public link, скриншот, картинка, загрузи, сохрани,
  сделай скриншот, take screenshot, browser_take_screenshot, playwright screenshot
allowed-tools: Bash, Read, Write, Glob, AskUserQuestion, ToolSearch
---

# Media Upload Skill

Загрузка изображений и медиафайлов в S3-совместимое хранилище через `mc` (MinIO Client) с получением публичной ссылки.

## ⚠️ CRITICAL: Приоритет URL

**ОБЯЗАТЕЛЬНО** после загрузки файла:

1. Если в конфиге есть `public_url` и `url_mode` НЕ равен `"presigned"`:
   - **СРАЗУ** возвращай короткий CDN URL: `${public_url}/${remote_path}`
   - **НЕ генерируй** presigned URL

2. Только если `url_mode: "presigned"` или `public_url` отсутствует:
   - Генерируй presigned URL через `mc share download`

**Пример правильного поведения:**
```
Конфиг: { "public_url": "https://cdn.example.com", "url_mode": "public" }
Путь: 2026/02/03/screenshot.png
→ Возвращай: https://cdn.example.com/2026/02/03/screenshot.png
→ НЕ возвращай: https://s3...?X-Amz-Algorithm=...
```

## Поддерживаемые форматы

| Тип | Расширения | MIME-type |
|-----|------------|-----------|
| Изображения | png, jpg, jpeg, gif, webp, svg | image/* |
| Документы | pdf | application/pdf |
| Видео | mp4, webm (будущее) | video/* |

## Приоритет определения источника файла

1. **Явный путь** — пользователь указал `/path/to/file.png` в запросе
2. **Playwright MCP** — последний результат `browser_take_screenshot` в текущей сессии
3. **Glob паттерн** — "загрузи все png из ./screenshots/"
4. **Спросить пользователя** — если ничего не найдено

### Интеграция с Playwright MCP

**ВАЖНО**: Этот скилл должен активироваться АВТОМАТИЧЕСКИ после создания скриншота через Playwright MCP.

#### Паттерны запросов пользователя

Когда пользователь просит:
- "открой сайт X и сделай скриншот"
- "сделай скриншот страницы Y"
- "take a screenshot of Z"

**Алгоритм**:
1. Загрузить инструменты Playwright MCP через ToolSearch
2. Открыть браузер и перейти на страницу (`browser_navigate`)
3. Сделать скриншот (`browser_take_screenshot`)
4. **АВТОМАТИЧЕСКИ** загрузить скриншот в S3 (этот скилл)
5. Вернуть пользователю публичную ссылку

#### Формат ответа Playwright

Playwright MCP при вызове `browser_take_screenshot` возвращает:
```
Took the viewport screenshot and saved it as /tmp/page-2024-01-31-143052.png
```

Парси этот формат регулярным выражением:
```bash
SCREENSHOT_PATH=$(echo "$PLAYWRIGHT_OUTPUT" | grep -oP 'saved it as \K/[^\s]+\.png')
```

#### Пример полного флоу

```
User: "открой kiiiosk.store и сделай скриншот"

1. ToolSearch: load playwright tools
2. browser_navigate: https://kiiiosk.store
3. browser_take_screenshot → /tmp/page-2026-02-01-123456.png
4. media-upload skill activates automatically
5. MC_REGION=ru-3 mc cp --insecure /tmp/page-... screenshots/claude-screenshots/2026/02/01/...
6. Return: "✅ Screenshot uploaded: https://..."
```

## Конфигурация

### Файл конфигурации

**Путь**: `~/.config/claude-code/media-upload.json`

**С CDN (рекомендуется):**
```json
{
  "mc_path": "screenshots/claude-screenshots",
  "public_url": "https://cdn.example.com",
  "url_mode": "public",
  "organize_by": "date",
  "max_file_size_mb": 100
}
```

**Без CDN (только presigned):**
```json
{
  "mc_path": "screenshots/claude-screenshots",
  "url_mode": "presigned",
  "presigned_expire": "168h",
  "organize_by": "date",
  "max_file_size_mb": 100
}
```

**Примечание**: Если есть `public_url`, используй `url_mode: "public"` для коротких постоянных ссылок.

### Режимы URL (`url_mode`)

| Режим | Описание |
|-------|----------|
| `public` | Использовать публичный URL (требует CDN домен, не S3 API) |
| `presigned` | **Рекомендуется для Selectel**. Генерировать presigned URL через `mc share` |
| `auto` | Проверить публичный доступ, fallback на presigned |

**`presigned_expire`** — время жизни presigned URL (по умолчанию `168h` = 7 дней, **максимум** для mc)

**⚠️ ВАЖНО для Selectel Cloud Storage:**
- S3 API Selectel **НЕ поддерживает анонимный доступ** — все запросы должны быть подписаны
- Настройка "Публичный" в консоли Selectel работает **только через домен `selstorage.ru`**, не через S3 API
- Для S3-совместимого доступа используйте `presigned` режим

### Переменные окружения (высший приоритет)

```bash
MEDIA_UPLOAD_MC_PATH=screenshots/claude-screenshots
MEDIA_UPLOAD_PUBLIC_URL=https://s3.ru-3.storage.selcloud.ru/claude-screenshots
MEDIA_UPLOAD_ORGANIZE_BY=date
MEDIA_UPLOAD_MAX_FILE_SIZE_MB=100
MEDIA_UPLOAD_HISTORY_FILE=~/.media-upload-history.json
MEDIA_UPLOAD_URL_MODE=auto
MEDIA_UPLOAD_PRESIGNED_EXPIRE=168h
```

**Приоритет конфигурации**: Environment variables > JSON config > Default values

### Организация файлов в S3

```bash
# organize_by: "date" (по умолчанию)
screenshots/2024/01/31/screenshot-2024-01-31-143052.png

# organize_by: "type"
screenshots/images/screenshot-2024-01-31-143052.png
screenshots/documents/report.pdf

# organize_by: "flat"
screenshots/screenshot-2024-01-31-143052.png
```

## Security

### Credentials
- Credentials хранятся **только** в `mc alias` (настраивается через `mc alias set`)
- **Никогда** не хранить access/secret keys в `media-upload.json`
- Минимальные IAM права для mc alias: `PutObject` на конкретный bucket

### Валидация файлов
- Проверка magic bytes файла (соответствие расширению)
- Санитизация имени файла: удаление `../`, замена спецсимволов
- Пример: `my screenshot (1).png` → `my-screenshot-1.png`

### Права доступа
- Config файлы создаются с правами 600 (только владелец)

## Лимиты размера файлов

| Порог | Действие |
|-------|----------|
| > 10 MB | Warning: показать размер |
| > 50 MB | Confirmation: запросить подтверждение |
| > 100 MB | Block: отказать (настраивается в конфигурации) |

## mc CLI Contract

### Selectel Cloud Storage: Обязательные настройки

**⚠️ КРИТИЧЕСКИ ВАЖНО для Selectel:**

MinIO Client по умолчанию использует `eu-central-1` в подписи, а Selectel требует `ru-3`.

**Вариант 1: Добавить регион в конфиг mc (рекомендуется)**
```bash
# Добавить регион в существующий alias через jq
jq '.aliases.screenshots.region = "ru-3"' ~/.mc/config.json > /tmp/mc-config.json && \
  mv /tmp/mc-config.json ~/.mc/config.json
```

**Вариант 2: Через переменную окружения**
```bash
export MC_REGION=ru-3
mc cp LOCAL_FILE ALIAS/BUCKET/PATH
```

**SSL проблемы**: Если есть ошибки SSL certificate, использовать `--insecure`:
```bash
mc cp --insecure LOCAL_FILE ALIAS/BUCKET/PATH
```

### Используемые команды
```bash
# Проверка алиаса
mc alias list | grep ALIAS_NAME

# Загрузка файла (Selectel)
MC_REGION=ru-3 mc cp LOCAL_FILE ALIAS/BUCKET/PATH

# Загрузка файла (Selectel с SSL проблемами)
MC_REGION=ru-3 mc cp --insecure LOCAL_FILE ALIAS/BUCKET/PATH

# Проверка соединения (Setup Wizard)
MC_REGION=ru-3 mc ls ALIAS/BUCKET --limit 1
```

### Exit codes
- `0` — успех
- `1` — ошибка (детали в stderr)

## Алгоритм загрузки

### Шаг 1: Проверка конфигурации

```bash
# Проверить наличие конфигурации
CONFIG_FILE="$HOME/.config/claude-code/media-upload.json"
if [[ ! -f "$CONFIG_FILE" ]]; then
  # Запустить Setup Wizard
fi
```

### Шаг 2: Чтение конфигурации

```bash
# Проверить наличие jq
if ! command -v jq &> /dev/null; then
  echo "❌ jq не установлен (требуется для чтения конфигурации)"
  echo "Установка: brew install jq / apt install jq"
  exit 1
fi

# Проверить валидность JSON
if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
  echo "❌ Невалидный JSON в $CONFIG_FILE"
  exit 1
fi

# Приоритет: ENV > JSON > defaults
MC_PATH="${MEDIA_UPLOAD_MC_PATH:-$(jq -r '.mc_path // empty' "$CONFIG_FILE")}"
PUBLIC_URL="${MEDIA_UPLOAD_PUBLIC_URL:-$(jq -r '.public_url // empty' "$CONFIG_FILE")}"
ORGANIZE_BY="${MEDIA_UPLOAD_ORGANIZE_BY:-$(jq -r '.organize_by // "date"' "$CONFIG_FILE")}"
MAX_SIZE="${MEDIA_UPLOAD_MAX_FILE_SIZE_MB:-$(jq -r '.max_file_size_mb // 100' "$CONFIG_FILE")}"

# Проверить обязательные поля
if [[ -z "$MC_PATH" ]]; then
  echo "❌ mc_path не задан в конфигурации"
  exit 1
fi
# public_url необязателен для режима presigned
```

### Шаг 3: Валидация файла

```bash
# Проверить существование и доступность
if [[ ! -f "$FILE" ]] || [[ ! -r "$FILE" ]]; then
  echo "❌ Файл не найден или недоступен для чтения: $FILE"
  exit 1
fi

# Проверить пустой файл
if [[ ! -s "$FILE" ]]; then
  echo "❌ Файл пустой, загрузка отменена"
  exit 1
fi

# Получить размер файла (кроссплатформенно)
if ! SIZE_BYTES=$(stat -f%z "$FILE" 2>/dev/null || stat -c%s "$FILE" 2>/dev/null); then
  echo "❌ Не удалось получить размер файла: $FILE"
  exit 1
fi
if ! [[ "$SIZE_BYTES" =~ ^[0-9]+$ ]]; then
  echo "❌ Ошибка определения размера файла: $FILE"
  exit 1
fi
SIZE_MB=$(( SIZE_BYTES / 1048576 ))

if [[ $SIZE_MB -gt $MAX_SIZE ]]; then
  echo "❌ Файл слишком большой: ${SIZE_MB}MB > ${MAX_SIZE}MB"
  exit 1
fi
```

### Шаг 4: Санитизация имени файла

```bash
sanitize_filename() {
  local filename="$1"
  # Удалить путь, оставить только имя
  filename="${filename##*/}"
  # Заменить пробелы и спецсимволы на дефисы
  filename=$(echo "$filename" | sed 's/[^a-zA-Z0-9._-]/-/g' | sed 's/--*/-/g' | sed 's/-$//')
  echo "$filename"
}
```

### Шаг 5: Формирование пути в S3

```bash
EXT="${FILE##*.}"
DATE_PATH=$(date +%Y/%m/%d)
SANITIZED_NAME=$(sanitize_filename "$FILE")

case "$ORGANIZE_BY" in
  date) REMOTE_PATH="${DATE_PATH}/${SANITIZED_NAME}" ;;
  type)
    # Определить тип по расширению
    case "${EXT,,}" in
      pdf) TYPE_DIR="documents" ;;
      png|jpg|jpeg|gif|webp|svg) TYPE_DIR="images" ;;
      mp4|webm) TYPE_DIR="videos" ;;
      *) TYPE_DIR="other" ;;
    esac
    REMOTE_PATH="${TYPE_DIR}/${SANITIZED_NAME}"
    ;;
  flat) REMOTE_PATH="${SANITIZED_NAME}" ;;
esac
```

### Шаг 6: Загрузка через mc

```bash
# Проверить наличие региона в конфиге mc
MC_ALIAS=$(echo "$MC_PATH" | cut -d'/' -f1)
MC_HAS_REGION=$(jq -r ".aliases.${MC_ALIAS}.region // empty" ~/.mc/config.json 2>/dev/null)

# Если региона нет в конфиге, попробовать добавить (для Selectel)
if [[ -z "$MC_HAS_REGION" ]] && [[ "$MC_ALIAS" == "screenshots" ]]; then
  # Добавить регион ru-3 для Selectel
  jq ".aliases.${MC_ALIAS}.region = \"ru-3\"" ~/.mc/config.json > /tmp/mc-config.json && \
    mv /tmp/mc-config.json ~/.mc/config.json
  echo "ℹ️ Добавлен регион ru-3 в конфиг mc для Selectel"
fi

# Захватить stderr для диагностики
MC_OUTPUT=$(mc cp "$FILE" "${MC_PATH}/${REMOTE_PATH}" 2>&1)
MC_EXIT=$?

# Если ошибка региона - попробовать с MC_REGION
if [[ $MC_EXIT -ne 0 ]] && echo "$MC_OUTPUT" | grep -q "region.*wrong"; then
  echo "ℹ️ Повторная попытка с MC_REGION=ru-3"
  MC_OUTPUT=$(MC_REGION=ru-3 mc cp "$FILE" "${MC_PATH}/${REMOTE_PATH}" 2>&1)
  MC_EXIT=$?
fi

# Если SSL ошибка - попробовать с --insecure
if [[ $MC_EXIT -ne 0 ]] && echo "$MC_OUTPUT" | grep -qi "ssl\|certificate"; then
  echo "ℹ️ Повторная попытка с --insecure"
  MC_OUTPUT=$(mc cp --insecure "$FILE" "${MC_PATH}/${REMOTE_PATH}" 2>&1)
  MC_EXIT=$?
fi

if [[ $MC_EXIT -ne 0 ]]; then
  echo "❌ Ошибка загрузки файла: $FILE"
  echo ""
  echo "Детали ошибки:"
  echo "$MC_OUTPUT"
  exit 1
fi
```

### Шаг 6.1: Генерация URL

```bash
URL_MODE="${MEDIA_UPLOAD_URL_MODE:-$(jq -r '.url_mode // "auto"' "$CONFIG_FILE")}"
PRESIGNED_EXPIRE="${MEDIA_UPLOAD_PRESIGNED_EXPIRE:-$(jq -r '.presigned_expire // "168h"' "$CONFIG_FILE")}"

generate_url() {
  local remote_path="$1"
  local public_url_full="${PUBLIC_URL}/${remote_path}"

  case "$URL_MODE" in
    public)
      echo "$public_url_full"
      ;;
    presigned)
      # Генерировать presigned URL
      mc share download --expire="$PRESIGNED_EXPIRE" "${MC_PATH}/${remote_path}" 2>&1 | \
        grep "^Share:" | cut -d' ' -f2
      ;;
    auto|*)
      # Проверить публичный доступ
      HTTP_CODE=$(curl -sI -o /dev/null -w "%{http_code}" "$public_url_full" 2>/dev/null || echo "000")

      if [[ "$HTTP_CODE" == "200" ]]; then
        echo "$public_url_full"
      else
        # Fallback на presigned
        mc share download --expire="$PRESIGNED_EXPIRE" "${MC_PATH}/${remote_path}" 2>&1 | \
          grep "^Share:" | cut -d' ' -f2
      fi
      ;;
  esac
}

PUBLIC_URL_FULL=$(generate_url "$REMOTE_PATH")
```

### Шаг 7: Запись в историю

```bash
# Получить путь к файлу истории (ENV > JSON config > default)
HISTORY_FILE="${MEDIA_UPLOAD_HISTORY_FILE:-$(jq -r '.history_file // empty' "$CONFIG_FILE" 2>/dev/null | sed "s|~|$HOME|")}"
HISTORY_FILE="${HISTORY_FILE:-$HOME/.media-upload-history.json}"

# Создать файл если не существует
if [[ ! -f "$HISTORY_FILE" ]]; then
  echo '{"uploads":[]}' > "$HISTORY_FILE"
  chmod 600 "$HISTORY_FILE"
fi

# Добавить запись (через jq)
# SIZE_BYTES определен в Шаге 3
if ! jq --arg file "$FILE" \
       --arg url "$PUBLIC_URL_FULL" \
       --arg size "$SIZE_BYTES" \
       --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
       '.uploads += [{"file":$file,"url":$url,"size":($size|tonumber),"timestamp":$ts}]' \
       "$HISTORY_FILE" > "${HISTORY_FILE}.tmp"; then
  echo "⚠️ Загрузка успешна, но запись в историю не удалась"
  rm -f "${HISTORY_FILE}.tmp"
elif ! mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"; then
  echo "⚠️ Не удалось сохранить историю: ошибка перемещения файла"
  rm -f "${HISTORY_FILE}.tmp"
fi
```

## Setup Wizard (первый запуск)

**Условие запуска**:
- Отсутствует файл `~/.config/claude-code/media-upload.json`
- ИЛИ отсутствуют обязательные поля: `mc_path`, `public_url`

### Процесс

1. Проверить установку mc:
```bash
if ! command -v mc &> /dev/null; then
  echo "❌ mc не установлен"
  echo "Установка:"
  echo "  macOS: brew install minio-mc"
  echo "  Linux: apt install minio-mc"
  exit 1
fi
echo "✅ mc is installed"
```

2. Запросить параметры через AskUserQuestion:
- `mc_path` (alias/bucket): например `screenshots/screenshots`
- `public_url`: например `https://cdn.example.com/screenshots`

3. Проверить соединение:
```bash
mc ls "${MC_PATH}" --limit 1
if [[ $? -ne 0 ]]; then
  echo "❌ Не удалось подключиться к ${MC_PATH}"
  echo "Проверьте настройку alias: mc alias set ..."
  exit 1
fi
echo "✅ Bucket accessible"
```

4. Сохранить конфигурацию:
```bash
mkdir -p ~/.config/claude-code
cat > ~/.config/claude-code/media-upload.json << EOF
{
  "mc_path": "${MC_PATH}",
  "public_url": "${PUBLIC_URL}",
  "organize_by": "date",
  "max_file_size_mb": 100
}
EOF
chmod 600 ~/.config/claude-code/media-upload.json
echo "✅ Configuration saved"
```

## Batch Upload

При загрузке нескольких файлов:

```bash
# Пример: загрузи все png из ./screenshots/
# Защита от пустого glob
shopt -s nullglob
files=(./screenshots/*.png)
shopt -u nullglob

if [[ ${#files[@]} -eq 0 ]]; then
  echo "❌ Файлы не найдены: ./screenshots/*.png"
  exit 1
fi

success=()
failed=()

for file in "${files[@]}"; do
  if upload_file "$file"; then
    success+=("$file")
  else
    failed+=("$file")
  fi
done
```

### Частичный успех

При ошибке части файлов показать:
- Успешные с URL
- Неуспешные с причиной ошибки
- **Не откатывать** успешные загрузки

Формат вывода:
```
⚠️ Uploaded 3 of 5 files:

✅ Успешно:
- screenshot-1.png → https://cdn...
- screenshot-2.png → https://cdn...
- screenshot-3.png → https://cdn...

❌ Ошибки:
- screenshot-4.png: Connection timeout
- screenshot-5.png: File too large (120MB > 100MB limit)
```

## История загрузок

**Файл**: `~/.media-upload-history.json`
```json
{
  "uploads": [
    {
      "file": "/tmp/page-2024-01-31-143052.png",
      "url": "https://cdn.example.com/screenshots/2024/01/31/screenshot-2024-01-31-143052.png",
      "size": 245678,
      "timestamp": "2024-01-31T14:30:52Z"
    }
  ]
}
```

**Просмотр истории**:
```bash
jq '.uploads[-10:]' ~/.media-upload-history.json
```

## Выход после успешной загрузки

### Одиночный файл:

**Публичный URL** (короткий, постоянный):
```
✅ Image uploaded!

📎 URL: https://s3.example.com/bucket/2024/01/31/screenshot.png
📋 Markdown: ![screenshot](https://s3.example.com/bucket/2024/01/31/screenshot.png)
📦 Size: 245 KB
```

**Presigned URL** (длинный, временный):
```
✅ Image uploaded!

📎 URL: https://s3.example.com/bucket/2024/01/31/screenshot.png?X-Amz-...
⏰ Expires: 7 days
📋 Markdown: ![screenshot](URL)
📦 Size: 245 KB

💡 Tip: Настройте публичный доступ к bucket для коротких постоянных ссылок
```

### Batch:
```
✅ 5 images uploaded!

| File | URL | Size |
|------|-----|------|
| screenshot-1.png | https://cdn... | 120 KB |
| screenshot-2.png | https://cdn... | 245 KB |
| ... | ... | ... |

Total: 1.2 MB

📋 Markdown (all):
![screenshot-1](https://cdn...)
![screenshot-2](https://cdn...)
```

## Edge Cases

| Ситуация | Действие |
|----------|----------|
| `mc` не установлен | Показать `brew install minio-mc` / `apt install minio-mc` |
| Alias не настроен | Показать `mc alias set screenshots ...` |
| Файл не найден | Спросить путь явно |
| Неподдерживаемый формат | Предупредить, но загрузить если попросят |
| Файл слишком большой | Показать размер, запросить подтверждение (>50MB) или отказать (>100MB) |
| Нет Playwright скриншотов | Спросить путь явно |
| Ошибка загрузки | Показать stderr от mc |
| Спецсимволы в имени | Санитизировать: `my file (1).png` → `my-file-1.png` |
| Пустой файл (0 байт) | Показать ошибку: "Файл пустой, загрузка отменена" |
| Bucket приватный (403) | В режиме `auto` — fallback на presigned URL |
| Presigned URL слишком длинный | Рекомендовать настроить публичный bucket |
| SSL ошибка при проверке | Использовать `curl -k` или сразу presigned |
| Region mismatch (Selectel) | Установить `MC_REGION=ru-3` перед командами mc |
| SSL certificate verify failed | Использовать `mc cp --insecure` или `aws --no-verify-ssl` |

## Рекомендации по настройке публичного доступа

Для коротких URL без presigned подписей:

### Selectel Cloud Storage

**⚠️ ВАЖНО: S3 API Selectel НЕ поддерживает анонимный доступ!**

Даже если бакет настроен как "Публичный", запросы через S3 API (`s3.ru-3.storage.selcloud.ru`) требуют подписи.

**Варианты решения:**

1. **Presigned URLs** (рекомендуется):
   - Используйте `url_mode: "presigned"` в конфигурации
   - Максимальный срок — 7 дней (ограничение mc/S3)
   - URL длинный, но гарантированно работает

2. **Домен selstorage.ru** (публичный хостинг):
   - В консоли включите "Веб-сайт" для бакета
   - URL формата: `https://UUID.selstorage.ru/path/file.png`
   - Требует дополнительной настройки и может иметь проблемы с SSL

3. **CDN Selectel** (лучший вариант для продакшена):
   - Подключите CDN к бакету
   - URL через `*.selcdn.ru` поддерживает анонимный доступ
   - Быстрее и надёжнее

Подробнее: https://qna.habr.com/q/1147270

### MinIO
```bash
mc anonymous set download ALIAS/BUCKET
```

### AWS S3
```bash
aws s3api put-bucket-policy --bucket BUCKET --policy '{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": "*",
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::BUCKET/*"
  }]
}'
```
