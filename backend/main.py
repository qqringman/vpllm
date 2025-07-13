import os
import json
import uuid
import logging
from typing import List, Dict, Any, Optional
from datetime import datetime
import asyncio

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import httpx

# 簡化版本 - 不使用 embeddings
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

OLLAMA_URL = os.getenv("OLLAMA_URL", "http://ollama:11434")
UPLOAD_DIR = "/app/uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

app = FastAPI(title="ANR/Tombstone Analysis API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class ChatRequest(BaseModel):
    message: str
    file_ids: List[str] = []
    session_id: str

class ANRAnalyzer:
    def analyze_file(self, content: str, filename: str) -> Dict[str, Any]:
        file_type = "tombstone" if "tombstone" in filename.lower() else "anr"
        
        # 簡單分析
        analysis = {
            "file_type": file_type,
            "lines": len(content.split('\n')),
            "size": len(content)
        }
        
        # 提取關鍵信息
        if "ANR in" in content:
            for line in content.split('\n'):
                if "ANR in" in line:
                    analysis["anr_info"] = line.strip()
                    break
        
        if "signal" in content and "fault addr" in content:
            analysis["crash_detected"] = True
        
        return analysis
    
    def create_chunks(self, content: str, chunk_size: int = 1000) -> List[Dict[str, Any]]:
        lines = content.split('\n')
        chunks = []
        
        for i in range(0, len(lines), 50):  # 每50行一個塊
            chunk_lines = lines[i:i+50]
            chunk_text = '\n'.join(chunk_lines)
            chunks.append({
                "text": chunk_text,
                "start_line": i,
                "end_line": min(i+50, len(lines))
            })
        
        return chunks

analyzer = ANRAnalyzer()

class OllamaService:
    def __init__(self, base_url: str):
        self.base_url = base_url
        self.client = httpx.AsyncClient(timeout=300.0)
    
    async def generate(self, prompt: str, model: str = "mistral:7b") -> str:
        try:
            response = await self.client.post(
                f"{self.base_url}/api/generate",
                json={
                    "model": model,
                    "prompt": prompt,
                    "stream": False
                }
            )
            
            if response.status_code == 200:
                data = response.json()
                return data.get("response", "")
            else:
                return "AI 服務暫時不可用。"
                
        except Exception as e:
            logger.error(f"Ollama error: {e}")
            return f"AI 服務錯誤：{str(e)}"

ollama_service = OllamaService(OLLAMA_URL)
file_storage = {}

@app.get("/")
async def root():
    return {"message": "ANR/Tombstone Analysis API", "version": "1.0.0"}

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "services": {
            "api": "healthy",
            "storage": "healthy"
        }
    }

@app.post("/upload")
async def upload_file(file: UploadFile = File(...)):
    try:
        file_id = str(uuid.uuid4())
        content = await file.read()
        content_str = content.decode('utf-8', errors='ignore')
        
        # 保存文件
        file_path = os.path.join(UPLOAD_DIR, f"{file_id}_{file.filename}")
        with open(file_path, 'wb') as f:
            f.write(content)
        
        # 分析文件
        analysis = analyzer.analyze_file(content_str, file.filename)
        chunks = analyzer.create_chunks(content_str)
        
        # 存儲
        file_storage[file_id] = {
            "file_id": file_id,
            "filename": file.filename,
            "content": content_str[:10000],  # 只保存前10000字符
            "analysis": analysis,
            "chunks": chunks[:20]  # 只保存前20個塊
        }
        
        return {
            "file_id": file_id,
            "filename": file.filename,
            "size": len(content),
            "chunks": len(chunks),
            "file_type": analysis.get("file_type", "unknown"),
            "status": "success"
        }
        
    except Exception as e:
        logger.error(f"Upload error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/chat")
async def chat(request: ChatRequest):
    try:
        context = []
        
        # 添加文件上下文
        if request.file_ids:
            for file_id in request.file_ids:
                if file_id in file_storage:
                    file_info = file_storage[file_id]
                    context.append(f"文件：{file_info['filename']}")
                    context.append(f"類型：{file_info['analysis'].get('file_type', 'unknown')}")
                    
                    # 添加部分內容
                    content_preview = file_info['content'][:2000]
                    context.append(f"內容預覽：\n{content_preview}\n...")
        
        # 構建提示詞
        prompt = f"""你是 Android ANR 和 Tombstone 分析專家。

相關文件信息：
{chr(10).join(context)}

用戶問題：{request.message}

請提供專業的分析和建議："""
        
        # 調用 AI
        response = await ollama_service.generate(prompt)
        
        return {
            "response": response,
            "session_id": request.session_id
        }
        
    except Exception as e:
        logger.error(f"Chat error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
