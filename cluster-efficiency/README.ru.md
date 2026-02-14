# cluster-efficiency

Плагин анализа эффективности Kubernetes кластера для Claude Code — утилизация ресурсов, Karpenter, OOM, workloads.

## Установка

```bash
/plugin install cluster-efficiency@dapi
```

## Компоненты

### Команда: /cluster-efficiency

Запуск комплексного анализа кластера.

```
/cluster-efficiency
/cluster-efficiency --deep
```

### Навык: cluster-efficiency

Активируется автоматически при запросе об эффективности ресурсов кластера.

### Агенты

| Агент | Назначение |
|-------|------------|
| `cluster-efficiency-orchestrator` | Оркестрация анализа |
| `cluster-node-analyzer` | Анализ эффективности нод |
| `cluster-workload-analyzer` | Анализ workloads (requests vs actual) |
| `cluster-karpenter-analyzer` | Консолидация и provisioning Karpenter |
| `cluster-oom-analyzer` | Анализ OOM kills |

## Использование

```
/cluster-efficiency
"проанализируй эффективность кластера"
"найди переоценённые ресурсы"
"почему ноды не консолидируются"
"analyze cluster efficiency"
```

## Требования

- `kubectl` с доступом к кластеру
- Prometheus/metrics-server (для данных утилизации)

## Документация

См. [skills/cluster-efficiency/SKILL.md](./skills/cluster-efficiency/SKILL.md)

## Лицензия

MIT
