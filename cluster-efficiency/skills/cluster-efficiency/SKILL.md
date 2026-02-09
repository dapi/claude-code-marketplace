---
name: cluster-efficiency
description: |
  **UNIVERSAL TRIGGER**: Use when user wants to ANALYZE Kubernetes cluster resource efficiency.

  Common patterns:
  - "analyze cluster efficiency", "check cluster resources"
  - "проанализируй эффективность кластера", "проверь ресурсы кластера"
  - "find over-provisioned workloads", "найди переоцененные ресурсы"
  - "why nodes are not consolidating", "почему ноды не консолидируются"
  - "optimize cluster costs", "оптимизируй затраты на кластер"

  Specific analysis types supported:

  📊 **Nodes Utilization**:
  - "show node utilization", "check nodes efficiency"
  - "low utilization nodes", "ноды с низкой утилизацией"
  - "node consolidation candidates", "кандидаты на консолидацию"

  ⚙️ **Workloads Efficiency**:
  - "find over-provisioned pods", "переоцененные workloads"
  - "CPU/memory efficiency", "эффективность CPU/памяти"
  - "requests vs actual usage", "requests vs фактическое потребление"

  🔄 **Karpenter Analysis**:
  - "karpenter consolidation status", "статус консолидации"
  - "consolidation blockers", "блокеры консолидации"
  - "nodepool configuration", "конфигурация NodePool"

  💰 **Cost Optimization**:
  - "cluster cost optimization", "оптимизация затрат"
  - "resource savings recommendations", "рекомендации по экономии"
  - "YAML resource patches", "YAML патчи ресурсов"

  📈 **Historical Analysis** (with Prometheus):
  - "analyze with prometheus", "historical resource usage"
  - "7-day resource trends", "тренды за 7 дней"

  TRIGGERS: cluster efficiency, cluster resources, node utilization, workload efficiency,
  karpenter consolidation, over-provisioned, resource optimization, cost optimization,
  kubernetes resources, k8s efficiency, эффективность кластера, утилизация нод,
  переоцененные ресурсы, оптимизация затрат, консолидация, анализ кластера,
  cluster analysis, resource analysis, node analysis, pod resources

  This skill provides comprehensive Kubernetes cluster resource efficiency analysis
  using a bash script that works with any cluster context.
allowed-tools: Bash, Read
---

# /cluster-efficiency — Анализ эффективности ресурсов кластера

Выполни комплексный анализ эффективности использования ресурсов кластера Kubernetes.

## Path Resolution

**КРИТИЧЕСКИ ВАЖНО**: При выполнении команд используй скрипт из директории skill.

```bash
# Найти директорию skill
SKILL_DIR=$(find ~/.claude -path "*/cluster-efficiency/cluster-efficiency.sh" -type f 2>/dev/null | head -1 | xargs dirname)

# Или напрямую если известен путь
SKILL_DIR="/home/danil/code/claude-code-marketplace/dev-tools/skills/cluster-efficiency"
```

## Режим работы

Ты работаешь как **оркестратор**, который:
1. Запускает bash скрипт `cluster-efficiency.sh` для сбора базовых метрик
2. Параллельно запускает подагенты для глубокого анализа (если нужен детальный разбор)
3. Формирует итоговый отчет с рекомендациями

## Шаги выполнения

### Шаг 1: Определение контекста

Скрипт автоматически определяет Kubernetes контекст в следующем порядке:
1. `--context=NAME` (CLI аргумент)
2. `CLUSTER_EFFICIENCY_CONTEXT` (переменная окружения)
3. `kubectl config current-context` (текущий контекст)

### Шаг 2: Запуск базового анализа

```bash
# Найти директорию skill и запустить скрипт
SKILL_DIR=$(find ~/.claude -path "*/cluster-efficiency/cluster-efficiency.sh" -type f 2>/dev/null | head -1 | xargs dirname)
cd "$SKILL_DIR" && ./cluster-efficiency.sh --save --compare
```

Или с явным контекстом:
```bash
cd "$SKILL_DIR" && ./cluster-efficiency.sh --context=production --save
```

Это создаст:
- ASCII отчет с метриками
- Лог в директории логов (см. Environment Variables)
- JSON summary для сравнения

### Шаг 3: Анализ результатов

Проанализируй вывод скрипта и определи:

1. **Ноды с низкой утилизацией** (<30%) — кандидаты на консолидацию
2. **Переоцененные workloads** — requests значительно выше фактического потребления
3. **Блокеры консолидации Karpenter** — почему ноды не консолидируются
4. **Потенциальная экономия** — сколько ресурсов можно освободить

### Шаг 4: Глубокий анализ (если нужен)

При обнаружении серьезных проблем, запусти **параллельно** подагенты через Task tool:

```
1. cluster-efficiency:node-analyzer — детальный анализ каждой ноды
2. cluster-efficiency:workload-analyzer — анализ по namespace/deployment
3. cluster-efficiency:karpenter-analyzer — анализ событий и конфигурации Karpenter
```

Пример вызова:
```
Task(subagent_type="cluster-efficiency:node-analyzer",
     prompt="Проанализируй эффективность нод кластера. Контекст: $CONTEXT")
```

### Шаг 5: Генерация рекомендаций

На основе анализа сформируй:

1. **Приоритизированный список рекомендаций** (HIGH/MEDIUM/LOW)
2. **YAML патчи** для исправления ресурсов
3. **Сравнение с предыдущим отчетом** (если доступен)

## Параметры скрипта

| Параметр | Описание | Пример |
|----------|----------|--------|
| `--context=NAME` | Kubernetes контекст | `--context=production` |
| `--namespace=NS` | Фильтр по namespace | `--namespace=default` |
| `--focus=AREA` | Фокус анализа: all, nodes, workloads, karpenter, cost | `--focus=nodes` |
| `--save` | Сохранить отчет в файл | |
| `--compare` | Сравнить с предыдущим отчетом | |
| `--prometheus` | Использовать Prometheus для исторических данных | |
| `--period=PERIOD` | Период для Prometheus: 1d, 7d, 14d | `--period=7d` |
| `--deep` | Подсказка для глубокого анализа | |
| `--quiet` | Минимальный вывод | |

## Environment Variables

| Переменная | Описание | Default |
|------------|----------|---------|
| `CLUSTER_EFFICIENCY_CONTEXT` | Default Kubernetes контекст | current-context |
| `CLUSTER_EFFICIENCY_LOGS_DIR` | Директория для отчетов | ./logs или /tmp/cluster-efficiency |
| `CLUSTER_EFFICIENCY_CPU_WARNING` | Порог warning для CPU efficiency | 40 |
| `CLUSTER_EFFICIENCY_MEM_WARNING` | Порог warning для Memory efficiency | 50 |
| `CLUSTER_EFFICIENCY_NODE_LOW` | Порог низкой утилизации ноды | 30 |
| `CLUSTER_EFFICIENCY_PROMETHEUS_NS` | Namespace Prometheus | monitoring |

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
- Нод можно консолидировать: N

📝 Рекомендации:
1. ...
2. ...

📁 Отчет сохранен: ./logs/cluster-efficiency_TIMESTAMP.log
```

## Критерии эффективности

| Метрика | Хорошо | Приемлемо | Плохо |
|---------|--------|-----------|-------|
| CPU utilization | >70% | 40-70% | <40% |
| Memory utilization | >60% | 40-60% | <40% |
| Requests efficiency | >60% | 30-60% | <30% |
| Node count vs workload | optimal | +1-2 | >+3 |

## Примеры использования

### Базовый анализ текущего контекста
```bash
cd "$SKILL_DIR" && ./cluster-efficiency.sh
```

### Анализ конкретного кластера с сохранением
```bash
cd "$SKILL_DIR" && ./cluster-efficiency.sh --context=production --save --compare
```

### Анализ только workloads в namespace
```bash
cd "$SKILL_DIR" && ./cluster-efficiency.sh --namespace=production --focus=workloads
```

### Анализ с историческими данными из Prometheus
```bash
cd "$SKILL_DIR" && ./cluster-efficiency.sh --prometheus --period=7d --save
```

## Зависимости

| Инструмент | Обязательно | Проверка |
|------------|-------------|----------|
| kubectl | Да | `command -v kubectl` |
| jq | Да | `command -v jq` |
| Prometheus | Нет | В кластере (для `--prometheus`) |

## Важно

- Фокус на **бюджете и загрузке** — избегать простоя ресурсов
- При этом сохранять **гибкость масштабирования** для пиков
- Сравнивать с предыдущими отчетами для отслеживания трендов
- Для project-specific настроек используй Environment Variables
