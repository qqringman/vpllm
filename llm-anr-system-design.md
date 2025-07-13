# ANR/Tombstone 智能分析系統設計文檔

## 1. 系統架構概覽

```
┌─────────────────────────────────────────────────────────────┐
│                         前端應用層                           │
│            (React/Next.js - ChatGPT 風格 UI)               │
├─────────────────────────────────────────────────────────────┤
│                      API Gateway                            │
│                  (Kong/Nginx + Auth)                        │
├──────────────┬──────────────┬──────────────┬───────────────┤
│   文件處理   │   RAG 檢索   │  LLM 推理   │  外部整合     │
│   服務       │   服務       │   服務      │   服務        │
│ (FastAPI)    │ (FastAPI)    │ (Ollama)    │ (FastAPI)     │
├──────────────┴──────────────┴──────────────┴───────────────┤
│                      消息隊列層                             │
│                  (RabbitMQ/Redis)                           │
├─────────────────────────────────────────────────────────────┤
│                      數據存儲層                             │
│   PostgreSQL │ Qdrant/Weaviate │ MinIO │ Redis Cache      │
└─────────────────────────────────────────────────────────────┘
```

## 2. 核心組件設計

### 2.1 文件處理服務
```python
# 智能 Chunking 策略
class ANRChunkingStrategy:
    - 基於日誌結構的智能分塊
    - 保留上下文關係
    - 支援 ANR/Tombstone 特定格式
    - 塊大小：512-1024 tokens
```

### 2.2 RAG 檢索服務
```python
# 向量化和檢索
class RAGService:
    - 嵌入模型：sentence-transformers/all-MiniLM-L6-v2
    - 向量數據庫：Qdrant（輕量級，適合無 GPU）
    - 混合檢索：向量 + 關鍵詞
    - 重排序：Cross-encoder
```

### 2.3 LLM 推理服務
```python
# Ollama 模型配置
models = {
    "primary": "mistral:7b",      # 主模型
    "code": "codellama:7b",       # 程式碼分析
    "fast": "qwen2:0.5b"          # 快速回應
}
```

### 2.4 外部整合服務
```yaml
integrations:
  - wiki: MediaWiki API
  - outlook: Microsoft Graph API
  - gerrit: Gerrit REST API
  - jira: Atlassian REST API
```

## 3. 技術棧選擇

### 後端技術
- **框架**: FastAPI (async, 高效能)
- **LLM**: Ollama (本地部署，無需 GPU)
- **向量DB**: Qdrant (輕量級，效能好)
- **文件存儲**: MinIO (S3 兼容)
- **數據庫**: PostgreSQL (元數據)
- **緩存**: Redis (上下文記憶)
- **消息隊列**: RabbitMQ (異步處理)

### 前端技術
- **框架**: Next.js 14 (React)
- **UI**: Tailwind CSS + shadcn/ui
- **狀態管理**: Zustand
- **WebSocket**: Socket.io (流式回應)

## 4. 核心功能實現

### 4.1 智能 Chunking
```python
def chunk_anr_file(content: str) -> List[Chunk]:
    """ANR/Tombstone 專用分塊策略"""
    chunks = []
    
    # 1. 識別關鍵區塊
    sections = {
        "header": extract_header(content),
        "main_thread": extract_main_thread(content),
        "stack_traces": extract_stack_traces(content),
        "system_info": extract_system_info(content)
    }
    
    # 2. 基於重要性分配權重
    for section, weight in section_weights.items():
        chunks.extend(
            create_chunks(sections[section], 
                        max_tokens=1024,
                        overlap=128,
                        weight=weight)
        )
    
    return chunks
```

### 4.2 分步 Prompt 策略
```python
class ANRAnalysisPrompt:
    steps = [
        "1. 識別錯誤類型和關鍵線程",
        "2. 分析調用棧和死鎖情況", 
        "3. 定位根本原因",
        "4. 提供解決建議",
        "5. 給出預防措施"
    ]
    
    def generate_prompt(self, context: str, step: int):
        return f"""
        分析以下 ANR/Tombstone 日誌：
        {context}
        
        請執行第 {step} 步：{self.steps[step-1]}
        """
```

### 4.3 流式回應實現
```python
async def stream_response(query: str, context: List[str]):
    """WebSocket 流式回應"""
    async for chunk in ollama.generate_stream(
        model="mistral:7b",
        prompt=build_prompt(query, context),
        stream=True
    ):
        await websocket.send_json({
            "type": "chunk",
            "content": chunk
        })
```

## 5. Docker 部署架構

### 5.1 docker-compose.yml
```yaml
version: '3.9'

services:
  # API Gateway
  nginx:
    image: nginx:alpine
    ports:
      - "${API_PORT:-8080}:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
    depends_on:
      - backend
      - frontend

  # 前端服務
  frontend:
    build: ./frontend
    environment:
      - NEXT_PUBLIC_API_URL=${API_URL}
    volumes:
      - ./frontend:/app

  # 後端服務
  backend:
    build: ./backend
    environment:
      - DATABASE_URL=${DATABASE_URL}
      - REDIS_URL=${REDIS_URL}
      - OLLAMA_URL=${OLLAMA_URL}
    depends_on:
      - postgres
      - redis
      - qdrant

  # Ollama 服務
  ollama:
    image: ollama/ollama:latest
    volumes:
      - ollama_data:/root/.ollama
    ports:
      - "${OLLAMA_PORT:-11434}:11434"

  # 向量數據庫
  qdrant:
    image: qdrant/qdrant:latest
    ports:
      - "${QDRANT_PORT:-6333}:6333"
    volumes:
      - qdrant_data:/qdrant/storage

  # PostgreSQL
  postgres:
    image: postgres:15-alpine
    environment:
      - POSTGRES_DB=${DB_NAME}
      - POSTGRES_USER=${DB_USER}
      - POSTGRES_PASSWORD=${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data

  # Redis
  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes
    volumes:
      - redis_data:/data

  # MinIO
  minio:
    image: minio/minio:latest
    command: server /data --console-address ":9001"
    environment:
      - MINIO_ROOT_USER=${MINIO_USER}
      - MINIO_ROOT_PASSWORD=${MINIO_PASSWORD}
    volumes:
      - minio_data:/data

volumes:
  ollama_data:
  qdrant_data:
  postgres_data:
  redis_data:
  minio_data:
```

### 5.2 集中配置管理 (.env)
```bash
# API 配置
API_PORT=8080
API_URL=http://localhost:8080

# 數據庫配置
DB_NAME=anr_analysis
DB_USER=postgres
DB_PASSWORD=secure_password
DATABASE_URL=postgresql://postgres:secure_password@postgres:5432/anr_analysis

# Redis 配置
REDIS_URL=redis://redis:6379

# Ollama 配置
OLLAMA_URL=http://ollama:11434
OLLAMA_PORT=11434

# Qdrant 配置
QDRANT_PORT=6333
QDRANT_URL=http://qdrant:6333

# MinIO 配置
MINIO_USER=admin
MINIO_PASSWORD=secure_minio_password
MINIO_ENDPOINT=minio:9000

# 外部服務配置
WIKI_API_URL=https://wiki.company.com/api
OUTLOOK_CLIENT_ID=your_client_id
GERRIT_URL=https://gerrit.company.com
JIRA_URL=https://jira.company.com
```

## 6. 性能優化策略

### 6.1 無 GPU 優化
```python
# 1. 使用量化模型
ollama pull mistral:7b-q4_0  # 4-bit 量化

# 2. 批處理推理
batch_size = 4
responses = await ollama.batch_generate(prompts[:batch_size])

# 3. 緩存策略
@cache(expire=3600)
async def get_embedding(text: str):
    return await embedding_model.encode(text)
```

### 6.2 大文件處理
```python
class LargeFileProcessor:
    def __init__(self, chunk_size=1024*1024):  # 1MB chunks
        self.chunk_size = chunk_size
    
    async def process_file(self, file_path: str):
        # 1. 流式讀取
        async with aiofiles.open(file_path, 'rb') as f:
            while chunk := await f.read(self.chunk_size):
                await self.process_chunk(chunk)
        
        # 2. 並行處理
        tasks = [
            self.analyze_section(section) 
            for section in self.sections
        ]
        results = await asyncio.gather(*tasks)
```

## 7. UI 設計 (ChatGPT 風格)

### 7.1 主要組件
```tsx
// 聊天界面
<ChatInterface>
  <MessageList messages={messages} />
  <FileUpload onUpload={handleFileUpload} />
  <QuickActions suggestions={suggestions} />
  <InputArea onSubmit={handleSubmit} />
</ChatInterface>

// 主題切換
<ThemeToggle 
  defaultTheme="dark"
  themes={["dark", "light"]}
/>
```

### 7.2 快速建議按鈕
```tsx
const quickSuggestions = [
  "分析主線程阻塞原因",
  "查找死鎖情況",
  "生成修復建議",
  "檢查系統資源使用"
];
```

## 8. 上下文記憶實現

```python
class ContextMemory:
    def __init__(self, redis_client):
        self.redis = redis_client
        self.max_context_length = 4096
    
    async def add_message(self, session_id: str, message: dict):
        key = f"context:{session_id}"
        await self.redis.lpush(key, json.dumps(message))
        await self.redis.ltrim(key, 0, 20)  # 保留最近20條
        await self.redis.expire(key, 3600)  # 1小時過期
    
    async def get_context(self, session_id: str) -> List[dict]:
        key = f"context:{session_id}"
        messages = await self.redis.lrange(key, 0, -1)
        return [json.loads(m) for m in messages]
```

## 9. 外部服務整合架構

```python
class ExternalIntegration:
    async def search_wiki(self, query: str):
        # MediaWiki API 整合
        pass
    
    async def search_outlook(self, query: str):
        # Microsoft Graph API
        pass
    
    async def search_gerrit(self, query: str):
        # Gerrit REST API
        pass
    
    async def search_jira(self, query: str):
        # Atlassian REST API
        pass
```

## 10. 擴展性設計

### 10.1 水平擴展
- 使用 Kubernetes 部署
- 服務網格 (Istio)
- 自動擴縮容 (HPA)

### 10.2 模組化架構
- 微服務設計
- 事件驅動架構
- 插件系統支援

## 11. 監控和維護

```yaml
monitoring:
  - prometheus: 指標收集
  - grafana: 視覺化監控
  - elk_stack: 日誌分析
  - jaeger: 分散式追蹤
```

## 12. 快速啟動指南

```bash
# 1. 克隆專案
git clone https://github.com/your-org/anr-analyzer
cd anr-analyzer

# 2. 配置環境變量
cp .env.example .env
# 編輯 .env 文件

# 3. 啟動服務
docker-compose up -d

# 4. 初始化模型
docker exec -it ollama ollama pull mistral:7b

# 5. 訪問系統
# http://localhost:8080
```