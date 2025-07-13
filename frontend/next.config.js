/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,
  // 添加 CSS 配置
  experimental: {
    appDir: true,
  },
}

module.exports = nextConfig
