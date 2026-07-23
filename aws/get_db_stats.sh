#!/usr/bin/env bash
# RDS PostgreSQL load + disk stats (prod-us). Read-only.
#
# Usage:
#   scripts/get_db_stats.sh [DAYS] [DB_NAME]
#     DAYS     lookback window in days           (default: 7)
#     DB_NAME  single instance to inspect        (default: all postgres instances)
#
# Examples:
#   scripts/get_db_stats.sh                 # all postgres, last 7 days
#   scripts/get_db_stats.sh 14              # all postgres, last 14 days
#   scripts/get_db_stats.sh 30 messages-db  # just messages-db, last 30 days
set -euo pipefail

export AWS_PROFILE=sso-om-prod
export AWS_DEFAULT_REGION=us-east-1

DAYS="${1:-7}"
DB_FILTER="${2:-}"

END=$(date -u +%Y-%m-%dT%H:%M:%S)
START=$(date -u -d "${DAYS} days ago" +%Y-%m-%dT%H:%M:%S)

stat() {  # $1=db $2=metric $3=stat
  aws cloudwatch get-metric-statistics --namespace AWS/RDS --metric-name "$2" \
    --dimensions Name=DBInstanceIdentifier,Value="$1" \
    --start-time "$START" --end-time "$END" --period 3600 --statistics "$3" \
    --query "Datapoints[].$3" --output text 2>/dev/null
}

echo "window: last ${DAYS}d (${START}Z .. ${END}Z)  target: ${DB_FILTER:-all postgres}"
printf "%-26s %5s %7s %7s %7s %7s %9s %7s %7s %7s\n" \
  DB ver avgCPU maxCPU avgConn maxConn avgWIOPS allocGB usedGB freeGB

# instance list: single DB if given, otherwise auto-discover all postgres
if [ -n "$DB_FILTER" ]; then
  QUERY="DBInstances[?DBInstanceIdentifier=='${DB_FILTER}'].[DBInstanceIdentifier,EngineVersion,AllocatedStorage]"
else
  QUERY="DBInstances[?Engine=='postgres'].[DBInstanceIdentifier,EngineVersion,AllocatedStorage]"
fi

while IFS=$'\t' read -r db ver alloc; do
  [ -z "$db" ] && continue
  acpu=$(stat "$db" CPUUtilization Average      | tr '\t' '\n' | awk '{s+=$1;n++} END{if(n)printf "%.1f",s/n}')
  mcpu=$(stat "$db" CPUUtilization Maximum      | tr '\t' '\n' | awk '{if($1>m)m=$1} END{printf "%.1f",m}')
  acon=$(stat "$db" DatabaseConnections Average | tr '\t' '\n' | awk '{s+=$1;n++} END{if(n)printf "%.1f",s/n}')
  mcon=$(stat "$db" DatabaseConnections Maximum | tr '\t' '\n' | awk '{if($1>m)m=$1} END{printf "%.0f",m}')
  awio=$(stat "$db" WriteIOPS Average           | tr '\t' '\n' | awk '{s+=$1;n++} END{if(n)printf "%.1f",s/n}')
  free=$(stat "$db" FreeStorageSpace Average    | tr '\t' '\n' | tail -1)
  freeg=$(awk -v f="${free:-0}" 'BEGIN{printf "%.1f", f/1073741824}')
  usedg=$(awk -v a="${alloc:-0}" -v f="${free:-0}" 'BEGIN{printf "%.1f", a - f/1073741824}')
  printf "%-26s %5s %7s %7s %7s %7s %9s %7s %7s %7s\n" \
    "$db" "$ver" "${acpu:-0}" "${mcpu:-0}" "${acon:-0}" "${mcon:-0}" "${awio:-0}" "${alloc:-0}" "$usedg" "$freeg"
done < <(aws rds describe-db-instances --query "$QUERY" --output text | sort)

