# github-workflow

Плагин GitHub workflow для Claude Code — issues, PR, worktrees, sub-issues.

## Установка

```bash
/plugin install github-workflow@dapi
```

## Компоненты

### Навык: github-issues

Управление GitHub issues через `gh` CLI: чтение, редактирование, чекбоксы, sub-issues. Активируется автоматически при упоминании URL GitHub issue.

### Команда: /start-issue

Начало работы над GitHub issue — создаёт worktree и ветку.

```
/start-issue https://github.com/owner/repo/issues/123
```

### Команда: /fix-pr

Итеративный цикл ревью и исправления PR до устранения критических проблем.

```
/fix-pr
/fix-pr --max-iterations=3
```

## Использование

```
"прочитай issue #45"
"read issue #45"
"создай sub-issue для #123"
"отметь пункт 1 как выполненный"
"скачай картинки из issue"
```

## Требования

- [gh CLI](https://cli.github.com)
- [gh-sub-issue](https://github.com/yahsan2/gh-sub-issue) расширение (опционально)
- Плагин [pr-review-toolkit](https://github.com/anthropics/claude-code-plugins) (для `/fix-pr`)

## Документация

См. [skills/github-issues/SKILL.md](./skills/github-issues/SKILL.md)

## Лицензия

MIT
