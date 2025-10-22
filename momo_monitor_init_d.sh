#!/bin/sh /etc/rc.common

# put this as /etc/init.d/momo_monitor
# cat << 'EOF' > /etc/init.d/momo_monitor

# OpenWrt 服务脚本
# 负责管理 /usr/bin/momo_monitor.sh

USE_PROCD=1
START=99  # 启动优先级：99 (很晚，确保网络和 momo 都已启动)
STOP=10   # 停止优先级：10 (很早)

# 你的监控脚本的完整路径
MONITOR_SCRIPT="/usr/bin/momo_monitor.sh"

start_service() {
    # 检查脚本是否存在
    if [ ! -x "$MONITOR_SCRIPT" ]; then
        echo "错误: 监控脚本 $MONITOR_SCRIPT 不存在或不可执行"
        logger -t momo_monitor "错误: 监控脚本 $MONITOR_SCRIPT 不存在或不可执行"
        return 1
    fi

    procd_open_instance
    procd_set_param command /bin/sh "$MONITOR_SCRIPT"
    
    # --- 关键：自动重启 ---
    # 如果脚本意外崩溃或退出，procd 会自动重启它
    # [delay] [timeout] [fail_count]
    # 崩溃后等待 5 秒(NET_CHECK_INTERVAL) 重启, 
    # 如果在 3600秒(1小时) 内重启超过 5 次，则停止
    procd_set_param respawn 5 3600 5
    
    # 将脚本的 stdout 和 stderr 重定向到系统日志 (logread)
    procd_set_param stdout 1
    procd_set_param stderr 1
    
    procd_close_instance
}

# procd 会自动处理 stop 命令 (发送 SIGTERM/SIGKILL)
# 我们可以添加一个 reload，它只是简单地重启服务
reload_service() {
    stop
    start
}
EOF
