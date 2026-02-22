---
description: Start working on a GitHub issue by creating git worktree with proper branch naming
argument-hint: <issue-url>
version: 1.0.0
---

# Start Issue

Начни работу над GitHub issue.

## Входные данные

- **ISSUE_URL**: $ARGUMENTS (ссылка на GitHub issue)

## Формат имени ветки

```
<тип>/<номер-задачи>-<описание>
```

### Типы веток

| Тип       | Когда использовать                              |
|-----------|-------------------------------------------------|
| `feature` | Новая функциональность                          |
| `fix`     | Исправление бага                                |
| `chore`   | Рефакторинг, зависимости, CI, документация      |

### Определение типа

1. **По labels issue:**
   - `bug`, `fix` → `fix`
   - `enhancement`, `feature` → `feature`
   - `chore`, `refactor`, `docs`, `ci`, `dependencies` → `chore`

2. **Если labels нет** — определи по заголовку/описанию issue

### Формирование описания (slug)

- Lowercase
- Пробелы и спецсимволы → дефисы
- Множественные дефисы → один дефис
- Максимум 50 символов
- Убрать дефис в конце

**Примеры:**
- `feature/123-add-user-authentication`
- `fix/456-null-pointer-in-parser`
- `chore/789-update-eslint-config`

## Шаги выполнения

1. **Прочитай GitHub issue** по ISSUE_URL:
   - Номер issue
   - Заголовок
   - Labels (для определения типа)
   - Описание (если нужно для понимания типа)

2. **Проверь лейбл `progress`:**

   Если issue уже имеет лейбл `progress`:
   - Сообщи пользователю: `⚠️ Issue уже имеет лейбл 'progress' — возможно, над ней уже ведётся работа.`
   - Спроси: продолжить или отменить?
   - Если пользователь отменяет — заверши выполнение команды

3. **Сформируй имя ветки** по шаблону `<тип>/<номер>-<slug>`

4. **Создай git worktree от текущей ветки:**

   Сформируй переменные:
   - `BRANCH_NAME` — имя ветки из шага 3 (например `fix/123-some-bug`)
   - `WORKTREE_NAME` — имя директории: замени `/` на `-` (например `fix-123-some-bug`)
   - `WORKTREE_PATH` — полный путь: `~/worktrees/<WORKTREE_NAME>`

   Выполни команды последовательно:
   ```bash
   mkdir -p ~/worktrees
   ```
   ```bash
   git worktree add -b "<BRANCH_NAME>" "<WORKTREE_PATH>" HEAD
   ```

5. **Перейди в созданный каталог:**
   ```bash
   cd <WORKTREE_PATH>
   ```
   С этого момента `WORKTREE_PATH` — текущий рабочий каталог (CWD). Вся дальнейшая работа должна проводиться в этом каталоге.

6. **Создай init.sh** (если не существует):

   Если файл `init.sh` не существует в каталоге, скопируй шаблон:
   ```bash
   cp <plugin-path>/templates/init.sh ./init.sh
   ```
   Где `<plugin-path>` — путь к плагину github-workflow.

7. **Выполни init.sh:**
   ```bash
   ./init.sh
   ```

8. **Отметь issue лейблом `progress`:**

   Добавь лейбл `progress` к issue:
   ```bash
   gh issue edit <ISSUE_NUMBER> --add-label "progress"
   ```

   Если лейбл не существует в репозитории, сначала создай его:
   ```bash
   gh label create "progress" --color "1D76DB" --description "In progress"
   ```

9. **Переименуй вкладку zellij:**

   ```bash
   zellij-rename-tab-to-issue-number <ISSUE_NUMBER>
   ```

   Скрипт безопасен: если мы не внутри zellij — ничего не произойдёт.

10. **Выведи результат:**
   ```
   ✅ Worktree создан: <WORKTREE_PATH>
    Issue: <ISSUE_URL>
    Ветка: <BRANCH_NAME>
   ```

11. **Приступи к реализации:**

   Убедись что текущий рабочий каталог (CWD) = `<WORKTREE_PATH>`.

   Вызови Skill tool:
   - skill: "task-router:route-task"
   - args: "<ISSUE_URL> --new-session"

   Флаг `--new-session` сообщает task router, что мы уже в выделенной сессии (новая вкладка). Task router автоматически классифицирует задачу и запустит подходящий workflow (feature-dev или subagent-driven-dev).

---

## Завершение задачи

Когда считаешь задачу завершённой, выполни следующие шаги:

### 12. Commit, Push и создание PR

Используй skill `commit-commands:commit-push-pr` для:
- Коммита всех изменений
- Push в remote
- Создания Pull Request

```
/commit-commands:commit-push-pr
```

**⚠️ ВАЖНО: Формат коммитов и PR должен содержать номер issue!**

**Формат commit message:**
```
<тип>: <описание> (#<номер-issue>)

[опционально: детали изменений]

Refs #<номер-issue>
```

**Примеры:**
- `feat: add user authentication (#123)`
- `fix: resolve null pointer in parser (#456)`
- `chore: update eslint config (#789)`

**Формат PR:**
- **Title**: `<тип>: <краткое описание> (#<номер-issue>)`
- **Body**: Обязательно включи `Closes #<номер-issue>` для автоматического закрытия issue при merge

### 13. Параллельный запуск Code Review агентов

После создания PR **ОБЯЗАТЕЛЬНО** запусти review процесс используя **ОБА подхода параллельно**:

**Вариант A** — Skill для комплексного PR review:
```
/pr-review-toolkit:review-pr
```

**Вариант B** — Task tool с параллельными агентами:
Запусти следующие агенты **одновременно** через Task tool:
- `pr-review-toolkit:code-reviewer` — проверка кода на соответствие стандартам
- `pr-review-toolkit:pr-test-analyzer` — анализ покрытия тестами
- `pr-review-toolkit:silent-failure-hunter` — поиск скрытых ошибок
- `pr-review-toolkit:comment-analyzer` — проверка комментариев

**Пример запуска параллельных агентов:**
```
[Task tool: subagent_type="pr-review-toolkit:code-reviewer", prompt="Review PR for code quality"]
[Task tool: subagent_type="pr-review-toolkit:pr-test-analyzer", prompt="Analyze test coverage"]
[Task tool: subagent_type="pr-review-toolkit:silent-failure-hunter", prompt="Hunt for silent failures"]
[Task tool: subagent_type="pr-review-toolkit:comment-analyzer", prompt="Review code comments"]
```

### 14. Исправление найденных проблем

Если review агенты нашли проблемы:
1. Исправь найденные критические и важные issues
2. Сделай дополнительный commit с фиксами
3. Push изменения
4. Перезапусти review (повтори шаг 13)

Повторяй цикл fix → commit → push → review пока все критические проблемы не будут устранены.

### 15. Финализация

После успешного прохождения review:
- Убедись что все CI checks прошли
- PR готов к merge

**Вывод:**
```
✅ Задача завершена!
 Issue: <ISSUE_URL>
 PR: <PR_URL>
✔️ Review: passed
```
