import './globals.css'

export const metadata = {
  title: 'ANR/Tombstone 分析系統',
  description: '智能 Android 日誌分析助手',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="zh-TW">
      <body>{children}</body>
    </html>
  )
}
