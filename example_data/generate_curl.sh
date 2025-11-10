#!/bin/bash

# Script để tạo lệnh curl upload file .fkpb
# Usage: ./generate_curl.sh <file.fkpb> <portal-url> [token]

FILE="$1"
PORTAL_URL="$2"
TOKEN="$3"

if [ -z "$FILE" ] || [ -z "$PORTAL_URL" ]; then
    echo "Usage: $0 <file.fkpb> <portal-url> [token]"
    echo ""
    echo "Example:"
    echo "  $0 station1-small.fkpb https://api.fieldkit.org"
    echo "  $0 station1-small.fkpb https://api.fieldkit.org 'Bearer your-token-here'"
    exit 1
fi

if [ ! -f "$FILE" ]; then
    echo "Error: File not found: $FILE"
    exit 1
fi

# Extract metadata từ file
METADATA=$(cd .. && ./build/fkdata -file "example_data/$FILE" 2>&1)

DEVICE_ID=$(echo "$METADATA" | grep "DeviceId:" | sed 's/.*DeviceId: //')
GENERATION_ID=$(echo "$METADATA" | grep "GenerationId:" | sed 's/.*GenerationId: //')
DEVICE_NAME=$(echo "$METADATA" | grep "DeviceName:" | sed 's/.*DeviceName: //')
FIRST_RECORD=$(echo "$METADATA" | grep "FirstRecord:" | sed 's/.*FirstRecord: //')
LAST_RECORD=$(echo "$METADATA" | grep "LastRecord:" | sed 's/.*LastRecord: //')

if [ -z "$DEVICE_ID" ] || [ -z "$GENERATION_ID" ] || [ -z "$DEVICE_NAME" ]; then
    echo "Error: Could not extract metadata from file"
    echo "$METADATA"
    exit 1
fi

# Tạo lệnh curl
echo "# Upload file: $FILE"
echo "# DeviceId: $DEVICE_ID"
echo "# DeviceName: $DEVICE_NAME"
echo "# GenerationId: $GENERATION_ID"
echo "# Blocks: $FIRST_RECORD,$LAST_RECORD"
echo ""
echo "curl -X POST $PORTAL_URL/ingestion \\"
echo "  -H \"Content-Type: application/octet-stream\" \\"

if [ -n "$TOKEN" ]; then
    echo "  -H \"Authorization: $TOKEN\" \\"
else
    echo "  -H \"Authorization: \$TOKEN\" \\"
fi

echo "  -H \"Fk-DeviceId: $DEVICE_ID\" \\"
echo "  -H \"Fk-Generation: $GENERATION_ID\" \\"
echo "  -H \"Fk-DeviceName: $DEVICE_NAME\" \\"
echo "  -H \"Fk-Blocks: $FIRST_RECORD,$LAST_RECORD\" \\"
echo "  -H \"Fk-Type: data\" \\"
echo "  --data-binary @$FILE"

