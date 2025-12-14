---
description: Start working on a GitHub issue by creating git worktree with proper branch naming
argument-hint: <issue-url>
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

2. **Сформируй имя ветки** по шаблону `<тип>/<номер>-<slug>`

3. **Создай git worktree от текущей ветки:**
   ```bash
   BRANCH_NAME="<сформированное-имя>"

   # Имя директории: заменяем / на - для плоской структуры
   WORKTREE_NAME=$(echo "${BRANCH_NAME}" | tr '/' '-')

   # Абсолютный путь от корня репозитория
   REPO_ROOT=$(git rev-parse --show-toplevel)
   WORKTREE_PATH="${REPO_ROOT}/../worktrees/${WORKTREE_NAME}"

   # Создай директорию worktrees если не существует
   mkdir -p "${REPO_ROOT}/../worktrees"

   # Создай worktree от текущей ветки (HEAD)
   git worktree add -b "${BRANCH_NAME}" "${WORKTREE_PATH}" HEAD
   ```

4. **Перейди в созданный каталог:**
   ```bash
   cd "${WORKTREE_PATH}"
   ```
   С этого момента `${WORKTREE_PATH}` — текущий рабочий каталог (CWD). Вся дальнейшая работа должна проводиться в этом каталоге.

5. **Создай init.sh** (если не существует):
   ```bash
   if [ ! -f "./init.sh" ]; then
     cat > init.sh << 'INIT_EOF'
   #!/usr/bin/env bash
   mise trust
   git submodule init
   git submodule update

   # Copy .envrc from main/master worktree
   BASE_DIR=$(git worktree list | grep -E '\[(main|master)\]' | head -1 | awk '{print $1}')
   if [ -n "$BASE_DIR" ] && [ -f "$BASE_DIR/.envrc" ]; then
     cp "$BASE_DIR/.envrc" .envrc
     echo "Copied .envrc from $BASE_DIR"
   else
     echo "Warning: Could not find .envrc in main/master worktree"
   fi

   direnv allow
   INIT_EOF
     chmod +x init.sh
   fi
   ```

6. **Выполни init.sh:**
   ```bash
   ./init.sh
   ```

7. **Выведи результат:**
   ```
   ✅ Worktree создан: ${WORKTREE_PATH}
   📋 Issue: ${ISSUE_URL}
   🌿 Ветка: ${BRANCH_NAME}
   ```
