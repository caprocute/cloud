# Kiến trúc Hệ thống FieldKit Cloud

Tài liệu này mô tả kiến trúc tổng thể của hệ thống FieldKit Cloud, bao gồm các stack công nghệ, vai trò và cách chúng tương tác với nhau.

## Tổng quan

FieldKit Cloud là một nền tảng IoT (Internet of Things) để thu thập, lưu trữ và phân tích dữ liệu từ các thiết bị cảm biến. Hệ thống được xây dựng với kiến trúc microservices, chạy trên AWS cloud infrastructure.

## Kiến trúc Tổng thể

```
┌─────────────────────────────────────────────────────────────────┐
│                        Internet Users                            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              AWS Application Load Balancer (ALB)                  │
│              - Internet-facing                                  │
│              - HTTP/HTTPS routing                               │
│              - Health checks                                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ECS Application Cluster                      │
│              (fieldkit-{env}-app)                               │
│  ┌──────────────────────┐  ┌──────────────────────┐            │
│  │   Server Service      │  │  Charting Service    │            │
│  │   (Go + Vue.js)       │  │  (Node.js)           │            │
│  │   - API endpoints     │  │  - Data visualization│            │
│  │   - Portal SPA        │  │  - Chart generation  │            │
│  └──────────────────────┘  └──────────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ECS Database Cluster                          │
│              (fieldkit-{env}-db-v1)                              │
│  ┌──────────────────────┐  ┌──────────────────────┐            │
│  │   PostgreSQL Service  │  │  TimescaleDB Service │            │
│  │   - Primary database  │  │  - Time-series data │            │
│  │   - PostGIS          │  │  - Aggregations      │            │
│  └──────────────────────┘  └──────────────────────┘            │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│              AWS Network Load Balancer (NLB)                     │
│              - PostgreSQL public access                         │
│              - TCP port 5432                                    │
└─────────────────────────────────────────────────────────────────┘
```

## Stack Công nghệ

### 1. AWS (Amazon Web Services)

#### 1.1. ECS (Elastic Container Service)
**Vai trò**: Container orchestration platform để chạy và quản lý Docker containers

**Cấu hình**:
- **Launch Type**: Fargate (serverless containers)
- **Clusters**:
  - `fieldkit-{env}-app`: Application services (server, charting)
  - `fieldkit-{env}-db-v1`: Database services (PostgreSQL, TimescaleDB)
- **Services**: Tự động quản lý số lượng tasks, health checks, rolling updates
- **Task Definitions**: Định nghĩa container images, resources (CPU/memory), environment variables, secrets

**Lợi ích**:
- Không cần quản lý EC2 instances
- Tự động scaling
- Tích hợp với ALB/NLB
- Service discovery

#### 1.2. ECR (Elastic Container Registry)
**Vai trò**: Private Docker registry để lưu trữ container images

**Cấu trúc**:
- Repository prefix: `hieuhk_fieldkit`
- Images:
  - `hieuhk_fieldkit/server:latest` - Server + Portal
  - `hieuhk_fieldkit/charting:latest` - Charting service
  - `hieuhk_fieldkit/migrations:latest` - Database migrations

**Lợi ích**:
- Tích hợp với ECS
- Image versioning
- Security scanning
- IAM-based access control

#### 1.3. ALB (Application Load Balancer)
**Vai trò**: HTTP/HTTPS load balancer cho application services

**Cấu hình**:
- Scheme: Internet-facing
- Type: Application Load Balancer
- Target Group: `fieldkit-{env}-server-tg`
- Health Check: `/status` endpoint
- Listener: HTTP (port 80)

**Lợi ích**:
- High availability
- SSL/TLS termination
- Path-based routing
- Health checks

#### 1.4. NLB (Network Load Balancer)
**Vai trò**: TCP load balancer cho PostgreSQL database

**Cấu hình**:
- Scheme: Internet-facing
- Type: Network Load Balancer
- Target Group: `fieldkit-{env}-postgres-tg`
- Protocol: TCP (port 5432)
- Health Check: TCP connection

**Lợi ích**:
- Low latency
- Preserve source IP
- High throughput
- TCP passthrough

#### 1.5. Secrets Manager
**Vai trò**: Quản lý secrets và credentials

**Cấu trúc**:
- `fieldkit/{env}/database/postgres` - PostgreSQL connection URL
- `fieldkit/{env}/database/timescale` - TimescaleDB connection URL
- `fieldkit/{env}/database/postgres/password` - PostgreSQL password
- `fieldkit/{env}/database/timescale/password` - TimescaleDB password
- `fieldkit/{env}/session/key` - Session encryption key

**Lợi ích**:
- Automatic rotation
- Encryption at rest
- IAM-based access control
- Audit logging

#### 1.6. CloudWatch Logs
**Vai trò**: Centralized logging cho tất cả services

**Log Groups**:
- `/ecs/fieldkit-server` - Server logs
- `/ecs/fieldkit-charting` - Charting logs
- `/ecs/fieldkit-postgres` - PostgreSQL logs
- `/ecs/fieldkit-timescale` - TimescaleDB logs
- `/ecs/fieldkit-migrations` - Migration logs

**Lợi ích**:
- Centralized logging
- Log retention policies
- Search và filtering
- Integration với CloudWatch alarms

#### 1.7. VPC (Virtual Private Cloud)
**Vai trò**: Network isolation và security

**Cấu hình**:
- Subnets: Public và private subnets
- Security Groups: Firewall rules
- Internet Gateway: Internet access
- NAT Gateway: Outbound internet cho private subnets

**Lợi ích**:
- Network isolation
- Security groups
- Subnet segmentation
- Custom routing

#### 1.8. IAM (Identity and Access Management)
**Vai trò**: Quản lý quyền truy cập và authentication

**Roles**:
- `ecsTaskExecutionRole`: ECS task execution (pull images, access secrets, write logs)
- `ecsTaskRole`: ECS task runtime (access AWS services từ trong container)
- `AWSServiceRoleForECS`: Service-linked role cho ECS

**Policies**:
- `FieldKitDeploymentPolicy`: Quyền cho deployment user/role
- ECR permissions: Push/pull images
- ECS permissions: Create/update services
- Secrets Manager permissions: Read/write secrets
- CloudWatch Logs permissions: Create log groups, write logs

**Lợi ích**:
- Fine-grained access control
- Least privilege principle
- Audit trail
- Role-based access

### 2. Docker

**Vai trò**: Containerization platform để đóng gói và chạy applications

#### 2.1. Multi-stage Builds
**Server Image** (`Dockerfile`):
```dockerfile
# Stage 1: Build Go server
FROM golang:1.22-bookworm AS golang
# Build server binary

# Stage 2: Build Vue.js portal
FROM node:20.9.0 AS node
# Build portal static files

# Stage 3: Final image (scratch - minimal)
FROM scratch
COPY --from=golang /app/server/build/server /
COPY --from=node /app/build /portal
```

**Lợi ích**:
- Small image size (scratch base)
- Separate build stages
- Optimized caching
- Security (minimal attack surface)

#### 2.2. Charting Image (`charting/Dockerfile`)
- Base: `node:20.19.0-bookworm-slim`
- Build tools: `build-essential`, `make`, `g++`, `python3` (cho native modules)
- Dependencies: `canvas`, `vega`, TypeScript

#### 2.3. Migrations Image (`migrations/Dockerfile`)
- Multi-stage: Build Go binary, copy migration files
- Minimal runtime: Ubuntu base với migration binary

**Lợi ích của Docker**:
- Consistent environments
- Isolation
- Portability
- Version control cho dependencies

### 3. Go (Golang)

**Vai trò**: Backend server language

**Cấu trúc**:
- **API Layer**: RESTful API endpoints (Goa framework)
- **Business Logic**: Domain logic, data processing
- **Data Layer**: Database access, repositories
- **Infrastructure**: File storage, email, webhooks

**Frameworks/Libraries**:
- **Goa**: API design framework (code generation)
- **Gorilla Mux**: HTTP router
- **pgx**: PostgreSQL driver
- **Viper**: Configuration management

**Lợi ích**:
- High performance
- Strong typing
- Excellent concurrency
- Small binary size

### 4. Vue.js

**Vai trò**: Frontend framework cho Portal (Single Page Application)

**Cấu trúc**:
- **Components**: Reusable UI components
- **Views**: Page-level components
- **Store**: Vuex state management
- **Router**: Vue Router cho navigation
- **i18n**: Internationalization (English, Spanish, Vietnamese)

**Build Process**:
- Webpack bundling
- TypeScript compilation
- SCSS preprocessing
- Asset optimization (gzip)

**Lợi ích**:
- Reactive UI
- Component-based architecture
- Rich ecosystem
- Developer experience

### 5. Node.js

**Vai trò**: Runtime cho Charting service

**Cấu trúc**:
- **TypeScript**: Type-safe JavaScript
- **Vega**: Visualization library
- **Canvas**: Native image generation
- **Express-like**: HTTP server

**Lợi ích**:
- Rich ecosystem
- Native module support
- Fast development cycle

### 6. PostgreSQL

**Vai trò**: Primary relational database

**Cấu hình**:
- Image: `kartoza/postgis:14-3` (PostGIS extension)
- Database: `fieldkit`
- User: `fieldkit`
- Port: 5432

**Extensions**:
- **PostGIS**: Geographic data support
- **TimescaleDB**: Time-series data (optional, có thể chạy trên instance riêng)

**Schema**:
- `fieldkit` schema: Main application schema
- Migrations: Version-controlled schema changes

**Lợi ích**:
- ACID compliance
- Rich feature set
- Extensibility
- Mature ecosystem

### 7. TimescaleDB

**Vai trò**: Time-series database cho sensor data

**Cấu hình**:
- Image: `timescale/timescaledb:2.4.2-pg13`
- Database: `fk`
- User: `postgres`
- Port: 5432

**Features**:
- Hypertables: Automatic partitioning
- Continuous aggregates: Pre-computed aggregations
- Compression: Automatic data compression
- Retention policies: Automatic data retention

**Lợi ích**:
- Optimized cho time-series data
- High write throughput
- Efficient queries
- Automatic partitioning

### 8. GitLab CI/CD

**Vai trò**: Continuous Integration và Deployment

**Pipeline Stages**:
1. **Build**: Build Docker images
2. **Test**: Run unit tests
3. **Deploy**: Deploy to staging/production

**Tools**:
- **Terraform**: Infrastructure as Code (referenced trong `.gitlab-ci.yml`)
- **Docker**: Build và push images
- **Deployer**: Custom deployment tool

**Lợi ích**:
- Automated testing
- Consistent deployments
- Version control integration
- Rollback capabilities

### 9. Bash Scripts

**Vai trò**: Deployment automation và infrastructure management

**Scripts**:
- `build-and-push.sh`: Build và push Docker images
- `deploy.sh`: Deploy images to ECS
- `create-ecs-services.sh`: Setup ECS infrastructure
- `deploy-database.sh`: Deploy database services
- `setup-load-balancer.sh`: Setup ALB
- `setup-postgres-public.sh`: Setup NLB cho PostgreSQL
- `run-migrations.sh`: Run database migrations
- `setup-iam-policy.sh`: Setup IAM policies

**Lợi ích**:
- Automation
- Consistency
- Error handling
- Documentation (self-documenting scripts)

## Luồng Dữ liệu

### 1. User Request Flow

```
User Browser
    │
    ▼
ALB (Application Load Balancer)
    │
    ▼
ECS Server Service
    │
    ├─→ API Request → Go Handler → Database
    │
    └─→ Portal Request → Static Files (Vue.js SPA)
```

### 2. Data Ingestion Flow

```
IoT Devices
    │
    ▼
Ingestion Endpoint (/ingestion)
    │
    ▼
Go Ingester Service
    │
    ├─→ PostgreSQL (metadata)
    │
    └─→ TimescaleDB (time-series data)
```

### 3. Charting Flow

```
User Request Chart
    │
    ▼
Portal (Vue.js)
    │
    ▼
Charting Service (Node.js)
    │
    ├─→ Query TimescaleDB
    │
    └─→ Generate Chart (Vega/Canvas)
```

## Security

### 1. Network Security
- **Security Groups**: Firewall rules cho services
- **VPC**: Network isolation
- **Private Subnets**: Database services không expose trực tiếp
- **Public Subnets**: Application services với ALB

### 2. Access Control
- **IAM Roles**: Least privilege access
- **Secrets Manager**: Encrypted secrets
- **Session Keys**: Encrypted session data
- **CORS**: Cross-origin resource sharing policies

### 3. Data Security
- **Encryption at Rest**: Secrets Manager, database
- **Encryption in Transit**: HTTPS/TLS
- **Database Passwords**: Stored in Secrets Manager
- **Session Encryption**: AES encryption

## Scalability

### 1. Horizontal Scaling
- **ECS Services**: Auto-scaling based on CPU/memory
- **ALB**: Distribute traffic across multiple tasks
- **Database**: Read replicas (có thể thêm)

### 2. Vertical Scaling
- **Task Resources**: CPU/memory có thể tăng
- **Database**: Instance size có thể tăng

### 3. Caching
- **Browser Cache**: Static assets
- **CDN**: Có thể thêm CloudFront
- **Application Cache**: In-memory caching (có thể thêm Redis)

## Monitoring & Logging

### 1. CloudWatch Logs
- Centralized logging
- Log retention policies
- Search và filtering

### 2. Health Checks
- **ALB Health Checks**: `/status` endpoint
- **ECS Health Checks**: Container health
- **Database Health Checks**: `pg_isready`

### 3. Metrics
- **ECS Metrics**: CPU, memory, task count
- **ALB Metrics**: Request count, latency
- **Database Metrics**: Connection count, query performance

## Deployment Process

### 1. Build Phase
```bash
./deployment/build-and-push.sh <VERSION> <ENV>
```
- Build Docker images
- Tag với version
- Push lên ECR

### 2. Deploy Phase
```bash
./deployment/deploy.sh <VERSION> <ENV>
```
- Update task definitions
- Update ECS services
- Rolling deployment

### 3. Migration Phase
```bash
./deployment/run-migrations.sh <ENV>
# hoặc
./deployment/run-migrations-local.sh <ENV>
```
- Run database migrations
- Verify migration success

## Environment Variables

### Server Service
- `FIELDKIT_ADDR`: Server address (default: `:80`)
- `FIELDKIT_HTTP_SCHEME`: HTTP scheme (default: `https`)
- `FIELDKIT_PORTAL_ROOT`: Portal root path (default: `/portal`)
- `FIELDKIT_POSTGRES_URL`: PostgreSQL connection URL (from Secrets Manager)
- `FIELDKIT_TIME_SCALE_URL`: TimescaleDB connection URL (from Secrets Manager)
- `FIELDKIT_SESSION_KEY`: Session encryption key (from Secrets Manager)

### Database Services
- `POSTGRES_DB`: Database name
- `POSTGRES_USER`: Database user
- `POSTGRES_PASSWORD`: Database password (from Secrets Manager)

## Best Practices

### 1. Version Control
- Git cho source code
- Docker image tags cho versions
- Task definition revisions

### 2. Configuration Management
- Environment variables cho configuration
- Secrets Manager cho sensitive data
- Namespace-based secrets (`fieldkit/{env}/...`)

### 3. Error Handling
- Graceful degradation
- Retry logic
- Error logging
- Health checks

### 4. Security
- Least privilege IAM policies
- Encrypted secrets
- Network isolation
- Regular security updates

## Tài liệu Tham khảo

- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Docker Documentation](https://docs.docker.com/)
- [Go Documentation](https://golang.org/doc/)
- [Vue.js Documentation](https://vuejs.org/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [TimescaleDB Documentation](https://docs.timescale.com/)

## Liên hệ

Để biết thêm thông tin về kiến trúc hoặc deployment, xem:
- `deployment/README.md`: Hướng dẫn deployment chi tiết
- `README.md`: Hướng dẫn setup local development

