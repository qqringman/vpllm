FROM node:20-alpine
WORKDIR /app
RUN npm install -g http-server
RUN mkdir -p /app/public && \
    echo '<!DOCTYPE html><html><head><title>ANR Analyzer</title><style>body{font-family:Arial,sans-serif;margin:0;padding:20px;background:#f5f5f5}.container{max-width:800px;margin:0 auto;background:white;padding:30px;border-radius:10px;box-shadow:0 2px 10px rgba(0,0,0,0.1)}h1{color:#333;text-align:center}p{color:#666;text-align:center}.status{background:#e3f2fd;padding:15px;border-radius:5px;margin:20px 0}</style></head><body><div class="container"><h1>ANR/Tombstone 分析系統</h1><div class="status"><p>✅ 前端服務運行中</p><p>📡 API: http://localhost:8080/api</p></div></div></body></html>' > /app/public/index.html
EXPOSE 3000
CMD ["http-server", "public", "-p", "3000", "-a", "0.0.0.0"]
