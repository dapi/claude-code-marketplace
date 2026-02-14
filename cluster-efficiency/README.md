# cluster-efficiency

Kubernetes cluster efficiency analysis plugin for Claude Code — resource utilization, Karpenter, OOM, workloads.

## Installation

```bash
/plugin install cluster-efficiency@dapi
```

## Components

### Command: /cluster-efficiency

Launch a comprehensive cluster analysis.

```
/cluster-efficiency
/cluster-efficiency --deep
```

### Skill: cluster-efficiency

Activates automatically when you ask about cluster resource efficiency.

### Agents

| Agent | Purpose |
|-------|---------|
| `cluster-efficiency-orchestrator` | Analysis orchestration |
| `cluster-node-analyzer` | Node efficiency analysis |
| `cluster-workload-analyzer` | Workload analysis (requests vs actual) |
| `cluster-karpenter-analyzer` | Karpenter consolidation and provisioning |
| `cluster-oom-analyzer` | OOM kill analysis |

## Usage

```
/cluster-efficiency
"analyze cluster efficiency"
"проанализируй эффективность кластера"
"find over-provisioned resources"
"почему ноды не консолидируются"
```

## Requirements

- `kubectl` configured with cluster access
- Prometheus/metrics-server (for utilization data)

## Documentation

See [skills/cluster-efficiency/SKILL.md](./skills/cluster-efficiency/SKILL.md)

## License

MIT
