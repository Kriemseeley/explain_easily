#!/usr/bin/env bash
# ============================================================
# publish-repo.sh — 将 .deb 发布为 GitHub Pages apt 仓库
# ============================================================
set -e

# ── 0. 在任何操作前固定原始目录（绝对路径）─────────────────
ORIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GITHUB_USER="Kriemseeley"
GITHUB_REPO="explain_easily"
BRANCH="apt-repo"
REPO_COMPONENT="main"
REPO_CODENAME="stable"

# .deb 路径转绝对路径
_DEB_RAW="${1:-$(ls "${ORIG_DIR}"/*.deb 2>/dev/null | sort | tail -1)}"
if [ -n "$_DEB_RAW" ] && [ -f "$_DEB_RAW" ]; then
    DEB_FILE="$(cd "$(dirname "$_DEB_RAW")" && pwd)/$(basename "$_DEB_RAW")"
else
    DEB_FILE=""
fi

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[*]${RESET} $*"; }
success() { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${RED}[✗]${RESET} $*" >&2; exit 1; }

echo -e "\n${BOLD}====================================${RESET}"
echo -e "${BOLD}  发布 explain-tool 到 GitHub apt 仓库${RESET}"
echo -e "${BOLD}====================================${RESET}\n"

info "项目目录：$ORIG_DIR"

# ── 1. 检查 .deb 文件 ────────────────────────────────────────
[ -z "$DEB_FILE" ] || [ ! -f "$DEB_FILE" ] && \
    error "未找到 .deb 文件，请先运行：bash build-deb.sh"
success "找到包文件：$DEB_FILE"

# ── 2. 检查工具 ──────────────────────────────────────────────
info "检查工具依赖..."
for tool in dpkg-scanpackages gpg git; do
    command -v "$tool" &>/dev/null || \
        error "缺少工具：$tool  请运行：sudo apt install dpkg-dev gnupg"
done
success "工具依赖就绪"

# ── 3. 确认是 git 仓库 ───────────────────────────────────────
info "确认 git 仓库..."
git -C "$ORIG_DIR" status --short > /dev/null 2>&1 || \
    error "\"$ORIG_DIR\" 不是 git 仓库，请检查是否已 git init"
success "git 仓库确认：$ORIG_DIR"

# ── 4. GPG 密钥 ──────────────────────────────────────────────
info "检查 GPG 密钥..."
EXISTING=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep "^sec" | head -1 || true)

if [ -z "$EXISTING" ]; then
    warn "未找到 GPG 密钥，正在生成..."
    gpg --batch --gen-key <<EOF
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: ${GITHUB_USER}
Name-Email: your-email@example.com
Expire-Date: 0
%no-protection
%commit
EOF
    success "GPG 密钥生成完成"
fi

GPG_KEY_ID=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null \
    | grep "^sec" | head -1 | awk '{print $2}' | cut -d'/' -f2)
info "使用 GPG Key ID：$GPG_KEY_ID"

GPG_KEY_FILE="${ORIG_DIR}/explain-tool.gpg.key"
gpg --armor --export "$GPG_KEY_ID" > "$GPG_KEY_FILE"
success "公钥已导出 → $GPG_KEY_FILE"

# ── 5. 在临时目录中构建 apt 仓库结构 ────────────────────────
WORK_DIR=$(mktemp -d)
# EXIT 时自动清理临时目录
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

POOL_DIR="$WORK_DIR/pool/${REPO_COMPONENT}"
DISTS_DIR="$WORK_DIR/dists/${REPO_CODENAME}/${REPO_COMPONENT}/binary-all"
mkdir -p "$POOL_DIR" "$DISTS_DIR"

info "复制 .deb 到 pool..."
cp "$DEB_FILE" "$POOL_DIR/"

info "生成 Packages 索引..."
# 注意：所有 cd 都在子 shell 中完成，不影响主 shell 的 pwd
(
    cd "$WORK_DIR"
    dpkg-scanpackages --multiversion pool/ \
        > "dists/${REPO_CODENAME}/${REPO_COMPONENT}/binary-all/Packages" 2>/dev/null
    gzip -k "dists/${REPO_CODENAME}/${REPO_COMPONENT}/binary-all/Packages"
)
success "Packages 索引生成完成"

info "生成 Release 文件..."
RELEASE_DIR="$WORK_DIR/dists/${REPO_CODENAME}"
cat > "${RELEASE_DIR}/Release" <<EOF
Origin: ${GITHUB_USER}
Label: explain-tool
Suite: ${REPO_CODENAME}
Codename: ${REPO_CODENAME}
Components: ${REPO_COMPONENT}
Architectures: all
Description: explain-tool unofficial apt repository
EOF

(
    cd "$RELEASE_DIR"
    {
        echo "MD5Sum:"
        find "${REPO_COMPONENT}" -type f | sort | while read -r f; do
            printf " %s %s %s\n" \
                "$(md5sum "$f" | awk '{print $1}')" \
                "$(wc -c < "$f")" "$f"
        done
        echo "SHA256:"
        find "${REPO_COMPONENT}" -type f | sort | while read -r f; do
            printf " %s %s %s\n" \
                "$(sha256sum "$f" | awk '{print $1}')" \
                "$(wc -c < "$f")" "$f"
        done
    } >> Release

    gpg --default-key "$GPG_KEY_ID" --clearsign -o InRelease Release 2>/dev/null
    gpg --default-key "$GPG_KEY_ID" -abs      -o Release.gpg Release 2>/dev/null
)
success "Release 文件及签名生成完成"

# ── 6. git 操作：全部用 git -C "$ORIG_DIR" ──────────────────
# 主 shell 的 pwd 从未改变过，始终是脚本启动时的目录
# 但为保险起见，使用 git -C 显式指定仓库路径

info "切换到 apt-repo 分支（git -C ${ORIG_DIR}）..."

if git -C "$ORIG_DIR" show-ref --verify --quiet "refs/heads/${BRANCH}"; then
    git -C "$ORIG_DIR" checkout "$BRANCH"
    git -C "$ORIG_DIR" rm -rf . --quiet 2>/dev/null || true
else
    git -C "$ORIG_DIR" checkout --orphan "$BRANCH"
    git -C "$ORIG_DIR" rm -rf . --quiet 2>/dev/null || true
fi

# 复制 apt 仓库内容到工作目录
# 注意：GPG 公钥已在第4步直接导出到 $ORIG_DIR，无需再次复制
info "拷贝仓库文件到工作目录..."
cp -r "$WORK_DIR/pool"  "$ORIG_DIR/"
cp -r "$WORK_DIR/dists" "$ORIG_DIR/"

# 生成 index.html
PAGES_URL="https://${GITHUB_USER}.github.io/${GITHUB_REPO}"
cat > "${ORIG_DIR}/index.html" <<HTMLEOF
<!DOCTYPE html>
<html lang="zh">
<head><meta charset="UTF-8"><title>explain-tool apt repository</title></head>
<body>
<h1>explain-tool apt 仓库</h1>
<p>一键安装命令：</p>
<pre>
# 1. 添加 GPG 公钥
curl -fsSL ${PAGES_URL}/explain-tool.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/explain-tool.gpg

# 2. 添加软件源
echo "deb [signed-by=/etc/apt/keyrings/explain-tool.gpg arch=all] ${PAGES_URL} ${REPO_CODENAME} ${REPO_COMPONENT}" | sudo tee /etc/apt/sources.list.d/explain-tool.list

# 3. 安装
sudo apt update &amp;&amp; sudo apt install explain-tool
</pre>
</body>
</html>
HTMLEOF

# 提交并推送
git -C "$ORIG_DIR" add .
git -C "$ORIG_DIR" commit -m "ci: 发布 apt 仓库 $(date +'%Y-%m-%d %H:%M')" --allow-empty
git -C "$ORIG_DIR" push -u origin "$BRANCH" --force

success "apt 仓库已推送到 ${BRANCH} 分支！"

# ── 7. 切回 main 分支 ────────────────────────────────────────
git -C "$ORIG_DIR" checkout main
success "已切回 main 分支"

# ── 8. 打印用户安装说明 ──────────────────────────────────────
echo ""
echo -e "${BOLD}===================================================${RESET}"
echo -e "${BOLD}  ✅ 发布完成！用户安装命令如下：${RESET}"
echo -e "${BOLD}===================================================${RESET}"
echo ""
echo -e "${CYAN}步骤一：添加 GPG 公钥${RESET}"
echo -e "  ${YELLOW}curl -fsSL ${PAGES_URL}/explain-tool.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/explain-tool.gpg${RESET}"
echo ""
echo -e "${CYAN}步骤二：添加软件源${RESET}"
echo -e "  ${YELLOW}echo \"deb [signed-by=/etc/apt/keyrings/explain-tool.gpg arch=all] ${PAGES_URL} ${REPO_CODENAME} ${REPO_COMPONENT}\" | sudo tee /etc/apt/sources.list.d/explain-tool.list${RESET}"
echo ""
echo -e "${CYAN}步骤三：安装${RESET}"
echo -e "  ${YELLOW}sudo apt update && sudo apt install explain-tool${RESET}"
echo ""
echo -e "${CYAN}⚠️  提醒：${RESET}"
echo -e "  1. 在 GitHub → Settings → Pages 中将 Source 设为 ${BRANCH} 分支根目录"
echo -e "  2. GitHub Pages 首次部署约需 1-2 分钟生效"
echo -e "  3. 更新版本：bash build-deb.sh <版本号> && bash publish-repo.sh"
echo ""
