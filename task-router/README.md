# Task Router Plugin

Классифицирует задачи по ссылке и маршрутизирует в оптимальный workflow разработки.

## Возможности

- **Классификация задач** — определяет сложность и сигналы маршрутизации через haiku-агента
- **Поддержка источников** — GitHub Issues, Google Docs, произвольные URL
- **Маршрутизация** — направляет в feature-dev, subagent-driven-dev или hybrid workflow
- **Экономия контекста** — спека сохраняется в файл, в основной контекст возвращается только компактный JSON

## Зависимости

Для запуска workflow требуются плагины:
- **feature-dev** — для workflow `feature-dev` и `hybrid`
- **superpowers** — для workflow `subagent-driven-dev` и `hybrid` (writing-plans + subagent-driven-development)

## Установка

```bash
/plugin install task-router@dapi
```

## Использование

### Команда

```bash
/route-task https://github.com/org/repo/issues/42
/route-task https://docs.google.com/document/d/1abc/edit
/route-task #123
```

### Естественный язык

```
"возьми задачу https://github.com/org/repo/issues/42"
"реализуй по спеке https://docs.google.com/document/d/1abc/edit"
"сделай issue #123"
"take this task https://github.com/org/repo/issues/99"
```

## Маршрутизация

| Сложность | Сигналы | Маршрут |
|-----------|---------|---------|
| S/M | любые | feature-dev |
| L/XL | есть задачи, нет исследования, архитектура ясна | subagent-driven-dev |
| L/XL | нужно исследование ИЛИ архитектура неясна | hybrid |
| L/XL | нет задач | subagent-driven-dev |

## Компоненты

| Компонент | Назначение |
|-----------|------------|
| `/route-task` | Команда: классификация → презентация → подтверждение → запуск workflow |
| `task-routing` skill | Автотриггер: обнаруживает ссылки на задачи в сообщениях |
| `task-classifier` agent | Haiku-агент: fetch → save → classify → JSON |

## Подробная документация

См. [commands/route-task.md](./commands/route-task.md)
