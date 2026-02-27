#!/usr/bin/env bash
# ============================================================
# build-deb.sh — 构建 explain-tool 的 .deb 安装包
#
# 依赖：sudo apt install devscripts debhelper dpkg-dev
# 用法：bash build-deb.sh [版本号]  默认 1.0.0
# ============================================================
set -e

VERSION="${1:-1.0.0}"
PKG_NAME="explain-tool"
DEB_NAME="${PKG_NAME}_${VERSION}-1_all.deb"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[*]${RESET} $*"; }
success() { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${RED}[✗]${RESET} $*" >&2; exit 1; }

echo -e "\n${BOLD}===================================${RESET}"
echo -e "${BOLD}  构建 explain-tool v${VERSION} .deb 包${RESET}"
echo -e "${BOLD}===================================${RESET}\n"

# ── 1. 检查依赖 ─────────────────────────────────────────────
info "检查构建依赖..."
MISSING=()
for tool in dpkg-buildpackage debhelper dh; do
    if ! command -v "$tool" &>/dev/null 2>&1; then
        # dh 在 debhelper 包里，dpkg-buildpackage 在 dpkg-dev
        :
    fi
done
if ! dpkg -l debhelper &>/dev/null 2>&1; then
    MISSING+=("debhelper")
fi
if ! dpkg -l dpkg-dev &>/dev/null 2>&1; then
    MISSING+=("dpkg-dev")
fi
if [ ${#MISSING[@]} -gt 0 ]; then
    warn "缺少构建依赖，正在安装：${MISSING[*]}"
    sudo apt-get install -y "${MISSING[@]}" -q || error "依赖安装失败"
fi
success "构建依赖就绪"

# ── 2. 确保 explain 脚本有执行权限 ──────────────────────────
info "设置脚本权限..."
chmod +x explain
chmod +x debian/postinst 2>/dev/null || true

# ── 3. 更新 debian/changelog 中的版本号 ─────────────────────
info "更新版本号 → $VERSION ..."
TODAY=$(date -R)
cat > debian/changelog <<EOF
explain-tool (${VERSION}-1) stable; urgency=low

  * Build version ${VERSION}.

 -- Kriemseeley <your-email@example.com>  ${TODAY}
EOF

# ── 4. 构建 .deb ─────────────────────────────────────────────
info "开始构建 .deb 包（dpkg-buildpackage）..."
# -us -uc：不签名（本地构建无需 GPG）
# -b：只构建二进制包
dpkg-buildpackage -us -uc -b 2>&1 | tail -5

# ── 5. 找到生成的 .deb ───────────────────────────────────────
# dpkg-buildpackage 默认把 .deb 放在上级目录
DEB_PATH=$(find .. -maxdepth 1 -name "${PKG_NAME}_*.deb" | sort | tail -1)
if [ -z "$DEB_PATH" ]; then
    # fallback: 尝试当前目录
    DEB_PATH=$(find . -maxdepth 2 -name "*.deb" | head -1)
fi

if [ -z "$DEB_PATH" ]; then
    error "未找到生成的 .deb 文件，请检查构建输出"
fi

# 复制到当前目录方便后续处理
cp "$DEB_PATH" "./${DEB_NAME}" 2>/dev/null || true
DEB_PATH="./${DEB_NAME}"

# ── 6. 验证包内容 ────────────────────────────────────────────
echo ""
info "包内容预览："
dpkg -c "$DEB_PATH" 2>/dev/null || true

echo ""
success "构建完成：$DEB_PATH"
echo ""
echo -e "  ${CYAN}本地安装测试：${RESET}"
echo -e "    ${YELLOW}sudo dpkg -i $DEB_PATH${RESET}"
echo -e "    ${YELLOW}explain --help${RESET}"
echo ""
echo -e "  ${CYAN}发布到 apt 仓库：${RESET}"
echo -e "    ${YELLOW}bash publish-repo.sh${RESET}"
echo ""
