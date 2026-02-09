# Cluster Efficiency - Trigger Examples

## Примеры срабатывания skill

### ✅ ДОЛЖЕН срабатывать

#### Прямые запросы на анализ кластера

| Запрос | Язык |
|--------|------|
| "analyze cluster efficiency" | EN |
| "check cluster resource usage" | EN |
| "проанализируй эффективность кластера" | RU |
| "проверь использование ресурсов кластера" | RU |

#### Анализ нод

| Запрос | Язык |
|--------|------|
| "show node utilization" | EN |
| "find nodes with low utilization" | EN |
| "which nodes can be consolidated" | EN |
| "покажи утилизацию нод" | RU |
| "найди ноды с низкой загрузкой" | RU |
| "какие ноды можно консолидировать" | RU |

#### Анализ workloads

| Запрос | Язык |
|--------|------|
| "find over-provisioned pods" | EN |
| "which workloads have too high requests" | EN |
| "CPU/memory efficiency report" | EN |
| "найди переоцененные поды" | RU |
| "у каких workloads завышены requests" | RU |
| "отчет по эффективности CPU/памяти" | RU |

#### Karpenter

| Запрос | Язык |
|--------|------|
| "why nodes are not consolidating" | EN |
| "karpenter consolidation blockers" | EN |
| "check nodepool status" | EN |
| "почему ноды не консолидируются" | RU |
| "блокеры консолидации karpenter" | RU |
| "статус nodepool" | RU |

#### Оптимизация затрат

| Запрос | Язык |
|--------|------|
| "optimize cluster costs" | EN |
| "resource savings recommendations" | EN |
| "generate YAML patches for resources" | EN |
| "оптимизируй затраты на кластер" | RU |
| "рекомендации по экономии ресурсов" | RU |
| "сгенерируй YAML патчи для ресурсов" | RU |

#### С параметрами

| Запрос | Описание |
|--------|----------|
| "analyze cluster efficiency for production context" | С указанием контекста |
| "check resources in namespace default" | С указанием namespace |
| "deep cluster analysis" | Глубокий анализ с подагентами |
| "cluster efficiency with prometheus data" | С историческими данными |

### ❌ НЕ ДОЛЖЕН срабатывать

| Запрос | Почему |
|--------|--------|
| "what is kubernetes" | Общий вопрос, не анализ |
| "create a deployment" | Создание, не анализ |
| "how to install kubectl" | Инструкция, не анализ |
| "list pods" | Простой kubectl, не анализ эффективности |
| "describe node" | Описание, не анализ эффективности |
| "что такое kubernetes" | Общий вопрос |
| "создай deployment" | Создание |
| "как установить kubectl" | Инструкция |

## Контекстные примеры

### Пример 1: Базовый анализ
```
User: "Проанализируй эффективность кластера"
Action: Запустить skill cluster-efficiency
```

### Пример 2: Анализ конкретного кластера
```
User: "Check cluster efficiency for production cluster"
Action: Запустить skill с --context=production
```

### Пример 3: После изменения ресурсов
```
User: "Мы изменили requests для merchantly, проверь эффект"
Action: Запустить skill с --compare для сравнения с предыдущим отчетом
```

### Пример 4: Глубокий анализ
```
User: "Нужен детальный анализ почему ноды не консолидируются"
Action: Запустить skill, затем подагенты через Task tool
```

### Пример 5: С Prometheus
```
User: "Проанализируй ресурсы за последнюю неделю"
Action: Запустить skill с --prometheus --period=7d
```

## Ключевые слова для триггеринга

### Английские
- cluster efficiency
- resource utilization
- node utilization
- workload efficiency
- over-provisioned
- under-utilized
- consolidation
- karpenter
- cost optimization
- resource analysis

### Русские
- эффективность кластера
- утилизация ресурсов
- утилизация нод
- эффективность workloads
- переоцененные ресурсы
- недозагруженные
- консолидация
- оптимизация затрат
- анализ ресурсов
