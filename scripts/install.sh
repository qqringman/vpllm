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
    echo "下載 qwen:0.5b 模型..."
    docker exec -it anr_ollama ollama pull qwen:0.5b

    echo "下載 gemma:2b 模型..."
    docker exec -it anr_ollama ollama pull gemma:2b

    echo "下載 mistral:7b 模型..."
    docker exec -it anr_ollama ollama pull mistral:7b

    echo "下載 deepseek-coder:6.7b 模型..."
    docker exec -it anr_ollama ollama pull deepseek-coder:6.7b

    echo "下載 starcoder2:7b 模型..."
    docker exec -it anr_ollama ollama pull starcoder2:7b

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