---
name: github-issues
description: |
  **UNIVERSAL TRIGGER**: Use when user mentions GitHub issue URL or asks to read/work with GitHub issues.

  **Default handler**: Bare GitHub issue URL without action verb -> github-issues (read mode).
  If user sends just a URL like "https://github.com/org/repo/issues/42" with no action word, this skill handles it.

  **CRITICAL RULE**: ALWAYS use `gh` CLI for GitHub issues, NEVER use WebFetch!

   **Reading**: "read issue #N", "show issue", "прочитай задачу"
  ✅ **Checkboxes**: "mark done", "complete step", "отметь пункт"
   **Sub-issues**: "create sub-issue", "link as child", "подзадача"
   **Management**: "edit issue", "close issue", "add label"
  ️ **Images**: "download images from issue", "скачать картинки"

  TRIGGERS:
   github.com/issues, issue #, read issue, show issue, view issue,
     прочитай issue, покажи issue, задача
  ✅ checkbox, mark done, complete step, check off,
     отметь пункт, закрой этап
   sub-issue, subtask, child issue, parent issue,
     подзадача, создай подзадачу
   edit issue, close issue, reopen issue, issue labels,
     create issue, update task
  ️ download images, issue attachments, скачать картинки
allowed-tools: Bash, Read
---

# GitHub Issues Management Skill

Управление GitHub issues через `gh` CLI с поддержкой sub-issues и атомарных операций над checkboxes.

## КРИТИЧЕСКИЕ ПРАВИЛА

### 1. ВСЕГДА использовать `gh`, НИКОГДА WebFetch

```bash
# ПРАВИЛЬНО
gh issue view 123 -R owner/repo

# НЕПРАВИЛЬНО - НЕ ДЕЛАЙ ТАК!
# WebFetch для github.com/.../issues/...
```

### 2. Переименование вкладки zellij при начале работы с issue

Когда пользователь **начинает работу** с issue (читает issue, изучает задачу, обсуждает реализацию), переименуй вкладку zellij:

```bash
zellij-rename-tab-to-issue-number <ISSUE_NUMBER>
```

Скрипт безопасен: если мы не внутри zellij -- ничего не произойдёт.

**Когда вызывать:**
- Пользователь просит прочитать/показать issue
- Пользователь начинает обсуждать задачу из issue
- Первое обращение к issue в сессии

**Когда НЕ вызывать:**
- Отметка checkbox (мелкая операция)
- Закрытие/открытие issue
- Работа с labels

### 3. Атомарные операции с checkboxes (без кеша!)

**ВАЖНО**: При отметке checkbox ВСЕГДА выполняй атомарную операцию fetch→modify→push в ОДНОЙ команде. Это предотвращает конфликты при параллельной работе нескольких агентов.

```bash
# Атомарная отметка checkbox (fetch → modify → push) — ОДНОЙ СТРОКОЙ!
gh issue view 123 -R owner/repo --json body -q .body | sed 's/- \[ \] Точный текст пункта/- [x] Точный текст пункта/' | gh issue edit 123 -R owner/repo --body-file -
```

**ВАЖНО**: Команда должна быть в ОДНУ строку без `\` переносов — иначе ошибка в zsh.

**НИКОГДА** не кешируй body issue! Всегда скачивай заново перед изменением.

### 4. Сначала отметить — потом продолжать

После выполнения любого пункта/этапа/шага:
1. **СНАЧАЛА** отметить как выполненный в issue
2. **ПОТОМ** переходить к следующему

## Проверка зависимостей

При первом использовании проверь установленные расширения:

```bash
gh extension list
```

Если расширения отсутствуют — предложи установить:

```bash
# Для работы с sub-issues
gh extension install yahsan2/gh-sub-issue

# Для расширенного project management (опционально)
gh extension install rubrical-studios/gh-pmu
```

## Команды

### Чтение issue

```bash
# Полный вывод
gh issue view 123 -R owner/repo

# Только body (для парсинга checkboxes)
gh issue view 123 -R owner/repo --json body -q .body

# С комментариями
gh issue view 123 -R owner/repo --comments

# JSON со всеми полями
gh issue view 123 -R owner/repo --json title,body,state,labels
```

### Редактирование issue

```bash
# Изменить заголовок
gh issue edit 123 -R owner/repo --title "Новый заголовок"

# Изменить body
gh issue edit 123 -R owner/repo --body "Новый текст"

# Body из файла или stdin
gh issue edit 123 -R owner/repo --body-file -

# Добавить labels
gh issue edit 123 -R owner/repo --add-label "in-progress"
```

### Атомарная отметка checkbox

```bash
# Шаблон (ОДНОЙ СТРОКОЙ!):
gh issue view NUMBER -R owner/repo --json body -q .body | sed 's/- \[ \] ТОЧНЫЙ_ТЕКСТ/- [x] ТОЧНЫЙ_ТЕКСТ/' | gh issue edit NUMBER -R owner/repo --body-file -
```

**Пример с реальным пунктом:**

```bash
# Было: - [ ] Создать структуру базы данных → Стало: - [x] ...
gh issue view 45 -R dapi/myproject --json body -q .body | sed 's/- \[ \] Создать структуру базы данных/- [x] Создать структуру базы данных/' | gh issue edit 45 -R dapi/myproject --body-file -
```

**Для пунктов с номерами:**

```bash
# Было: - [ ] 1. Первый этап
gh issue view 45 -R owner/repo --json body -q .body | sed 's/- \[ \] 1\. Первый этап/- [x] 1. Первый этап/' | gh issue edit 45 -R owner/repo --body-file -
```

### Sub-issues (требует gh-sub-issue)

```bash
# Список sub-issues родителя
gh sub-issue list 123 -R owner/repo

# Создать новый sub-issue
gh sub-issue create --parent 123 --title "Подзадача" -R owner/repo

# Связать существующий issue как sub-issue (ОДИН репозиторий)
gh sub-issue add 123 456 -R owner/repo

# Связать issue из РАЗНЫХ репозиториев — используй ПОЛНЫЕ URL!
# ВАЖНО: формат owner/repo#123 НЕ работает, только полные URL
gh sub-issue add https://github.com/owner/repo/issues/123 https://github.com/other-owner/other-repo/issues/456

# Удалить связь
gh sub-issue remove 123 456 -R owner/repo
```

### Создание и закрытие

```bash
# Создать issue
gh issue create -R owner/repo --title "Заголовок" --body "Описание"

# Закрыть issue
gh issue close 123 -R owner/repo

# Открыть заново
gh issue reopen 123 -R owner/repo
```

## Парсинг checkboxes

Для получения списка checkboxes из issue:

```bash
# Все checkboxes
gh issue view 123 -R owner/repo --json body -q .body | grep -E '^\s*- \[([ x])\]'

# Только невыполненные
gh issue view 123 -R owner/repo --json body -q .body | grep -E '^\s*- \[ \]'

# Только выполненные
gh issue view 123 -R owner/repo --json body -q .body | grep -E '^\s*- \[x\]'
```

## Извлечение owner/repo из URL

```bash
# Из URL вида https://github.com/owner/repo/issues/123
# owner/repo = dapi/claude-code-marketplace
# number = 123

# Пример парсинга в bash:
URL="https://github.com/dapi/myrepo/issues/45"
REPO=$(echo "$URL" | sed -E 's|https://github.com/([^/]+/[^/]+)/issues/([0-9]+)|\1|')
NUMBER=$(echo "$URL" | sed -E 's|https://github.com/([^/]+/[^/]+)/issues/([0-9]+)|\2|')
```

## Важные замечания

1. **Экранирование в sed**: Если текст пункта содержит спецсимволы (`/`, `.`, `*`), их нужно экранировать
2. **Точное совпадение**: Используй точный текст checkbox, включая пробелы
3. **Проверка результата**: После изменения можно проверить `gh issue view` что checkbox отмечен
4. **Параллельная работа**: Атомарная операция минимизирует риск конфликтов, но не исключает их полностью при одновременном редактировании одного пункта

## Скачивание изображений из issue

Если в issue прикреплены изображения и нужно их скачать:

```bash
# Получить body и извлечь URL изображений, затем скачать каждое
gh api repos/OWNER/REPO/issues/123 --jq '.body' | grep -oP 'https://user-images\.githubusercontent\.com/[^)]+' | while read url; do
    curl -O "$url"
done
```

**Примечание**: Изображения хранятся на `user-images.githubusercontent.com`. Этот паттерн работает для стандартных вложений GitHub. Для изображений из других источников (внешние URL) может потребоваться модификация regex.

## Примеры сценариев

### Выполнить пункт из issue

```bash
# 1. Прочитать issue
gh issue view 123 -R owner/repo

# 2. Выполнить работу по пункту "Написать тесты"
# ... (выполняем работу)

# 3. СРАЗУ отметить как выполненный (атомарно, ОДНОЙ СТРОКОЙ!)
gh issue view 123 -R owner/repo --json body -q .body | sed 's/- \[ \] Написать тесты/- [x] Написать тесты/' | gh issue edit 123 -R owner/repo --body-file -

# 4. Только теперь переходить к следующему пункту
```

### Работа с sub-issues

```bash
# 1. Проверить расширение
gh extension list | grep sub-issue || gh extension install yahsan2/gh-sub-issue

# 2. Посмотреть структуру
gh sub-issue list 123 -R owner/repo

# 3. Создать подзадачу для сложного пункта
gh sub-issue create --parent 123 --title "Реализовать API авторизации" -R owner/repo

# 4. Связать issue из ДРУГОГО репозитория как sub-issue
#    ВАЖНО: только полные URL работают для cross-repo!
gh sub-issue add https://github.com/owner/parent-repo/issues/123 https://github.com/owner/child-repo/issues/456
```
