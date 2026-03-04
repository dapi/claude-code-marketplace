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

Определи контекст Kubernetes:
```bash
CONTEXT="${CLUSTER_EFFICIENCY_CONTEXT:-$(kubectl config current-context)}"
echo "Using context: $CONTEXT"
```

**ПЕРЕД любым анализом:**

1. **Прочитай журнал изменений ресурсов**:
```bash
cat docs/resource-changes.md 2>/dev/null || echo "Журнал не найден"
```

2. **Получи OOM историю**:
```bash
kubectl --context=$CONTEXT get events -A --field-selector reason=OOMKilling --sort-by='.lastTimestamp' | tail -20
kubectl --context=$CONTEXT get pods -A -o json | jq -r '.items[] | select(.status.containerStatuses[]?.lastState.terminated.reason == "OOMKilled") | "\(.metadata.namespace)/\(.metadata.name)"' 2>/dev/null
```

3. **Сформируй "защитный список"** workloads, для которых снижение ЗАПРЕЩЕНО:
   - Упомянутые в откатах resource-changes.md
   - Имевшие OOM за последние 7 дней
   - Production namespace (без явной просьбы)

### Фаза 1: Базовый анализ

```bash
SCRIPT_DIR=$(find ~/.claude -path "*/cluster-efficiency/scripts/cluster-efficiency.sh" -type f 2>/dev/null | head -1 | xargs dirname)
cd "$SCRIPT_DIR" && ./cluster-efficiency.sh $ARGUMENTS
```

### Фаза 2: Глубокий анализ (`--deep`)

Если передан `--deep` или базовый анализ выявил серьёзные проблемы — запусти **параллельно** через Task tool три подагента (subagent_type="general-purpose"). Передай каждому контекст и защитный список.

#### Промпт для node-analyzer:

```
Ты — специализированный агент для анализа эффективности нод Kubernetes.

Контекст: $CONTEXT (используй во всех kubectl командах: --context=$CONTEXT)

Задачи:
1. Собрать метрики нод:
   kubectl --context=$CONTEXT get nodes -o wide
   kubectl --context=$CONTEXT top nodes
   kubectl --context=$CONTEXT get nodes -L karpenter.sh/nodepool -L karpenter.sh/capacity-type
   kubectl --context=$CONTEXT describe nodes | grep -E "^Name:|Allocatable:|Allocated resources:|cpu|memory"

2. Классифицировать ноды по типу (system/worker/spot/on-demand), управлению (static/Karpenter) и утилизации (low <30% / normal / high >70%)

3. Выявить проблемы: ноды <30% утилизации, переоцененные workloads (высокие requests при низком usage), несбалансированное распределение

Формат вывода:
NODE EFFICIENCY ANALYSIS
========================
Context: $CONTEXT
Summary: total/system/on-demand/spot ноды
Utilization Distribution: low/normal/high
Issues Found: конкретные ноды с цифрами
Recommendations: приоритизированные действия

Отвечай на русском. Конкретные числа и имена нод.
```

#### Промпт для workload-analyzer:

```
Ты — специализированный агент для анализа эффективности ресурсов workloads.

Контекст: $CONTEXT (используй во всех kubectl командах: --context=$CONTEXT)
Защитный список (снижение ЗАПРЕЩЕНО): $PROTECTED_WORKLOADS

Задачи:
1. Собрать метрики:
   kubectl --context=$CONTEXT top pods -A --no-headers | sort -k3 -h -r | head -30
   kubectl --context=$CONTEXT get pods -A -o json | jq -r '.items[] | select(.status.phase=="Running") | "\(.metadata.namespace)\t\(.metadata.name)\t\(.spec.containers[0].resources.requests.cpu // "none")\t\(.spec.containers[0].resources.requests.memory // "none")"'

2. Рассчитать efficiency ratio: actual/requested * 100%
3. Группировать по namespace и severity

Правила безопасности:
- Rails/Ruby apps: низкий CPU (5-20%) — НОРМА (I/O bound). НЕ снижать!
- Job processing: пиковые нагрузки непредсказуемы. Buffer x2 минимум
- Без Prometheus данных — НЕ рекомендуй снижение memory!
- Workloads из защитного списка — НЕ трогать!

Формула рекомендации (только с Prometheus 7d данными):
  recommended_cpu = max(prometheus_max_7d, p95_7d) * 1.5
  recommended_mem = prometheus_max_7d * 1.3

Формат вывода с тремя секциями:
  ЗАЩИЩЕНО (снижение запрещено): список с причинами
  МОЖНО ОПТИМИЗИРОВАТЬ: конкретные значения current -> recommended
  НЕТ ДАННЫХ (нужен Prometheus): список

Отвечай на русском. Конкретные числа и рекомендуемые значения.
```

#### Промпт для karpenter-analyzer:

```
Ты — специализированный агент для анализа работы Karpenter в Kubernetes.

Контекст: $CONTEXT (используй во всех kubectl командах: --context=$CONTEXT)

Задачи:
1. Конфигурация NodePools:
   kubectl --context=$CONTEXT get nodepools -o yaml

2. NodeClaims:
   kubectl --context=$CONTEXT get nodeclaims -o wide

3. События консолидации:
   kubectl --context=$CONTEXT get events -A --sort-by='.lastTimestamp' | grep -iE "karpen|nodeclaim|provision|consolidat" | tail -30
   kubectl --context=$CONTEXT get events -A --field-selector reason=Unconsolidatable

4. Логи Karpenter:
   kubectl --context=$CONTEXT -n kube-system logs -l app.kubernetes.io/name=karpenter --tail=200 | grep -iE "consolidat|disrupt|provision"

Типичные причины блокировки консолидации:
- "SpotToSpotConsolidation requires 15 cheaper instance types" — мало типов инстансов
- "Can't replace with a cheaper node" — нет дешевых вариантов
- "Pod has do-not-disrupt annotation" — под защищен

Формат вывода:
KARPENTER ANALYSIS
==================
NodePools Configuration: таблица с policy/consolidateAfter/limits
Managed Nodes: список с instance type/capacity type/age
Consolidation Status: eligible vs blocked
Consolidation Blockers: топ причин с частотой
Recommendations: конкретные действия

Отвечай на русском. Конкретные рекомендации по конфигурации.
```

#### Когда запускать OOM-анализ дополнительно:

Если найдены OOMKilled поды или memory usage >80% limit — добавь четвёртый Task с промптом:

```
Ты — специализированный агент для глубокого анализа OOM kills в Kubernetes.

Контекст: $CONTEXT

Источники данных (используй все доступные):

1. kubectl:
   kubectl --context=$CONTEXT get pods -A -o json | jq -r '.items[] | select(.status.containerStatuses[]?.lastState.terminated.reason == "OOMKilled") | "\(.metadata.namespace)|\(.metadata.name)|\(.status.containerStatuses[].restartCount)|\(.status.containerStatuses[].lastState.terminated.finishedAt)"'
   kubectl --context=$CONTEXT get events -A --field-selector reason=OOMKilling -o json
   kubectl --context=$CONTEXT top pods -A

2. Prometheus (если доступен):
   PROM_POD=$(kubectl --context=$CONTEXT get pods -n monitoring -l app.kubernetes.io/name=prometheus -o jsonpath='{.items[0].metadata.name}')
   kubectl --context=$CONTEXT exec -n monitoring $PROM_POD -c prometheus -- wget -qO- 'http://localhost:9090/api/v1/query?query=sum+by+(namespace,pod)(increase(container_oom_events_total[7d]))'
   kubectl --context=$CONTEXT exec -n monitoring $PROM_POD -c prometheus -- wget -qO- 'http://localhost:9090/api/v1/query?query=max+by+(namespace,pod)(max_over_time(container_memory_working_set_bytes[7d]))'

Задачи: выявить паттерны (время, дни, корреляции с деплоями), проанализировать workloads по OOM и restarts, сформировать рекомендации с конкретными limits и YAML патчами.

Формула: recommended_limit = max(max_observed * 1.3, p95_usage * 1.5), округлять до 64Mi.

Отвечай на русском. Конкретные числа, YAML патчи.
```

### Фаза 3: Итоговый отчет

```
+====================================================================+
|            CLUSTER EFFICIENCY REPORT — EXECUTIVE SUMMARY            |
+====================================================================+

Date: YYYY-MM-DD HH:MM
Context: $CONTEXT

OVERALL HEALTH SCORE: XX/100
CPU Utilization:     XX% (target: 70%)
Memory Utilization:  XX%
Requests Efficiency: XX%
Karpenter Health:    OK/WARNING
OOM Status:          X pods affected

COST OPTIMIZATION OPPORTUNITIES
---------------------------------
* Potential CPU savings: Xm
* Potential Memory savings: XGi
* Nodes for consolidation: X

TOP ISSUES (by priority)
---------------------------------
[HIGH]   ...
[MEDIUM] ...
[LOW]    ...

RECOMMENDED ACTIONS
---------------------------------
1. [IMMEDIATE] ...
2. [THIS WEEK] ...
3. [MONITOR] ...
```

## Критерии эффективности

| Метрика | Хорошо | Приемлемо | Плохо |
|-|-|-|-|
| CPU utilization | >70% | 40-70% | <40% |
| Memory utilization | >60% | 40-60% | <40% |
| Requests efficiency | >60% | 30-60% | <30% |
| Consolidation blockers | 0 | 1-2 | >2 |
| OOM/7d | 0 | 1-5 | >5 |

## Правила безопасности

**НЕ рекомендовать снижение для:**

| Условие | Причина |
|-|-|
| Workload в журнале откатов | Уже пробовали, получили OOM |
| OOM за последние 7 дней | Очевидный риск |
| Production namespace | Только с явной просьбы |
| Rails/Ruby apps (низкий CPU) | I/O bound — это НОРМА |
| Job processing workloads | Пиковые нагрузки непредсказуемы |
| Нет Prometheus данных | Нет истории — нет доказательств |

### Журнал изменений: `docs/resource-changes.md`

```markdown
## 2025-01-15: app-job-processing CPU снижение
- Было: 1500m -> Стало: 500m
- Результат: OOM через 2 дня при пиковой нагрузке
- Откат: вернули 1500m
- Вывод: НЕ СНИЖАТЬ без Prometheus анализа пиков
```
