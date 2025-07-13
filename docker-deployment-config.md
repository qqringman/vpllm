# Docker 部署配置和安裝指南

## 1. 項目結構

```
anr-analyzer/
├── docker-compose.yml
├── .env.example
├── .env
├── nginx/
│   └── nginx.conf
├── backend/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── main.py
│   └── ...
├── frontend/
│   ├── Dockerfile
│   ├── package.json
│   ├── src/
│   │   └── App.tsx
│   └── ...
├── scripts/
│   ├── install.sh
│   ├── start.sh
│   └── stop.sh
└── README.md
```

## 2. Docker Compose 配置

### docker-compose.yml
```yaml
version: '3.9'

services:
  # Nginx 反向代理
  nginx:
    image: nginx:alpine
    container_name: anr_nginx
    ports:
      - "${API_PORT:-8080}:80"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - backend
      - frontend
    networks:
      - anr_network
    restart: unless-stopped

  # 前端服務
  frontend:
    build:
      context: ./frontend
      dockerfile: Dockerfile
    container_name: anr_frontend
    environment:
      - NEXT_PUBLIC_API_URL=${API_URL:-http://localhost:8080}
      - NODE_ENV=production
    volumes:
      - ./frontend:/app
      - /app/node_modules
      - /app/.next
    networks:
      - anr_network
    restart: unless-stopped

  # 後端 API 服務
  backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    container_name: anr_backend
    environment:
      - DATABASE_URL=postgresql+asyncpg://${DB_USER}:${DB_PASSWORD}@postgres:5432/${DB_NAME}
      - REDIS_URL=redis://redis:6379
      - OLLAMA_URL=http://ollama:11434
      - QDRANT_URL=http://qdrant:6333
      - MINIO_ENDPOINT=minio:9000
      - MINIO_ACCESS_KEY=${MINIO_USER}
      - MINIO_SECRET_KEY=${MINIO_PASSWORD}
      - PYTHONUNBUFFERED=1
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
      qdrant:
        condition: service_started
      ollama:
        condition: service_started
    volumes:
      - ./backend:/app
      - backend_cache:/root/.cache
    networks:
      - anr_network
    restart: unless-stopped

  # Ollama LLM 服務
  ollama:
    image: ollama/ollama:latest
    container_name: anr_ollama
    ports:
      - "${OLLAMA_PORT:-11434}:11434"
    volumes:
      - ollama_data:/root/.ollama
    environment:
      - OLLAMA_KEEP_ALIVE=24h
      - OLLAMA_HOST=0.0.0.0
    networks:
      - anr_network
    restart: unless-stopped
    deploy:
      resources:
        limits:
          memory: 8G
        reservations:
          memory: 4G

  # Qdrant 向量數據庫
  qdrant:
    image: qdrant/qdrant:latest
    container_name: anr_qdrant
    ports:
      - "${QDRANT_PORT:-6333}:6333"
      - "${QDRANT_GRPC_PORT:-6334}:6334"
    volumes:
      - qdrant_data:/qdrant/storage
    environment:
      - QDRANT__LOG_LEVEL=INFO
    networks:
      - anr_network
    restart: unless-stopped

  # PostgreSQL 數據庫
  postgres:
    image: postgres:15-alpine
    container_name: anr_postgres
    environment:
      - POSTGRES_DB=${DB_NAME}
      - POSTGRES_USER=${DB_USER}
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - PGDATA=/var/lib/postgresql/data/pgdata
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "${DB_PORT:-5432}:5432"
    networks:
      - anr_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d ${DB_NAME}"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Redis 緩存
  redis:
    image: redis:7-alpine
    container_name: anr_redis
    command: redis-server --appendonly yes --maxmemory 512mb --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data
    ports:
      - "${REDIS_PORT:-6379}:6379"
    networks:
      - anr_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # MinIO 對象存儲
  minio:
    image: minio/minio:latest
    container_name: anr_minio
    command: server /data --console-address ":9001"
    environment:
      - MINIO_ROOT_USER=${MINIO_USER}
      - MINIO_ROOT_PASSWORD=${MINIO_PASSWORD}
    volumes:
      - minio_data:/data
    ports:
      - "${MINIO_PORT:-9000}:9000"
      - "${MINIO_CONSOLE_PORT:-9001}:9001"
    networks:
      - anr_network
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/minio/health/live"]
      interval: 30s
      timeout: 20s
      retries: 3

  # RabbitMQ 消息隊列（可選）
  rabbitmq:
    image: rabbitmq:3-management-alpine
    container_name: anr_rabbitmq
    environment:
      - RABBITMQ_DEFAULT_USER=${RABBITMQ_USER:-admin}
      - RABBITMQ_DEFAULT_PASS=${RABBITMQ_PASSWORD:-password}
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    ports:
      - "${RABBITMQ_PORT:-5672}:5672"
      - "${RABBITMQ_MANAGEMENT_PORT:-15672}:15672"
    networks:
      - anr_network
    restart: unless-stopped

volumes:
  ollama_data:
    driver: local
  qdrant_data:
    driver: local
  postgres_data:
    driver: local
  redis_data:
    driver: local
  minio_data:
    driver: local
  rabbitmq_data:
    driver: local
  backend_cache:
    driver: local

networks:
  anr_network:
    driver: bridge
```

## 3. 環境變量配置

### .env.example
```bash
# API 配置
API_PORT=8080
API_URL=http://localhost:8080

# 數據庫配置
DB_NAME=anr_analysis
DB_USER=postgres
DB_PASSWORD=your_secure_password_here
DB_PORT=5432

# Redis 配置
REDIS_PORT=6379

# Ollama 配置
OLLAMA_PORT=11434

# Qdrant 配置
QDRANT_PORT=6333
QDRANT_GRPC_PORT=6334

# MinIO 配置
MINIO_USER=minioadmin
MINIO_PASSWORD=your_minio_password_here
MINIO_PORT=9000
MINIO_CONSOLE_PORT=9001

# RabbitMQ 配置（可選）
RABBITMQ_USER=admin
RABBITMQ_PASSWORD=your_rabbitmq_password_here
RABBITMQ_PORT=5672
RABBITMQ_MANAGEMENT_PORT=15672

# 外部服務配置
WIKI_API_URL=https://your-wiki.com/api
OUTLOOK_CLIENT_ID=your_outlook_client_id
OUTLOOK_CLIENT_SECRET=your_outlook_client_secret
GERRIT_URL=https://your-gerrit.com
GERRIT_USER=your_gerrit_user
GERRIT_PASSWORD=your_gerrit_password
JIRA_URL=https://your-jira.com
JIRA_USER=your_jira_user
JIRA_API_TOKEN=your_jira_api_token
```

## 4. Nginx 配置

### nginx/nginx.conf
```nginx
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;

    # Gzip 壓縮
    gzip on;
    gzip_vary on;
    gzip_min_length 10240;
    gzip_proxied expired no-cache no-store private auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml;
    gzip_disable "MSIE [1-6]\.";

    # 上游服務器
    upstream backend {
        server backend:8000;
    }

    upstream frontend {
        server frontend:3000;
    }

    # 主服務器配置
    server {
        listen 80;
        server_name localhost;

        # API 路由
        location /api/ {
            proxy_pass http://backend/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
        }

        # WebSocket 路由
        location /ws/ {
            proxy_pass http://backend/ws/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_read_timeout 86400;
        }

        # 前端路由
        location / {
            proxy_pass http://frontend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host $host;
            proxy_cache_bypass $http_upgrade;
        }

        # 健康檢查
        location /health {
            access_log off;
            return 200 "healthy\n";
        }
    }
}
```

## 5. 後端 Dockerfile

### backend/Dockerfile
```dockerfile
FROM python:3.12-slim

# 設置工作目錄
WORKDIR /app

# 安裝系統依賴
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    build-essential \
    libpq-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 複製 requirements.txt
COPY requirements.txt .

# 安裝 Python 依賴
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# 複製應用代碼
COPY . .

# 暴露端口
EXPOSE 8000

# 啟動命令
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
```

### backend/requirements.txt
```txt
fastapi==0.111.0
uvicorn[standard]==0.30.1
httpx==0.27.0
redis[hiredis]==5.0.1
asyncpg==0.29.0
sqlalchemy==2.0.23
alembic==1.13.1
pydantic==2.5.3
python-multipart==0.0.6
aiofiles==23.2.1
numpy==1.26.4
sentence-transformers==3.0.1
qdrant-client==1.7.0
minio==7.2.0
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
python-dotenv==1.0.0
```

## 6. 前端 Dockerfile

### frontend/Dockerfile
```dockerfile
FROM node:20-alpine AS builder

# 設置工作目錄
WORKDIR /app

# 複製 package.json 和 package-lock.json
COPY package*.json ./

# 安裝依賴
RUN npm ci

# 複製源代碼
COPY . .

# 構建應用
RUN npm run build

# 生產階段
FROM node:20-alpine

WORKDIR /app

# 複製構建結果和必要文件
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/package*.json ./
COPY --from=builder /app/next.config.js ./

# 只安裝生產依賴
RUN npm ci --only=production

# 暴露端口
EXPOSE 3000

# 啟動命令
CMD ["npm", "start"]
```

### frontend/package.json
```json
{
  "name": "anr-analyzer-frontend",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "14.0.4",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "lucide-react": "^0.303.0",
    "tailwindcss": "^3.4.0",
    "autoprefixer": "^10.4.16",
    "postcss": "^8.4.32",
    "@tailwindcss/typography": "^0.5.10",
    "clsx": "^2.0.0"
  },
  "devDependencies": {
    "@types/node": "^20.10.5",
    "@types/react": "^18.2.45",
    "@types/react-dom": "^18.2.18",
    "typescript": "^5.3.3",
    "eslint": "^8.56.0",
    "eslint-config-next": "14.0.4"
  }
}
```

## 7. 安裝腳本

### scripts/install.sh
```bash
#!/bin/bash

set -e

echo "========================================="
echo "ANR/Tombstone 分析系統安裝腳本"
echo "========================================="

# 檢查 Docker 和 Docker Compose
check_requirements() {
    echo "檢查系統需求..."
    
    if ! command -v docker &> /dev/null; then
        echo "錯誤：未找到 Docker，請先安裝 Docker"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        echo "錯誤：未找到 Docker Compose，請先安裝 Docker Compose"
        exit 1
    fi
    
    echo "✓ Docker 和 Docker Compose 已安裝"
}

# 配置環境變量
setup_env() {
    echo "配置環境變量..."
    
    if [ ! -f .env ]; then
        cp .env.example .env
        echo "✓ 已創建 .env 文件，請編輯並設置密碼"
        echo "  運行: nano .env"
        exit 0
    fi
    
    echo "✓ 環境變量已配置"
}

# 創建必要的目錄
create_directories() {
    echo "創建必要的目錄..."
    
    mkdir -p nginx
    mkdir -p backend
    mkdir -p frontend/src
    mkdir -p scripts
    
    echo "✓ 目錄結構已創建"
}

# 下載 Ollama 模型
download_models() {
    echo "下載 Ollama 模型..."
    
    # 啟動 Ollama 服務
    docker-compose up -d ollama
    
    # 等待服務啟動
    echo "等待 Ollama 服務啟動..."
    sleep 10
    
    # 下載模型
    echo "下載 mistral:7b 模型..."
    docker exec -it anr_ollama ollama pull mistral:7b
    
    echo "下載 codellama:7b 模型（可選）..."
    docker exec -it anr_ollama ollama pull codellama:7b || true
    
    echo "✓ 模型下載完成"
}

# 初始化數據庫
init_database() {
    echo "初始化數據庫..."
    
    # 啟動數據庫服務
    docker-compose up -d postgres redis qdrant
    
    # 等待服務啟動
    echo "等待數據庫服務啟動..."
    sleep 15
    
    echo "✓ 數據庫初始化完成"
}

# 主安裝流程
main() {
    check_requirements
    setup_env
    create_directories
    
    echo ""
    echo "開始安裝服務..."
    
    # 構建鏡像
    echo "構建 Docker 鏡像..."
    docker-compose build
    
    # 啟動基礎服務
    init_database
    
    # 下載模型
    download_models
    
    # 啟動所有服務
    echo "啟動所有服務..."
    docker-compose up -d
    
    echo ""
    echo "========================================="
    echo "✓ 安裝完成！"
    echo ""
    echo "訪問地址："
    echo "  - 主應用：http://localhost:8080"
    echo "  - Ollama API：http://localhost:11434"
    echo "  - MinIO 控制台：http://localhost:9001"
    echo "  - RabbitMQ 管理界面：http://localhost:15672"
    echo ""
    echo "使用以下命令管理服務："
    echo "  - 啟動：./scripts/start.sh"
    echo "  - 停止：./scripts/stop.sh"
    echo "  - 查看日誌：docker-compose logs -f [service_name]"
    echo "========================================="
}

# 運行主函數
main
```

### scripts/start.sh
```bash
#!/bin/bash

echo "啟動 ANR/Tombstone 分析系統..."
docker-compose up -d

echo ""
echo "檢查服務狀態..."
docker-compose ps

echo ""
echo "服務已啟動！"
echo "主應用地址：http://localhost:8080"
```

### scripts/stop.sh
```bash
#!/bin/bash

echo "停止 ANR/Tombstone 分析系統..."
docker-compose down

echo ""
echo "服務已停止！"
```

## 8. 快速開始指南

### 8.1 系統需求
- Ubuntu 20.04 或更高版本
- Docker 20.10+
- Docker Compose 2.0+
- 至少 16GB RAM（建議 32GB）
- 至少 50GB 可用磁盤空間

### 8.2 安裝步驟

```bash
# 1. 克隆項目
git clone https://github.com/your-org/anr-analyzer.git
cd anr-analyzer

# 2. 設置執行權限
chmod +x scripts/*.sh

# 3. 運行安裝腳本
./scripts/install.sh

# 4. 編輯環境變量
nano .env

# 5. 重新啟動服務
./scripts/start.sh
```

### 8.3 驗證安裝

```bash
# 檢查服務狀態
docker-compose ps

# 查看日誌
docker-compose logs -f backend

# 測試 API
curl http://localhost:8080/api/health
```

### 8.4 使用系統

1. 打開瀏覽器訪問 http://localhost:8080
2. 上傳 ANR 或 Tombstone 文件
3. 使用快速操作按鈕或輸入問題開始分析
4. 查看分析結果和建議

## 9. 維護和監控

### 9.1 備份數據

```bash
# 備份 PostgreSQL
docker exec anr_postgres pg_dump -U postgres anr_analysis > backup.sql

# 備份向量數據庫
docker cp anr_qdrant:/qdrant/storage ./qdrant_backup

# 備份 MinIO 數據
docker cp anr_minio:/data ./minio_backup
```

### 9.2 更新系統

```bash
# 拉取最新代碼
git pull

# 重新構建
docker-compose build

# 重啟服務
docker-compose down
docker-compose up -d
```

### 9.3 查看日誌

```bash
# 查看所有日誌
docker-compose logs -f

# 查看特定服務日誌
docker-compose logs -f backend
docker-compose logs -f ollama
```

### 9.4 性能調優

1. **調整 Ollama 內存**：編輯 docker-compose.yml 中的內存限制
2. **優化 PostgreSQL**：調整 shared_buffers 和 work_mem
3. **Redis 緩存策略**：根據使用情況調整 maxmemory-policy
4. **Nginx 優化**：調整 worker_connections 和緩存設置

## 10. 故障排除

### 常見問題

1. **Ollama 模型下載失敗**
   ```bash
   # 手動下載
   docker exec -it anr_ollama ollama pull mistral:7b
   ```

2. **數據庫連接錯誤**
   ```bash
   # 檢查數據庫狀態
   docker-compose logs postgres
   # 重啟數據庫
   docker-compose restart postgres
   ```

3. **內存不足**
   ```bash
   # 查看內存使用
   docker stats
   # 調整 Docker 內存限制
   ```

4. **端口衝突**
   - 編輯 .env 文件修改端口配置

## 11. 安全建議

1. **修改默認密碼**：必須修改 .env 中的所有默認密碼
2. **配置防火牆**：只開放必要的端口
3. **使用 HTTPS**：在生產環境配置 SSL 證書
4. **定期更新**：保持 Docker 鏡像和依賴更新
5. **訪問控制**：配置 API 認證和授權

## 12. 擴展部署

### Kubernetes 部署（可選）
- 使用 Helm Chart 管理部署
- 配置 HPA 自動擴縮容
- 使用 Istio 進行服務網格管理

### 監控系統（可選）
- Prometheus + Grafana 監控
- ELK Stack 日誌分析
- Jaeger 分佈式追蹤