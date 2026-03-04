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
/cluster-efficiency --context=production --save
/cluster-efficiency --namespace=production --focus=workloads
/cluster-efficiency --prometheus
```

С `--deep` команда запускает параллельные подагенты для анализа нод, workloads, Karpenter и OOM.

## Требования

- `kubectl` с доступом к кластеру
- Prometheus/metrics-server (для данных утилизации)

## Лицензия

MIT
