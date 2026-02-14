#!/bin/bash
# ProxyGuard 场景测试辅助工具

echo "========================================="
echo "ProxyGuard 场景测试辅助工具"
echo "========================================="
echo ""

# 检测 Clash 进程
check_clash_process() {
    if pgrep -f "Clash Verge" > /dev/null || pgrep -f "clash-verge" > /dev/null; then
        echo "✅ Clash Verge 进程: 运行中"
        return 0
    else
        echo "❌ Clash Verge 进程: 未运行"
        return 1
    fi
}

# 检测 Proxyman 进程
check_proxyman_process() {
    if pgrep -f "Proxyman" > /dev/null; then
        echo "✅ Proxyman 进程: 运行中"
        return 0
    else
        echo "❌ Proxyman 进程: 未运行"
        return 1
    fi
}

# 读取 Clash 配置
read_clash_config() {
    local config_file="$HOME/Library/Application Support/io.github.clash-verge-rev.clash-verge-rev/verge.yaml"
    if [ -f "$config_file" ]; then
        local enable=$(grep "^[[:space:]]*enable_system_proxy:" "$config_file" 2>/dev/null | sed 's/.*:[[:space:]]*//' || echo "unknown")
        local port=$(grep "^[[:space:]]*mixed-port:" "$config_file" 2>/dev/null | sed 's/.*:[[:space:]]*//' || \
                   grep "^[[:space:]]*port:" "$config_file" 2>/dev/null | sed 's/.*:[[:space:]]*//' || echo "7897")
        echo "📄 Clash 配置文件: 存在"
        echo "   - enable_system_proxy: $enable"
        echo "   - mixed-port/port: $port"
    else
        echo "⚠️  Clash 配置文件: 不存在 ($config_file)"
    fi
}

# 检查系统代理状态
check_system_proxy() {
    local http_state=$(networksetup -getwebproxy "Wi-Fi" 2>/dev/null | grep "Enabled" | awk '{print $3}')
    local http_port=$(networksetup -getwebproxy "Wi-Fi" 2>/dev/null | grep "Port" | awk '{print $2}')

    local https_state=$(networksetup -getsecurewebproxy "Wi-Fi" 2>/dev/null | grep "Enabled" | awk '{print $3}')
    local https_port=$(networksetup -getsecurewebproxy "Wi-Fi" 2>/dev/null | grep "Port" | awk '{print $2}')

    echo "🌐 系统代理状态:"
    echo "   - HTTP: ${http_state:-No} (Port: ${http_port:-N/A})"
    echo "   - HTTPS: ${https_state:-No} (Port: ${https_port:-N/A})"

    if [ "$http_state" = "Yes" ] || [ "$https_state" = "Yes" ]; then
        local current_port=${http_port:-$https_port}
        echo "   📍 当前代理端口: $current_port"

        # 判断是 Clash 还是 Proxyman 端口
        if [ "$current_port" = "7897" ]; then
            echo "   🔵 端口属于: Clash Verge (7897)"
        elif [ "$current_port" = "9090" ]; then
            echo "   🟠 端口属于: Proxyman (9090)"
        else
            echo "   ⚪ 端口属于: 其他"
        fi
    else
        echo "   ⭕ 系统代理: 已关闭"
    fi
}

# 显示当前状态摘要
show_status() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "当前状态快照"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    check_clash_process
    check_proxyman_process
    read_clash_config
    echo ""
    check_system_proxy
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

# 显示测试场景说明
show_scenarios() {
    echo "========================================="
    echo "测试场景说明"
    echo "========================================="
    echo ""
    echo "场景一: Proxyman 存在 + 端口7897 + Clash 开启"
    echo "  1. 启动 Clash Verge，确保系统代理开启"
    echo "  2. 启动 Proxyman"
    echo "  3. 手动关闭 Clash Verge"
    echo "  预期: 系统代理被关闭"
    echo ""
    echo "场景二: Proxyman 存在 + 端口7897 + Clash 关闭"
    echo "  1. 确保 Clash 关闭"
    echo "  2. 启动 Proxyman"
    echo "  3. 确保系统代理端口是 7897"
    echo "  预期: 切换到 Proxyman 端口 9090"
    echo ""
    echo "场景三: Proxyman 关闭 + 端口7897 + Clash 开启"
    echo "  1. 启动 Clash Verge"
    echo "  2. 确保 Proxyman 关闭"
    echo "  预期: 无需干预"
    echo ""
    echo "场景四: Proxyman 关闭 + 代理关闭 + Clash 开启"
    echo "  1. 启动 Clash Verge"
    echo "  2. 确保 Proxyman 关闭"
    echo "  3. 手动关闭系统代理"
    echo "  预期: 自动恢复为 Clash 代理"
    echo ""
    echo "场景五: Proxyman 关闭 + 代理关闭 + Clash 关闭"
    echo "  1. 确保 Clash 和 Proxyman 都关闭"
    echo "  2. 关闭系统代理"
    echo "  预期: 不干预"
    echo ""
    echo "场景六: Proxyman 关闭 + 端口9090 + Clash 开启"
    echo "  1. 启动 Clash Verge"
    echo "  2. 确保 Proxyman 关闭"
    echo "  3. 手动设置系统代理为 9090 (模拟 Proxyman 刚关闭)"
    echo "  预期: 自动恢复为 Clash 代理"
    echo ""
    echo "场景七: Proxyman 关闭 + 端口9090 + Clash 关闭"
    echo "  1. 确保 Clash 和 Proxyman 都关闭"
    echo "  2. 系统代理端口是 9090"
    echo "  预期: 关闭系统代理"
    echo ""
}

# 实时监控模式
monitor_mode() {
    echo "🔍 实时监控模式 (Ctrl+C 退出)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    local counter=0
    while true; do
        counter=$((counter + 1))
        clear
        echo "🔄 扫描 #$counter - $(date '+%H:%M:%S')"
        echo ""
        check_clash_process
        check_proxyman_process
        echo ""
        check_system_proxy
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "按 Ctrl+C 退出监控..."
        sleep 3
    done
}

# 主菜单
show_menu() {
    echo "========================================="
    echo "请选择操作:"
    echo "========================================="
    echo "1) 显示当前状态"
    echo "2) 显示测试场景说明"
    echo "3) 实时监控模式"
    echo "4) 退出"
    echo ""
    read -p "请输入选项 [1-4]: " choice

    case $choice in
        1)
            show_status
            ;;
        2)
            show_scenarios
            ;;
        3)
            monitor_mode
            ;;
        4)
            echo "退出..."
            exit 0
            ;;
        *)
            echo "无效选项，请重试"
            show_menu
            ;;
    esac
}

# 如果带参数，直接执行对应操作
case "${1:-}" in
    status)
        show_status
        ;;
    scenarios)
        show_scenarios
        ;;
    monitor)
        monitor_mode
        ;;
    *)
        show_menu
        ;;
esac
