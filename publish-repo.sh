#!/usr/bin/env bash
# ============================================================
# publish-repo.sh — 将 .deb 发布为 GitHub Pages apt 仓库
#
# 原理：
#   在 GitHub 上创建 apt-repo 分支，用 dpkg-scanpackages 生成
#   Packages / Release 元数据，用 GPG 签名，托管到 GitHub Pages。
#   用户添加 sources.list 后即可 apt install explain-tool。
#
# 前置条件：
#   sudo apt install dpkg-dev apt-utils gnupg
#   git 已配置好 GitHub 访问权限
#
# 用法：
#   bash publish-repo.sh [路径/到/.deb文件]
# ============================================================
set -e

# 最开头固定原始目录，任何 cd 之后都能精确回来
ORIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GITHUB_USER="Kriemseeley"
GITHUB_REPO="explain_easily"
BRANCH="apt-repo"                            # GitHub Pages 专用分支
REPO_COMPONENT="main"
REPO_CODENAME="stable"
# 转为绝对路径，防止 cd 后找不到文件
_DEB_RAW="${1:-$(ls "${ORIG_DIR}"/*.deb 2>/dev/null | sort | tail -1)}"
DEB_FILE="$(cd "$(dirname "$_DEB_RAW")" 2>/dev/null && echo "$(pwd)/$(basename "$_DEB_RAW")")"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[*]${RESET} $*"; }
success() { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${RED}[✗]${RESET} $*" >&2; exit 1; }

echo -e "\n${BOLD}====================================${RESET}"
echo -e "${BOLD}  发布 explain-tool 到 GitHub apt 仓库${RESET}"
echo -e "${BOLD}====================================${RESET}\n"

# ── 0. 检查 .deb 文件 ────────────────────────────────────────
if [ -z "$DEB_FILE" ] || [ ! -f "$DEB_FILE" ]; then
    error "未找到 .deb 文件。请先运行：bash build-deb.sh"
fi
success "找到包文件：$DEB_FILE"

# ── 1. 检查工具 ──────────────────────────────────────────────
info "检查工具依赖..."
for tool in dpkg-scanpackages gpg git; do
    if ! command -v "$tool" &>/dev/null; then
        error "缺少工具：$tool  请运行：sudo apt install dpkg-dev gnupg"
    fi
done
success "工具依赖就绪"

# ── 2. GPG 密钥检查 / 创建 ───────────────────────────────────
GPG_KEY_ID=""
info "检查 GPG 密钥..."
EXISTING_KEYS=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep "^sec" | head -1 || true)

if [ -z "$EXISTING_KEYS" ]; then
    warn "未找到 GPG 密钥，正在生成（apt 仓库签名需要）..."
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

# 导出公钥（用户需要导入才能验证签名）
gpg --armor --export "$GPG_KEY_ID" > "${ORIG_DIR}/explain-tool.gpg.key"
success "公钥已导出 → ${ORIG_DIR}/explain-tool.gpg.key"

# ── 3. 准备临时工作目录 ──────────────────────────────────────
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

POOL_DIR="$WORK_DIR/pool/${REPO_COMPONENT}"
DISTS_DIR="$WORK_DIR/dists/${REPO_CODENAME}/${REPO_COMPONENT}/binary-all"
mkdir -p "$POOL_DIR" "$DISTS_DIR"

info "复制 .deb 到仓库 pool..."
cp "$DEB_FILE" "$POOL_DIR/"

# ── 4. 生成 Packages 元数据 ──────────────────────────────────
info "生成 Packages 索引..."
cd "$WORK_DIR"
dpkg-scanpackages --multiversion pool/ > "dists/${REPO_CODENAME}/${REPO_COMPONENT}/binary-all/Packages" 2>/dev/null
gzip -k "dists/${REPO_CODENAME}/${REPO_COMPONENT}/binary-all/Packages"
success "Packages 索引生成完成"

# ── 5. 生成 Release 文件 ─────────────────────────────────────
info "生成 Release 文件..."
cd "dists/${REPO_CODENAME}"
cat > Release <<EOF
Origin: ${GITHUB_USER}
Label: explain-tool
Suite: ${REPO_CODENAME}
Codename: ${REPO_CODENAME}
Components: ${REPO_COMPONENT}
Architectures: all
Description: explain-tool unofficial apt repository
EOF

# 计算校验和
{
    echo "MD5Sum:"
    find "${REPO_COMPONENT}" -type f | sort | while read -r f; do
        printf " %s %s %s\n" "$(md5sum "$f" | awk '{print $1}')" "$(wc -c < "$f")" "$f"
    done
    echo "SHA256:"
    find "${REPO_COMPONENT}" -type f | sort | while read -r f; do
        printf " %s %s %s\n" "$(sha256sum "$f" | awk '{print $1}')" "$(wc -c < "$f")" "$f"
    done
} >> Release

# GPG 签名
gpg --default-key "$GPG_KEY_ID" --clearsign -o InRelease Release 2>/dev/null
gpg --default-key "$GPG_KEY_ID" -abs -o Release.gpg Release 2>/dev/null
success "Release 文件及签名生成完成"

# ── 6. 回到原项目目录，推送到 apt-repo 分支 ─────────────────
cd "$ORIG_DIR"

info "切换到 apt-repo 分支..."
# 如果分支不存在则创建孤立分支
if git show-ref --verify --quiet "refs/heads/${BRANCH}"; then
    git checkout "$BRANCH"
    # 清空旧内容（保留 .git）
    git rm -rf . --quiet 2>/dev/null || true
else
    git checkout --orphan "$BRANCH"
    git rm -rf . --quiet 2>/dev/null || true
fi

# 复制仓库内容
info "拷贝仓库文件..."
cp -r "$WORK_DIR/pool" .
cp -r "$WORK_DIR/dists" .
cp "${ORIG_DIR}/explain-tool.gpg.key" .

# 创建 index.html 方便在浏览器访问
cat > index.html <<HTMLEOF
<!DOCTYPE html>
<html lang="zh">
<head><meta charset="UTF-8"><title>explain-tool apt repository</title></head>
<body>
<h1>explain-tool apt 仓库</h1>
<p>安装命令：</p>
<pre>
# 添加 GPG 公钥
curl -fsSL https://${GITHUB_USER}.github.io/${GITHUB_REPO}/explain-tool.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/explain-tool.gpg

# 添加软件源
echo "deb [signed-by=/etc/apt/keyrings/explain-tool.gpg arch=all] https://${GITHUB_USER}.github.io/${GITHUB_REPO} ${REPO_CODENAME} ${REPO_COMPONENT}" | sudo tee /etc/apt/sources.list.d/explain-tool.list

# 安装
sudo apt update && sudo apt install explain-tool
</pre>
</body>
</html>
HTMLEOF

# 提交并推送
git add .
git commit -m "ci: 发布 apt 仓库 $(date +'%Y-%m-%d %H:%M')" --allow-empty
git push origin "$BRANCH" --force

success "apt 仓库已发布到 ${BRANCH} 分支！"

# ── 7. 回到 main 分支 ────────────────────────────────────────
git checkout main

# ── 8. 打印用户使用说明 ──────────────────────────────────────
PAGES_URL="https://${GITHUB_USER}.github.io/${GITHUB_REPO}"
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
echo -e "${CYAN}注意事项：${RESET}"
echo -e "  1. 需先在 GitHub 仓库 Settings → Pages 中将 Source 设为 ${BRANCH} 分支根目录"
echo -e "  2. GitHub Pages 首次部署约需 1-2 分钟生效"
echo -e "  3. 若更新版本，重新运行：bash build-deb.sh <新版本号> && bash publish-repo.sh"
echo ""
