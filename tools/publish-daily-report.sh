#!/usr/bin/env bash
set -euo pipefail

# 在仓库根目录运行。由 cron fresh session 提供日报正文：
#   REPORT_BODY_FILE=/tmp/report.md ./scripts/publish-daily-report.sh
# 正文为空或仅空白时安全退出，不创建 commit。

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
export TZ="Asia/Shanghai"
TODAY="$(date +%F)"
POST_PATH="source/_posts/daily-${TODAY}.md"
BODY_FILE="${REPORT_BODY_FILE:-}"

if [[ -z "$BODY_FILE" || ! -f "$BODY_FILE" ]]; then
  echo "未提供 REPORT_BODY_FILE，跳过发布。" >&2
  exit 0
fi

# 过滤常见凭据/敏感配置；日报只保留工作事实，不保留 token、密码、私钥或 .env 内容。
SANITIZED_BODY="$(python3 - "$BODY_FILE" <<'PY'
from pathlib import Path
import re, sys
text = Path(sys.argv[1]).read_text(encoding="utf-8")
patterns = [
    (r'(?i)(api[_ -]?key|access[_ -]?token|refresh[_ -]?token|password|passwd|secret|authorization)\s*[:=：]\s*[^\s,;]+', r'\1: [已过滤]'),
    (r'(?i)bearer\s+[A-Za-z0-9._~+/=-]+', 'Bearer [已过滤]'),
    (r'(?i)(gh[pousr]_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9_-]{16,}|xox[baprs]-[A-Za-z0-9-]+)', '[已过滤]'),
    (r'-----BEGIN [^-]+ PRIVATE KEY-----.*?-----END [^-]+ PRIVATE KEY-----', '[已过滤的私钥]',),
]
for pattern, replacement in patterns:
    text = re.sub(pattern, replacement, text, flags=re.DOTALL if 'PRIVATE KEY' in pattern else 0)
print(text.strip())
PY
)"

if [[ -z "${SANITIZED_BODY//[[:space:]]/}" ]]; then
  echo "日报正文为空，跳过发布。"
  exit 0
fi

mkdir -p source/_posts
python3 - "$POST_PATH" "$TODAY" <<'PY' "$SANITIZED_BODY"
from pathlib import Path
import sys
path, today, body = sys.argv[1], sys.argv[2], sys.argv[3]
if Path(path).exists():
    print(f"文章已存在，保持幂等：{path}")
    raise SystemExit(0)
Path(path).write_text(
    f"---\ntitle: 每日日报｜{today}\ndate: {today} 03:00:00\ntags:\n  - 日报\n  - 自动化\ncategories: 工作记录\ndescription: 自动汇总过去一天的工作记录（已过滤敏感信息）。\n---\n\n{body}\n",
    encoding="utf-8",
)
print(f"已生成：{path}")
PY

# 只在内容确实新增时继续；构建失败不会产生提交。
if git diff --quiet -- "$POST_PATH"; then
  echo "没有新的日报变更，跳过提交。"
  exit 0
fi
npm run build

git add "$POST_PATH"
git commit -m "docs: 发布 ${TODAY} 日报"
# 先同步远端，避免 cron 与人工提交竞争；不使用 reset/force push。
git pull --rebase origin main
git push origin HEAD:main
printf '已推送日报：%s (%s)\n' "$(git rev-parse HEAD)" "$TODAY"
