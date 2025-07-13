'use client'

import React, { useState, useEffect, useRef, useCallback } from 'react';
import { Send, Upload, Moon, Sun, FileText, Search, Zap, Bot, User, Loader2, X } from 'lucide-react';

// 類型定義
interface Message {
  id: string;
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: Date;
  searchResults?: SearchResult[];
  isStreaming?: boolean;
}

interface SearchResult {
  text: string;
  score: number;
  metadata: any;
}

interface QuickAction {
  id: string;
  label: string;
  icon: React.ReactNode;
  action: string;
}

// WebSocket 連接管理
class WSConnection {
  private ws: WebSocket | null = null;
  private clientId: string;
  private onMessage: (data: any) => void;
  private reconnectAttempts = 0;
  private maxReconnects = 5;

  constructor(clientId: string, onMessage: (data: any) => void) {
    this.clientId = clientId;
    this.onMessage = onMessage;
  }

  connect() {
    // 動態構建 WebSocket URL
    const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const host = process.env.NEXT_PUBLIC_WS_HOST || window.location.hostname;
    const port = process.env.NEXT_PUBLIC_WS_PORT || window.location.port || '8080';
    const wsUrl = `${protocol}//${host}:${port}/api/ws/${this.clientId}`;
    
    console.log('Connecting to WebSocket:', wsUrl);
    this.ws = new WebSocket(wsUrl);

    this.ws.onopen = () => {
      console.log('WebSocket connected');
      this.reconnectAttempts = 0;
    };

    this.ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      this.onMessage(data);
    };

    this.ws.onerror = (error) => {
      console.error('WebSocket error:', error);
    };

    this.ws.onclose = () => {
      console.log('WebSocket disconnected');
      if (this.reconnectAttempts < this.maxReconnects) {
        setTimeout(() => {
          this.reconnectAttempts++;
          this.connect();
        }, 1000 * Math.pow(2, this.reconnectAttempts));
      }
    };
  }

  send(data: any) {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(data));
    }
  }

  disconnect() {
    if (this.ws) {
      this.ws.close();
    }
  }
}

// 主應用組件
export default function App() {
  // 狀態管理
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputValue, setInputValue] = useState('');
  const [isConnected, setIsConnected] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [theme, setTheme] = useState<'dark' | 'light'>('dark');
  const [uploadedFile, setUploadedFile] = useState<File | null>(null);
  const [fileId, setFileId] = useState<string | null>(null);
  const [showSearchResults, setShowSearchResults] = useState(false);
  const [currentSearchResults, setCurrentSearchResults] = useState<SearchResult[]>([]);
  
  // Refs
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const wsRef = useRef<WSConnection | null>(null);
  const sessionId = useRef(generateSessionId());
  
  // 快速操作按鈕
  const quickActions: QuickAction[] = [
    { id: '1', label: '分析主線程阻塞', icon: <Search className="w-4 h-4" />, action: '請分析這個 ANR 日誌中的主線程阻塞原因' },
    { id: '2', label: '查找死鎖', icon: <FileText className="w-4 h-4" />, action: '幫我查找是否存在死鎖情況' },
    { id: '3', label: '生成修復建議', icon: <Zap className="w-4 h-4" />, action: '基於分析結果，請提供修復建議' },
    { id: '4', label: '檢查資源使用', icon: <Bot className="w-4 h-4" />, action: '檢查系統資源使用情況' },
  ];

  // WebSocket 消息處理
  const handleWSMessage = useCallback((data: any) => {
    switch (data.type) {
      case 'chunk':
        // 流式更新最後一條消息
        setMessages(prev => {
          const newMessages = [...prev];
          const lastMessage = newMessages[newMessages.length - 1];
          if (lastMessage && lastMessage.isStreaming) {
            lastMessage.content += data.content;
          } else {
            newMessages.push({
              id: generateId(),
              role: 'assistant',
              content: data.content,
              timestamp: new Date(),
              isStreaming: true
            });
          }
          return newMessages;
        });
        break;
        
      case 'search_results':
        setCurrentSearchResults(data.data);
        setShowSearchResults(true);
        break;
        
      case 'done':
        // 結束流式傳輸
        setMessages(prev => {
          const newMessages = [...prev];
          const lastMessage = newMessages[newMessages.length - 1];
          if (lastMessage && lastMessage.isStreaming) {
            lastMessage.isStreaming = false;
          }
          return newMessages;
        });
        setIsLoading(false);
        break;
        
      case 'error':
        console.error('WebSocket error:', data.message);
        setIsLoading(false);
        break;
    }
  }, []);

  // 初始化 WebSocket
  useEffect(() => {
    const clientId = generateId();
    wsRef.current = new WSConnection(clientId, handleWSMessage);
    wsRef.current.connect();
    setIsConnected(true);

    // 設置主題
    if (theme === 'dark') {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }

    return () => {
      if (wsRef.current) {
        wsRef.current.disconnect();
      }
    };
  }, [handleWSMessage]);

  // 主題切換效果
  useEffect(() => {
    if (theme === 'dark') {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, [theme]);

  // 自動滾動到底部
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  // 發送消息
  const sendMessage = async (content: string) => {
    if (!content.trim() || !wsRef.current) return;

    // 添加用戶消息
    const userMessage: Message = {
      id: generateId(),
      role: 'user',
      content,
      timestamp: new Date()
    };
    setMessages(prev => [...prev, userMessage]);
    setInputValue('');
    setIsLoading(true);

    // 發送到後端
    wsRef.current.send({
      type: 'chat',
      message: content,
      session_id: sessionId.current,
      model: 'primary'
    });
  };

  // 處理文件上傳
  const handleFileUpload = async (file: File) => {
    if (!file) return;

    const formData = new FormData();
    formData.append('file', file);

    try {
      // 使用相對路徑，讓 Next.js 的 rewrites 處理
      const response = await fetch('/api/upload', {
        method: 'POST',
        body: formData
      });

      if (!response.ok) throw new Error('Upload failed');

      const data = await response.json();
      setFileId(data.file_id);
      setUploadedFile(file);

      // 添加系統消息
      const sysMessage: Message = {
        id: generateId(),
        role: 'system',
        content: `已上傳文件：${file.name} (${formatFileSize(file.size)})，共提取 ${data.chunks} 個文本塊。你可以開始詢問相關問題了。`,
        timestamp: new Date()
      };
      setMessages(prev => [...prev, sysMessage]);
    } catch (error) {
      console.error('Upload error:', error);
      alert('文件上傳失敗');
    }
  };

  // 切換主題
  const toggleTheme = () => {
    setTheme(prev => prev === 'dark' ? 'light' : 'dark');
  };

  // 渲染消息
  const renderMessage = (message: Message) => {
    const isUser = message.role === 'user';
    const isSystem = message.role === 'system';

    return (
      <div
        key={message.id}
        className={`flex ${isUser ? 'justify-end' : 'justify-start'} mb-4 fade-in`}
      >
        <div className={`flex max-w-[80%] ${isUser ? 'flex-row-reverse' : 'flex-row'} gap-3`}>
          <div className={`flex-shrink-0 w-8 h-8 rounded-full flex items-center justify-center ${
            isUser ? 'bg-blue-600' : isSystem ? 'bg-gray-600' : 'bg-green-600'
          }`}>
            {isUser ? <User className="w-5 h-5 text-white" /> : <Bot className="w-5 h-5 text-white" />}
          </div>
          <div className={`flex flex-col ${isUser ? 'items-end' : 'items-start'}`}>
            <div className={`rounded-lg px-4 py-2 ${
              isUser ? 'bg-blue-600 text-white' : 
              isSystem ? 'bg-gray-100 dark:bg-gray-800 text-gray-800 dark:text-gray-200' :
              'bg-gray-100 dark:bg-gray-800 text-gray-800 dark:text-gray-200'
            }`}>
              <div className="whitespace-pre-wrap break-words">
                {message.content}
                {message.isStreaming && <span className="inline-block w-2 h-4 ml-1 bg-current animate-pulse" />}
              </div>
            </div>
            <span className="text-xs text-gray-500 dark:text-gray-400 mt-1">
              {formatTime(message.timestamp)}
            </span>
          </div>
        </div>
      </div>
    );
  };

  return (
    <div className={`flex flex-col h-screen ${theme === 'dark' ? 'dark bg-gray-900' : 'bg-white'}`}>
      {/* 頂部欄 */}
      <header className="border-b border-gray-200 dark:border-gray-700 px-4 py-3">
        <div className="flex items-center justify-between max-w-6xl mx-auto">
          <div className="flex items-center gap-3">
            <Bot className="w-8 h-8 text-blue-600" />
            <h1 className="text-xl font-semibold text-gray-800 dark:text-white">
              ANR/Tombstone 智能分析助手
            </h1>
          </div>
          <div className="flex items-center gap-3">
            {uploadedFile && (
              <div className="flex items-center gap-2 px-3 py-1 bg-blue-100 dark:bg-blue-900 rounded-lg">
                <FileText className="w-4 h-4 text-blue-600 dark:text-blue-400" />
                <span className="text-sm text-blue-800 dark:text-blue-200">{uploadedFile.name}</span>
                <button
                  onClick={() => {
                    setUploadedFile(null);
                    setFileId(null);
                  }}
                  className="ml-1 text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-200"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>
            )}
            <button
              onClick={toggleTheme}
              className="p-2 rounded-lg bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors"
            >
              {theme === 'dark' ? <Sun className="w-5 h-5" /> : <Moon className="w-5 h-5" />}
            </button>
          </div>
        </div>
      </header>

      {/* 消息區域 */}
      <div className="flex-1 overflow-y-auto px-4 py-6">
        <div className="max-w-4xl mx-auto">
          {messages.length === 0 ? (
            <div className="text-center py-12">
              <Bot className="w-16 h-16 mx-auto text-gray-400 dark:text-gray-600 mb-4" />
              <h2 className="text-xl font-semibold text-gray-700 dark:text-gray-300 mb-2">
                歡迎使用 ANR/Tombstone 分析助手
              </h2>
              <p className="text-gray-500 dark:text-gray-400 mb-8">
                上傳您的日誌文件或直接提問，我會幫您分析問題並提供解決方案
              </p>
              
              {/* 快速操作按鈕 */}
              <div className="grid grid-cols-2 gap-3 max-w-md mx-auto">
                {quickActions.map(action => (
                  <button
                    key={action.id}
                    onClick={() => sendMessage(action.action)}
                    className="flex items-center gap-2 px-4 py-3 bg-gray-100 dark:bg-gray-800 rounded-lg hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors text-left"
                  >
                    {action.icon}
                    <span className="text-sm text-gray-700 dark:text-gray-300">{action.label}</span>
                  </button>
                ))}
              </div>
            </div>
          ) : (
            <>
              {messages.map(renderMessage)}
              <div ref={messagesEndRef} />
            </>
          )}
        </div>
      </div>

      {/* 搜索結果面板 */}
      {showSearchResults && currentSearchResults.length > 0 && (
        <div className="border-t border-gray-200 dark:border-gray-700 px-4 py-3 bg-gray-50 dark:bg-gray-800">
          <div className="max-w-4xl mx-auto">
            <div className="flex items-center justify-between mb-2">
              <h3 className="text-sm font-semibold text-gray-700 dark:text-gray-300">
                相關文檔片段 ({currentSearchResults.length})
              </h3>
              <button
                onClick={() => setShowSearchResults(false)}
                className="text-gray-500 hover:text-gray-700 dark:text-gray-400 dark:hover:text-gray-200"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
            <div className="space-y-2 max-h-32 overflow-y-auto">
              {currentSearchResults.map((result, idx) => (
                <div key={idx} className="text-xs text-gray-600 dark:text-gray-400 bg-white dark:bg-gray-900 p-2 rounded">
                  <span className="font-mono">{result.text.substring(0, 100)}...</span>
                  <span className="ml-2 text-gray-400">相似度: {(result.score * 100).toFixed(1)}%</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}

      {/* 輸入區域 */}
      <div className="border-t border-gray-200 dark:border-gray-700 px-4 py-4">
        <div className="max-w-4xl mx-auto">
          <div className="flex items-end gap-3">
            {/* 文件上傳按鈕 */}
            <input
              ref={fileInputRef}
              type="file"
              accept=".txt,.log,.anr,.tombstone"
              onChange={(e) => {
                const file = e.target.files?.[0];
                if (file) handleFileUpload(file);
              }}
              className="hidden"
            />
            <button
              onClick={() => fileInputRef.current?.click()}
              className="p-3 rounded-lg bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors"
              title="上傳文件"
            >
              <Upload className="w-5 h-5" />
            </button>

            {/* 輸入框 */}
            <div className="flex-1 relative">
              <textarea
                value={inputValue}
                onChange={(e) => setInputValue(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === 'Enter' && !e.shiftKey) {
                    e.preventDefault();
                    sendMessage(inputValue);
                  }
                }}
                placeholder={uploadedFile ? "詢問關於上傳文件的問題..." : "輸入您的問題..."}
                className="w-full px-4 py-3 pr-12 bg-gray-100 dark:bg-gray-800 text-gray-800 dark:text-gray-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 resize-none"
                rows={1}
                style={{ minHeight: '48px', maxHeight: '120px' }}
              />
              <button
                onClick={() => sendMessage(inputValue)}
                disabled={!inputValue.trim() || isLoading}
                className="absolute right-2 bottom-2 p-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:bg-gray-400 disabled:cursor-not-allowed transition-colors"
              >
                {isLoading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}
              </button>
            </div>
          </div>
          
          <div className="mt-2 text-xs text-gray-500 dark:text-gray-400 text-center">
            按 Enter 發送，Shift + Enter 換行
          </div>
        </div>
      </div>
    </div>
  );
}

// 工具函數
function generateId(): string {
  return Math.random().toString(36).substr(2, 9);
}

function generateSessionId(): string {
  return `session_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

function formatTime(date: Date): string {
  return date.toLocaleTimeString('zh-TW', { 
    hour: '2-digit', 
    minute: '2-digit' 
  });
}

function formatFileSize(bytes: number): string {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
}