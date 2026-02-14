# ТЗ: Email Skill

## Обзор

Skill для работы с email через CLI-клиент [Himalaya](https://github.com/pimalaya/himalaya).

**Ключевой принцип:** используем существующую конфигурацию himalaya, НЕ генерируем конфиг. Himalaya должен быть установлен и настроен пользователем.

## Требования

### Функциональные требования

#### 1. Проверка почты (чтение)

| Функция | Описание | Команда himalaya |
|---------|----------|------------------|
| Список писем | Показать последние N писем из папки | `himalaya envelope list -f INBOX -s 20` |
| Непрочитанные | Показать только непрочитанные | `himalaya envelope list "not flag seen"` |
| Чтение письма | Прочитать содержимое по ID | `himalaya message read <id>` |
| Поиск | Найти по отправителю/теме/дате | `himalaya envelope list "from <pattern>"` |
| Папки | Список доступных папок | `himalaya folder list` |

#### 2. Отправка писем

| Функция | Описание | Команда himalaya |
|---------|----------|------------------|
| Отправка | Отправить новое письмо | `himalaya template send` (stdin) |
| Ответ | Ответить на письмо | `himalaya template reply` + `template send` |
| Пересылка | Переслать письмо | `himalaya template forward` + `template send` |

**Важно:** `From` обязателен — использовать email из `himalaya account list`.

#### 3. Управление аккаунтами

| Функция | Описание | Команда himalaya |
|---------|----------|------------------|
| Список аккаунтов | Показать настроенные аккаунты | `himalaya account list` |
| Выбор аккаунта | Использовать конкретный аккаунт | флаг `-a <name>` |

### Нефункциональные требования

1. **Простота:** прямые вызовы himalaya, без wrapper-скриптов
2. **Без конфигурации:** использовать существующие аккаунты himalaya
3. **Предустановка:** himalaya должен быть установлен и настроен пользователем
4. **Интерактивность:** при отправке/ответе спрашивать у пользователя где взять текст письма

## Архитектура

### Структура файлов

```
dev-tools/skills/email/
├── SKILL.md              # Описание skill для Claude Code (обязательно)
├── SPEC.md               # Это ТЗ
└── TRIGGER_EXAMPLES.md   # Примеры триггеров (обязательно)
```

### Подход: Direct CLI

**НЕ создаём bash-wrapper.** Skill содержит только инструкции для Claude, как использовать himalaya напрямую.

## SKILL.md - Спецификация

### Frontmatter

```yaml
---
name: email
description: |
  **UNIVERSAL TRIGGER**: Use when user wants to READ/SEND email.

  Common patterns:
  - "check my email/inbox", "show unread"
  - "send email to [recipient]"
  - "проверить почту", "отправить письмо"

   **Reading**:
  - "check inbox", "show unread emails"
  - "read email from [sender]"
  - "проверить входящие", "непрочитанные"

   **Sending**:
  - "send email to [address]"
  - "reply to email"
  - "отправить письмо", "ответить на письмо"

   **Accounts**:
  - "list email accounts", "switch to work email"
  - "список почтовых аккаунтов"

  TRIGGERS: email, mail, inbox, send email, check email,
  отправить письмо, проверить почту, входящие, письма,
  unread, compose, reply, forward, непрочитанные
allowed-tools: Bash
---
```

### Содержимое SKILL.md

Skill должен содержать:

1. **Prerequisite** - himalaya должен быть установлен и настроен
2. **Команды для чтения** - envelope list, message read
3. **Команды для отправки** - template send (формат MML)
4. **Работа с аккаунтами** - account list, флаг -a
5. **Обработка ошибок** - показывать ошибку пользователю

## Примеры использования

### Проверка почты

```bash
# Список аккаунтов
himalaya account list

# Последние 20 писем из INBOX
himalaya envelope list -f INBOX -s 20

# Непрочитанные письма
himalaya envelope list "not flag seen"

# Письма от конкретного отправителя
himalaya envelope list "from boss@company.com"

# Прочитать письмо по ID
himalaya message read 123

# Использовать другой аккаунт
himalaya envelope list -a "work@company.com" -s 10
```

### Отправка письма

**Важно:** Перед отправкой спросить у пользователя:
- От кого (From) — показать список из `himalaya account list`
- Кому отправить (To)
- Тема письма (Subject)
- Где взять текст письма (ввести сейчас / из файла / сформулировать задачу)

```bash
# From обязателен!
himalaya template send <<'EOF'
From: sender@example.com
To: recipient@example.com
Subject: Тема письма

Текст письма здесь.
Поддерживается Unicode.
EOF

# С конкретного аккаунта (флаг -a + From)
himalaya template send -a "work@company.com" <<'EOF'
From: work@company.com
To: recipient@example.com
Subject: Test

Body here.
EOF

# С CC и BCC
himalaya template send <<'EOF'
From: me@example.com
To: main@example.com
Cc: copy@example.com
Bcc: hidden@example.com
Subject: Important

Message body.
EOF
```

### Поиск

```bash
# По теме
himalaya envelope list "subject meeting"

# По дате
himalaya envelope list "after 2025-01-20"

# Комбинированный
himalaya envelope list "from boss@company.com and after 2025-01-01"
```

## Фильтры himalaya (query syntax)

### Операторы
- `not <condition>` - отрицание
- `<cond> and <cond>` - оба условия
- `<cond> or <cond>` - любое условие

### Условия
- `date <yyyy-mm-dd>` - точная дата
- `before <yyyy-mm-dd>` - до даты
- `after <yyyy-mm-dd>` - после даты
- `from <pattern>` - от отправителя
- `to <pattern>` - получателю
- `subject <pattern>` - тема содержит
- `body <pattern>` - тело содержит
- `flag <flag>` - флаг (seen, answered, flagged, deleted, draft)

## Обработка ошибок

При любых ошибках himalaya — показать вывод ошибки пользователю, чтобы он разобрался сам.

Типичные ошибки:
- `himalaya: command not found` — himalaya не установлен
- `no account found` — нет настроенных аккаунтов
- `connection refused` — проблемы с IMAP/SMTP сервером
- `authentication failed` — неверный пароль

## Acceptance Criteria

1. [ ] SKILL.md создан с корректным frontmatter
2. [ ] TRIGGER_EXAMPLES.md создан с 20+ позитивными и 5+ негативными примерами
3. [ ] Skill активируется на запросы "проверить почту", "check email"
4. [ ] Claude может показать список писем
5. [ ] Claude может прочитать конкретное письмо
6. [ ] Claude может отправить письмо (спрашивая у пользователя текст)
7. [ ] Claude может переключаться между аккаунтами
8. [ ] Ошибки himalaya показываются пользователю
9. [ ] Нет внешних зависимостей кроме himalaya

## Ограничения

1. **Himalaya должен быть установлен** — skill не устанавливает его
2. **Аккаунты должны быть настроены** — skill не конфигурирует аккаунты
3. **Нет вложений** — базовая версия без поддержки attachments
4. **Plain text only** — нет HTML-писем

## Будущие улучшения (out of scope)

- Поддержка вложений
- HTML-письма
- Управление папками (создание, удаление)
- Пометка писем (flag/unflag)
- Удаление писем
- Черновики
