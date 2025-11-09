# AWS Deployment Guide

Hướng dẫn đóng gói và triển khai các thành phần ứng dụng FieldKit lên AWS ECS.

## Kiến trúc Deployment

```
┌─────────────────────────────────────────────────┐
│           Build Local (Docker)                  │
│  - Build Docker images                          │
│  - Tag với version                              │
│  - Push lên AWS ECR                             │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│              AWS ECR Registry                   │
│  - fieldkit/server:latest                       │
│  - fieldkit/charting:latest                     │
│  - fieldkit/migrations:latest                   │
└─────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────┐
│          AWS ECS Deployment                     │
│  - ECS Cluster (Fargate)                        │
│  - Services (server, charting)                  │
│  - Task Definitions                             │
└─────────────────────────────────────────────────┘
```

## Yêu cầu

1. **AWS CLI** đã được cấu hình với credentials có quyền:
   - ECR (push/pull images)
   - ECS (create/update services)
   - IAM (roles cho ECS tasks)
   - Secrets Manager (để lưu secrets)
   - CloudWatch Logs (để logging)

   **Cách lấy AWS Access Key ID và Secret Access Key:**
   
   **Bước 1: Đăng nhập AWS Console**
   - Truy cập: https://console.aws.amazon.com
   - Đăng nhập với tài khoản AWS của bạn
   
   **Bước 2: Tạo Access Key**
   - Click vào tên user ở góc trên bên phải (hoặc vào IAM service)
   - Chọn "Security credentials" tab
   - Scroll xuống phần "Access keys"
   - Click "Create access key"
   - Chọn use case (ví dụ: "Command Line Interface (CLI)")
   - Click "Next" và "Create access key"
   - **QUAN TRỌNG**: Download hoặc copy ngay Access Key ID và Secret Access Key
     - Secret Access Key chỉ hiển thị 1 lần duy nhất
     - Nếu mất, phải tạo access key mới
   
   **Bước 3: Cấu hình AWS CLI**
   ```bash
   # Cấu hình default credentials
   aws configure
   
   # Hoặc tạo profile riêng
   aws configure --profile fieldkit
   ```
   
   Khi được hỏi, nhập:
   - **AWS Access Key ID**: [Paste Access Key ID đã copy]
   - **AWS Secret Access Key**: [Paste Secret Access Key đã copy]
   - **Default region name**: `ap-southeast-1` (hoặc region bạn muốn)
   - **Default output format**: `json`
   
   **Lưu ý bảo mật:**
   - Không commit Access Keys vào Git
   - Không chia sẻ Access Keys qua email/chat
   - Nếu nghi ngờ bị lộ, xóa access key ngay và tạo mới
   - Sử dụng IAM roles thay vì access keys khi có thể (trên EC2/ECS)
   
   **Kiểm tra quyền AWS CLI:**
   ```bash
   # Kiểm tra AWS CLI đã được cài đặt
   aws --version
   
   # Kiểm tra credentials hiện tại
   aws sts get-caller-identity
   # Kết quả sẽ hiển thị Account ID, User/Role ARN
   
   # Kiểm tra quyền ECR
   aws ecr describe-repositories --region ap-southeast-1
   
   # Kiểm tra quyền ECS
   aws ecs list-clusters --region ap-southeast-1
   
   # Kiểm tra quyền Secrets Manager
   aws secretsmanager list-secrets --region ap-southeast-1
   
   # Kiểm tra quyền CloudWatch Logs
   aws logs describe-log-groups --region ap-southeast-1 --max-items 1
   
   # Kiểm tra quyền IAM (xem roles)
   aws iam list-roles --max-items 1
   
   # Nếu có lỗi permission denied, cần cập nhật IAM policy cho user/role
   ```

2. **Docker** đã được cài đặt và chạy

   **Kiểm tra Docker:**
   ```bash
   docker --version
   docker info
   docker ps
   ```

3. **jq** để xử lý JSON

   **Kiểm tra jq:**
   ```bash
   jq --version
   # Nếu chưa có: brew install jq (macOS) hoặc apt-get install jq (Linux)
   ```

4. **Biến môi trường**:
   ```bash
   # AWS_ACCOUNT_ID sẽ được tự động lấy từ AWS credentials
   # Không cần set nếu đã cấu hình AWS credentials đúng
   
   export AWS_REGION="ap-southeast-1"
   export AWS_PROFILE="fieldkit"  # Optional - chỉ dùng nếu profile đã được tạo
   
   # Kiểm tra Account ID thực tế
   aws sts get-caller-identity --query Account --output text
   
   # Kiểm tra biến môi trường
   echo "AWS Region: $AWS_REGION"
   
   # Nếu muốn dùng AWS_PROFILE, tạo profile trước:
   aws configure --profile fieldkit
   # Nhập AWS Access Key ID, Secret Access Key, region, output format
   ```
   
   **Lưu ý**: Scripts sẽ tự động lấy AWS Account ID từ credentials. Nếu set `AWS_ACCOUNT_ID` trong environment nhưng khác với Account ID thực tế, script sẽ cảnh báo và sử dụng Account ID thực tế.

## Kiểm tra Prerequisites

Trước khi deploy, chạy script kiểm tra:

```bash
./deployment/check-prerequisites.sh
```

Script này sẽ kiểm tra:
- AWS CLI đã được cài đặt
- AWS credentials đã được cấu hình
- AWS permissions (ECR, ECS, Secrets Manager, CloudWatch, IAM)
- Docker đã được cài đặt và đang chạy
- jq đã được cài đặt
- Environment variables đã được set

## Kiến trúc Deployment

Ứng dụng được chia thành **2 cluster riêng biệt**:

1. **Database Cluster** (`fieldkit-{ENV}-db-v1`):
   - PostgreSQL service
   - TimescaleDB service

2. **Application Cluster** (`fieldkit-{ENV}-app`):
   - Server service (expose qua Application Load Balancer)
   - Charting service

### Kiến trúc Server và Portal

**Tại sao đóng gói cả Server và Portal trong 1 image?**

Server và Portal được đóng gói trong cùng một Docker image (`hieuhk_fieldkit/server`) vì:

1. **Kiến trúc Monolithic**: Server (Go) serve cả API và Portal static files (Vue.js)
2. **Routing thông minh**: 
   - API requests → Server xử lý
   - Portal requests → Server serve static files từ `/portal`
   - Default route → Portal SPA (Single Page Application)
3. **Lợi ích**:
   - Đơn giản hóa deployment (chỉ cần 1 service)
   - Giảm latency (không cần network hop giữa server và portal)
   - Dễ quản lý version (server và portal cùng version)

**Cấu hình:**

- **Port**: Server chạy ở port 80 (HTTP standard)
- **Portal Root**: Portal files được copy vào `/portal` trong image
- **Environment Variable**: `FIELDKIT_PORTAL_ROOT=/portal` (bắt buộc để server biết đường dẫn portal)
- **Health Check**: `/status` endpoint để kiểm tra server health
- **Routing**:
  - `/status` → Health check endpoint
  - `/robots.txt` → Robots.txt
  - `/.well-known/*` → Well-known files
  - `api.{domain}/*` → API endpoints
  - `*` → Portal SPA (fallback)

**Lưu ý quan trọng:**

- Nếu `FIELDKIT_PORTAL_ROOT` không được set, server sẽ không serve portal files và trả về 404
- Health check endpoint là `/status`, không phải `/health`
- Portal được serve như một SPA, tất cả routes không match API sẽ fallback về portal

## Quy trình Deployment

### Bước 1: Setup Infrastructure

#### 1.1. Setup Database Cluster và Services

```bash
# Set environment variables
export VPC_ID="vpc-xxxxx"
export SUBNET_IDS="subnet-xxxxx,subnet-yyyyy"
export SECURITY_GROUP_ID="sg-xxxxx"

# Deploy database services
./deployment/deploy-database.sh staging
```

Script này sẽ:
- Tạo cluster `fieldkit-staging-db-v1` (nếu chưa có)
- Đăng ký task definitions cho PostgreSQL và TimescaleDB
- Tạo services cho PostgreSQL và TimescaleDB

#### 1.2. Setup Application Cluster và Services

```bash
# Deploy application services
./deployment/create-ecs-services.sh staging
```

Script này sẽ:
- Tạo cluster `fieldkit-staging-app` (nếu chưa có)
- Đăng ký task definitions cho server và charting
- Tạo services cho server và charting

### Bước 2: Setup Load Balancers

Sau khi tạo database và server services, setup Load Balancers ngay để có thể truy cập các dịch vụ.

#### 2.1. Setup Application Load Balancer cho Server

```bash
./deployment/setup-load-balancer.sh staging
```

Script này sẽ:
- Tạo Application Load Balancer (ALB) internet-facing
- Tạo target group cho server service
- Cấu hình HTTP listener (port 80)
- Cập nhật server service để sử dụng load balancer

Sau khi hoàn thành, bạn sẽ nhận được ALB DNS name để truy cập web application.

#### 2.2. Setup Public Access cho PostgreSQL (Optional)

**Trước khi chạy script, cần set các biến môi trường:**

```bash
# Lấy VPC_ID
export VPC_ID=$(aws ec2 describe-vpcs --region ap-southeast-1 --filters "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text)

# Lấy SUBNET_IDS (cần ít nhất 2 subnets)
export SUBNET_IDS=$(aws ec2 describe-subnets --region ap-southeast-1 --filters "Name=vpc-id,Values=${VPC_ID}" --query 'Subnets[*].SubnetId' --output text | tr '\t' ',')

# Lấy SECURITY_GROUP_ID từ service hiện tại (nếu đã có)
export SECURITY_GROUP_ID=$(aws ecs describe-services \
  --cluster fieldkit-staging-db-v1 \
  --services fieldkit-staging-db-v1-postgres \
  --region ap-southeast-1 \
  --query 'services[0].networkConfiguration.awsvpcConfiguration.securityGroups[0]' \
  --output text)

# Hoặc tạo security group mới
# export SECURITY_GROUP_ID=$(aws ec2 create-security-group \
#   --group-name fieldkit-staging-postgres-sg \
#   --description "Security group for FieldKit PostgreSQL" \
#   --vpc-id ${VPC_ID} \
#   --region ap-southeast-1 \
#   --query 'GroupId' --output text)
```

**Chạy script:**

```bash
./deployment/setup-postgres-public.sh staging
```

Script này sẽ:
- Tự động tìm default VPC và subnets nếu chưa set biến môi trường
- Hiển thị hướng dẫn chi tiết nếu thiếu thông tin
- Tạo Network Load Balancer (NLB) internet-facing
- Tạo target group cho PostgreSQL service
- Cấu hình TCP listener (port 5432)
- Cập nhật PostgreSQL service để sử dụng load balancer

**⚠️ Cảnh báo bảo mật**: Expose PostgreSQL ra internet có rủi ro bảo mật. Nên:
- Giới hạn IP source trong security group
- Sử dụng SSL/TLS connection
- Xem xét sử dụng VPN hoặc Bastion Host thay vì public access

#### 2.3. Setup Public Access cho TimescaleDB (Optional)

**Trước khi chạy script, cần set các biến môi trường:**

```bash
# Lấy VPC_ID
export VPC_ID=$(aws ec2 describe-vpcs --region ap-southeast-1 --filters "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text)

# Lấy SUBNET_IDS (cần ít nhất 2 subnets)
export SUBNET_IDS=$(aws ec2 describe-subnets --region ap-southeast-1 --filters "Name=vpc-id,Values=${VPC_ID}" --query 'Subnets[*].SubnetId' --output text | tr '\t' ',')

# Lấy SECURITY_GROUP_ID từ service hiện tại (nếu đã có)
export SECURITY_GROUP_ID=$(aws ecs describe-services \
  --cluster fieldkit-staging-db-v1 \
  --services fieldkit-staging-db-v1-timescale \
  --region ap-southeast-1 \
  --query 'services[0].networkConfiguration.awsvpcConfiguration.securityGroups[0]' \
  --output text)

# Hoặc tạo security group mới
# export SECURITY_GROUP_ID=$(aws ec2 create-security-group \
#   --group-name fieldkit-staging-timescale-sg \
#   --description "Security group for FieldKit TimescaleDB" \
#   --vpc-id ${VPC_ID} \
#   --region ap-southeast-1 \
#   --query 'GroupId' --output text)
```

**Chạy script:**

```bash
./deployment/setup-timescale-public.sh staging
```

Script này sẽ:
- Tự động tìm default VPC và subnets nếu chưa set biến môi trường
- Hiển thị hướng dẫn chi tiết nếu thiếu thông tin
- Tạo Network Load Balancer (NLB) internet-facing
- Tạo target group cho TimescaleDB service
- Cấu hình TCP listener (port 5432)
- Cập nhật TimescaleDB service để sử dụng load balancer

**⚠️ Cảnh báo bảo mật**: Expose TimescaleDB ra internet có rủi ro bảo mật. Nên:
- Giới hạn IP source trong security group
- Sử dụng SSL/TLS connection
- Xem xét sử dụng VPN hoặc Bastion Host thay vì public access

### Bước 3: Setup Secrets

#### 3.1. Setup Session Key

```bash
./deployment/setup-session-key.sh staging
```

#### 3.2. Setup Database Connection Strings

```bash
# Tự động tạo connection strings từ service discovery
./deployment/create-database-secrets-from-services.sh staging
```

Hoặc setup thủ công:

```bash
./deployment/setup-database-secrets.sh staging
```

### Bước 4: Chạy Database Migrations

Có 2 cách để chạy migrations:

#### Cách 1: Chạy từ máy local (Khuyến nghị)

Chạy migrations trực tiếp từ máy tính của bạn, kết nối đến database trên AWS:

```bash
# Chạy migrations cho cả PostgreSQL và TimescaleDB
./deployment/run-migrations-local.sh staging
```

**Yêu cầu:**
- Go đã được cài đặt (`go version`)
- Database connection strings đã được setup trong Secrets Manager
- Network có thể kết nối đến database (qua NLB hoặc VPN)

**Lợi ích:**
- Nhanh hơn (không cần build/push Docker image)
- Dễ debug (xem logs trực tiếp)
- Không tốn chi phí ECS task

#### Cách 2: Chạy trên ECS (Tự động)

Chạy migrations như một ECS task:

```bash
# Chạy migrations cho cả PostgreSQL và TimescaleDB
./deployment/run-migrations.sh staging
```

Script này sẽ:
- Lấy connection strings từ Secrets Manager
- Tạo task definition cho migrations
- Chạy migrations cho PostgreSQL (từ `/work/primary`)
- Chạy migrations cho TimescaleDB (từ `/work/tsdb`)
- Đợi và kiểm tra kết quả

**Lưu ý**: Migrations image cần được build với migrations files đã được copy vào image (đã được cập nhật trong `migrations/Dockerfile`).

#### Kiểm tra trạng thái Public Services

Sau khi setup Load Balancers, bạn có thể kiểm tra trạng thái của tất cả các dịch vụ:

```bash
./deployment/check-public-services.sh staging
```

Script này sẽ kiểm tra:
- **Server Service**: Application Load Balancer (ALB) và health status
- **PostgreSQL**: Network Load Balancer (NLB) và connection info
- **TimescaleDB**: Network Load Balancer (NLB) và connection info

Với mỗi dịch vụ, script sẽ hiển thị:
- ✅ Load Balancer đã được tạo và DNS name
- ✅ Target Group và số lượng healthy targets
- ✅ Service đã được attach vào Load Balancer
- 🌐 Public access URLs/connection strings

**Ví dụ output:**
```
==========================================
Kiểm tra Public Services Status
==========================================
Environment: staging
Region: ap-southeast-1
==========================================

----------------------------------------
📋 server
----------------------------------------
✅ Load Balancer: fieldkit-staging-server-alb
   Type: application
   Scheme: internet-facing
   State: active
   DNS: fieldkit-staging-server-alb-xxx.elb.ap-southeast-1.amazonaws.com

✅ Target Group: fieldkit-staging-server-tg
   Healthy targets: 2/2
   ✅ Có 2 healthy target(s)

✅ Service đã được attach vào Target Group

🌐 Public Access:
   URL: http://fieldkit-staging-server-alb-xxx.elb.ap-southeast-1.amazonaws.com
   Health check: http://fieldkit-staging-server-alb-xxx.elb.ap-southeast-1.amazonaws.com/status
```

#### Export Database URLs để sử dụng

Trước khi chạy migrations, bạn có thể export database connection URLs vào biến môi trường:

```bash
# Export database URLs từ AWS Secrets Manager
source ./deployment/export-database-urls.sh staging

# Sau đó có thể sử dụng các biến:
echo $FIELDKIT_POSTGRES_URL
echo $FIELDKIT_TIME_SCALE_URL

# Hoặc sử dụng trực tiếp trong commands
cd migrations/cli
export MIGRATE_PATH="../primary"
export MIGRATE_DATABASE_URL="$FIELDKIT_POSTGRES_URL"
go run main.go migrate
```

Script này sẽ:
- Lấy PostgreSQL connection URL từ AWS Secrets Manager
- Lấy TimescaleDB connection URL từ AWS Secrets Manager
- Export vào biến môi trường `FIELDKIT_POSTGRES_URL` và `FIELDKIT_TIME_SCALE_URL`

**Lưu ý**: Phải dùng `source` để export biến vào shell hiện tại. Nếu chạy trực tiếp (`./deployment/export-database-urls.sh`), script sẽ chỉ hiển thị hướng dẫn.

#### Chi tiết về Migration CLI

Migration CLI sử dụng thư viện `go-pg-migrations` để quản lý database migrations. Dưới đây là các cách sử dụng:

**Cấu trúc Migration CLI:**

```
migrations/
├── cli/              # Migration CLI tool
│   ├── main.go       # Entry point
│   └── go.mod
├── support/          # Migration support library
│   ├── migrate.go    # Migration logic
│   └── go.mod
├── primary/          # PostgreSQL migrations
│   └── *.up.sql      # Migration files
└── tsdb/             # TimescaleDB migrations
    └── *.up.sql      # Migration files
```

**Cách sử dụng Migration CLI:**

**1. Chạy migrations từ local (sử dụng Go):**

**Cách A: Sử dụng export-database-urls.sh (Khuyến nghị)**

```bash
# Export database URLs từ AWS Secrets Manager
source ./deployment/export-database-urls.sh staging

# Chạy migrations cho PostgreSQL
cd migrations/cli
export MIGRATE_PATH="../primary"
export MIGRATE_DATABASE_URL="$FIELDKIT_POSTGRES_URL"
go run main.go migrate

# Chạy migrations cho TimescaleDB
export MIGRATE_PATH="../tsdb"
export MIGRATE_DATABASE_URL="$FIELDKIT_TIME_SCALE_URL"
go run main.go migrate
```

**Cách B: Set connection string trực tiếp**

```bash
# Chạy migrations cho PostgreSQL
cd migrations/cli
export MIGRATE_PATH="../primary"
export MIGRATE_DATABASE_URL="postgres://user:password@host:5432/database?sslmode=disable"
go run main.go migrate

# Chạy migrations cho TimescaleDB
export MIGRATE_PATH="../tsdb"
export MIGRATE_DATABASE_URL="postgres://user:password@host:5432/database?sslmode=disable"
go run main.go migrate
```

**2. Sử dụng Makefile commands:**

```bash
# Chạy migrations cho PostgreSQL
make migrate-up

# Chạy migrations cho TimescaleDB
make migrate-up-tsdb
```

**3. Chạy migrations từ Docker:**

```bash
# Build migration image
cd migrations
make image

# Chạy migrations
cd primary
export DATABASE_URL="postgres://user:password@host:5432/database?sslmode=disable"
make migrate
```

**4. Các commands có sẵn:**

Migration CLI hỗ trợ các commands từ thư viện `go-pg-migrations`:

- `migrate` - Chạy tất cả migrations chưa được apply
- `migrate up` - Tương tự `migrate`
- `migrate down` - Rollback migration cuối cùng
- `migrate reset` - Rollback tất cả migrations
- `migrate version` - Hiển thị version hiện tại
- `migrate set_version <version>` - Set version cụ thể (không chạy migration)

**Ví dụ:**
 export MIGRATE_DATABASE_URL="postgres://fieldkit:WxdI7USgPlkSVOcrE8cCcn2vA@fieldkit-staging-postgres-nlb-2e92e35ac371a189.elb.ap-southeast-1.amazonaws.com:5432/fieldkit?sslmode=disable"

  export MIGRATE_DATABASE_URL="postgres://postgres:GCDJNCpezOzfOhjPJLLkjZ2nh@fieldkit-staging-timescale-nlb-fb46e5c996ec1a7b.elb.ap-southeast-1.amazonaws.com:5432/fk?sslmode=disable"

```bash
# Export database URLs trước
source ./deployment/export-database-urls.sh staging

# Kiểm tra version hiện tại
cd migrations/cli
export MIGRATE_PATH="../primary"
export MIGRATE_DATABASE_URL="$FIELDKIT_POSTGRES_URL"
go run main.go version

# Rollback migration cuối cùng
go run main.go down

# Set version cụ thể (cẩn thận!)
go run main.go set_version 20220722000001
```

**Lưu ý quan trọng:**

1. **Biến môi trường bắt buộc:**
   - `MIGRATE_PATH`: Đường dẫn đến thư mục chứa migration files (ví dụ: `../primary` hoặc `../tsdb`)
   - `MIGRATE_DATABASE_URL`: Connection string đến database (PostgreSQL format)

2. **Migration files:**
   - Tên file phải theo format: `YYYYMMDDHHMMSS_description.up.sql`
   - File `.down.sql` tương ứng cho rollback (hiện tại chưa được implement đầy đủ)

3. **Schema và permissions:**
   - Migration CLI tự động tạo schema `fieldkit` nếu chưa có
   - Tự động grant permissions cho role `fieldkit` nếu tồn tại
   - Set `search_path` thành `fieldkit, public`

4. **Connection string format:**
   ```
   postgres://[user]:[password]@[host]:[port]/[database]?sslmode=[mode]
   ```

**Troubleshooting:**

- **Lỗi "MIGRATE_PATH is required"**: Đảm bảo đã set biến môi trường `MIGRATE_PATH`
- **Lỗi "MIGRATE_DATABASE_URL is required"**: Đảm bảo đã set biến môi trường `MIGRATE_DATABASE_URL`
- **Lỗi kết nối database**: Kiểm tra connection string và network connectivity
- **Lỗi permissions**: Đảm bảo user có quyền tạo schema và tables

### Bước 5: Build và Push Images

```bash
# Build và push tất cả images
./deployment/build-and-push.sh latest staging
```

Hoặc với version cụ thể:

```bash
./deployment/build-and-push.sh v1.0.0 staging
```

### Bước 6: Deploy Images lên ECS

```bash
# Deploy images đã build
./deployment/deploy.sh latest staging
```

Script này sẽ:
- Đăng ký task definitions mới với images mới
- Cập nhật services để sử dụng task definitions mới
- ECS sẽ tự động thực hiện rolling update

## Cấu trúc Files

```
deployment/
├── build-and-push.sh              # Build và push Docker images lên ECR
├── deploy.sh                       # Deploy images lên ECS
├── create-ecs-services.sh         # Setup application cluster và services
├── deploy-database.sh              # Deploy database cluster và services
├── setup-load-balancer.sh          # Setup ALB cho server service
├── setup-postgres-public.sh        # Setup NLB cho PostgreSQL (optional)
├── setup-timescale-public.sh       # Setup NLB cho TimescaleDB (optional)
├── export-database-urls.sh         # Export database URLs từ Secrets Manager
├── check-public-services.sh        # Kiểm tra trạng thái public của các dịch vụ
├── check-server-access.sh          # Kiểm tra server service access
├── run-migrations.sh               # Chạy database migrations trên ECS
├── run-migrations-local.sh        # Chạy database migrations từ máy local
├── setup-session-key.sh            # Tạo session key secret
├── setup-database-secrets.sh       # Setup database secrets thủ công
├── create-database-secrets-from-services.sh  # Tạo secrets từ service discovery
├── setup-ecs-roles.sh              # Setup ECS task roles
├── setup-ecs-service-linked-role.sh # Setup ECS service-linked role
├── check-prerequisites.sh          # Kiểm tra prerequisites
├── setup-iam-policy.sh             # Setup IAM policy
├── test-ecr-permissions.sh        # Test ECR permissions
├── fix-ecr-403.sh                  # Fix ECR 403 errors
├── list-ecr-images.sh              # List images trong ECR
├── stop-and-cleanup.sh             # Stop và cleanup services
├── port-forward-postgres.sh        # Port forward đến PostgreSQL
├── create-bastion-host.sh          # Tạo bastion host để access database
├── README.md                       # Hướng dẫn deployment
├── ecs-task-definitions/           # Task definition templates
│   ├── server-task.json
│   ├── charting-task.json
│   ├── postgres-task.json
│   └── timescale-task.json
├── iam-policies/                   # IAM policy templates
│   ├── deployment-full-policy.json
│   ├── ecr-policy.json
│   ├── ecs-policy.json
│   ├── secrets-policy.json
│   ├── cloudwatch-policy.json
│   ├── ecs-execution-policy.json
│   ├── ecs-task-execution-trust-policy.json
│   ├── ecs-task-trust-policy.json
│   ├── ecs-task-execution-policy.json
│   └── ecs-task-policy.json
├── troubleshooting-ecr-403.md     # Troubleshooting ECR 403
└── troubleshooting-aws-profile.md  # Troubleshooting AWS profile
```

```bash
# Kiểm tra và tạo ECS service-linked role
./deployment/setup-ecs-service-linked-role.sh

# Hoặc tạo thủ công:
aws iam create-service-linked-role --aws-service-name ecs.amazonaws.com
```

**Bước 2: Setup ECS cluster, services, và task definitions**

```bash
# Thiết lập VPC và networking trước
export VPC_ID="vpc-xxxxx"
export SUBNET_IDS="subnet-xxxxx,subnet-yyyyy"
export SECURITY_GROUP_ID="sg-xxxxx"

# Tạo cluster, services, và task definitions
./deployment/create-ecs-services.sh staging
```

**Hoặc tạo cluster đơn giản (nếu chỉ cần cluster để test):**
```bash
aws ecs create-cluster \
    --cluster-name fieldkit-staging \
    --region ap-southeast-1 \
    --capacity-providers FARGATE FARGATE_SPOT \
    --default-capacity-provider-strategy capacityProvider=FARGATE,weight=1
```

### 3. Deploy lên ECS

```bash
# Deploy version cụ thể
./deployment/deploy.sh v1.0.0 staging

# Hoặc deploy latest
./deployment/deploy.sh latest staging
```

Script này sẽ:
- Lấy task definition hiện tại
- Cập nhật image URI với version mới
- Đăng ký task definition mới
- Update ECS services để sử dụng task definition mới
- Force new deployment

## Cấu trúc Files

```
deployment/
├── build-and-push.sh          # Build và push images lên ECR
├── deploy.sh                   # Deploy images lên ECS
├── create-ecs-services.sh     # Setup ECS infrastructure
├── stop-and-cleanup.sh         # Stop và cleanup để tránh chi phí
├── list-ecr-images.sh          # List images trong ECR
├── check-prerequisites.sh      # Kiểm tra prerequisites
├── setup-iam-policy.sh         # Setup IAM policy
├── test-ecr-permissions.sh    # Test ECR permissions
├── fix-ecr-403.sh              # Fix lỗi 403 Forbidden
├── ecs-task-definitions/       # Task definitions
│   ├── server-task.json
│   └── charting-task.json
├── iam-policies/               # IAM policies
│   ├── deployment-full-policy.json
│   ├── ecr-policy.json
│   ├── ecs-policy.json
│   └── ...
└── README.md                   # File này
```

## ECS Task Definitions

Task definitions được định nghĩa trong `ecs-task-definitions/`:

- **server-task.json**: Configuration cho server service
  - CPU: 512
  - Memory: 1024 MB
  - Port: 80
  - Health check: `/status`
  - Environment variables:
    - `FIELDKIT_ADDR`: `:80` (server listen address)
    - `FIELDKIT_HTTP_SCHEME`: `https` (HTTP scheme)
    - `FIELDKIT_PORTAL_ROOT`: `/portal` (portal static files path - **bắt buộc**)

- **charting-task.json**: Configuration cho charting service
  - CPU: 256
  - Memory: 512 MB
  - Port: 3000

### Secrets Management

Secrets được lưu trong AWS Secrets Manager:
- `fieldkit/database/postgres`: PostgreSQL connection string
- `fieldkit/database/timescale`: TimescaleDB connection string
- `fieldkit/session/key`: Session encryption key

Để tạo secrets:
```bash
aws secretsmanager create-secret \
    --name fieldkit/database/postgres \
    --secret-string "postgres://user:pass@host:5432/db" \
    --region ap-southeast-1
```

## IAM Policies và Roles

### Permissions cần thiết cho Deployment User/Role

Trước khi deploy, đảm bảo IAM user/role có đủ quyền. Xem chi tiết trong `deployment/iam-policies/README.md`.

**Quick Setup (Tự động):**
```bash
# Setup IAM policy cho IAM user
./deployment/setup-iam-policy.sh YOUR_USERNAME USER

# Hoặc cho IAM role
./deployment/setup-iam-policy.sh YOUR_ROLE_NAME ROLE
```

**Manual Setup:**
```bash
# Xem full policy cần thiết
cat deployment/iam-policies/deployment-full-policy.json

# Thay ACCOUNT_ID và tạo policy
sed 's/ACCOUNT_ID/YOUR_ACCOUNT_ID/g' deployment/iam-policies/deployment-full-policy.json > /tmp/policy.json
aws iam create-policy --policy-name FieldKitDeploymentPolicy --policy-document file:///tmp/policy.json

# Attach vào user
aws iam attach-user-policy --user-name YOUR_USERNAME --policy-arn arn:aws:iam::YOUR_ACCOUNT_ID:policy/FieldKitDeploymentPolicy
```

**Minimum Permissions:**
- ECR: `GetAuthorizationToken`, `CreateRepository`, `DescribeRepositories`, `PutImage`
- ECS: `DescribeClusters`, `UpdateService`, `RegisterTaskDefinition`, `DescribeTaskDefinition`
- Secrets Manager: `GetSecretValue` (nếu dùng secrets)
- CloudWatch Logs: `CreateLogGroup`, `DescribeLogGroups`

### ECS Task Roles

Cần tạo các IAM roles sau:

### 1. ECS Task Execution Role (`ecsTaskExecutionRole`)
Permissions:
- `ecr:GetAuthorizationToken`
- `ecr:BatchCheckLayerAvailability`
- `ecr:GetDownloadUrlForLayer`
- `ecr:BatchGetImage`
- `logs:CreateLogStream`
- `logs:PutLogEvents`
- `secretsmanager:GetSecretValue`

### 2. ECS Task Role (`ecsTaskRole`)
Permissions cho ứng dụng (tùy theo nhu cầu):
- S3 access (nếu cần)
- Secrets Manager access
- Other AWS services

## Monitoring

Sau khi deploy, theo dõi:

1. **ECS Console**: https://console.aws.amazon.com/ecs/v2/clusters/
2. **CloudWatch Logs**: `/ecs/fieldkit-server` và `/ecs/fieldkit-charting`
3. **Service Events**: Xem trong ECS service details

## Rollback

Để rollback về version trước:

```bash
# List các task definition revisions
aws ecs list-task-definitions \
    --family-prefix fieldkit-server \
    --region ap-southeast-1

# Update service với revision cũ
aws ecs update-service \
    --cluster fieldkit-staging \
    --service fieldkit-staging-server \
    --task-definition fieldkit-server:PREVIOUS_REVISION \
    --force-new-deployment \
    --region ap-southeast-1
```

## Environment Variables

Các biến môi trường có thể được set trong task definitions hoặc qua ECS service configuration:

```bash
# Ví dụ update environment variable
aws ecs register-task-definition \
    --cli-input-json file://updated-task-def.json \
    --region ap-southeast-1
```

### 4. Stop và Cleanup (để tránh phát sinh chi phí)

Khi không sử dụng, có thể stop hoặc xóa các dịch vụ để tránh phát sinh chi phí:

```bash
# Chỉ scale services về 0 (giữ lại services và cluster)
./deployment/stop-and-cleanup.sh staging

# Xóa services (giữ lại cluster)
./deployment/stop-and-cleanup.sh staging --delete-services

# Xóa tất cả (services + cluster) - tiết kiệm chi phí nhất
./deployment/stop-and-cleanup.sh staging --all
```

**Lưu ý về chi phí:**
- **Scale về 0**: Không tốn chi phí cho tasks, nhưng vẫn tốn chi phí cho ALB (nếu có) và các resources khác
- **Xóa services**: Không tốn chi phí cho services, nhưng cluster vẫn tồn tại (chi phí minimal)
- **Xóa cluster**: Không tốn chi phí gì, nhưng cần setup lại khi deploy

**Khuyến nghị:**
- Nếu không dùng trong thời gian ngắn: `--delete-services` (giữ cluster để deploy nhanh hơn)
- Nếu không dùng trong thời gian dài: `--all` (xóa hết để tiết kiệm chi phí)

## Xem danh sách Images đã push

### Sử dụng script helper (Khuyến nghị)

```bash
# List tất cả images trong tất cả repositories
./deployment/list-ecr-images.sh

# List images trong một repository cụ thể
./deployment/list-ecr-images.sh server
./deployment/list-ecr-images.sh charting
./deployment/list-ecr-images.sh migrations
```

### Sử dụng AWS CLI trực tiếp

```bash
# List tất cả repositories
aws ecr describe-repositories \
    --region ap-southeast-1 \
    --query 'repositories[*].repositoryName' \
    --output table

# List images trong một repository
aws ecr list-images \
    --repository-name hieuhk_fieldkit/server \
    --region ap-southeast-1

# List images với tags
aws ecr list-images \
    --repository-name hieuhk_fieldkit/server \
    --region ap-southeast-1 \
    --query 'imageIds[?imageTag!=`null`].imageTag' \
    --output table

# Xem chi tiết một image cụ thể
aws ecr describe-images \
    --repository-name hieuhk_fieldkit/server \
    --image-ids imageTag=latest \
    --region ap-southeast-1

# Xem tất cả images với thông tin chi tiết
aws ecr describe-images \
    --repository-name hieuhk_fieldkit/server \
    --region ap-southeast-1 \
    --query 'imageDetails[*].[imageTags[0],imagePushedAt,imageSizeInBytes]' \
    --output table
```

### Xem trên AWS Console

1. Truy cập: https://ap-southeast-1.console.aws.amazon.com/ecr
2. Chọn region: `ap-southeast-1`
3. Vào "Repositories" → tìm repository `hieuhk_fieldkit/server`, `hieuhk_fieldkit/charting`, etc.
4. Click vào repository để xem danh sách images

## Troubleshooting

### Lỗi 403 Forbidden khi push images lên ECR

Xem chi tiết trong `deployment/troubleshooting-ecr-403.md`

**Nguyên nhân phổ biến:**
1. Thiếu IAM permissions: `ecr:PutImage`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`
2. Docker authentication token hết hạn (token chỉ có hiệu lực 12 giờ)
3. Repository ARN không khớp với IAM policy

**Quick Fix (Tự động):**
```bash
# Script tự động fix lỗi 403
./deployment/fix-ecr-403.sh YOUR_USERNAME

# Hoặc để script tự detect user
./deployment/fix-ecr-403.sh
```

**Manual Fix:**
```bash
# 1. Setup/Update IAM policy
./deployment/setup-iam-policy.sh YOUR_USERNAME USER

# 2. Test ECR permissions chi tiết
./deployment/test-ecr-permissions.sh

# 3. Re-authenticate Docker với ECR
aws ecr get-login-password --region ap-southeast-1 | \
  docker login --username AWS --password-stdin \
  ${AWS_ACCOUNT_ID}.dkr.ecr.ap-southeast-1.amazonaws.com

# 4. Kiểm tra permissions tổng quát
./deployment/check-prerequisites.sh
```

**Lưu ý quan trọng**: 
- Policy name hiện tại là `FieldKitDeploymentPolicyV5` (có thể thay đổi trong script)
- Nếu đã setup policy trước đó, cần cập nhật lại vì policy đã được cải thiện với Resource scope đúng
- Đảm bảo Resource ARN trong policy khớp với repository name pattern: `hieuhk_fieldkit/*`

### Lỗi "Không thể lấy AWS_ACCOUNT_ID từ AWS credentials"

**Nguyên nhân**: AWS CLI chưa được cấu hình với Access Key ID và Secret Access Key.

**Giải pháp**: Xem hướng dẫn chi tiết ở phần [Cách lấy AWS Access Key ID](#yêu-cầu) ở trên.

**Quick Fix:**
```bash
# 1. Lấy Access Key từ AWS Console (xem hướng dẫn ở trên)
# 2. Cấu hình AWS CLI
aws configure

# 3. Kiểm tra credentials
aws sts get-caller-identity

# 4. Chạy lại script
./deployment/setup-timescale-public.sh staging
```

### Lỗi "The config profile (fieldkit) could not be found"

Xem chi tiết trong `deployment/troubleshooting-aws-profile.md`

**Quick Fix:**
```bash
# Option 1: Không dùng AWS_PROFILE (nếu đã có default credentials)
unset AWS_PROFILE
./deployment/build-and-push.sh v1.0.0 staging

# Option 2: Tạo profile
aws configure --profile fieldkit
export AWS_PROFILE="fieldkit"
```

### Images không push được lên ECR
- Kiểm tra AWS credentials: `aws sts get-caller-identity`
- Kiểm tra ECR repository permissions
- Đảm bảo Docker đang chạy

### ECS services không start
- Kiểm tra task definition có đúng không
- Kiểm tra CloudWatch logs cho errors
- Kiểm tra IAM roles có đủ permissions
- Kiểm tra security groups và networking

### Secrets không được load
- Kiểm tra task execution role có permission `secretsmanager:GetSecretValue`
- Kiểm tra secret ARN trong task definition có đúng không
- Kiểm tra secrets tồn tại trong Secrets Manager

## Best Practices

1. **Versioning**: Luôn tag images với version cụ thể, không chỉ dùng `latest`
2. **Health Checks**: Đảm bảo health checks được cấu hình đúng
3. **Logging**: Sử dụng CloudWatch Logs để debug
4. **Secrets**: Không hardcode secrets, luôn dùng Secrets Manager
5. **Rolling Updates**: ECS sẽ tự động thực hiện rolling updates
6. **Resource Limits**: Đặt CPU và memory phù hợp với workload

## Notes

- **Không build trên AWS**: Tất cả images được build local và push lên ECR
- **Immutable Deployments**: Mỗi deployment tạo task definition mới
- **Zero Downtime**: ECS Fargate hỗ trợ rolling updates tự động

