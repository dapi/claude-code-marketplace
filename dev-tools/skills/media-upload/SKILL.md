---
name: media-upload
description: |
  **UNIVERSAL TRIGGER**: Use when user wants to UPLOAD/SAVE/ATTACH/SHARE images or media files to S3.

  Common patterns:
  - "upload/save/attach/share [file] to s3"
  - "get/fetch public link for [image]"
  - "show/list/display recent uploads"

  📸 **Screenshots**:
  - "upload screenshot", "save screenshot", "attach screenshot"
  - "загрузи скриншот", "приложи скриншот"

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
  s3, bucket, cdn, minio, public link, скриншот, картинка, загрузи, сохрани
allowed-tools: Bash, Read, Write, Glob, AskUserQuestion
---

# Media Upload Skill

Загрузка изображений и медиафайлов в S3-совместимое хранилище через `mc` (MinIO Client) с получением публичной ссылки.

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

### Интеграция с Playwright

Playwright MCP при вызове `browser_take_screenshot` возвращает:
```
Took the viewport screenshot and saved it as /tmp/page-2024-01-31-143052.png
```

Парси этот формат и автоматически подхватывай путь к скриншоту.

## Конфигурация

### Файл конфигурации

**Путь**: `~/.config/claude-code/media-upload.json`
```json
{
  "mc_path": "screenshots/screenshots",
  "public_url": "https://cdn.example.com/screenshots",
  "organize_by": "date",
  "history_file": "~/.media-upload-history.json",
  "max_file_size_mb": 100
}
```

### Переменные окружения (высший приоритет)

```bash
MEDIA_UPLOAD_MC_PATH=screenshots/screenshots
MEDIA_UPLOAD_PUBLIC_URL=https://cdn.example.com/screenshots
MEDIA_UPLOAD_ORGANIZE_BY=date
MEDIA_UPLOAD_MAX_FILE_SIZE_MB=100
MEDIA_UPLOAD_HISTORY_FILE=~/.media-upload-history.json
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

### Используемые команды
```bash
# Проверка алиаса
mc alias list | grep ALIAS_NAME

# Загрузка файла
mc cp LOCAL_FILE ALIAS/BUCKET/PATH

# Проверка соединения (Setup Wizard)
mc ls ALIAS/BUCKET --limit 1
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
if [[ -z "$PUBLIC_URL" ]]; then
  echo "❌ public_url не задан в конфигурации"
  exit 1
fi
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
# Захватить stderr для диагностики
MC_OUTPUT=$(mc cp "$FILE" "${MC_PATH}/${REMOTE_PATH}" 2>&1)
MC_EXIT=$?

if [[ $MC_EXIT -ne 0 ]]; then
  echo "❌ Ошибка загрузки файла: $FILE"
  echo ""
  echo "Детали ошибки:"
  echo "$MC_OUTPUT"
  exit 1
fi

PUBLIC_URL_FULL="${PUBLIC_URL}/${REMOTE_PATH}"
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
```
✅ Image uploaded!

📎 URL: https://cdn.example.com/screenshots/2024/01/31/screenshot-2024-01-31-143052.png
📋 Markdown: ![screenshot](https://cdn.example.com/screenshots/2024/01/31/screenshot-2024-01-31-143052.png)
📦 Size: 245 KB

Would you like me to attach it somewhere? (GitHub issue, Google Doc, etc.)
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
