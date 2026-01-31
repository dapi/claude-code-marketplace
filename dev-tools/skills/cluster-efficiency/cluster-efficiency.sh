#!/usr/bin/env bash
#
# cluster-efficiency - Universal Kubernetes cluster resource efficiency analyzer
#
# This script is part of dev-tools plugin and can be used with any Kubernetes cluster.
#
# Usage:
#   ./cluster-efficiency.sh [OPTIONS]
#
# Options:
#   --context=NAME    Kubernetes context (priority: CLI > ENV > current-context)
#   --namespace=NS    Filter by namespace (default: all)
#   --focus=AREA      Focus: all|nodes|workloads|oom|karpenter|cost (default: all)
#   --json            Output in JSON format
#   --save            Save report to logs/
#   --compare         Compare with previous report
#   --deep            Hint for deep analysis with subagents
#   --prometheus      Use Prometheus for historical data (7 days)
#   --loki            Use Loki for OOM logs analysis
#   --period=PERIOD   Period for Prometheus/Loki: 1d, 7d, 14d (default: 7d)
#   --quiet           Minimal output (only problems)
#   -h, --help        Show help
#
# Environment Variables:
#   CLUSTER_EFFICIENCY_CONTEXT      Default Kubernetes context
#   CLUSTER_EFFICIENCY_LOGS_DIR     Directory for saving reports
#   CLUSTER_EFFICIENCY_CPU_WARNING  CPU efficiency warning threshold (default: 40)
#   CLUSTER_EFFICIENCY_MEM_WARNING  Memory efficiency warning threshold (default: 50)
#   CLUSTER_EFFICIENCY_NODE_LOW     Low node utilization threshold (default: 30)
#   CLUSTER_EFFICIENCY_PROMETHEUS_NS Prometheus namespace (default: monitoring)
#   CLUSTER_EFFICIENCY_LOKI_NS       Loki namespace (default: monitoring)
#   CLUSTER_EFFICIENCY_OOM_RISK      Memory usage % threshold for "at risk" (default: 80)
#   CLUSTER_EFFICIENCY_OOM_HOURS     Hours to look back for OOM events (default: 24)
#
# Examples:
#   ./cluster-efficiency.sh
#   ./cluster-efficiency.sh --context=production --save
#   ./cluster-efficiency.sh --namespace=production --focus=workloads
#   CLUSTER_EFFICIENCY_CONTEXT=staging ./cluster-efficiency.sh

set -euo pipefail

# ==============================================================================
# Configuration
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Context resolution (will be set by determine_context)
CONTEXT=""

# Logs directory (will be set by determine_logs_dir)
LOGS_DIR=""

# Defaults
NAMESPACE=""
FOCUS="all"
OUTPUT_JSON=false
SAVE_REPORT=false
COMPARE_PREV=false
QUIET=false
DEEP_ANALYSIS=false
USE_PROMETHEUS=false
PROMETHEUS_PERIOD="7d"

# Prometheus configuration
PROMETHEUS_POD=""
PROMETHEUS_NAMESPACE="${CLUSTER_EFFICIENCY_PROMETHEUS_NS:-monitoring}"

# Loki configuration
LOKI_POD=""
LOKI_NAMESPACE="${CLUSTER_EFFICIENCY_LOKI_NS:-monitoring}"
USE_LOKI=false

# OOM thresholds
OOM_MEMORY_RISK_THRESHOLD="${CLUSTER_EFFICIENCY_OOM_RISK:-80}"  # % of limit = at risk
OOM_EVENTS_HOURS="${CLUSTER_EFFICIENCY_OOM_HOURS:-24}"          # hours to look back for events

# Temporary directory (cleaned up on exit)
TMP_DIR=""

# Thresholds (configurable via ENV)
CPU_EFFICIENCY_WARNING="${CLUSTER_EFFICIENCY_CPU_WARNING:-40}"      # % - below this = over-provisioned
CPU_EFFICIENCY_CRITICAL="${CLUSTER_EFFICIENCY_CPU_CRITICAL:-20}"    # %
MEM_EFFICIENCY_WARNING="${CLUSTER_EFFICIENCY_MEM_WARNING:-50}"      # %
MEM_EFFICIENCY_CRITICAL="${CLUSTER_EFFICIENCY_MEM_CRITICAL:-30}"    # %
NODE_UTILIZATION_LOW="${CLUSTER_EFFICIENCY_NODE_LOW:-30}"           # % - nodes below = candidates for removal
NODE_UTILIZATION_TARGET="${CLUSTER_EFFICIENCY_NODE_TARGET:-70}"     # % - target utilization

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ==============================================================================
# Functions
# ==============================================================================

usage() {
    sed -n '2,27p' "$0" | sed 's/^# \?//'
    exit 0
}

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_ok() { echo -e "${GREEN}[OK]${NC} $*"; }

# Check required dependencies
check_dependencies() {
    local missing=()

    if ! command -v kubectl &> /dev/null; then
        missing+=("kubectl")
    fi

    if ! command -v jq &> /dev/null; then
        missing+=("jq")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required dependencies: ${missing[*]}"
        log_info "Please install them and try again"
        exit 1
    fi
}

# Determine Kubernetes context with priority:
# 1. --context=NAME (CLI argument)
# 2. CLUSTER_EFFICIENCY_CONTEXT (environment variable)
# 3. kubectl config current-context (current context)
determine_context() {
    local cli_context="$1"

    if [[ -n "$cli_context" ]]; then
        CONTEXT="$cli_context"
        log_info "Using context from CLI: $CONTEXT"
    elif [[ -n "${CLUSTER_EFFICIENCY_CONTEXT:-}" ]]; then
        CONTEXT="$CLUSTER_EFFICIENCY_CONTEXT"
        log_info "Using context from ENV: $CONTEXT"
    else
        CONTEXT=$(kubectl config current-context 2>/dev/null || echo "")
        if [[ -z "$CONTEXT" ]]; then
            log_error "No Kubernetes context found. Please specify --context=NAME or set CLUSTER_EFFICIENCY_CONTEXT"
            exit 1
        fi
        log_info "Using current context: $CONTEXT"
    fi

    # Verify context exists
    if ! kubectl config get-contexts "$CONTEXT" &>/dev/null; then
        log_error "Context '$CONTEXT' not found in kubeconfig"
        exit 1
    fi
}

# Determine logs directory with priority:
# 1. CLUSTER_EFFICIENCY_LOGS_DIR (environment variable)
# 2. ./logs (if exists in current project)
# 3. /tmp/cluster-efficiency/ (fallback)
determine_logs_dir() {
    if [[ -n "${CLUSTER_EFFICIENCY_LOGS_DIR:-}" ]]; then
        LOGS_DIR="$CLUSTER_EFFICIENCY_LOGS_DIR"
    elif [[ -d "./logs" ]]; then
        LOGS_DIR="./logs"
    else
        LOGS_DIR="/tmp/cluster-efficiency"
    fi

    # Create logs directory if it doesn't exist
    mkdir -p "$LOGS_DIR"
    log_info "Logs directory: $LOGS_DIR"
}

setup_temp_dir() {
    TMP_DIR=$(mktemp -d -t cluster-efficiency.XXXXXX)
    # Cleanup on exit
    trap 'rm -rf "$TMP_DIR"' EXIT
}

parse_args() {
    local cli_context=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --context=*) cli_context="${1#*=}"; shift ;;
            --namespace=*) NAMESPACE="${1#*=}"; shift ;;
            --focus=*) FOCUS="${1#*=}"; shift ;;
            --json) OUTPUT_JSON=true; shift ;;
            --save) SAVE_REPORT=true; shift ;;
            --compare) COMPARE_PREV=true; shift ;;
            --quiet) QUIET=true; shift ;;
            --deep) DEEP_ANALYSIS=true; shift ;;
            --prometheus) USE_PROMETHEUS=true; shift ;;
            --loki) USE_LOKI=true; shift ;;
            --period=*) PROMETHEUS_PERIOD="${1#*=}"; shift ;;
            -h|--help) usage ;;
            *) log_error "Unknown option: $1"; usage ;;
        esac
    done

    # Determine context after parsing all args
    determine_context "$cli_context"

    # Determine logs dir if saving
    [[ "$SAVE_REPORT" == true || "$COMPARE_PREV" == true ]] && determine_logs_dir
}

# CPU conversion to millicores
parse_cpu() {
    local val="$1"
    if [[ "$val" =~ ^([0-9]+)m$ ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$val" =~ ^([0-9]+)$ ]]; then
        echo "$((${BASH_REMATCH[1]} * 1000))"
    else
        echo "0"
    fi
}

# Memory conversion to Mi (returns integer)
parse_memory() {
    local val="$1"
    if [[ "$val" =~ ^([0-9]+)Mi$ ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$val" =~ ^([0-9]+)Gi$ ]]; then
        echo "$((${BASH_REMATCH[1]} * 1024))"
    elif [[ "$val" =~ ^([0-9]+)Ki$ ]]; then
        local ki="${BASH_REMATCH[1]}"
        echo "$((ki / 1024))"
    elif [[ "$val" =~ ^([0-9]+)$ ]]; then
        local bytes="${BASH_REMATCH[1]}"
        echo "$((bytes / 1024 / 1024))"
    elif [[ "$val" =~ ^([0-9]+)M$ ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "0"
    fi
}

# Color indicator for percentage
colorize_percent() {
    local val="$1"
    local low="${2:-$NODE_UTILIZATION_LOW}"
    local target="${3:-$NODE_UTILIZATION_TARGET}"

    if (( val < low )); then
        echo -e "${RED}${val}%${NC}"
    elif (( val < target )); then
        echo -e "${YELLOW}${val}%${NC}"
    else
        echo -e "${GREEN}${val}%${NC}"
    fi
}

# ==============================================================================
# Prometheus Functions
# ==============================================================================

init_prometheus() {
    if [[ "$USE_PROMETHEUS" != true ]]; then
        return 0
    fi

    log_info "Initializing Prometheus connection..."

    PROMETHEUS_POD=$(kubectl --context="$CONTEXT" get pods -n "$PROMETHEUS_NAMESPACE" \
        -l app.kubernetes.io/name=prometheus \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [[ -z "$PROMETHEUS_POD" ]]; then
        log_error "Prometheus pod not found in namespace $PROMETHEUS_NAMESPACE"
        log_warn "Falling back to kubectl top metrics"
        USE_PROMETHEUS=false
        return 1
    fi

    local test_result=$(kubectl --context="$CONTEXT" exec -n "$PROMETHEUS_NAMESPACE" "$PROMETHEUS_POD" -c prometheus -- \
        wget -qO- 'http://localhost:9090/api/v1/query?query=up' 2>/dev/null | jq -r '.status' 2>/dev/null)

    if [[ "$test_result" != "success" ]]; then
        log_error "Failed to connect to Prometheus"
        log_warn "Falling back to kubectl top metrics"
        USE_PROMETHEUS=false
        return 1
    fi

    log_ok "Prometheus connected: $PROMETHEUS_POD"
    return 0
}

prometheus_query() {
    local query="$1"

    if [[ -z "$PROMETHEUS_POD" ]]; then
        echo ""
        return 1
    fi

    kubectl --context="$CONTEXT" exec -n "$PROMETHEUS_NAMESPACE" "$PROMETHEUS_POD" -c prometheus -- \
        wget -qO- --post-data="query=$query" 'http://localhost:9090/api/v1/query' 2>/dev/null
}

collect_prometheus_cpu_stats() {
    local period="$PROMETHEUS_PERIOD"

    log_info "Collecting CPU stats from Prometheus (period: $period)..."

    local current_query="sum by (namespace, pod) (rate(container_cpu_usage_seconds_total{image!~\".*pause.*\"}[5m])) * 1000"
    local max_query="max by (namespace, pod) (max_over_time(rate(container_cpu_usage_seconds_total{image!~\".*pause.*\"}[5m])[$period:5m])) * 1000"
    local p95_query="quantile by (namespace, pod) (0.95, rate(container_cpu_usage_seconds_total{image!~\".*pause.*\"}[5m])) * 1000"
    local avg_query="avg by (namespace, pod) (avg_over_time(rate(container_cpu_usage_seconds_total{image!~\".*pause.*\"}[5m])[$period:5m])) * 1000"

    prometheus_query "$current_query" | jq -r '.data.result[] | "\(.metric.namespace)|\(.metric.pod)|\(.value[1])"' > "$TMP_DIR/prom_cpu_current.txt" 2>/dev/null || true
    prometheus_query "$max_query" | jq -r '.data.result[] | "\(.metric.namespace)|\(.metric.pod)|\(.value[1])"' > "$TMP_DIR/prom_cpu_max.txt" 2>/dev/null || true
    prometheus_query "$p95_query" | jq -r '.data.result[] | "\(.metric.namespace)|\(.metric.pod)|\(.value[1])"' > "$TMP_DIR/prom_cpu_p95.txt" 2>/dev/null || true
    prometheus_query "$avg_query" | jq -r '.data.result[] | "\(.metric.namespace)|\(.metric.pod)|\(.value[1])"' > "$TMP_DIR/prom_cpu_avg.txt" 2>/dev/null || true

    log_ok "CPU stats collected"
}

collect_prometheus_memory_stats() {
    local period="$PROMETHEUS_PERIOD"

    log_info "Collecting Memory stats from Prometheus (period: $period)..."

    local current_query="sum by (namespace, pod) (container_memory_working_set_bytes{image!~\".*pause.*\"}) / 1024 / 1024"
    local max_query="max by (namespace, pod) (max_over_time(container_memory_working_set_bytes{image!~\".*pause.*\"}[$period:5m])) / 1024 / 1024"
    local p95_query="quantile by (namespace, pod) (0.95, container_memory_working_set_bytes{image!~\".*pause.*\"}) / 1024 / 1024"

    prometheus_query "$current_query" | jq -r '.data.result[] | "\(.metric.namespace)|\(.metric.pod)|\(.value[1])"' > "$TMP_DIR/prom_mem_current.txt" 2>/dev/null || true
    prometheus_query "$max_query" | jq -r '.data.result[] | "\(.metric.namespace)|\(.metric.pod)|\(.value[1])"' > "$TMP_DIR/prom_mem_max.txt" 2>/dev/null || true
    prometheus_query "$p95_query" | jq -r '.data.result[] | "\(.metric.namespace)|\(.metric.pod)|\(.value[1])"' > "$TMP_DIR/prom_mem_p95.txt" 2>/dev/null || true

    log_ok "Memory stats collected"
}

collect_prometheus_requests() {
    log_info "Collecting resource requests from Prometheus..."

    local cpu_req_query="sum by (namespace, pod) (kube_pod_container_resource_requests{resource=\"cpu\"}) * 1000"
    local mem_req_query="sum by (namespace, pod) (kube_pod_container_resource_requests{resource=\"memory\"}) / 1024 / 1024"

    prometheus_query "$cpu_req_query" | jq -r '.data.result[] | "\(.metric.namespace)|\(.metric.pod)|\(.value[1])"' > "$TMP_DIR/prom_cpu_requests.txt" 2>/dev/null || true
    prometheus_query "$mem_req_query" | jq -r '.data.result[] | "\(.metric.namespace)|\(.metric.pod)|\(.value[1])"' > "$TMP_DIR/prom_mem_requests.txt" 2>/dev/null || true

    log_ok "Resource requests collected"
}

get_prom_value() {
    local file="$1"
    local ns="$2"
    local pod="$3"

    if [[ ! -f "$file" ]]; then
        echo "0"
        return
    fi

    local value=$(grep "^$ns|$pod|" "$file" 2>/dev/null | cut -d'|' -f3 | head -1)
    if [[ -n "$value" && "$value" != "null" ]]; then
        printf "%.0f" "$value" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# ==============================================================================
# Loki Functions
# ==============================================================================

init_loki() {
    if [[ "$USE_LOKI" != true ]]; then
        return 0
    fi

    log_info "Initializing Loki connection..."

    # Auto-discovery: try common labels
    local labels=(
        "app.kubernetes.io/name=loki"
        "app=loki"
        "app.kubernetes.io/instance=loki"
        "app=loki-gateway"
        "app.kubernetes.io/component=gateway,app.kubernetes.io/name=loki"
    )

    for label in "${labels[@]}"; do
        LOKI_POD=$(kubectl --context="$CONTEXT" get pods -n "$LOKI_NAMESPACE" \
            -l "$label" \
            -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [[ -n "$LOKI_POD" ]]; then
            log_info "Found Loki pod with label: $label"
            break
        fi
    done

    if [[ -z "$LOKI_POD" ]]; then
        # Try to find any pod with "loki" in name
        LOKI_POD=$(kubectl --context="$CONTEXT" get pods -n "$LOKI_NAMESPACE" \
            -o jsonpath='{.items[?(@.metadata.name contains "loki")].metadata.name}' 2>/dev/null | awk '{print $1}')
    fi

    if [[ -z "$LOKI_POD" ]]; then
        log_error "Loki pod not found in namespace $LOKI_NAMESPACE"
        log_warn "Falling back to kubectl events for OOM data"
        USE_LOKI=false
        return 1
    fi

    # Detect Loki port (3100 for loki, 80 for gateway)
    local loki_port="3100"
    if [[ "$LOKI_POD" == *"gateway"* ]]; then
        loki_port="80"
    fi

    # Test connection
    local test_result=$(kubectl --context="$CONTEXT" exec -n "$LOKI_NAMESPACE" "$LOKI_POD" -- \
        wget -qO- "http://localhost:${loki_port}/ready" 2>/dev/null || echo "failed")

    if [[ "$test_result" == "failed" || -z "$test_result" ]]; then
        log_error "Failed to connect to Loki"
        log_warn "Falling back to kubectl events for OOM data"
        USE_LOKI=false
        return 1
    fi

    LOKI_PORT="$loki_port"
    log_ok "Loki connected: $LOKI_POD (port $loki_port)"
    return 0
}

loki_query() {
    local query="$1"
    local start="${2:-$(date -d "-${OOM_EVENTS_HOURS} hours" -Iseconds 2>/dev/null || date -v-${OOM_EVENTS_HOURS}H -Iseconds)}"
    local end="${3:-$(date -Iseconds)}"
    local limit="${4:-1000}"

    if [[ -z "$LOKI_POD" ]]; then
        echo ""
        return 1
    fi

    local encoded_query=$(echo -n "$query" | jq -sRr @uri)
    local encoded_start=$(echo -n "$start" | jq -sRr @uri)
    local encoded_end=$(echo -n "$end" | jq -sRr @uri)

    kubectl --context="$CONTEXT" exec -n "$LOKI_NAMESPACE" "$LOKI_POD" -- \
        wget -qO- "http://localhost:${LOKI_PORT}/loki/api/v1/query_range?query=${encoded_query}&start=${encoded_start}&end=${encoded_end}&limit=${limit}" 2>/dev/null
}

collect_loki_oom_events() {
    if [[ "$USE_LOKI" != true || -z "$LOKI_POD" ]]; then
        return 0
    fi

    log_info "Collecting OOM events from Loki (last ${OOM_EVENTS_HOURS}h)..."

    # Query 1: Kernel OOM killer logs
    local kernel_query='{job=~"systemd-journal|syslog|kernel"} |~ "oom.kill|Out of memory|Killed process"'
    loki_query "$kernel_query" | jq -r '.data.result[]?.values[]?[1]' > "$TMP_DIR/loki_kernel_oom.txt" 2>/dev/null || true

    # Query 2: Kubelet OOM events
    local kubelet_query='{job=~"kubelet|kubernetes-pods"} |~ "OOMKill|oom-kill|memory cgroup out of memory"'
    loki_query "$kubelet_query" | jq -r '.data.result[] | "\(.stream.namespace // "unknown")|\(.stream.pod // "unknown")|\(.values[][1])"' > "$TMP_DIR/loki_kubelet_oom.txt" 2>/dev/null || true

    # Query 3: Container last logs before OOM (for pods we know had OOM)
    # This will be populated after we know which pods had OOM

    local kernel_count=$(wc -l < "$TMP_DIR/loki_kernel_oom.txt" 2>/dev/null || echo "0")
    local kubelet_count=$(wc -l < "$TMP_DIR/loki_kubelet_oom.txt" 2>/dev/null || echo "0")

    log_ok "Loki OOM events: kernel=$kernel_count, kubelet=$kubelet_count"
}

# ==============================================================================
# Data Collection Functions
# ==============================================================================

collect_nodes_data() {
    log_info "Collecting nodes data..."

    kubectl --context="$CONTEXT" get nodes -o json > "$TMP_DIR/nodes.json"
    kubectl --context="$CONTEXT" top nodes --no-headers 2>/dev/null > "$TMP_DIR/nodes_top.txt" || true
    kubectl --context="$CONTEXT" describe nodes > "$TMP_DIR/nodes_describe.txt"
}

collect_pods_data() {
    log_info "Collecting pods data..."

    local ns_flag=""
    [[ -n "$NAMESPACE" ]] && ns_flag="-n $NAMESPACE" || ns_flag="-A"

    kubectl --context="$CONTEXT" get pods $ns_flag -o json > "$TMP_DIR/pods.json"
    kubectl --context="$CONTEXT" top pods $ns_flag --no-headers 2>/dev/null > "$TMP_DIR/pods_top.txt" || true

    if [[ "$USE_PROMETHEUS" == true ]]; then
        collect_prometheus_cpu_stats
        collect_prometheus_memory_stats
        collect_prometheus_requests
    fi
}

collect_karpenter_data() {
    log_info "Collecting Karpenter data..."

    kubectl --context="$CONTEXT" get nodepools -o json 2>/dev/null > "$TMP_DIR/nodepools.json" || echo '{"items":[]}' > "$TMP_DIR/nodepools.json"
    kubectl --context="$CONTEXT" get nodeclaims -o json 2>/dev/null > "$TMP_DIR/nodeclaims.json" || echo '{"items":[]}' > "$TMP_DIR/nodeclaims.json"
    kubectl --context="$CONTEXT" get events -A --field-selector reason=Unconsolidatable -o json 2>/dev/null > "$TMP_DIR/karpenter_events.json" || echo '{"items":[]}' > "$TMP_DIR/karpenter_events.json"
}

collect_oom_data() {
    log_info "Collecting OOM data..."

    local ns_flag=""
    [[ -n "$NAMESPACE" ]] && ns_flag="-n $NAMESPACE" || ns_flag="-A"

    # OOM events from kubectl (last N hours via --since if supported, otherwise all)
    kubectl --context="$CONTEXT" get events $ns_flag \
        --field-selector reason=OOMKilling \
        -o json 2>/dev/null > "$TMP_DIR/oom_events.json" || echo '{"items":[]}' > "$TMP_DIR/oom_events.json"

    # Also get OOMKilled reason events
    kubectl --context="$CONTEXT" get events $ns_flag \
        --field-selector reason=OOMKilled \
        -o json 2>/dev/null > "$TMP_DIR/oom_killed_events.json" || echo '{"items":[]}' > "$TMP_DIR/oom_killed_events.json"

    # Extract pods with OOMKilled from pods.json (already collected)
    jq -r '.items[] |
        select(.status.containerStatuses[]?.lastState.terminated.reason == "OOMKilled" or
               .status.containerStatuses[]?.state.terminated.reason == "OOMKilled") |
        "\(.metadata.namespace)|\(.metadata.name)|\(.status.containerStatuses[].name)|\(.status.containerStatuses[].restartCount)|\(.status.containerStatuses[].lastState.terminated.finishedAt // .status.containerStatuses[].state.terminated.finishedAt // "unknown")"
    ' "$TMP_DIR/pods.json" 2>/dev/null | sort -u > "$TMP_DIR/oom_killed_pods.txt" || true

    # Prometheus OOM metrics if enabled
    if [[ "$USE_PROMETHEUS" == true && -n "$PROMETHEUS_POD" ]]; then
        log_info "Collecting OOM metrics from Prometheus..."

        # Total OOM events counter
        local oom_total_query="sum by (namespace, pod, container) (increase(container_oom_events_total[${PROMETHEUS_PERIOD}]))"
        prometheus_query "$oom_total_query" | jq -r '.data.result[] | "\(.metric.namespace)|\(.metric.pod)|\(.metric.container)|\(.value[1])"' > "$TMP_DIR/prom_oom_total.txt" 2>/dev/null || true

        # Memory usage vs limits for risk assessment
        local mem_usage_query="sum by (namespace, pod, container) (container_memory_working_set_bytes{image!=\"\"})"
        local mem_limit_query="sum by (namespace, pod, container) (container_spec_memory_limit_bytes{image!=\"\"} > 0)"

        prometheus_query "$mem_usage_query" | jq -r '.data.result[] | "\(.metric.namespace)|\(.metric.pod)|\(.metric.container)|\(.value[1])"' > "$TMP_DIR/prom_mem_usage.txt" 2>/dev/null || true
        prometheus_query "$mem_limit_query" | jq -r '.data.result[] | "\(.metric.namespace)|\(.metric.pod)|\(.metric.container)|\(.value[1])"' > "$TMP_DIR/prom_mem_limit.txt" 2>/dev/null || true

        log_ok "Prometheus OOM metrics collected"
    fi

    # Loki OOM logs if enabled
    [[ "$USE_LOKI" == true ]] && collect_loki_oom_events

    log_ok "OOM data collection complete"
}

# ==============================================================================
# Analysis Functions
# ==============================================================================

analyze_nodes() {
    echo ""
    echo -e "${BOLD}+==============================================================================+${NC}"
    echo -e "${BOLD}|                           1. NODES UTILIZATION                               |${NC}"
    echo -e "${BOLD}+==============================================================================+${NC}"
    echo ""

    printf "%-20s %-10s %-8s %-10s %-10s %-10s %-10s %-8s\n" \
        "NODE" "TYPE" "POOL" "CPU_USED" "CPU_ALLOC" "MEM_USED" "MEM_ALLOC" "STATUS"
    printf "%s\n" "--------------------------------------------------------------------------------"

    local total_cpu_used=0
    local total_cpu_alloc=0
    local total_mem_used=0
    local total_mem_alloc=0
    local node_count=0
    local low_util_nodes=0

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        local node=$(echo "$line" | awk '{print $1}')
        local cpu_used=$(echo "$line" | awk '{print $2}')
        local cpu_pct=$(echo "$line" | awk '{print $3}' | tr -d '%')
        local mem_used=$(echo "$line" | awk '{print $4}')
        local mem_pct=$(echo "$line" | awk '{print $5}' | tr -d '%')

        local node_type=$(jq -r --arg n "$node" '.items[] | select(.metadata.name==$n) | .metadata.labels["karpenter.sh/capacity-type"] // "static"' "$TMP_DIR/nodes.json")
        local node_pool=$(jq -r --arg n "$node" '.items[] | select(.metadata.name==$n) | .metadata.labels["karpenter.sh/nodepool"] // "system"' "$TMP_DIR/nodes.json")

        local cpu_alloc_pct=$(awk -v node="$node" '
            /^Name:/ && $2 ~ node { found=1 }
            found && /Allocated resources:/ { alloc=1 }
            found && alloc && /cpu/ && !/Requests/ { gsub(/[()%]/,"",$3); print $3; exit }
        ' "$TMP_DIR/nodes_describe.txt" || echo "0")
        local mem_alloc_pct=$(awk -v node="$node" '
            /^Name:/ && $2 ~ node { found=1 }
            found && /Allocated resources:/ { alloc=1 }
            found && alloc && /memory/ && !/Requests/ { gsub(/[()%]/,"",$3); print $3; exit }
        ' "$TMP_DIR/nodes_describe.txt" || echo "0")

        local status="OK"
        if (( cpu_pct < NODE_UTILIZATION_LOW && mem_pct < NODE_UTILIZATION_LOW )); then
            status="${RED}LOW${NC}"
            ((++low_util_nodes)) || true
        elif (( cpu_pct > 85 || mem_pct > 85 )); then
            status="${YELLOW}HIGH${NC}"
        else
            status="${GREEN}OK${NC}"
        fi

        local cpu_color=""
        local mem_color=""
        [[ $cpu_pct -lt $NODE_UTILIZATION_LOW ]] && cpu_color="$RED" || { [[ $cpu_pct -lt $NODE_UTILIZATION_TARGET ]] && cpu_color="$YELLOW" || cpu_color="$GREEN"; }
        [[ $mem_pct -lt $NODE_UTILIZATION_LOW ]] && mem_color="$RED" || { [[ $mem_pct -lt $NODE_UTILIZATION_TARGET ]] && mem_color="$YELLOW" || mem_color="$GREEN"; }

        printf "%-20s %-10s %-8s ${cpu_color}%3d%%${NC}       %-10s ${mem_color}%3d%%${NC}       %-10s %b\n" \
            "${node:0:20}" "$node_type" "$node_pool" \
            "$cpu_pct" "${cpu_alloc_pct}%" \
            "$mem_pct" "${mem_alloc_pct}%" \
            "$status"

        total_cpu_used=$((total_cpu_used + cpu_pct))
        total_mem_used=$((total_mem_used + mem_pct))
        ((++node_count))

    done < "$TMP_DIR/nodes_top.txt"

    echo ""
    echo -e "${BOLD}Summary:${NC}"
    if (( node_count > 0 )); then
        local avg_cpu=$((total_cpu_used / node_count))
        local avg_mem=$((total_mem_used / node_count))
        echo "  Total nodes: $node_count"
        echo -e "  Average CPU utilization: $(colorize_percent $avg_cpu)"
        echo -e "  Average MEM utilization: $(colorize_percent $avg_mem)"
        echo "  Low utilization nodes (<${NODE_UTILIZATION_LOW}%): $low_util_nodes"

        if (( low_util_nodes > 0 )); then
            echo -e "  ${YELLOW}Warning: $low_util_nodes node(s) are candidates for consolidation${NC}"
        fi
    fi
}

analyze_workloads() {
    echo ""
    echo -e "${BOLD}+==============================================================================+${NC}"
    echo -e "${BOLD}|                        2. WORKLOADS EFFICIENCY                               |${NC}"
    echo -e "${BOLD}+==============================================================================+${NC}"
    echo ""

    echo -e "${CYAN}Top Over-provisioned Workloads (CPU):${NC}"
    printf "%-12s %-40s %-10s %-10s %-10s\n" "NAMESPACE" "POD" "CPU_REQ" "CPU_USED" "EFFICIENCY"
    printf "%s\n" "--------------------------------------------------------------------------------"

    local inefficient_pods=()

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        local ns=$(echo "$line" | awk '{print $1}')
        local pod=$(echo "$line" | awk '{print $2}')
        local cpu_used=$(echo "$line" | awk '{print $3}')
        local mem_used=$(echo "$line" | awk '{print $4}')

        local cpu_req=$(jq -r --arg ns "$ns" --arg pod "$pod" \
            '.items[] | select(.metadata.namespace==$ns and .metadata.name==$pod) | .spec.containers[0].resources.requests.cpu // "0"' \
            $TMP_DIR/pods.json)

        local cpu_used_m=$(parse_cpu "$cpu_used")
        local cpu_req_m=$(parse_cpu "$cpu_req")

        if (( cpu_req_m > 0 )); then
            local efficiency=$((cpu_used_m * 100 / cpu_req_m))

            if (( efficiency < CPU_EFFICIENCY_WARNING )); then
                inefficient_pods+=("$efficiency|$ns|$pod|$cpu_req|$cpu_used")
            fi
        fi
    done < $TMP_DIR/pods_top.txt

    printf '%s\n' "${inefficient_pods[@]}" | sort -t'|' -k1 -n | head -10 | while IFS='|' read -r eff ns pod req used; do
        local color="$GREEN"
        (( eff < CPU_EFFICIENCY_CRITICAL )) && color="$RED"
        (( eff >= CPU_EFFICIENCY_CRITICAL && eff < CPU_EFFICIENCY_WARNING )) && color="$YELLOW"

        printf "%-12s %-40s %-10s %-10s ${color}%-10s${NC}\n" \
            "${ns:0:12}" "${pod:0:40}" "$req" "$used" "${eff}%"
    done

    echo ""
    echo -e "${CYAN}Top Over-provisioned Workloads (Memory):${NC}"
    printf "%-12s %-40s %-10s %-10s %-10s\n" "NAMESPACE" "POD" "MEM_REQ" "MEM_USED" "EFFICIENCY"
    printf "%s\n" "--------------------------------------------------------------------------------"

    local inefficient_mem_pods=()

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        local ns=$(echo "$line" | awk '{print $1}')
        local pod=$(echo "$line" | awk '{print $2}')
        local mem_used=$(echo "$line" | awk '{print $4}')

        local mem_req=$(jq -r --arg ns "$ns" --arg pod "$pod" \
            '.items[] | select(.metadata.namespace==$ns and .metadata.name==$pod) | .spec.containers[0].resources.requests.memory // "0"' \
            $TMP_DIR/pods.json)

        local mem_used_m=$(parse_memory "$mem_used")
        local mem_req_m=$(parse_memory "$mem_req")

        if (( mem_req_m > 0 )); then
            local efficiency=$((mem_used_m * 100 / mem_req_m))

            if (( efficiency < MEM_EFFICIENCY_WARNING )); then
                inefficient_mem_pods+=("$efficiency|$ns|$pod|$mem_req|$mem_used")
            fi
        fi
    done < $TMP_DIR/pods_top.txt

    printf '%s\n' "${inefficient_mem_pods[@]}" | sort -t'|' -k1 -n | head -10 | while IFS='|' read -r eff ns pod req used; do
        local color="$GREEN"
        (( eff < MEM_EFFICIENCY_CRITICAL )) && color="$RED"
        (( eff >= MEM_EFFICIENCY_CRITICAL && eff < MEM_EFFICIENCY_WARNING )) && color="$YELLOW"

        printf "%-12s %-40s %-10s %-10s ${color}%-10s${NC}\n" \
            "${ns:0:12}" "${pod:0:40}" "$req" "$used" "${eff}%"
    done
}

analyze_oom() {
    echo ""
    echo -e "${BOLD}+==============================================================================+${NC}"
    echo -e "${BOLD}|                            3. OOM ANALYSIS                                   |${NC}"
    echo -e "${BOLD}+==============================================================================+${NC}"
    echo ""

    local total_oom_pods=0
    local total_at_risk=0
    local affected_namespaces=()

    # Section 1: Recent OOMKilled Pods
    echo -e "${CYAN}Recent OOMKilled Pods:${NC}"
    printf "%-15s %-35s %-15s %-10s %-20s\n" "NAMESPACE" "POD" "CONTAINER" "RESTARTS" "LAST_OOM"
    printf "%s\n" "--------------------------------------------------------------------------------"

    if [[ -s "$TMP_DIR/oom_killed_pods.txt" ]]; then
        while IFS='|' read -r ns pod container restarts last_oom; do
            [[ -z "$ns" ]] && continue
            printf "%-15s %-35s %-15s %-10s %-20s\n" \
                "${ns:0:15}" "${pod:0:35}" "${container:0:15}" "$restarts" "${last_oom:0:20}"
            ((++total_oom_pods)) || true
            if [[ ! " ${affected_namespaces[*]} " =~ " ${ns} " ]]; then
                affected_namespaces+=("$ns")
            fi
        done < "$TMP_DIR/oom_killed_pods.txt"
    else
        echo -e "  ${GREEN}No OOMKilled pods found${NC}"
    fi

    # Section 2: OOM Events
    echo ""
    echo -e "${CYAN}OOMKilling Events (from kubectl events):${NC}"

    local oom_events=$(jq -r '.items[] | "\(.involvedObject.namespace)/\(.involvedObject.name): \(.message)"' "$TMP_DIR/oom_events.json" 2>/dev/null | sort | uniq -c | sort -rn | head -10)
    local oom_killed_events=$(jq -r '.items[] | "\(.involvedObject.namespace)/\(.involvedObject.name): \(.message)"' "$TMP_DIR/oom_killed_events.json" 2>/dev/null | sort | uniq -c | sort -rn | head -10)

    if [[ -n "$oom_events" || -n "$oom_killed_events" ]]; then
        [[ -n "$oom_events" ]] && echo "$oom_events" | while read -r count msg; do
            echo -e "  ${RED}[$count]${NC} $msg"
        done
        [[ -n "$oom_killed_events" ]] && echo "$oom_killed_events" | while read -r count msg; do
            echo -e "  ${RED}[$count]${NC} $msg"
        done
    else
        echo -e "  ${GREEN}No OOM events found${NC}"
    fi

    # Section 3: Prometheus OOM data (if available)
    if [[ "$USE_PROMETHEUS" == true && -s "$TMP_DIR/prom_oom_total.txt" ]]; then
        echo ""
        echo -e "${CYAN}OOM Events from Prometheus (last ${PROMETHEUS_PERIOD}):${NC}"
        printf "%-15s %-35s %-15s %-10s\n" "NAMESPACE" "POD" "CONTAINER" "OOM_COUNT"
        printf "%s\n" "--------------------------------------------------------------------------------"

        sort -t'|' -k4 -rn "$TMP_DIR/prom_oom_total.txt" | head -10 | while IFS='|' read -r ns pod container count; do
            local count_int=$(printf "%.0f" "$count" 2>/dev/null || echo "0")
            if (( count_int > 0 )); then
                printf "%-15s %-35s %-15s ${RED}%-10s${NC}\n" \
                    "${ns:0:15}" "${pod:0:35}" "${container:0:15}" "$count_int"
            fi
        done
    fi

    # Section 4: Memory Pressure (at risk)
    echo ""
    echo -e "${CYAN}Memory Pressure (>${OOM_MEMORY_RISK_THRESHOLD}% of limit = at risk):${NC}"
    printf "%-15s %-35s %-15s %-10s %-10s %-8s\n" "NAMESPACE" "POD" "CONTAINER" "USAGE" "LIMIT" "%"
    printf "%s\n" "--------------------------------------------------------------------------------"

    local at_risk_found=false

    if [[ "$USE_PROMETHEUS" == true && -s "$TMP_DIR/prom_mem_usage.txt" && -s "$TMP_DIR/prom_mem_limit.txt" ]]; then
        # Use Prometheus data
        while IFS='|' read -r ns pod container usage_bytes; do
            [[ -z "$ns" ]] && continue
            local limit_bytes=$(grep "^$ns|$pod|$container|" "$TMP_DIR/prom_mem_limit.txt" 2>/dev/null | cut -d'|' -f4 | head -1)
            [[ -z "$limit_bytes" || "$limit_bytes" == "0" ]] && continue

            local usage_mi=$(printf "%.0f" "$(echo "$usage_bytes / 1024 / 1024" | bc -l 2>/dev/null)" 2>/dev/null || echo "0")
            local limit_mi=$(printf "%.0f" "$(echo "$limit_bytes / 1024 / 1024" | bc -l 2>/dev/null)" 2>/dev/null || echo "0")

            if (( limit_mi > 0 )); then
                local pct=$((usage_mi * 100 / limit_mi))
                if (( pct >= OOM_MEMORY_RISK_THRESHOLD )); then
                    local color="$YELLOW"
                    (( pct >= 90 )) && color="$RED"
                    printf "%-15s %-35s %-15s %-10s %-10s ${color}%-8s${NC}\n" \
                        "${ns:0:15}" "${pod:0:35}" "${container:0:15}" "${usage_mi}Mi" "${limit_mi}Mi" "${pct}%"
                    ((++total_at_risk)) || true
                    at_risk_found=true
                fi
            fi
        done < "$TMP_DIR/prom_mem_usage.txt"
    else
        # Use kubectl data (pods.json + pods_top.txt)
        while IFS= read -r line; do
            [[ -z "$line" ]] && continue
            local ns=$(echo "$line" | awk '{print $1}')
            local pod=$(echo "$line" | awk '{print $2}')
            local mem_used=$(echo "$line" | awk '{print $4}')

            # Get memory limit from pods.json
            local mem_limit=$(jq -r --arg ns "$ns" --arg pod "$pod" \
                '.items[] | select(.metadata.namespace==$ns and .metadata.name==$pod) | .spec.containers[0].resources.limits.memory // "0"' \
                "$TMP_DIR/pods.json" 2>/dev/null)

            [[ -z "$mem_limit" || "$mem_limit" == "0" || "$mem_limit" == "null" ]] && continue

            local usage_mi=$(parse_memory "$mem_used")
            local limit_mi=$(parse_memory "$mem_limit")

            if (( limit_mi > 0 )); then
                local pct=$((usage_mi * 100 / limit_mi))
                if (( pct >= OOM_MEMORY_RISK_THRESHOLD )); then
                    local color="$YELLOW"
                    (( pct >= 90 )) && color="$RED"
                    printf "%-15s %-35s %-15s %-10s %-10s ${color}%-8s${NC}\n" \
                        "${ns:0:15}" "${pod:0:35}" "-" "${usage_mi}Mi" "${limit_mi}Mi" "${pct}%"
                    ((++total_at_risk)) || true
                    at_risk_found=true
                fi
            fi
        done < "$TMP_DIR/pods_top.txt"
    fi

    if [[ "$at_risk_found" == false ]]; then
        echo -e "  ${GREEN}No pods at memory risk${NC}"
    fi

    # Section 5: Loki OOM logs (if available)
    if [[ "$USE_LOKI" == true ]]; then
        echo ""
        echo -e "${CYAN}OOM Logs from Loki (last ${OOM_EVENTS_HOURS}h):${NC}"

        if [[ -s "$TMP_DIR/loki_kernel_oom.txt" ]]; then
            echo -e "${YELLOW}Kernel OOM killer events:${NC}"
            head -5 "$TMP_DIR/loki_kernel_oom.txt" | while read -r logline; do
                echo "  $logline" | head -c 100
                echo "..."
            done
            local kernel_total=$(wc -l < "$TMP_DIR/loki_kernel_oom.txt")
            (( kernel_total > 5 )) && echo "  ... and $((kernel_total - 5)) more"
        fi

        if [[ -s "$TMP_DIR/loki_kubelet_oom.txt" ]]; then
            echo -e "${YELLOW}Kubelet OOM events:${NC}"
            head -5 "$TMP_DIR/loki_kubelet_oom.txt" | while IFS='|' read -r ns pod logline; do
                echo "  [$ns/$pod] ${logline:0:80}..."
            done
            local kubelet_total=$(wc -l < "$TMP_DIR/loki_kubelet_oom.txt")
            (( kubelet_total > 5 )) && echo "  ... and $((kubelet_total - 5)) more"
        fi

        if [[ ! -s "$TMP_DIR/loki_kernel_oom.txt" && ! -s "$TMP_DIR/loki_kubelet_oom.txt" ]]; then
            echo -e "  ${GREEN}No OOM logs found in Loki${NC}"
        fi
    fi

    # Summary
    echo ""
    echo -e "${BOLD}Summary:${NC}"
    echo "  OOMKilled pods: $total_oom_pods"
    echo "  Pods at risk (>${OOM_MEMORY_RISK_THRESHOLD}% memory): $total_at_risk"
    echo "  Affected namespaces: ${affected_namespaces[*]:-none}"

    if (( total_oom_pods > 0 || total_at_risk > 0 )); then
        echo ""
        echo -e "  ${YELLOW}Recommendations:${NC}"
        (( total_oom_pods > 0 )) && echo -e "  ${RED}→ Review and increase memory limits for OOMKilled workloads${NC}"
        (( total_at_risk > 0 )) && echo -e "  ${YELLOW}→ Monitor at-risk pods; consider increasing limits preemptively${NC}"
        echo "  → Use --prometheus for historical memory usage analysis"
        [[ "$USE_LOKI" != true ]] && echo "  → Use --loki for detailed OOM log analysis"
    fi
}

analyze_karpenter() {
    echo ""
    echo -e "${BOLD}+==============================================================================+${NC}"
    echo -e "${BOLD}|                        4. KARPENTER CONSOLIDATION                            |${NC}"
    echo -e "${BOLD}+==============================================================================+${NC}"
    echo ""

    echo -e "${CYAN}NodePools:${NC}"
    printf "%-15s %-12s %-10s %-15s %-20s\n" "NAME" "POLICY" "AFTER" "CPU_LIMIT" "STATUS"
    printf "%s\n" "--------------------------------------------------------------------------------"

    jq -r '.items[] | "\(.metadata.name)|\(.spec.disruption.consolidationPolicy // "N/A")|\(.spec.disruption.consolidateAfter // "N/A")|\(.spec.limits.cpu // "unlimited")|\(.status.conditions[-1].reason // "Unknown")"' \
        $TMP_DIR/nodepools.json | while IFS='|' read -r name policy after limit status; do
        printf "%-15s %-12s %-10s %-15s %-20s\n" "$name" "$policy" "$after" "$limit" "$status"
    done

    echo ""
    echo -e "${CYAN}NodeClaims (Karpenter-managed nodes):${NC}"
    printf "%-20s %-15s %-12s %-10s %-10s\n" "NAME" "INSTANCE_TYPE" "CAPACITY" "POOL" "AGE"
    printf "%s\n" "--------------------------------------------------------------------------------"

    jq -r '.items[] | "\(.metadata.name)|\(.status.instanceType // "pending")|\(.status.capacity.cpu // "?")|\(.metadata.labels["karpenter.sh/nodepool"] // "?")|\(.metadata.creationTimestamp)"' \
        $TMP_DIR/nodeclaims.json | while IFS='|' read -r name type cap pool created; do
        local age="?"
        if [[ "$created" != "null" ]]; then
            local created_ts=$(date -d "$created" +%s 2>/dev/null || echo "0")
            local now_ts=$(date +%s)
            local age_s=$((now_ts - created_ts))
            if (( age_s < 3600 )); then
                age="$((age_s / 60))m"
            elif (( age_s < 86400 )); then
                age="$((age_s / 3600))h"
            else
                age="$((age_s / 86400))d"
            fi
        fi
        printf "%-20s %-15s %-12s %-10s %-10s\n" "${name:0:20}" "$type" "$cap" "$pool" "$age"
    done

    echo ""
    echo -e "${CYAN}Consolidation Blockers (recent events):${NC}"

    local blockers=$(jq -r '.items[] | select(.reason=="Unconsolidatable") | "\(.involvedObject.name): \(.message)"' $TMP_DIR/karpenter_events.json | sort | uniq -c | sort -rn | head -10)

    if [[ -n "$blockers" ]]; then
        echo "$blockers" | while read -r count msg; do
            echo -e "  ${YELLOW}[$count]${NC} $msg"
        done
    else
        echo -e "  ${GREEN}No consolidation blockers found${NC}"
    fi
}

generate_recommendations() {
    echo ""
    echo -e "${BOLD}+==============================================================================+${NC}"
    echo -e "${BOLD}|                           5. RECOMMENDATIONS                                 |${NC}"
    echo -e "${BOLD}+==============================================================================+${NC}"
    echo ""

    if [[ "$USE_PROMETHEUS" == true ]]; then
        echo -e "${CYAN}Data source: Prometheus (historical data over $PROMETHEUS_PERIOD)${NC}"
    else
        echo -e "${YELLOW}Data source: kubectl top (instant snapshot)${NC}"
        echo -e "${YELLOW}Tip: Use --prometheus for historical analysis (more accurate)${NC}"
    fi
    echo ""

    local rec_count=0
    local recommendations=()

    declare -A workload_cpu_req
    declare -A workload_cpu_max
    declare -A workload_cpu_p95
    declare -A workload_cpu_sum
    declare -A workload_pod_count
    declare -A workload_kind

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        local ns=$(echo "$line" | awk '{print $1}')
        local pod=$(echo "$line" | awk '{print $2}')
        local cpu_used=$(echo "$line" | awk '{print $3}')

        local cpu_req=$(jq -r --arg ns "$ns" --arg pod "$pod" \
            '.items[] | select(.metadata.namespace==$ns and .metadata.name==$pod) | .spec.containers[0].resources.requests.cpu // "0"' \
            "$TMP_DIR/pods.json")

        local cpu_used_m=$(parse_cpu "$cpu_used")
        local cpu_req_m=$(parse_cpu "$cpu_req")

        local cpu_max_historical=$cpu_used_m
        local cpu_p95_m=0
        if [[ "$USE_PROMETHEUS" == true ]]; then
            cpu_max_historical=$(get_prom_value "$TMP_DIR/prom_cpu_max.txt" "$ns" "$pod")
            cpu_p95_m=$(get_prom_value "$TMP_DIR/prom_cpu_p95.txt" "$ns" "$pod")
            local prom_req=$(get_prom_value "$TMP_DIR/prom_cpu_requests.txt" "$ns" "$pod")
            [[ "$prom_req" -gt 0 ]] && cpu_req_m=$prom_req
        fi

        if (( cpu_req_m > 100 && cpu_max_historical > 0 )); then
            local efficiency=$((cpu_max_historical * 100 / cpu_req_m))

            if (( efficiency < CPU_EFFICIENCY_WARNING )); then
                local owner=$(jq -r --arg ns "$ns" --arg pod "$pod" \
                    '.items[] | select(.metadata.namespace==$ns and .metadata.name==$pod) | .metadata.ownerReferences[0].name // "unknown"' \
                    "$TMP_DIR/pods.json")
                local owner_kind=$(jq -r --arg ns "$ns" --arg pod "$pod" \
                    '.items[] | select(.metadata.namespace==$ns and .metadata.name==$pod) | .metadata.ownerReferences[0].kind // "unknown"' \
                    "$TMP_DIR/pods.json")

                if [[ "$owner_kind" == "ReplicaSet" ]]; then
                    owner=$(echo "$owner" | sed 's/-[a-z0-9]\{5,10\}$//')
                    owner_kind="Deployment"
                fi

                local key="$ns/$owner"

                workload_cpu_req[$key]=$cpu_req_m
                workload_kind[$key]=$owner_kind

                local current_max=${workload_cpu_max[$key]:-0}
                if (( cpu_max_historical > current_max )); then
                    workload_cpu_max[$key]=$cpu_max_historical
                fi

                if [[ "$USE_PROMETHEUS" == true ]]; then
                    local current_p95=${workload_cpu_p95[$key]:-0}
                    if (( cpu_p95_m > current_p95 )); then
                        workload_cpu_p95[$key]=$cpu_p95_m
                    fi
                fi

                local current_sum=${workload_cpu_sum[$key]:-0}
                workload_cpu_sum[$key]=$((current_sum + cpu_used_m))

                local current_count=${workload_pod_count[$key]:-0}
                workload_pod_count[$key]=$((current_count + 1))
            fi
        fi
    done < "$TMP_DIR/pods_top.txt"

    for key in "${!workload_cpu_req[@]}"; do
        local cpu_req_m=${workload_cpu_req[$key]}
        local cpu_max_m=${workload_cpu_max[$key]}
        local cpu_p95_m=${workload_cpu_p95[$key]:-0}
        local cpu_sum_m=${workload_cpu_sum[$key]}
        local pod_count=${workload_pod_count[$key]}
        local kind=${workload_kind[$key]}

        local recommended
        if [[ "$USE_PROMETHEUS" == true && "$cpu_p95_m" -gt 0 ]]; then
            local p95_based=$((cpu_p95_m * 130 / 100))
            recommended=$(( cpu_max_m > p95_based ? cpu_max_m : p95_based ))
            recommended=$((recommended * 120 / 100))
        else
            recommended=$((cpu_max_m * 150 / 100))
        fi
        (( recommended < 50 )) && recommended=50

        local avg_usage=$((cpu_sum_m / pod_count))

        local source_info=""
        if [[ "$USE_PROMETHEUS" == true ]]; then
            source_info=" over ${PROMETHEUS_PERIOD}"
        fi

        if (( pod_count > 1 )); then
            if [[ "$USE_PROMETHEUS" == true && "$cpu_p95_m" -gt 0 ]]; then
                recommendations+=("[HIGH] $key ($kind, ${pod_count} pods): Reduce CPU request from ${cpu_req_m}m to ${recommended}m (max${source_info}: ${cpu_max_m}m, p95: ${cpu_p95_m}m)")
            else
                recommendations+=("[HIGH] $key ($kind, ${pod_count} pods): Reduce CPU request from ${cpu_req_m}m to ${recommended}m (max${source_info}: ${cpu_max_m}m, avg: ${avg_usage}m)")
            fi
        else
            recommendations+=("[HIGH] $key ($kind): Reduce CPU request from ${cpu_req_m}m to ${recommended}m (max${source_info}: ${cpu_max_m}m)")
        fi
        ((++rec_count)) || true
    done

    local spot_blocker=$(jq -r '.items[] | select(.message | contains("SpotToSpotConsolidation")) | .message' "$TMP_DIR/karpenter_events.json" | head -1)
    if [[ -n "$spot_blocker" ]]; then
        recommendations+=("[MEDIUM] Add more instance types to spot NodePool for Spot-to-Spot consolidation (need 15+)")
        ((++rec_count)) || true
    fi

    local cant_replace=$(jq -r '.items[] | select(.message | contains("Can'"'"'t replace with a cheaper node")) | .involvedObject.name' "$TMP_DIR/karpenter_events.json" | wc -l)
    if (( cant_replace > 0 )); then
        recommendations+=("[LOW] $cant_replace node(s) can't be replaced with cheaper options - consider diversifying instance types")
        ((++rec_count)) || true
    fi

    if (( rec_count > 0 )); then
        printf '%s\n' "${recommendations[@]}" | sort -t']' -k1 | while read -r rec; do
            if [[ "$rec" == "[HIGH]"* ]]; then
                echo -e "  ${RED}$rec${NC}"
            elif [[ "$rec" == "[MEDIUM]"* ]]; then
                echo -e "  ${YELLOW}$rec${NC}"
            else
                echo -e "  ${BLUE}$rec${NC}"
            fi
        done
    else
        echo -e "  ${GREEN}No critical recommendations at this time${NC}"
    fi

    echo ""
    echo "Total recommendations: $rec_count"
}

generate_yaml_recommendations() {
    echo ""
    echo -e "${BOLD}+==============================================================================+${NC}"
    echo -e "${BOLD}|                      6. YAML RECOMMENDATIONS                                 |${NC}"
    echo -e "${BOLD}+==============================================================================+${NC}"
    echo ""

    echo -e "${CYAN}Suggested resource changes (aggregated by workload):${NC}"
    if [[ "$USE_PROMETHEUS" == true ]]; then
        echo -e "${CYAN}Based on Prometheus historical data (${PROMETHEUS_PERIOD})${NC}"
    fi
    echo ""

    declare -A workload_cpu_req
    declare -A workload_mem_req
    declare -A workload_cpu_max
    declare -A workload_mem_max
    declare -A workload_kind
    declare -A workload_pod_count

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        local ns=$(echo "$line" | awk '{print $1}')
        local pod=$(echo "$line" | awk '{print $2}')
        local cpu_used=$(echo "$line" | awk '{print $3}')
        local mem_used=$(echo "$line" | awk '{print $4}')

        local cpu_req=$(jq -r --arg ns "$ns" --arg pod "$pod" \
            '.items[] | select(.metadata.namespace==$ns and .metadata.name==$pod) | .spec.containers[0].resources.requests.cpu // "0"' \
            "$TMP_DIR/pods.json")
        local mem_req=$(jq -r --arg ns "$ns" --arg pod "$pod" \
            '.items[] | select(.metadata.namespace==$ns and .metadata.name==$pod) | .spec.containers[0].resources.requests.memory // "0"' \
            "$TMP_DIR/pods.json")

        local cpu_used_m=$(parse_cpu "$cpu_used")
        local cpu_req_m=$(parse_cpu "$cpu_req")
        local mem_used_m=$(parse_memory "$mem_used")
        local mem_req_m=$(parse_memory "$mem_req")

        local cpu_max_historical=$cpu_used_m
        local mem_max_historical=$mem_used_m
        if [[ "$USE_PROMETHEUS" == true ]]; then
            cpu_max_historical=$(get_prom_value "$TMP_DIR/prom_cpu_max.txt" "$ns" "$pod")
            mem_max_historical=$(get_prom_value "$TMP_DIR/prom_mem_max.txt" "$ns" "$pod")
            [[ "$cpu_max_historical" -eq 0 ]] && cpu_max_historical=$cpu_used_m
            [[ "$mem_max_historical" -eq 0 ]] && mem_max_historical=$mem_used_m
            local prom_cpu_req=$(get_prom_value "$TMP_DIR/prom_cpu_requests.txt" "$ns" "$pod")
            local prom_mem_req=$(get_prom_value "$TMP_DIR/prom_mem_requests.txt" "$ns" "$pod")
            [[ "$prom_cpu_req" -gt 0 ]] && cpu_req_m=$prom_cpu_req
            [[ "$prom_mem_req" -gt 0 ]] && mem_req_m=$prom_mem_req
        fi

        if (( cpu_req_m > 100 && cpu_max_historical > 0 )); then
            local cpu_eff=$((cpu_max_historical * 100 / cpu_req_m))

            if (( cpu_eff < CPU_EFFICIENCY_WARNING )); then
                local owner=$(jq -r --arg ns "$ns" --arg pod "$pod" \
                    '.items[] | select(.metadata.namespace==$ns and .metadata.name==$pod) | .metadata.ownerReferences[0].name // "unknown"' \
                    "$TMP_DIR/pods.json")
                local owner_kind=$(jq -r --arg ns "$ns" --arg pod "$pod" \
                    '.items[] | select(.metadata.namespace==$ns and .metadata.name==$pod) | .metadata.ownerReferences[0].kind // "Deployment"' \
                    "$TMP_DIR/pods.json")

                if [[ "$owner_kind" == "ReplicaSet" ]]; then
                    owner=$(echo "$owner" | sed 's/-[a-z0-9]\{5,10\}$//')
                    owner_kind="Deployment"
                fi

                local key="$ns/$owner"

                workload_cpu_req[$key]=$cpu_req_m
                workload_mem_req[$key]=$mem_req_m
                workload_kind[$key]=$owner_kind

                local current_cpu_max=${workload_cpu_max[$key]:-0}
                if (( cpu_max_historical > current_cpu_max )); then
                    workload_cpu_max[$key]=$cpu_max_historical
                fi

                local current_mem_max=${workload_mem_max[$key]:-0}
                if (( mem_max_historical > current_mem_max )); then
                    workload_mem_max[$key]=$mem_max_historical
                fi

                local current_count=${workload_pod_count[$key]:-0}
                workload_pod_count[$key]=$((current_count + 1))
            fi
        fi
    done < "$TMP_DIR/pods_top.txt"

    local count=0
    for key in "${!workload_cpu_req[@]}"; do
        (( count >= 20 )) && break

        local cpu_req_m=${workload_cpu_req[$key]}
        local mem_req_m=${workload_mem_req[$key]}
        local cpu_max_m=${workload_cpu_max[$key]}
        local mem_max_m=${workload_mem_max[$key]}
        local kind=${workload_kind[$key]}
        local pod_count=${workload_pod_count[$key]}

        local cpu_buffer=150
        local mem_buffer=120
        if [[ "$USE_PROMETHEUS" == true ]]; then
            cpu_buffer=120
            mem_buffer=115
        fi

        local new_cpu=$((cpu_max_m * cpu_buffer / 100))
        (( new_cpu < 50 )) && new_cpu=50

        local new_mem=$((mem_max_m * mem_buffer / 100))
        (( new_mem < 128 )) && new_mem=128

        local source_info=""
        [[ "$USE_PROMETHEUS" == true ]] && source_info=" [${PROMETHEUS_PERIOD}]"

        echo "# $key ($kind, $pod_count pod(s))"
        echo "# CPU: ${cpu_req_m}m -> ${new_cpu}m (max usage${source_info}: ${cpu_max_m}m)"
        echo "# Memory: ${mem_req_m}Mi -> ${new_mem}Mi (max usage${source_info}: ${mem_max_m}Mi)"
        echo "resources:"
        echo "  requests:"
        echo "    cpu: ${new_cpu}m"
        echo "    memory: ${new_mem}Mi"
        echo ""

        ((++count))
    done

    if (( count == 0 )); then
        echo -e "  ${GREEN}No YAML recommendations at this time${NC}"
    fi
}

REPORT_TIMESTAMP=""
REPORT_FILE=""
JSON_FILE=""

prepare_report_files() {
    REPORT_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    REPORT_FILE="${LOGS_DIR}/cluster-efficiency_${REPORT_TIMESTAMP}.log"
    JSON_FILE="${LOGS_DIR}/cluster-efficiency_${REPORT_TIMESTAMP}.json"

    {
        echo "CLUSTER EFFICIENCY REPORT"
        echo "========================="
        echo "Date: $(date)"
        echo "Context: $CONTEXT"
        echo "Namespace filter: ${NAMESPACE:-all}"
        echo ""
    } > "$REPORT_FILE"
}

output_and_save() {
    if [[ "$SAVE_REPORT" == true && -n "$REPORT_FILE" ]]; then
        tee >(sed 's/\x1b\[[0-9;]*m//g' >> "$REPORT_FILE")
    else
        cat
    fi
}

save_json_summary() {
    [[ "$SAVE_REPORT" != true ]] && return

    local node_count=$(jq '.items | length' "$TMP_DIR/nodes.json")
    local pod_count=$(jq '.items | length' "$TMP_DIR/pods.json")
    local karpenter_nodes=$(jq '.items | length' "$TMP_DIR/nodeclaims.json")

    local avg_cpu=0
    local avg_mem=0
    local count=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local cpu_pct=$(echo "$line" | awk '{print $3}' | tr -d '%')
        local mem_pct=$(echo "$line" | awk '{print $5}' | tr -d '%')
        avg_cpu=$((avg_cpu + cpu_pct))
        avg_mem=$((avg_mem + mem_pct))
        ((++count)) || true
    done < "$TMP_DIR/nodes_top.txt"

    if (( count > 0 )); then
        avg_cpu=$((avg_cpu / count))
        avg_mem=$((avg_mem / count))
    fi

    local low_util_nodes=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local cpu_pct=$(echo "$line" | awk '{print $3}' | tr -d '%')
        local mem_pct=$(echo "$line" | awk '{print $5}' | tr -d '%')
        if (( cpu_pct < NODE_UTILIZATION_LOW && mem_pct < NODE_UTILIZATION_LOW )); then
            ((++low_util_nodes)) || true
        fi
    done < "$TMP_DIR/nodes_top.txt"

    cat > "$JSON_FILE" <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "context": "$CONTEXT",
  "namespace_filter": "${NAMESPACE:-all}",
  "node_count": $node_count,
  "pod_count": $pod_count,
  "karpenter_nodes": $karpenter_nodes,
  "avg_cpu_utilization": $avg_cpu,
  "avg_mem_utilization": $avg_mem,
  "low_utilization_nodes": $low_util_nodes,
  "thresholds": {
    "cpu_efficiency_warning": $CPU_EFFICIENCY_WARNING,
    "cpu_efficiency_critical": $CPU_EFFICIENCY_CRITICAL,
    "mem_efficiency_warning": $MEM_EFFICIENCY_WARNING,
    "mem_efficiency_critical": $MEM_EFFICIENCY_CRITICAL,
    "node_utilization_low": $NODE_UTILIZATION_LOW,
    "node_utilization_target": $NODE_UTILIZATION_TARGET
  }
}
EOF

    log_ok "Report saved: $REPORT_FILE"
    log_ok "JSON summary: $JSON_FILE"
}

compare_with_previous() {
    echo ""
    echo -e "${BOLD}+==============================================================================+${NC}"
    echo -e "${BOLD}|                      7. COMPARISON WITH PREVIOUS                             |${NC}"
    echo -e "${BOLD}+==============================================================================+${NC}"
    echo ""

    local json_files=($(ls -t "${LOGS_DIR}"/cluster-efficiency_*.json 2>/dev/null))
    local prev_json=""

    if [[ ${#json_files[@]} -lt 2 ]]; then
        if [[ ${#json_files[@]} -eq 1 && "${json_files[0]}" == "$JSON_FILE" ]]; then
            echo -e "  ${YELLOW}No previous report found for comparison (this is the first report)${NC}"
            return
        elif [[ ${#json_files[@]} -eq 1 ]]; then
            prev_json="${json_files[0]}"
        else
            echo -e "  ${YELLOW}No previous report found for comparison${NC}"
            return
        fi
    else
        if [[ "${json_files[0]}" == "$JSON_FILE" ]]; then
            prev_json="${json_files[1]}"
        else
            prev_json="${json_files[0]}"
        fi
    fi

    local prev_nodes=$(jq -r '.node_count // 0' "$prev_json")
    local prev_pods=$(jq -r '.pod_count // 0' "$prev_json")
    local prev_karpenter=$(jq -r '.karpenter_nodes // 0' "$prev_json")
    local prev_date=$(jq -r '.timestamp // "unknown"' "$prev_json")
    local prev_avg_cpu=$(jq -r '.avg_cpu_utilization // "N/A"' "$prev_json")
    local prev_avg_mem=$(jq -r '.avg_mem_utilization // "N/A"' "$prev_json")
    local prev_low_util=$(jq -r '.low_utilization_nodes // "N/A"' "$prev_json")

    local curr_nodes=$(jq '.items | length' "$TMP_DIR/nodes.json")
    local curr_pods=$(jq '.items | length' "$TMP_DIR/pods.json")
    local curr_karpenter=$(jq '.items | length' "$TMP_DIR/nodeclaims.json")

    local curr_avg_cpu=0
    local curr_avg_mem=0
    local count=0
    local curr_low_util=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        local cpu_pct=$(echo "$line" | awk '{print $3}' | tr -d '%')
        local mem_pct=$(echo "$line" | awk '{print $5}' | tr -d '%')
        curr_avg_cpu=$((curr_avg_cpu + cpu_pct))
        curr_avg_mem=$((curr_avg_mem + mem_pct))
        ((++count)) || true
        if (( cpu_pct < NODE_UTILIZATION_LOW && mem_pct < NODE_UTILIZATION_LOW )); then
            ((++curr_low_util)) || true
        fi
    done < "$TMP_DIR/nodes_top.txt"
    if (( count > 0 )); then
        curr_avg_cpu=$((curr_avg_cpu / count))
        curr_avg_mem=$((curr_avg_mem / count))
    fi

    echo "Previous report: $prev_date"
    echo "Comparing with: $(basename "$prev_json")"
    echo ""
    printf "%-25s %-15s %-15s %-15s\n" "METRIC" "PREVIOUS" "CURRENT" "CHANGE"
    printf "%s\n" "------------------------------------------------------------------------"

    local node_diff=$((curr_nodes - prev_nodes))
    local pod_diff=$((curr_pods - prev_pods))
    local karp_diff=$((curr_karpenter - prev_karpenter))

    printf "%-25s %-15s %-15s %-15s\n" "Total nodes" "$prev_nodes" "$curr_nodes" "$([[ $node_diff -ge 0 ]] && echo "+")$node_diff"
    printf "%-25s %-15s %-15s %-15s\n" "Total pods" "$prev_pods" "$curr_pods" "$([[ $pod_diff -ge 0 ]] && echo "+")$pod_diff"
    printf "%-25s %-15s %-15s %-15s\n" "Karpenter nodes" "$prev_karpenter" "$curr_karpenter" "$([[ $karp_diff -ge 0 ]] && echo "+")$karp_diff"

    if [[ "$prev_avg_cpu" != "N/A" ]]; then
        local cpu_diff=$((curr_avg_cpu - prev_avg_cpu))
        local mem_diff=$((curr_avg_mem - prev_avg_mem))
        local low_diff=$((curr_low_util - prev_low_util))

        printf "%-25s %-15s %-15s %-15s\n" "Avg CPU utilization" "${prev_avg_cpu}%" "${curr_avg_cpu}%" "$([[ $cpu_diff -ge 0 ]] && echo "+")${cpu_diff}%"
        printf "%-25s %-15s %-15s %-15s\n" "Avg MEM utilization" "${prev_avg_mem}%" "${curr_avg_mem}%" "$([[ $mem_diff -ge 0 ]] && echo "+")${mem_diff}%"
        printf "%-25s %-15s %-15s %-15s\n" "Low util nodes" "$prev_low_util" "$curr_low_util" "$([[ $low_diff -ge 0 ]] && echo "+")$low_diff"
    fi
}

# ==============================================================================
# Main
# ==============================================================================

main() {
    # Check dependencies first
    check_dependencies

    parse_args "$@"
    setup_temp_dir

    echo ""
    echo -e "${BOLD}+==============================================================================+${NC}"
    echo -e "${BOLD}|               CLUSTER EFFICIENCY ANALYZER v2.0 (Universal)                  |${NC}"
    echo -e "${BOLD}|               Context: $CONTEXT                                              ${NC}"
    echo -e "${BOLD}+==============================================================================+${NC}"
    echo ""
    echo "Date: $(date)"
    echo "Focus: $FOCUS"
    [[ -n "$NAMESPACE" ]] && echo "Namespace filter: $NAMESPACE"
    if [[ "$USE_PROMETHEUS" == true ]]; then
        echo -e "Data source: ${GREEN}Prometheus (historical, ${PROMETHEUS_PERIOD})${NC}"
    else
        echo "Data source: kubectl top (instant)"
    fi
    if [[ "$USE_LOKI" == true ]]; then
        echo -e "OOM logs: ${GREEN}Loki (last ${OOM_EVENTS_HOURS}h)${NC}"
    fi
    echo ""

    [[ "$USE_PROMETHEUS" == true ]] && init_prometheus
    [[ "$USE_LOKI" == true ]] && init_loki

    collect_nodes_data
    collect_pods_data
    collect_karpenter_data
    collect_oom_data

    [[ "$SAVE_REPORT" == true ]] && prepare_report_files

    case "$FOCUS" in
        all)
            analyze_nodes 2>&1 | output_and_save
            analyze_workloads 2>&1 | output_and_save
            analyze_oom 2>&1 | output_and_save
            analyze_karpenter 2>&1 | output_and_save
            generate_recommendations 2>&1 | output_and_save
            generate_yaml_recommendations 2>&1 | output_and_save
            ;;
        nodes)
            analyze_nodes 2>&1 | output_and_save
            ;;
        workloads)
            analyze_workloads 2>&1 | output_and_save
            analyze_oom 2>&1 | output_and_save
            generate_yaml_recommendations 2>&1 | output_and_save
            ;;
        oom)
            analyze_oom 2>&1 | output_and_save
            ;;
        karpenter)
            analyze_karpenter 2>&1 | output_and_save
            ;;
        cost)
            analyze_nodes 2>&1 | output_and_save
            generate_recommendations 2>&1 | output_and_save
            ;;
    esac

    [[ "$SAVE_REPORT" == true ]] && save_json_summary

    [[ "$COMPARE_PREV" == true ]] && compare_with_previous

    if [[ "$DEEP_ANALYSIS" == true ]]; then
        echo ""
        log_info "Deep analysis requested. Use Claude Code with /cluster-efficiency --deep for detailed agent-based analysis."
    fi

    echo ""
    log_ok "Analysis complete"
}

main "$@"
