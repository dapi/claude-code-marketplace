# /cluster-efficiency — Анализ эффективности ресурсов кластера

Выполни комплексный анализ эффективности использования ресурсов кластера Kubernetes.

## Аргументы

Передаются через `$ARGUMENTS`:
- `--context=NAME` — Kubernetes контекст
- `--namespace=NS` — Фильтр по namespace
- `--focus=AREA` — Фокус: all, nodes, workloads, karpenter, cost
- `--save` — Сохранить отчет
- `--compare` — Сравнить с предыдущим
- `--prometheus` — Использовать Prometheus
- `--deep` — Глубокий анализ с подагентами

## Режим работы

1. **Найди skill директорию**:
```bash
SKILL_DIR=$(find ~/.claude -path "*/cluster-efficiency/cluster-efficiency.sh" -type f 2>/dev/null | head -1 | xargs dirname)
```

2. **Запусти базовый анализ**:
```bash
cd "$SKILL_DIR" && ./cluster-efficiency.sh $ARGUMENTS
```

3. **Если `--deep` или обнаружены серьёзные проблемы** — запусти подагенты параллельно:
```
Task(subagent_type="cluster-efficiency:node-analyzer", prompt="...")
Task(subagent_type="cluster-efficiency:workload-analyzer", prompt="...")
Task(subagent_type="cluster-efficiency:karpenter-analyzer", prompt="...")
```

4. **Сформируй итоговый отчет**

## Примеры использования

```bash
# Базовый анализ текущего контекста
/cluster-efficiency

# Анализ конкретного кластера
/cluster-efficiency --context=production --save

# Глубокий анализ с подагентами
/cluster-efficiency --deep

# Анализ workloads в namespace
/cluster-efficiency --namespace=production --focus=workloads

# С историческими данными
/cluster-efficiency --prometheus --period=7d
```

## Формат вывода

```
=== CLUSTER EFFICIENCY SUMMARY ===

📊 Утилизация:
- Средняя CPU: X% (target: 70%)
- Средняя Memory: Y%
- Ноды с низкой утилизацией: N

⚠️ Проблемы:
- [HIGH] ...
- [MEDIUM] ...

💰 Потенциальная экономия:
- CPU: Xm можно освободить
- Memory: XGi можно освободить

📝 Рекомендации:
1. ...
2. ...
```

## Критерии эффективности

| Метрика | Хорошо | Приемлемо | Плохо |
|---------|--------|-----------|-------|
| CPU utilization | >70% | 40-70% | <40% |
| Memory utilization | >60% | 40-60% | <40% |
| Requests efficiency | >60% | 30-60% | <30% |
