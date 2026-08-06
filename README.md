# iscaozilong.github.io

基于 Hexo 的中文技术与工作记录博客。

## 本地构建

```bash
npm ci
npm run build
```

构建产物位于 `public/`，该目录已被 Git 忽略。GitHub Pages 由 `.github/workflows/deploy.yml` 在 `main` 分支推送后自动构建并部署。

## 每日日报发布入口

由外部 cron 在 **Asia/Shanghai 每天 03:00** 启动 fresh session，先汇总过去一天 Hermes 会话中用户实际完成的工作，写入临时 Markdown 文件，再运行：

```bash
cd /home/zilong/projects/iscaozilong.github.io
REPORT_BODY_FILE=/tmp/hermes-daily-report.md ./tools/publish-daily-report.sh
```

脚本特性：按上海时区命名、空内容不提交、同日幂等、常见敏感信息过滤、构建成功后提交、`git pull --rebase` 后推送 `main`。不要在仓库内保存 token、密码、私钥或 `.env` 内容。
