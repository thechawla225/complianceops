#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "Building and starting the stack..."
docker compose up -d --build

cleanup() { echo "Tearing down..."; docker compose down -v; }
trap cleanup EXIT

#checking if Gateway service is workign fine in the image
echo "Waiting for the gateway to report healthy..."
status="starting"
for _ in $(seq 1 30); do
  status=$(docker inspect --format='{{.State.Health.Status}}' "$(docker compose ps -q gateway)" 2>/dev/null || echo "starting")
  [ "$status" = "healthy" ] && break
  sleep 2
done
if [ "$status" != "healthy" ]; then
  echo "gateway never became healthy" >&2
  docker compose logs
  exit 1
fi

#Posting the Tranaction
echo "Posting a transaction through the Gateway..."
resp=$(curl -sf -X POST http://localhost:8000/transactions \
  -H "x-api-key: dev-secret-key" -H "Content-Type: application/json" \
  -d '{
        "endToEndId": "REF-ROUNDTRIP",
        "debtor": {"name": "DebTor Company Ltd"},
        "creditor": {"name": "Example Trading Co"},
        "instructedAmount": {"amount": "1020.00", "currency": "USD"}
      }')
echo "$resp"

status_field=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['status'])" "$resp")
if [ "$status_field" != "clear" ]; then
  echo "expected status 'clear' , got '$status_field'" >&2
  exit 1
fi

txn_id=$(python3 -c "import json,sys; print(json.loads(sys.argv[1])['id'])" "$resp")
echo "Fetching it back by id ($txn_id)..."
curl -sf "http://localhost:8000/transactions/$txn_id" -H "x-api-key: dev-secret-key" | grep -q "$txn_id"

echo "Round trip OK — Gateway, Transaction Service, and Postgres are wired correctly."