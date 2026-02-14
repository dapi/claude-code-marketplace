# zellij-tab-claude-status

Индикатор статуса Claude в заголовке вкладки Zellij — отображает состояние сессии через иконку-префикс.

## Установка

### Шаг 1: Установить зависимость — Zellij плагин

Установите [zellij-tab-status](https://github.com/dapi/zellij-tab-status):

```bash
# Из корня маркетплейса
make install-zellij-tab-status
```

Устанавливается:
- WASM плагин Zellij (`~/.config/zellij/plugins/zellij-tab-status.wasm`)
- CLI скрипт (`~/.local/bin/zellij-tab-status`)

Добавьте в `~/.config/zellij/config.kdl`:

```kdl
load_plugins {
    "file:~/.config/zellij/plugins/zellij-tab-status.wasm"
}
```

Перезапустите Zellij.

### Шаг 2: Установить плагин Claude Code

```bash
/plugin install zellij-tab-claude-status@dapi
```

## Иконки статуса

| Иконка | Состояние | Описание |
|--------|-----------|----------|
| `◉` | Работает | Обрабатывает запрос |
| `○` | Готов | Ожидает ввода |
| `✋` | Ждёт ввода | Запрос разрешения |

## Как работает

Плагин использует хуки Claude Code для обновления статуса вкладки:

| Событие | Статус |
|---------|--------|
| SessionStart | `○` |
| UserPromptSubmit | `◉` |
| Notification (permission/elicitation) | `✋` |
| Notification (idle_prompt) | `○` |
| Stop | `○` |
| SessionEnd | --clear |

## Требования

- [Zellij](https://zellij.dev) терминальный мультиплексор
- Плагин [zellij-tab-status](https://github.com/dapi/zellij-tab-status)

## Устранение проблем

**Иконки не отображаются**: Убедитесь, что вы работаете внутри Zellij и команда `zellij-tab-status` доступна.

```bash
which zellij-tab-status
zellij-tab-status test  # проверка вручную
```

## Лицензия

MIT
