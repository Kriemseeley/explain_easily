#!/usr/bin/env bash
# ============================================================
# explain-tool 一键卸载脚本
# 适用于 Kali Linux / Ubuntu 20.04+
# ============================================================
set -e

INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="$HOME/.config/explain-tool"
BINARY="$INSTALL_DIR/explain"

# ── 颜色 ─────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[*]${RESET} $*"; }
success() { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${RED}[✗]${RESET} $*" >&2; exit 1; }

echo -e "\n${BOLD}==============================${RESET}"
echo -e "${BOLD}  explain-tool 卸载向导${RESET}"
echo -e "${BOLD}==============================${RESET}\n"

# ── 确认提示 ───────────────────────────────────────────────
echo -e "将要删除以下内容："
echo -e "  ${YELLOW}▸ 可执行文件：${RESET}$BINARY"
echo -e "  ${YELLOW}▸ 配置 & 缓存：${RESET}$CONFIG_DIR"
echo ""
read -rp "$(echo -e "${BOLD}确认卸载？[y/N]${RESET} ")" confirm
case "$confirm" in
    [yY][eE][sS]|[yY]) ;;
    *)
        warn "已取消卸载"
        exit 0
        ;;
esac
echo ""

# ── 删除可执行文件 ─────────────────────────────────────────
if [ -f "$BINARY" ]; then
    info "删除 $BINARY ..."
    if [ -w "$INSTALL_DIR" ]; then
        rm -f "$BINARY"
    else
        sudo rm -f "$BINARY"
    fi
    success "可执行文件已删除"
else
    warn "未找到 $BINARY，跳过"
fi

# ── 删除配置目录（含缓存）────────────────────────────────
if [ -d "$CONFIG_DIR" ]; then
    # 统计缓存文件数量
    cache_count=$(find "$CONFIG_DIR/cache" -name "*.md" 2>/dev/null | wc -l || echo 0)
    info "删除配置目录 $CONFIG_DIR（缓存 ${cache_count} 条）..."
    rm -rf "$CONFIG_DIR"
    success "配置目录已删除"
else
    warn "配置目录不存在，跳过"
fi

# ── 完成 ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}==============================${RESET}"
success "explain-tool 已完全卸载！"
echo -e "${BOLD}==============================${RESET}"
echo ""
echo -e "  如需重新安装，请运行：${YELLOW}./install.sh${RESET}"
echo ""
