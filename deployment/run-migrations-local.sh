#!/bin/bash

# Script để chạy database migrations từ máy local
# Kết nối trực tiếp đến database trên AWS
# Sử dụng: ./deployment/run-migrations-local.sh [ENVIRONMENT]
# Ví dụ: ./deployment/run-migrations-local.sh staging

set -e

ENVIRONMENT=${1:-staging}
AWS_REGION=${AWS_REGION:-ap-southeast-1}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-""}

# Xử lý AWS_PROFILE (optional)
if [ -n "$AWS_PROFILE" ]; then
    if ! aws configure list-profiles 2>/dev/null | grep -q "^${AWS_PROFILE}$"; then
        echo "⚠️  Warning: AWS_PROFILE '${AWS_PROFILE}' không tồn tại. Sử dụng default credentials."
        unset AWS_PROFILE
    else
        export AWS_PROFILE
    fi
fi

# Validate AWS_ACCOUNT_ID - Luôn lấy từ AWS credentials
DETECTED_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")

if [ -z "$DETECTED_ACCOUNT_ID" ]; then
    echo "Error: Không thể lấy AWS_ACCOUNT_ID từ AWS credentials."
    exit 1
fi

AWS_ACCOUNT_ID="$DETECTED_ACCOUNT_ID"

echo "=========================================="
echo "Running Database Migrations từ Local"
echo "=========================================="
echo "Environment: ${ENVIRONMENT}"
echo "AWS Region: ${AWS_REGION}"
echo "=========================================="
echo ""

# Kiểm tra Go đã được cài đặt
if ! command -v go &> /dev/null; then
    echo "❌ Go chưa được cài đặt."
    echo "   Cài đặt Go: https://golang.org/dl/"
    exit 1
fi

# Lấy connection strings từ Secrets Manager
echo "Đang lấy database connection strings từ AWS Secrets Manager..."

POSTGRES_SECRET_NAME="fieldkit/${ENVIRONMENT}/database/postgres"
TIMESCALE_SECRET_NAME="fieldkit/${ENVIRONMENT}/database/timescale"

POSTGRES_URL=$(aws secretsmanager get-secret-value \
    --secret-id ${POSTGRES_SECRET_NAME} \
    --region ${AWS_REGION} \
    --query 'SecretString' \
    --output text 2>/dev/null || echo "")

TIMESCALE_URL=$(aws secretsmanager get-secret-value \
    --secret-id ${TIMESCALE_SECRET_NAME} \
    --region ${AWS_REGION} \
    --query 'SecretString' \
    --output text 2>/dev/null || echo "")

if [ -z "$POSTGRES_URL" ] || [ "$POSTGRES_URL" = "None" ]; then
    echo "❌ Không thể lấy PostgreSQL connection string từ secret: ${POSTGRES_SECRET_NAME}"
    echo "   Chạy: ./deployment/create-database-secrets-from-services.sh ${ENVIRONMENT}"
    exit 1
fi

if [ -z "$TIMESCALE_URL" ] || [ "$TIMESCALE_URL" = "None" ]; then
    echo "❌ Không thể lấy TimescaleDB connection string từ secret: ${TIMESCALE_SECRET_NAME}"
    echo "   Chạy: ./deployment/create-database-secrets-from-services.sh ${ENVIRONMENT}"
    exit 1
fi

echo "✅ Đã lấy connection strings"
echo ""

# Kiểm tra migrations directory
PRIMARY_MIGRATIONS_PATH="$(pwd)/migrations/primary"
TSDB_MIGRATIONS_PATH="$(pwd)/migrations/tsdb"

if [ ! -d "$PRIMARY_MIGRATIONS_PATH" ]; then
    echo "❌ Không tìm thấy migrations directory: ${PRIMARY_MIGRATIONS_PATH}"
    exit 1
fi

if [ ! -d "$TSDB_MIGRATIONS_PATH" ]; then
    echo "⚠️  Không tìm thấy tsdb migrations directory: ${TSDB_MIGRATIONS_PATH}"
    echo "   Sẽ bỏ qua TimescaleDB migrations"
    TSDB_MIGRATIONS_PATH=""
fi

# Chạy migration cho PostgreSQL
echo "=========================================="
echo "Chạy migrations cho PostgreSQL"
echo "=========================================="
echo "Database: ${POSTGRES_URL}"
echo "Migrations path: ${PRIMARY_MIGRATIONS_PATH}"
echo ""

cd migrations/cli

export MIGRATE_PATH="${PRIMARY_MIGRATIONS_PATH}"
export MIGRATE_DATABASE_URL="${POSTGRES_URL}"

echo "Đang chạy migrations..."
if go run main.go migrate; then
    echo "✅ PostgreSQL migrations đã hoàn thành thành công!"
else
    echo "❌ PostgreSQL migrations có lỗi"
    exit 1
fi

echo ""

# Chạy migration cho TimescaleDB (nếu có)
if [ -n "$TSDB_MIGRATIONS_PATH" ] && [ -d "$TSDB_MIGRATIONS_PATH" ]; then
    # Kiểm tra xem có migrations files không
    MIGRATION_COUNT=$(find "$TSDB_MIGRATIONS_PATH" -name "*.up.sql" 2>/dev/null | wc -l | tr -d ' ')
    
    if [ "$MIGRATION_COUNT" -eq 0 ]; then
        echo "⚠️  Không có migrations files trong ${TSDB_MIGRATIONS_PATH}"
        echo "   Bỏ qua TimescaleDB migrations."
    else
        echo "=========================================="
        echo "Chạy migrations cho TimescaleDB"
        echo "=========================================="
        echo "Database: ${TIMESCALE_URL}"
        echo "Migrations path: ${TSDB_MIGRATIONS_PATH}"
        echo ""
        
        export MIGRATE_PATH="${TSDB_MIGRATIONS_PATH}"
        export MIGRATE_DATABASE_URL="${TIMESCALE_URL}"
        
        echo "Đang chạy migrations..."
        if go run main.go migrate; then
            echo "✅ TimescaleDB migrations đã hoàn thành thành công!"
        else
            echo "❌ TimescaleDB migrations có lỗi"
            echo "   Lưu ý: Nếu TimescaleDB không expose ra internet, cần setup NLB hoặc VPN để kết nối."
            exit 1
        fi
        echo ""
    fi
fi

echo "=========================================="
echo "✅ Tất cả migrations đã hoàn thành!"
echo "=========================================="

