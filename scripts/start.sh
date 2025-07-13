#!/bin/bash

echo "啟動 ANR/Tombstone 分析系統..."
docker-compose up -d

echo ""
echo "檢查服務狀態..."
docker-compose ps

echo ""
echo "服務已啟動！"
echo "主應用地址：http://localhost:8080"