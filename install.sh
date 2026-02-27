#!/usr/bin/env bash
# ============================================================
# install.sh — explain-tool 安装脚本
# 支持: Debian/Ubuntu/Kali · Fedora/RHEL/CentOS/Rocky/Alma
#       Arch/Manjaro · openSUSE · Alpine Linux
# ============================================================
set -e

INSTALL_DIR="/usr/local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[*]${RESET} $*"; }
success() { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${RED}[✗]${RESET} $*" >&2; exit 1; }

echo -e "\n${BOLD}================================${RESET}"
echo -e "${BOLD}  explain-tool 安装向导${RESET}"
echo -e "${BOLD}================================${RESET}\n"

# ── 1. 检测发行版 / 包管理器 ─────────────────────────────────
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO_ID="${ID:-unknown}"
        DISTRO_ID_LIKE="${ID_LIKE:-}"
        DISTRO_NAME="${NAME:-Linux}"
    else
        DISTRO_ID="unknown"
        DISTRO_ID_LIKE=""
        DISTRO_NAME="Linux"
    fi
}

detect_pkg_manager() {
    if command -v apt-get &>/dev/null; then
        PKG_MGR="apt"
    elif command -v dnf &>/dev/null; then
        PKG_MGR="dnf"
    elif command -v yum &>/dev/null; then
        PKG_MGR="yum"
    elif command -v pacman &>/dev/null; then
        PKG_MGR="pacman"
    elif command -v zypper &>/dev/null; then
        PKG_MGR="zypper"
    elif command -v apk &>/dev/null; then
        PKG_MGR="apk"
    else
        PKG_MGR="unknown"
    fi
}

detect_distro
detect_pkg_manager

info "发行版：${DISTRO_NAME}（${DISTRO_ID}），包管理器：${PKG_MGR}"

# ── 2. 检查 Python3 ──────────────────────────────────────────
info "检查 Python3..."
if ! command -v python3 &>/dev/null; then
    warn "未找到 python3，尝试自动安装..."
    case "$PKG_MGR" in
        apt)     sudo apt-get install -y python3 python3-pip -q ;;
        dnf)     sudo dnf install -y python3 python3-pip -q ;;
        yum)     sudo yum install -y python3 python3-pip -q ;;
        pacman)  sudo pacman -S --noconfirm python python-pip ;;
        zypper)  sudo zypper install -y python3 python3-pip ;;
        apk)     sudo apk add --quiet python3 py3-pip ;;
        *)       error "无法自动安装 Python3，请手动安装后重试" ;;
    esac
fi

PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
# 版本号检查：需要 >= 3.8
PY_MAJOR=$(echo "$PY_VER" | cut -d. -f1)
PY_MINOR=$(echo "$PY_VER" | cut -d. -f2)
if [ "$PY_MAJOR" -lt 3 ] || { [ "$PY_MAJOR" -eq 3 ] && [ "$PY_MINOR" -lt 8 ]; }; then
    error "Python 版本 ${PY_VER} 过低，需要 3.8 或以上"
fi
success "Python ${PY_VER}"

# ── 3. 确保 pip3 可用 ────────────────────────────────────────
if ! command -v pip3 &>/dev/null && ! python3 -m pip --version &>/dev/null 2>&1; then
    warn "未找到 pip3，尝试自动安装..."
    case "$PKG_MGR" in
        apt)     sudo apt-get install -y python3-pip -q ;;
        dnf)     sudo dnf install -y python3-pip -q ;;
        yum)     sudo yum install -y python3-pip -q ;;
        pacman)  sudo pacman -S --noconfirm python-pip ;;
        zypper)  sudo zypper install -y python3-pip ;;
        apk)     sudo apk add --quiet py3-pip ;;
        *)
            warn "无法自动安装 pip，尝试 ensurepip..."
            python3 -m ensurepip --upgrade 2>/dev/null || \
                error "pip 安装失败，请手动安装"
            ;;
    esac
fi

# pip 安装命令：优先 pip3，回退到 python3 -m pip
PIP_CMD="pip3"
command -v pip3 &>/dev/null || PIP_CMD="python3 -m pip"

# ── 4. 安装 Python 依赖（rich 可选，用于彩色输出）───────────
info "安装 Python 依赖（rich）..."
# --break-system-packages 用于 PEP 668 保护的系统（如 Debian 12+）
$PIP_CMD install rich --quiet --break-system-packages 2>/dev/null \
    || $PIP_CMD install rich --quiet 2>/dev/null \
    || warn "rich 安装失败，将使用纯文本输出（不影响功能）"

# ── 5. 复制主脚本 ─────────────────────────────────────────────
info "安装 explain 到 ${INSTALL_DIR}..."
[ -f "${SCRIPT_DIR}/explain" ] || error "未找到 explain 脚本，请在项目根目录下运行本脚本"

if [ -w "$INSTALL_DIR" ]; then
    cp "${SCRIPT_DIR}/explain" "${INSTALL_DIR}/explain"
    chmod +x "${INSTALL_DIR}/explain"
else
    sudo cp "${SCRIPT_DIR}/explain" "${INSTALL_DIR}/explain"
    sudo chmod +x "${INSTALL_DIR}/explain"
fi

# ── 6. 验证安装 ───────────────────────────────────────────────
if command -v explain &>/dev/null; then
    success "explain 已安装到 ${INSTALL_DIR}/explain"
else
    warn "安装完成，但 explain 未在 PATH 中，请检查 ${INSTALL_DIR} 是否在 \$PATH"
fi

# ── 7. 引导提示 ───────────────────────────────────────────────
echo ""
echo -e "${BOLD}安装完成！下一步：${RESET}"
echo ""
echo -e "  ${CYAN}1. 首次配置 LLM 后端（必须）：${RESET}"
echo -e "     ${YELLOW}explain --config${RESET}"
echo ""
echo -e "  ${CYAN}2. 也可通过环境变量传入 API Key：${RESET}"
echo -e "     ${YELLOW}export EXPLAIN_API_KEY='sk-xxxxxxxx'${RESET}"
echo ""
echo -e "  ${CYAN}3. 使用本地 Ollama（无需 API Key，推荐安全场景）：${RESET}"
echo -e "     ${YELLOW}ollama pull qwen2.5:7b${RESET}"
echo -e "     ${YELLOW}explain --config${RESET}  → 选择 ollama 后端"
echo ""
echo -e "  ${CYAN}4. 快速开始示例：${RESET}"
echo -e "     ${YELLOW}explain -q chmod u+s /bin/bash${RESET}      # ⚡ 快速一句话"
echo -e "     ${YELLOW}explain -s find / -perm -4000${RESET}       # 🔴 安全视角"
echo -e "     ${YELLOW}explain -g systemctl restart nginx${RESET}  # 🔧 通用视角"
echo ""
