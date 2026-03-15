# 🧠 头脑风暴：终端代理环境变量自动管理

## 背景

**问题**：Antigravity 等终端应用打开新 shell 时，不会继承 Clash Verge 的代理设置。macOS 的"系统代理"只影响遵循系统代理的应用（浏览器等），而终端下的 `curl`、`git`、`npm` 等 CLI 工具依赖 `http_proxy` / `https_proxy` / `all_proxy` 环境变量。

**目标**：当 Clash Verge 系统代理开启时，新终端自动设置代理环境变量；Clash 关闭后，新终端不带代理。

---

## 理解确认

1. 用户是开发者，需要终端 CLI 工具自动走代理
2. 代理端口固定为 **7897**（HTTP/HTTPS/SOCKS5）
3. ProxyGuard 已能感知 Clash 代理状态变化（SCDynamicStore 事件驱动）
4. 只需影响**新打开的终端**，已打开终端提供手动/自动刷新机制
5. Clash 关闭后新终端不设代理，避免影响国内网络
6. 需要兼容 **zsh**（`~/.zshrc`）和 **bash**（`~/.bash_profile`）
7. 设置中增加开关，**默认开启**

### 假设

- macOS 默认 shell 为 zsh，但不排除用户使用 bash
- 端口号从 Clash 配置动态读取（已有 `ClashConfigReader`）
- ProxyGuard 对 `~/` 目录有文件写入权限

---

## 选定方案：Shell Profile 动态文件注入

### 核心机制

ProxyGuard 管理 `~/.proxyguard_env` 文件。代理开启时写入 export 语句，关闭时清空。用户在 shell 配置中 source 该文件。

```
代理状态变化 → handleProxyChange() → 同步更新 ~/.proxyguard_env
↓
新终端启动 → shell rc source ~/.proxyguard_env → 环境变量就位
```

### 文件内容

**代理开启时：**
```bash
# Managed by ProxyGuard — DO NOT EDIT
export http_proxy="http://127.0.0.1:7897"
export https_proxy="http://127.0.0.1:7897"
export all_proxy="socks5://127.0.0.1:7897"
```

**代理关闭时：**
```bash
# Managed by ProxyGuard — proxy disabled
```

---

### Shell 兼容方案

ProxyGuard 需要在用户的 shell 配置文件中注入一行 source 命令。兼容两种主流 shell：

| Shell | 配置文件 | 注入内容 |
|-------|---------|---------|
| zsh | `~/.zshrc` | `[ -f "$HOME/.proxyguard_env" ] && source "$HOME/.proxyguard_env"` |
| bash | `~/.bash_profile` | `[ -f "$HOME/.proxyguard_env" ] && source "$HOME/.proxyguard_env"` |

**安装方式（设置页按钮）：**

设置页提供 **"安装 Shell 集成"** 按钮：
1. 检测 `~/.zshrc` 和 `~/.bash_profile` 是否存在
2. 检查是否已包含 source 行（防重复注入）
3. 在文件末尾追加 source 行
4. 显示安装结果（✅ zsh 已安装 / ✅ bash 已安装 / ⚠️ 已存在）

提供 **"卸载 Shell 集成"** 按钮，移除注入行 + 删除 `~/.proxyguard_env`。

---

### 设置页开关

`ProxyConfig` 新增字段：

```swift
var terminalProxyEnabled: Bool  // 默认 true
```

| 开关状态 | 行为 |
|---------|------|
| 开启（默认） | 代理变化时同步更新 `~/.proxyguard_env` |
| 关闭 | 不管理 env 文件，已有文件内容清空 |

---

### 已打开终端的处理

对于已打开的终端，有以下几种思路，按推荐优先级排列：

#### 思路 1：菜单栏"复制代理命令"按钮 ⭐ 推荐

在 ProxyGuard 菜单栏新增 **"📋 复制代理命令"** 按钮：
- 代理开启时：复制 `source ~/.proxyguard_env` 到剪贴板
- 代理关闭时：复制 `unset http_proxy https_proxy all_proxy` 到剪贴板
- 用户在已打开的终端粘贴执行即可

**优势**：实现简单（一行剪贴板操作），用户主动控制
**劣势**：需要手动操作

#### 思路 2：precmd / PROMPT_COMMAND 钩子（可选高级模式）

将 source 脚本从静态 export 升级为注册 shell 钩子，让已打开终端在每次执行命令前自动检查文件变化：

```bash
# ~/.proxyguard_env 升级版 — 自动刷新模式
_proxyguard_check() {
  local envfile="$HOME/.proxyguard_env.d/exports"
  local ts_file="$HOME/.proxyguard_env.d/timestamp"
  local last="${_PROXYGUARD_LAST_TS:-0}"
  if [ -f "$ts_file" ]; then
    local current
    current=$(cat "$ts_file" 2>/dev/null)
    if [ "$current" != "$last" ]; then
      _PROXYGUARD_LAST_TS="$current"
      [ -f "$envfile" ] && source "$envfile"
    fi
  fi
}

# zsh 用 precmd，bash 用 PROMPT_COMMAND
if [ -n "$ZSH_VERSION" ]; then
  precmd_functions+=(_proxyguard_check)
elif [ -n "$BASH_VERSION" ]; then
  PROMPT_COMMAND="_proxyguard_check;${PROMPT_COMMAND}"
fi
```

**工作方式**：
- ProxyGuard 写入 `~/.proxyguard_env.d/exports`（实际环境变量）
- 同时更新 `~/.proxyguard_env.d/timestamp`（变更时间戳）
- Shell 钩子只比较时间戳字符串，仅在变化时才 source，性能开销极低

**优势**：已打开的终端在下一次按回车时自动刷新代理状态
**劣势**：每次命令前多一次文件 stat 检查（< 0.1ms，可忽略）

#### 思路 3：macOS 通知 + 手动刷新

ProxyGuard 在代理状态变化时发送 macOS 通知："代理已开启，新终端自动生效。已打开终端请执行 `source ~/.proxyguard_env`"。

**优势**：提醒用户，不需要额外代码
**劣势**：通知容易被忽略

### 推荐组合

- **默认行为**：思路 1（菜单栏复制按钮）+ 新终端自动 source
- **高级可选**：思路 2（precmd 钩子），在设置页提供"实时刷新模式"开关

---

## 📋 决策日志

| 决策 | 备选方案 | 选择理由 |
|------|---------|---------|
| 环境变量注入方式 | launchctl setenv | 副作用范围不可控，影响所有进程 |
| 与 ProxyGuard 集成 | 独立 Shell 脚本 | 无法区分 Clash/Proxyman，不受统一管理 |
| Shell 兼容 | 仅 zsh | 需要同时支持 bash 用户 |
| 设置开关默认值 | 默认关闭 | 代理设置是高频需求，默认开启更便捷 |
| 已打开终端 | AppleScript 远程控制 | 需要 Accessibility 权限，侵入性过强 |

## ✅ 验收标准

- [ ] Clash 代理开启时，`~/.proxyguard_env` 写入正确的 export 语句
- [ ] Clash 代理关闭时，`~/.proxyguard_env` 被清空
- [ ] 新 zsh 终端 source 后 `echo $http_proxy` 输出正确值
- [ ] 新 bash 终端 source 后 `echo $http_proxy` 输出正确值
- [ ] 设置页"终端代理"开关默认为开启
- [ ] 关闭开关后不再管理 env 文件
- [ ] "安装/卸载 Shell 集成"按钮正常工作
- [ ] 菜单栏"复制代理命令"按钮将正确命令复制到剪贴板
- [ ] Proxyman 接管代理时，不写入终端代理变量
