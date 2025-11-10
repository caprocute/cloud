#!/bin/bash

# Lệnh curl để upload file station1-small.fkpb
# Thay thế $TOKEN bằng token thực tế của bạn
# Thay thế URL bằng portal URL của bạn

TOKEN="Bearer your-token-here"
PORTAL_URL="https://api.fieldkit.org"
FILE="station1-small.fkpb"

curl -X POST ${PORTAL_URL}/ingestion \
  -H "Content-Type: application/octet-stream" \
  -H "Authorization: ${TOKEN}" \
  -H "Fk-DeviceId: 0123456789abcdef0123456789abcdef" \
  -H "Fk-Generation: f64c34338a1a0b6629617ae73c24fb1f9f2d5808" \
  -H "Fk-DeviceName: My Test Station" \
  -H "Fk-Blocks: 0,10" \
  -H "Fk-Type: data" \
  --data-binary @${FILE}

