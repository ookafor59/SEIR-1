#!/usr/bin/env bash
set -euo pipefail

#Chewbacca: If it’s real, it passes a gate.
VM_IP="${VM_IP:-}"
OUT_JSON="${OUT_JSON:-gate_result.json}"
BADGE="${BADGE:-badge.txt}"

if [[ -z "$VM_IP" ]]; then
  echo "ERROR: set VM_IP" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq not installed (needed for JSON validation)" >&2
  exit 1
fi

failures=()
details=()
add_fail(){ failures+=("$1"); }
add_ok(){ details+=("$1"); }

BASE="http://${VM_IP}"

code="$(curl -s -o /dev/null -w "%{http_code}" "$BASE" || echo "000")"
[[ "$code" == "200" ]] && add_ok "PASS: / returns 200" || add_fail "FAIL: / returns $code"

hz="$(curl -s "$BASE/healthz" || true)"
[[ "$hz" == "ok" ]] && add_ok "PASS: /healthz == ok" || add_fail "FAIL: /healthz not ok"

meta="$(curl -s "$BASE/metadata" || true)"
echo "$meta" | jq . >/dev/null 2>&1 && add_ok "PASS: /metadata valid JSON" || add_fail "FAIL: /metadata invalid JSON"

echo "$meta" | jq -e '.region' >/dev/null 2>&1 && add_ok "PASS: metadata has region" || add_fail "FAIL: metadata missing region"
echo "$meta" | jq -e '.network.vpc' >/dev/null 2>&1 && add_ok "PASS: metadata has VPC" || add_fail "FAIL: metadata missing VPC"
echo "$meta" | jq -e '.network.subnet' >/dev/null 2>&1 && add_ok "PASS: metadata has subnet" || add_fail "FAIL: metadata missing subnet"

status="PASS"; exit_code=0
if (( ${#failures[@]} > 0 )); then status="FAIL"; exit_code=2; fi

[[ "$status" == "PASS" ]] && echo "GREEN" > "$BADGE" || echo "RED" > "$BADGE"

details_json="$(printf '%s\n' "${details[@]}" | jq -R . | jq -s .)"
failures_json="$(printf '%s\n' "${failures[@]}" | jq -R . | jq -s .)"

cat > "$OUT_JSON" <<EOF
{
  "lab": "SEIR-I Lab 2 (Terraform)",
  "target": "$VM_IP",
  "status": "$status",
  "details": $details_json,
  "failures": $failures_json
}
EOF

echo "Lab 2 Gate: $status"
exit "$exit_code"
