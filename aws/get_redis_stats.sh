#!/usr/bin/env bash
# ElastiCache Valkey load stats (prod-us). Read-only.
# Auto-discovers ALL valkey nodes (new ones included automatically).
#
# Usage:
#   scripts/get_valkey_stats.sh [DAYS] [CLUSTER_ID]
#     DAYS        lookback window in days     (default: 7)
#     CLUSTER_ID  single node id to inspect   (default: all valkey nodes)
#   scripts/get_valkey_stats.sh list          # just list all valkey nodes (no metrics)
#
# Examples:
#   scripts/get_valkey_stats.sh
#   scripts/get_valkey_stats.sh 14
#   scripts/get_valkey_stats.sh 30 apigw-redis-0001-001
#   scripts/get_valkey_stats.sh list
#
# Note: node ids still carry the -redis suffix; the replication group id is the
# cluster identity and cannot be renamed without recreating the cluster.
set -euo pipefail

export AWS_PROFILE=sso-om-prod
export AWS_DEFAULT_REGION=us-east-1

# Both engines are matched so the script keeps working during a migration.
ENGINE_FILTER="Engine=='valkey' || Engine=='redis'"

if [ "${1:-}" = "list" ]; then
  aws elasticache describe-cache-clusters --show-cache-node-info \
    --query "CacheClusters[?${ENGINE_FILTER}].[CacheClusterId,Engine,EngineVersion]" \
    --output table
  exit 0
fi

DAYS="${1:-7}"
NODE_FILTER="${2:-}"

END=$(date -u +%Y-%m-%dT%H:%M:%S)
START=$(date -u -d "${DAYS} days ago" +%Y-%m-%dT%H:%M:%S)

stat() {  # $1=node $2=metric $3=stat
  aws cloudwatch get-metric-statistics --namespace AWS/ElastiCache --metric-name "$2" \
    --dimensions Name=CacheClusterId,Value="$1" \
    --start-time "$START" --end-time "$END" --period 3600 --statistics "$3" \
    --query "Datapoints[].$3" --output text 2>/dev/null
}

echo "window: last ${DAYS}d (${START}Z .. ${END}Z)  target: ${NODE_FILTER:-all valkey nodes}"
printf "%-34s %-7s %7s %7s %7s %7s %8s %8s %10s %9s\n" \
  NODE engine ver avgCPU maxCPU avgMem% maxMem% avgConn maxConn evictions

if [ -n "$NODE_FILTER" ]; then
  QUERY="CacheClusters[?CacheClusterId=='${NODE_FILTER}'].[CacheClusterId,Engine,EngineVersion]"
else
  QUERY="CacheClusters[?${ENGINE_FILTER}].[CacheClusterId,Engine,EngineVersion]"
fi

while IFS=$'\t' read -r node engine ver; do
  [ -z "$node" ] && continue
  acpu=$(stat "$node" EngineCPUUtilization Average          | tr '\t' '\n' | awk '{s+=$1;n++} END{if(n)printf "%.1f",s/n}')
  mcpu=$(stat "$node" EngineCPUUtilization Maximum          | tr '\t' '\n' | awk '{if($1>m)m=$1} END{printf "%.1f",m}')
  amem=$(stat "$node" DatabaseMemoryUsagePercentage Average | tr '\t' '\n' | awk '{s+=$1;n++} END{if(n)printf "%.1f",s/n}')
  mmem=$(stat "$node" DatabaseMemoryUsagePercentage Maximum | tr '\t' '\n' | awk '{if($1>m)m=$1} END{printf "%.1f",m}')
  acon=$(stat "$node" CurrConnections Average               | tr '\t' '\n' | awk '{s+=$1;n++} END{if(n)printf "%.1f",s/n}')
  mcon=$(stat "$node" CurrConnections Maximum               | tr '\t' '\n' | awk '{if($1>m)m=$1} END{printf "%.0f",m}')
  evic=$(stat "$node" Evictions Sum                         | tr '\t' '\n' | awk '{s+=$1} END{printf "%.0f",s}')
  printf "%-34s %-7s %7s %7s %7s %7s %8s %8s %10s %9s\n" \
    "$node" "$engine" "$ver" "${acpu:-0}" "${mcpu:-0}" "${amem:-0}" "${mmem:-0}" "${acon:-0}" "${mcon:-0}" "${evic:-0}"
done < <(aws elasticache describe-cache-clusters --show-cache-node-info --query "$QUERY" --output text | sort)

