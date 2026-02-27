# explain-tool

> 专为 **Kali Linux / Ubuntu** 设计的命令行解释工具  
> 双视角输出：🔧 通用（运维管理）+ 🔴 安全（渗透测试 / CTF）

---

## 功能特性

| 特性 | 说明 |
|------|------|
| 🔧 通用视角 | 系统管理、运维场景、参数解析、最佳实践 |
| 🔴 安全视角 | PrivEsc、GTFOBins、CTF 利用链、蓝队检测 |
| 🌐 双语支持 | 中文（zh）/ English（en），可配置或临时切换 |
| 🤖 多后端 | OpenAI / DeepSeek / Kimi / Ollama（本地） |
| 💾 缓存 | 相同命令结果自动缓存，减少 API 消耗 |
| 🎨 彩色输出 | 基于 `rich` 库，自动降级纯文本 |
| 🔑 环境变量 | 支持 `EXPLAIN_API_KEY` / `EXPLAIN_LANG` 等覆盖 |

---

## 快速安装

```bash
git clone <repo-url> explain-tool
cd explain-tool
chmod +x install.sh
./install.sh
```

或手动安装：

```bash
pip3 install rich
sudo cp explain /usr/local/bin/explain
sudo chmod +x /usr/local/bin/explain
```

---

## 配置

### 方式一：交互式配置向导（推荐）

```bash
explain --config
```

配置文件保存在 `~/.config/explain-tool/config.json`。

### 方式二：环境变量（适合临时使用或 CI/CD）

```bash
export EXPLAIN_API_KEY='sk-xxxxxxxxxxxxxxxx'
export EXPLAIN_API_BASE='https://api.openai.com/v1'   # 可选
export EXPLAIN_MODEL='gpt-4o-mini'                     # 可选
export EXPLAIN_LANG='en'                               # 可选：zh（默认）或 en
```

### 方式三：使用本地 Ollama（无需 API Key）

```bash
# 先启动 Ollama 并拉取模型
ollama pull qwen2.5:7b

# 配置时选择 ollama 后端
explain --config
```

---

## 使用方法

### 基本用法

```bash
# 全视角（通用 + 安全，默认，中文）
explain chmod u+s /bin/bash

# 仅安全视角（渗透/CTF/红队）
explain -s find / -perm -4000 2>/dev/null

# 仅通用视角（系统管理/运维）
explain -g tar -czf backup.tar.gz /var/www

# 同时指定 -s 和 -g（等价于默认全视角）
explain -sg nmap -sV -O 192.168.1.1

# 英文输出（临时）
explain --lang en chmod u+s /bin/bash

# 英文 + 安全视角
explain --lang en -s sudo -l

# 永久切换为英文（写入配置）
explain --config    # 在向导中选择 en
# 或
export EXPLAIN_LANG=en
```

### 命令行参数

```
用法: explain [-s] [-g] [-n] [--lang LANG] [--backend BACKEND]
              [--config] [--show-config] [--clear-cache] [command ...]

视角标志（可同时使用）:
  -s, --security      安全视角（渗透测试 / CTF / 红队 / PrivEsc）
  -g, --general       通用视角（系统管理 / 运维 / 最佳实践）
  （默认不加标志 = -sg 全视角）

语言选项:
  --lang zh           中文回复（默认）
  --lang en           English response（英文回复）
  （也可在 explain --config 中永久设置，或用 EXPLAIN_LANG 环境变量）

其他选项:
  -n, --no-cache      忽略缓存，强制重新查询
  --backend BACKEND   临时指定后端（openai/ollama/deepseek/custom）
  --config            运行交互式配置向导
  --show-config       显示当前配置
  --clear-cache       清空本地缓存
  -h, --help          显示帮助
```

---

## 示例输出

### `explain chmod u+s /bin/bash`（全视角）

```
🔍 Explain Tool
 命令: chmod u+s /bin/bash
 模式: 全视角（通用 + 安全）

## 📋 命令概览
chmod u+s /bin/bash 为 /bin/bash 设置 SUID 位，使任何用户执行该文件时
都以文件所有者（通常是 root）的身份运行。

## 🔩 参数解析
| 参数       | 含义                                    |
|------------|-----------------------------------------|
| chmod      | 修改文件权限的命令                        |
| u+s        | 为文件所有者（u）添加 SUID 位（s）        |
| /bin/bash  | 目标文件（bash shell 可执行文件）         |

## 🔧 通用视角
SUID 位的合法用途包括...（继续输出）

## 🔴 安全视角
⚠️ 风险等级：极高
GTFOBins 收录：是
利用方式：/bin/bash -p  即可获得 root shell...
```

---

## 支持的 LLM 后端

| 后端 | 说明 | 是否需要 API Key |
|------|------|----------------|
| `openai` | OpenAI API（gpt-4o-mini 等） | 是 |
| `deepseek` | DeepSeek API（性价比高，推荐）| 是 |
| `ollama` | 本地 Ollama（qwen2.5、llama3 等）| 否 |
| `custom` | 兼容 OpenAI 格式的任意 API | 视情况 |

> 推荐国内用户使用 **DeepSeek**（`https://platform.deepseek.com`）  
> 或本地 **Ollama** + `qwen2.5:7b` 以保证数据安全

---

## 文件结构

```
~/.config/explain-tool/
├── config.json     # 配置文件
└── cache/          # 查询缓存（.md 文件）
```

---

## 卸载

```bash
sudo rm /usr/local/bin/explain
rm -rf ~/.config/explain-tool
```

---

## 注意事项

- 所有命令解释均通过 LLM 生成，可能存在误差，请结合 `man` 手册验证
- 安全视角内容仅供授权渗透测试和学习研究使用，请遵守相关法律法规
- 建议安全敏感场景下使用本地 Ollama 模型，避免命令内容泄露至云端
