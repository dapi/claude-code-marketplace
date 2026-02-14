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

### Фаза 0: Сбор контекста (ОБЯЗАТЕЛЬНО!)

**ПЕРЕД любым анализом:**

1. **Прочитай журнал изменений ресурсов**:
```bash
cat docs/resource-changes.md 2>/dev/null || echo "⚠️ Журнал не найден"
```

2. **Получи OOM историю**:
```bash
kubectl get events -A --field-selector reason=OOMKilling --sort-by='.lastTimestamp' | tail -20
```

3. **Сформируй "защитный список"** workloads, для которых снижение ЗАПРЕЩЕНО.

### Фаза 1: Базовый анализ

1. **Найди skill директорию**:
```bash
SKILL_DIR=$(find ~/.claude -path "*/cluster-efficiency/cluster-efficiency.sh" -type f 2>/dev/null | head -1 | xargs dirname)
```

2. **Запусти базовый анализ**:
```bash
cd "$SKILL_DIR" && ./cluster-efficiency.sh $ARGUMENTS
```

### Фаза 2: Глубокий анализ

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

 Утилизация:
- Средняя CPU: X% (target: 70%)
- Средняя Memory: Y%
- Ноды с низкой утилизацией: N

⚠️ Проблемы:
- [HIGH] ...
- [MEDIUM] ...

 Потенциальная экономия:
- CPU: Xm можно освободить
- Memory: XGi можно освободить

 Рекомендации:
1. ...
2. ...
```

## Критерии эффективности

| Метрика | Хорошо | Приемлемо | Плохо |
|---------|--------|-----------|-------|
| CPU utilization | >70% | 40-70% | <40% |
| Memory utilization | >60% | 40-60% | <40% |
| Requests efficiency | >60% | 30-60% | <30% |

## ️ Правила безопасности

### Журнал изменений: `docs/resource-changes.md`

**Формат журнала:**
```markdown
# Resource Changes Log

## 2025-01-15: app-job-processing CPU снижение
- **Было:** 1500m → **Стало:** 500m
- **Результат:** OOM через 2 дня при пиковой нагрузке
- **Откат:** вернули 1500m
- **Вывод:** НЕ СНИЖАТЬ без Prometheus анализа пиков

## 2025-01-10: thumbor memory increase
- **Было:** 512Mi → **Стало:** 1Gi
- **Причина:** частые OOM при обработке больших изображений
- **Статус:** стабильно
```

### НЕ рекомендовать снижение для:

| Условие | Причина |
|---------|---------|
| Workload в журнале откатов | Уже пробовали, получили OOM |
| OOM за последние 7 дней | Очевидный риск |
| Production namespace | Только с явной просьбы |
| Rails/Ruby apps (низкий CPU) | I/O bound — это НОРМА |
| Job processing workloads | Пиковые нагрузки непредсказуемы |
| Нет Prometheus данных | Нет истории — нет доказательств |

### Формат вывода с защитой

```
 Рекомендации:

✅ МОЖНО ОПТИМИЗИРОВАТЬ:
1. dev/test-app: CPU 500m → 100m (Prometheus max 7d: 45m)

⚠️ ЗАЩИЩЁННЫЕ (снижение запрещено):
- prod/api-server: был OOM 3 дня назад
- prod/app-job-processing: откат в docs/resource-changes.md
- stage/thumbor: burst workload

❓ НУЖЕН АНАЛИЗ:
- stage/new-service: efficiency 5%, но нет Prometheus истории
```
