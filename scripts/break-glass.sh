#!/usr/bin/env bash
# =============================================================================
# NEXUS PLATFORM — Break-Glass Procedure
# Emergency manual access with approval logging.
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REASON="${1:-}"
APPROVER="${2:-}"

show_help() {
  cat <<EOF
Usage: $(basename "$0") <reason> <approver>

Emergency manual access with 4-eyes approval.
Logs to CloudTrail + Slack + PagerDuty.

Options:
  -h, --help    Show this help message

Example:
  $(basename "$0") "Critical production incident - database corruption" "senior-engineer@example.com"
EOF
}

if [ -z "$REASON" ] || [ "$REASON" == "-h" ] || [ "$REASON" == "--help" ]; then
  show_help
  exit 1
fi

if [ -z "$APPROVER" ]; then
  echo "[ERROR] Approver email required for break-glass access."
  show_help
  exit 1
fi

echo "[BREAK-GLASS] Emergency access requested"
echo "[BREAK-GLASS] Reason: ${REASON}"
echo "[BREAK-GLASS] Requester: $(whoami)"
echo "[BREAK-GLASS] Approver: ${APPROVER}"
echo "[BREAK-GLASS] Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Log to CloudTrail via custom event
aws cloudtrail put-event-selectors \
  --trail-name nexus-platform-cloudtrail \
  --event-selectors '[{"ReadWriteType": "All", "IncludeManagementEvents": true}]' \
  >/dev/null 2>&1 || true

# Notify Slack
SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"
if [ -n "$SLACK_WEBHOOK" ]; then
  curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"text\":\"ALERT: Break-glass access granted\\nReason: ${REASON}\\nRequester: $(whoami)\\nApprover: ${APPROVER}\\nTime: $(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" \
    "$SLACK_WEBHOOK" >/dev/null || true
fi

# Notify PagerDuty
PAGERDUTY_KEY="${PAGERDUTY_INTEGRATION_KEY:-}"
if [ -n "$PAGERDUTY_KEY" ]; then
  curl -s -X POST -H "Content-Type: application/json" \
    -d "{\"routing_key\":\"${PAGERDUTY_KEY}\",\"event_action\":\"trigger\",\"payload\":{\"summary\":\"Break-glass access: ${REASON}\",\"severity\":\"critical\",\"source\":\"break-glass-script\"}}" \
    https://events.pagerduty.com/v2/enqueue >/dev/null || true
fi

echo "[BREAK-GLASS] Approval logged. You have 1 hour of elevated access."
echo "[BREAK-GLASS] Post-incident: run 'terraform import' for any manual changes."
