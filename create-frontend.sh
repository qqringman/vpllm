#!/bin/bash

echo "🎨 創建前端文件..."

# 確保目錄存在
mkdir -p frontend/public

# 創建 index.html
cat > frontend/public/index.html << 'HTML_EOF'
<!DOCTYPE html>
<html lang="zh-TW">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ANR/Tombstone 智能分析系統</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #f5f5f5; min-height: 100vh; display: flex; flex-direction: column; }
        .header { background: #1976d2; color: white; padding: 1rem 2rem; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .header h1 { font-size: 1.5rem; font-weight: 500; }
        .main-container { flex: 1; display: flex; max-width: 1400px; width: 100%; margin: 0 auto; gap: 2rem; padding: 2rem; }
        .left-panel { width: 350px; background: white; border-radius: 8px; padding: 1.5rem; box-shadow: 0 2px 8px rgba(0,0,0,0.1); height: fit-content; }
        .upload-area { border: 2px dashed #ccc; border-radius: 8px; padding: 2rem; text-align: center; cursor: pointer; transition: all 0.3s; }
        .upload-area:hover { border-color: #1976d2; background: #f0f7ff; }
        .upload-area.dragover { border-color: #1976d2; background: #e3f2fd; }
        .file-input { display: none; }
        .upload-icon { font-size: 3rem; color: #666; margin-bottom: 1rem; }
        .uploaded-files { margin-top: 1.5rem; }
        .file-item { background: #f5f5f5; padding: 0.75rem; border-radius: 4px; margin-bottom: 0.5rem; display: flex; justify-content: space-between; align-items: center; }
        .file-name { font-size: 0.9rem; color: #333; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; flex: 1; }
        .file-size { font-size: 0.8rem; color: #666; margin-left: 1rem; }
        .right-panel { flex: 1; background: white; border-radius: 8px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); display: flex; flex-direction: column; overflow: hidden; }
        .chat-header { padding: 1rem 1.5rem; border-bottom: 1px solid #eee; background: #fafafa; }
        .chat-messages { flex: 1; padding: 1.5rem; overflow-y: auto; max-height: 600px; }
        .message { margin-bottom: 1.5rem; display: flex; gap: 1rem; }
        .message.user { flex-direction: row-reverse; }
        .message-avatar { width: 36px; height: 36px; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-size: 1rem; flex-shrink: 0; }
        .message.user .message-avatar { background: #1976d2; color: white; }
        .message.assistant .message-avatar { background: #4caf50; color: white; }
        .message-content { max-width: 70%; padding: 0.75rem 1rem; border-radius: 8px; line-height: 1.5; white-space: pre-wrap; }
        .message.user .message-content { background: #1976d2; color: white; }
        .message.assistant .message-content { background: #f5f5f5; color: #333; }
        .chat-input-container { padding: 1.5rem; border-top: 1px solid #eee; background: #fafafa; }
        .chat-input-wrapper { display: flex; gap: 1rem; }
        .chat-input { flex: 1; padding: 0.75rem 1rem; border: 1px solid #ddd; border-radius: 24px; outline: none; font-size: 1rem; resize: none; max-height: 120px; }
        .chat-input:focus { border-color: #1976d2; }
        .send-button { background: #1976d2; color: white; border: none; border-radius: 50%; width: 44px; height: 44px; display: flex; align-items: center; justify-content: center; cursor: pointer; transition: background 0.3s; }
        .send-button:hover { background: #1565c0; }
        .send-button:disabled { background: #ccc; cursor: not-allowed; }
        .quick-actions { margin-top: 1.5rem; padding-top: 1.5rem; border-top: 1px solid #eee; }
        .quick-actions h3 { font-size: 0.9rem; color: #666; margin-bottom: 1rem; }
        .action-button { display: block; width: 100%; padding: 0.75rem; margin-bottom: 0.5rem; background: #f5f5f5; border: 1px solid #e0e0e0; border-radius: 6px; text-align: left; cursor: pointer; transition: all 0.3s; font-size: 0.9rem; }
        .action-button:hover { background: #e3f2fd; border-color: #1976d2; }
        .loading { display: inline-block; width: 20px; height: 20px; border: 3px solid #f3f3f3; border-top: 3px solid #1976d2; border-radius: 50%; animation: spin 1s linear infinite; }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
        .error { background: #ffebee; color: #c62828; padding: 0.5rem 1rem; border-radius: 4px; margin: 0.5rem 0; }
    </style>
</head>
<body>
    <div class="header">
        <h1>🔍 ANR/Tombstone 智能分析系統</h1>
    </div>
    
    <div class="main-container">
        <div class="left-panel">
            <h2 style="margin-bottom: 1rem;">上傳文件</h2>
            <div class="upload-area" id="uploadArea">
                <input type="file" id="fileInput" class="file-input" accept=".txt,.log,.anr,.tombstone" multiple>
                <div class="upload-icon">📁</div>
                <p>點擊或拖放文件到這裡</p>
                <p style="font-size: 0.8rem; color: #666; margin-top: 0.5rem;">支持 .txt, .log, .anr, .tombstone</p>
            </div>
            <div class="uploaded-files" id="uploadedFiles"></div>
            <div class="quick-actions">
                <h3>快速分析</h3>
                <button class="action-button" onclick="sendQuickAction('分析主線程阻塞原因')">🔍 分析主線程阻塞</button>
                <button class="action-button" onclick="sendQuickAction('查找死鎖情況')">🔒 查找死鎖</button>
                <button class="action-button" onclick="sendQuickAction('生成修復建議')">💡 生成修復建議</button>
                <button class="action-button" onclick="sendQuickAction('檢查系統資源使用')">📊 檢查資源使用</button>
            </div>
        </div>
        
        <div class="right-panel">
            <div class="chat-header">
                <h2>AI 分析助手</h2>
            </div>
            <div class="chat-messages" id="chatMessages">
                <div class="message assistant">
                    <div class="message-avatar">AI</div>
                    <div class="message-content">歡迎使用 ANR/Tombstone 分析系統！請上傳您的日誌文件，我會幫您分析問題並提供解決方案。</div>
                </div>
            </div>
            <div class="chat-input-container">
                <div class="chat-input-wrapper">
                    <textarea id="chatInput" class="chat-input" placeholder="輸入您的問題..." rows="1" onkeydown="handleKeyPress(event)"></textarea>
                    <button id="sendButton" class="send-button" onclick="sendMessage()">➤</button>
                </div>
            </div>
        </div>
    </div>
    
    <script>
        // 使用端口 5566
        const API_BASE_URL = 'http://localhost:5566/api';
        
        let uploadedFileIds = [];
        let isProcessing = false;
        
        document.addEventListener('DOMContentLoaded', function() {
            console.log('系統啟動，API URL:', API_BASE_URL);
            setupUploadArea();
            adjustTextarea();
            checkBackendHealth();
        });
        
        async function checkBackendHealth() {
            try {
                const response = await fetch(API_BASE_URL + '/health');
                if (response.ok) {
                    const data = await response.json();
                    console.log('後端健康檢查:', data);
                    if (data.status !== 'healthy') {
                        addMessage('assistant', '⚠️ 系統部分服務異常，可能影響使用。');
                    }
                } else {
                    console.error('健康檢查失敗:', response.status);
                    addMessage('assistant', '⚠️ 無法連接到分析服務，請稍後再試。');
                }
            } catch (error) {
                console.error('健康檢查錯誤:', error);
                addMessage('assistant', '⚠️ 系統連接失敗，請檢查服務是否正常運行。\n\n可能的原因：\n1. 後端服務未啟動\n2. 網絡連接問題\n3. 防火牆阻擋\n\n請聯繫管理員。');
            }
        }
        
        function setupUploadArea() {
            const uploadArea = document.getElementById('uploadArea');
            const fileInput = document.getElementById('fileInput');
            
            uploadArea.addEventListener('click', () => fileInput.click());
            fileInput.addEventListener('change', handleFileSelect);
            
            uploadArea.addEventListener('dragover', (e) => {
                e.preventDefault();
                uploadArea.classList.add('dragover');
            });
            
            uploadArea.addEventListener('dragleave', () => {
                uploadArea.classList.remove('dragover');
            });
            
            uploadArea.addEventListener('drop', (e) => {
                e.preventDefault();
                uploadArea.classList.remove('dragover');
                handleFiles(e.dataTransfer.files);
            });
        }
        
        function handleFileSelect(e) {
            handleFiles(e.target.files);
        }
        
        async function handleFiles(files) {
            for (let file of files) {
                await uploadFile(file);
            }
        }
        
        async function uploadFile(file) {
            const formData = new FormData();
            formData.append('file', file);
            
            addMessage('assistant', '📤 正在上傳文件: ' + file.name + '...');
            
            try {
                showLoading(true);
                const response = await fetch(API_BASE_URL + '/upload', {
                    method: 'POST',
                    body: formData
                });
                
                if (!response.ok) {
                    const errorText = await response.text();
                    throw new Error('上傳失敗 (' + response.status + '): ' + errorText);
                }
                
                const data = await response.json();
                uploadedFileIds.push(data.file_id);
                
                displayUploadedFile(file, data);
                
                // 移除上傳中消息，添加成功消息
                const messages = document.getElementById('chatMessages');
                const lastMessage = messages.lastElementChild;
                if (lastMessage && lastMessage.textContent.includes('正在上傳文件')) {
                    messages.removeChild(lastMessage);
                }
                
                addMessage('assistant', 
                    '✅ 文件上傳成功！\n\n' +
                    '文件名：' + file.name + '\n' +
                    '大小：' + formatFileSize(file.size) + '\n' +
                    '類型：' + data.file_type + '\n' +
                    '提取塊數：' + data.chunks + '\n\n' +
                    '您現在可以開始提問了！'
                );
                
            } catch (error) {
                console.error('上傳錯誤:', error);
                const messages = document.getElementById('chatMessages');
                const lastMessage = messages.lastElementChild;
                if (lastMessage && lastMessage.textContent.includes('正在上傳文件')) {
                    messages.removeChild(lastMessage);
                }
                addMessage('assistant', '❌ 上傳失敗：' + error.message);
            } finally {
                showLoading(false);
            }
        }
        
        function displayUploadedFile(file, data) {
            const uploadedFiles = document.getElementById('uploadedFiles');
            const fileItem = document.createElement('div');
            fileItem.className = 'file-item';
            fileItem.innerHTML = 
                '<span class="file-name" title="' + file.name + '">' + file.name + '</span>' +
                '<span class="file-size">' + formatFileSize(file.size) + '</span>';
            uploadedFiles.appendChild(fileItem);
        }
        
        async function sendMessage() {
            const input = document.getElementById('chatInput');
            const message = input.value.trim();
            
            if (!message || isProcessing) return;
            
            addMessage('user', message);
            input.value = '';
            adjustTextarea();
            
            try {
                isProcessing = true;
                showLoading(true);
                
                const response = await fetch(API_BASE_URL + '/chat', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        message: message,
                        file_ids: uploadedFileIds,
                        session_id: getSessionId()
                    })
                });
                
                if (!response.ok) {
                    const errorText = await response.text();
                    throw new Error('請求失敗 (' + response.status + '): ' + errorText);
                }
                
                const data = await response.json();
                addMessage('assistant', data.response || '抱歉，我暫時無法回答您的問題。');
                
            } catch (error) {
                console.error('聊天錯誤:', error);
                addMessage('assistant', '❌ 錯誤：' + error.message);
            } finally {
                isProcessing = false;
                showLoading(false);
            }
        }
        
        function sendQuickAction(action) {
            if (uploadedFileIds.length === 0) {
                addMessage('assistant', '⚠️ 請先上傳要分析的 ANR 或 Tombstone 文件！');
                return;
            }
            
            document.getElementById('chatInput').value = action;
            sendMessage();
        }
        
        function addMessage(role, content) {
            const chatMessages = document.getElementById('chatMessages');
            const messageDiv = document.createElement('div');
            messageDiv.className = 'message ' + role;
            
            const avatar = role === 'user' ? '👤' : 'AI';
            messageDiv.innerHTML = 
                '<div class="message-avatar">' + avatar + '</div>' +
                '<div class="message-content">' + escapeHtml(content) + '</div>';
            
            chatMessages.appendChild(messageDiv);
            chatMessages.scrollTop = chatMessages.scrollHeight;
        }
        
        function escapeHtml(text) {
            const div = document.createElement('div');
            div.textContent = text;
            return div.innerHTML;
        }
        
        function handleKeyPress(event) {
            if (event.key === 'Enter' && !event.shiftKey) {
                event.preventDefault();
                sendMessage();
            }
        }
        
        function adjustTextarea() {
            const textarea = document.getElementById('chatInput');
            textarea.style.height = 'auto';
            textarea.style.height = Math.min(textarea.scrollHeight, 120) + 'px';
        }
        
        function showLoading(show) {
            const sendButton = document.getElementById('sendButton');
            if (show) {
                sendButton.innerHTML = '<div class="loading"></div>';
                sendButton.disabled = true;
            } else {
                sendButton.innerHTML = '➤';
                sendButton.disabled = false;
            }
        }
        
        function getSessionId() {
            let sessionId = localStorage.getItem('sessionId');
            if (!sessionId) {
                sessionId = 'session_' + Date.now() + '_' + Math.random().toString(36).substr(2, 9);
                localStorage.setItem('sessionId', sessionId);
            }
            return sessionId;
        }
        
        function formatFileSize(bytes) {
            if (bytes === 0) return '0 Bytes';
            const k = 1024;
            const sizes = ['Bytes', 'KB', 'MB', 'GB'];
            const i = Math.floor(Math.log(bytes) / Math.log(k));
            return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
        }
        
        document.getElementById('chatInput').addEventListener('input', adjustTextarea);
    </script>
</body>
</html>
HTML_EOF

# 檢查文件是否創建成功
if [ -f frontend/public/index.html ]; then
    echo "✅ index.html 創建成功！"
    echo "文件大小: $(ls -lh frontend/public/index.html | awk '{print $5}')"
else
    echo "❌ 創建失敗！"
fi

# 重建前端容器
echo ""
echo "🔄 重建前端容器..."
docker-compose build frontend
docker-compose up -d frontend

echo ""
echo "✅ 完成！"
echo ""
echo "🌐 請訪問: http://localhost:5566"
echo ""
echo "如果還是看到目錄列表，請嘗試："
echo "1. 清除瀏覽器緩存"
echo "2. 使用無痕模式訪問"
echo "3. 或按 Ctrl+F5 強制刷新"
