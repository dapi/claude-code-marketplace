---
name: doc-validate
description: Documentation quality validation with interactive fixes
---

# Documentation Validation

Запусти Ruby скрипт для валидации документации проекта.

## Алгоритм

1. Найди скрипт:
   ```bash
   SKILL_DIR=$(dirname "$(find ~/.claude -name "doc_validate.rb" -type f 2>/dev/null | head -1)")
   ```

2. Спроси пользователя какую проверку запустить:

| Команда | Описание | Когда использовать |
|---------|----------|-------------------|
| `lint` | Форматирование, битые ссылки, naming | Быстрая проверка перед коммитом |
| `links` | Граф связей, orphans, dead-ends | Проверка навигации |
| `terms` | Терминология, глоссарий, синонимы | После добавления новых терминов |
| `viewpoints` | BABOK артефакты, state diagrams | Проверка полноты моделирования |
| `contradictions` | Конфликты значений, противоречия | Поиск несоответствий |
| `gaps` | Полнота покрытия, missing sections | Анализ пробелов |
| `review` | **Полный аудит** (все проверки + оценка) | Перед релизом |

3. Выполни выбранную команду:
   ```bash
   ruby "$SKILL_DIR/doc_validate.rb" <command> --project="$(pwd)"
   ```

4. Для интерактивного режима добавь `--interactive`:
   ```bash
   ruby "$SKILL_DIR/doc_validate.rb" <command> --interactive --project="$(pwd)"
   ```

## Режимы

- **Default**: Показывает все проблемы
- **Interactive** (`--interactive`): Для каждой проблемы предлагает действия:
  - `[f]ix` — автоисправление (если доступно)
  - `[s]kip` — пропустить
  - `[i]gnore` — добавить в .docignore
  - `[e]dit` — открыть в редакторе
  - `[x]plain` — подробнее
- **Batch** (`--batch`): Для CI/CD, exit codes: 0=ok, 1=warnings, 2=critical

## Быстрые команды

Если пользователь сразу указал что проверять:
- `/doc-validate lint` → сразу запустить lint
- `/doc-validate review` → сразу запустить полный аудит
- `/doc-validate links --mermaid` → граф с Mermaid диаграммой

## Конфигурация

Проверь наличие `.docvalidate.yml` в корне проекта. Если нет — предложи создать из шаблона.
