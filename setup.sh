#!/usr/bin/env bash
#
# 一键拉齐 midoffice-workspace 的三 repo 布局，并检查环境。
#
#   ./setup.sh <github-owner>
#   GITHUB_OWNER=xxx ./setup.sh
#
# 可选环境变量：
#   API_REPO / WEB_REPO   仓库名（默认 midoffice-api / midoffice-web）
#   GIT_PROTOCOL=ssh      用 SSH 而非 HTTPS 克隆
#
# 本脚本不会覆盖任何已存在的目录：已经克隆过的会跳过。

set -euo pipefail

API_DIR="midoffice-api"
WEB_DIR="midoffice-web"
API_REPO="${API_REPO:-midoffice-api}"
WEB_REPO="${WEB_REPO:-midoffice-web}"

ok()   { printf '  \033[32m✓\033[0m %s\n' "$1"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$1"; }
bad()  { printf '  \033[31m✗\033[0m %s\n' "$1"; }
head_() { printf '\n\033[1m%s\033[0m\n' "$1"; }

# ── 0. 必须在工作区根运行 ────────────────────────────────────
if [ ! -f "README.md" ] || [ ! -f ".gitignore" ] || ! grep -q 'midoffice-workspace' README.md 2>/dev/null; then
  bad "请在 midoffice-workspace 的根目录运行本脚本。"
  exit 1
fi

# ── 1. 解析 GitHub owner ─────────────────────────────────────
OWNER="${1:-${GITHUB_OWNER:-}}"
if [ -z "$OWNER" ] && { [ ! -d "$API_DIR" ] || [ ! -d "$WEB_DIR" ]; }; then
  head_ "缺少 GitHub owner"
  cat <<EOF
  两个代码 repo 还没克隆，需要知道它们在哪。用法：

      ./setup.sh <github-owner>

  例如仓库地址是 https://github.com/acme/midoffice-api ，就传 acme。
  仓库名不是默认值时，用 API_REPO= / WEB_REPO= 覆盖。
EOF
  exit 1
fi

if [ "${GIT_PROTOCOL:-https}" = "ssh" ]; then
  base="git@github.com:$OWNER"; sep=":"
else
  base="https://github.com/$OWNER"; sep="/"
fi

# ── 2. 克隆两个代码 repo（已存在则跳过，绝不覆盖）────────────
head_ "代码 repo"
clone_one() {
  local dir="$1" repo="$2"
  if [ -d "$dir/.git" ]; then
    ok "$dir 已存在（跳过克隆）"
  elif [ -e "$dir" ]; then
    bad "$dir 已存在但不是 git repo —— 请先自行处理，脚本不会动它"
    return 1
  else
    echo "  克隆 $base$sep$repo.git → $dir"
    git clone --quiet "$base$sep$repo.git" "$dir"
    ok "$dir"
  fi
}
clone_one "$API_DIR" "$API_REPO"
clone_one "$WEB_DIR" "$WEB_REPO"

# ── 3. 环境检查 ──────────────────────────────────────────────
head_ "环境"
missing=0

if command -v java >/dev/null 2>&1; then
  jraw=$(java -version 2>&1 || true)
  jv=$(printf '%s\n' "$jraw" | sed -n '1s/.*version "\([0-9][0-9]*\).*/\1/p')
  if [ "$jv" = "21" ]; then
    ok "JDK $jv"
  elif printf '%s' "$jraw" | grep -q 'Unable to locate a Java Runtime'; then
    # macOS 上 /usr/bin/java 是个永远存在的占位程序，command -v java 会假阳性
    bad "PATH 上的 java 是 macOS 的占位程序，实际没装 JDK。
      装一个 JDK 21，并把 JAVA_HOME 指向它、把它的 bin 加进 PATH。"
    missing=1
  elif [ -z "$jv" ]; then
    warn "认不出 java 版本，原始输出第一行：
      $(printf '%s\n' "$jraw" | sed -n '1p')
      本项目要求 JDK 21。"
  else
    warn "当前 java 是 $jv，本项目要求 JDK 21。更高版本会出现「假通过」：
      编译按 release 21 走，但运行时行为没在 21 上验证过。
      把 JAVA_HOME 指向你机器上的 JDK 21 再跑。"
  fi
else
  bad "找不到 java（需要 JDK 21）"; missing=1
fi

if command -v mvn >/dev/null 2>&1; then
  mraw=$(mvn -v 2>/dev/null || true)
  mver=$(printf '%s\n' "$mraw" | sed -n '1s/^Apache Maven \([^ ]*\).*/\1/p')
  ok "maven ${mver:-已安装}"
else
  bad "找不到 mvn"; missing=1
fi

if command -v node >/dev/null 2>&1; then
  nv=$(node -v | sed 's/^v\([0-9][0-9]*\).*/\1/')
  [ "$nv" -ge 20 ] 2>/dev/null && ok "Node $(node -v)" || warn "Node $(node -v)，建议 20 或更高"
else
  bad "找不到 node（需要 20+）"; missing=1
fi

# ── 4. BMAD 本地安装（不进 git，需自行安装）──────────────────
head_ "BMAD（本机安装，不在仓库里）"
if [ -d ".kiro/skills" ] && [ -d "_bmad" ]; then
  ver=$(sed -n 's/^ *version: *\(.*\)$/\1/p;' _bmad/_config/manifest.yaml 2>/dev/null | sed -n '1p')
  if [ "$ver" = "6.10.0" ]; then
    ok "BMAD $ver"
  else
    warn "BMAD 版本是 ${ver:-未知}，本起点按 6.10.0 准备。版本不同时流程和产物可能对不上。"
  fi
  echo "  确认这几个配置取值（README「准备」一节有完整列表）："
  { grep -h -E '^(document_output_language|project_name)' _bmad/*/config.yaml 2>/dev/null || true; } \
    | sort -u | sed 's/^/      /'
else
  warn "还没装 BMAD。在当前目录（工作区根）安装 BMAD 6.10.0，它会生成 .kiro/skills/ 和 _bmad/。
      两者都不在 git 里 —— 它们属于你这台机器。"
fi

# ── 5. 收尾 ──────────────────────────────────────────────────
head_ "布局"
for d in "$API_DIR" "$WEB_DIR"; do
  [ -d "$d/.git" ] && ok "$d ($(git -C "$d" rev-parse --short HEAD))" || bad "$d 缺失"
done

head_ "下一步"
cat <<'EOF'
  所有命令都在工作区根执行：

    mvn -f midoffice-api/pom.xml test              # 起点应为 5 个全绿
    mvn -f midoffice-api/pom.xml spring-boot:run   # :8080
    npm --prefix midoffice-web install
    npm --prefix midoffice-web run dev             # :5173

  登录：alice / alice123 或 bob / bob123
EOF

if [ "$missing" != "0" ]; then
  head_ "有必需工具缺失，先装齐再跑上面的命令。"
  exit 1
fi
echo
