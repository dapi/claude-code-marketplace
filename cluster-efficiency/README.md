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
/cluster-efficiency --context=production --save
/cluster-efficiency --namespace=production --focus=workloads
/cluster-efficiency --prometheus
```

With `--deep`, the command spawns parallel subagents for node, workload, Karpenter, and OOM analysis.

## Requirements

- `kubectl` configured with cluster access
- Prometheus/metrics-server (for utilization data)

## License

MIT
