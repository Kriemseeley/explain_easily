#!/usr/bin/env bash
# ============================================================
# explain-tool 一键安装脚本
# 适用于 Kali Linux / Ubuntu 20.04+
# ============================================================
set -e

INSTALL_DIR="/usr/local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 颜色 ─────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[*]${RESET} $*"; }
success() { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${RED}[✗]${RESET} $*" >&2; exit 1; }

echo -e "\n${BOLD}==============================${RESET}"
echo -e "${BOLD}  explain-tool 安装向导${RESET}"
echo -e "${BOLD}==============================${RESET}\n"

# ── 检查 Python3 ──────────────────────────────────────────────
info "检查 Python3..."
if ! command -v python3 &>/dev/null; then
    error "未找到 python3，请先安装：sudo apt install python3"
fi
PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
info "Python 版本：$PY_VER"

# ── 安装 pip（如果缺失）────────────────────────────────────────
if ! command -v pip3 &>/dev/null; then
    warn "未找到 pip3，尝试安装..."
    sudo apt-get install -y python3-pip -q || error "pip3 安装失败"
fi

# ── 安装 rich（可选彩色输出）──────────────────────────────────
info "安装 Python 依赖..."
pip3 install rich --quiet --break-system-packages 2>/dev/null \
    || pip3 install rich --quiet 2>/dev/null \
    || warn "rich 安装失败（将使用纯文本输出，不影响功能）"

# ── 复制主脚本 ─────────────────────────────────────────────────
info "安装 explain 到 $INSTALL_DIR..."
if [ ! -f "$SCRIPT_DIR/explain" ]; then
    error "未找到 explain 脚本，请确保在项目目录下执行此脚本"
fi

if [ -w "$INSTALL_DIR" ]; then
    cp "$SCRIPT_DIR/explain" "$INSTALL_DIR/explain"
    chmod +x "$INSTALL_DIR/explain"
else
    sudo cp "$SCRIPT_DIR/explain" "$INSTALL_DIR/explain"
    sudo chmod +x "$INSTALL_DIR/explain"
fi

# ── 验证安装 ───────────────────────────────────────────────────
if command -v explain &>/dev/null; then
    success "explain 已成功安装到 $INSTALL_DIR/explain"
else
    warn "安装完成，但 explain 未在 PATH 中，请检查 $INSTALL_DIR 是否在 PATH"
fi

# ── 后续引导 ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}安装完成！下一步：${RESET}"
echo ""
echo -e "  ${CYAN}1. 配置 LLM 后端（首次必须）：${RESET}"
echo -e "     ${YELLOW}explain --config${RESET}"
echo ""
echo -e "  ${CYAN}2. 可选：用环境变量传 API Key（无需写入配置文件）：${RESET}"
echo -e "     ${YELLOW}export EXPLAIN_API_KEY='sk-xxxxxxxx'${RESET}"
echo ""
echo -e "  ${CYAN}3. 快速开始：${RESET}"
echo -e "     ${YELLOW}explain chmod u+s /bin/bash${RESET}          # 全视角"
echo -e "     ${YELLOW}explain -s find / -perm -4000${RESET}        # 仅安全视角"
echo -e "     ${YELLOW}explain -g systemctl restart nginx${RESET}   # 仅通用视角"
echo ""
echo -e "  ${CYAN}4. 使用本地 Ollama（无需 API Key）：${RESET}"
echo -e "     ${YELLOW}explain --config${RESET}  → 选择 ollama 后端"
echo ""
