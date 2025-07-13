'use client'

import { useState, useEffect } from 'react'

export default function Home() {
  const [status, setStatus] = useState('檢查中...')
  const [apiHealth, setApiHealth] = useState<any>(null)

  useEffect(() => {
    // 檢查 API 健康狀態
    fetch('/api/health')
      .then(res => res.json())
      .then(data => {
        setApiHealth(data)
        setStatus('系統運行正常')
      })
      .catch(err => {
        console.error('API 錯誤:', err)
        setStatus('API 連接失敗')
      })
  }, [])

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-100">
      <div className="bg-white p-8 rounded-lg shadow-lg max-w-md w-full">
        <h1 className="text-2xl font-bold text-center mb-6">
          ANR/Tombstone 分析系統
        </h1>
        
        <div className="space-y-4">
          <div className="p-4 bg-gray-50 rounded">
            <p className="text-sm text-gray-600">系統狀態</p>
            <p className="text-lg font-semibold">{status}</p>
          </div>
          
          {apiHealth && (
            <div className="p-4 bg-gray-50 rounded">
              <p className="text-sm text-gray-600 mb-2">服務狀態</p>
              <ul className="space-y-1">
                {Object.entries(apiHealth.services || {}).map(([service, status]) => (
                  <li key={service} className="flex justify-between">
                    <span className="text-sm">{service}</span>
                    <span className={`text-sm font-medium ${
                      status === 'healthy' ? 'text-green-600' : 'text-red-600'
                    }`}>
                      {String(status)}
                    </span>
                  </li>
                ))}
              </ul>
            </div>
          )}
          
          <div className="text-center text-sm text-gray-500">
            前端已成功部署
          </div>
        </div>
      </div>
    </div>
  )
}
