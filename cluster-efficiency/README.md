# Cluster Efficiency Plugin

Комплексный анализ эффективности ресурсов Kubernetes кластера.

## Возможности

- **Анализ нод** — утилизация CPU/Memory, распределение подов
- **Анализ workloads** — requests vs actual usage, переоценённые ресурсы
- **Karpenter анализ** — консолидация, provisioning, события
- **OOM анализ** — глубокий анализ OOM kills
- **Оркестрация** — комплексный отчёт по всем аспектам

## Установка

```bash
/plugin install cluster-efficiency@dapi
```

## Использование

### Команда

```bash
/cluster-efficiency
/cluster-efficiency --deep
```

### Естественный язык

```
"проанализируй эффективность кластера"
"почему ноды не консолидируются"
"найди переоценённые ресурсы"
"оптимизируй затраты на кластер"
```

## Агенты

| Агент | Назначение |
|-------|------------|
| `cluster-orchestrator` | Оркестратор анализа |
| `cluster-node-analyzer` | Анализ эффективности нод |
| `cluster-workload-analyzer` | Анализ workloads |
| `cluster-karpenter-analyzer` | Анализ Karpenter |
| `cluster-oom-analyzer` | Анализ OOM kills |

## Подробная документация

См. [skills/cluster-efficiency/SKILL.md](./skills/cluster-efficiency/SKILL.md)
