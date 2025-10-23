#!/bin/sh

# put this as /usr/bin/momo_monitor.sh

# --- 配置 ---
CHECK_URL="https://www.gstatic.com/generate_204" # 谷歌的连接测试 URL
CONNECT_TIMEOUT=3  # curl 连接超时时间 (秒)
MAX_TIME=5         # curl 总超时时间 (秒)
MOMO_CHECK_INTERVAL=30 # momo 未运行时，的检查间隔 (秒)
NET_CHECK_INTERVAL=5   # momo 运行时，的网络检查间隔 (秒)

# 启动延迟 (秒)
#  脚本启动后等待 N 秒再开始监控。
#  这可以防止在开机时，momo 尚未准备好时就误判。
#  如果你的 momo 启动很慢，可以适当调高此值。
BOOT_DELAY=90

# 失败阈值 (次)
# 连续 N 次网络检查失败后，才执行 stop。
# 这可以防止因网络瞬时抖动而误判。
FAILURE_THRESHOLD=10

# BARK 通知 API
NOTIFY_API="https://api.day.app/PLACEHOLDER"
NOTIFY_TITLE="Momo监控提醒"
NOTIFY_BODY="Momo因为连接超时而自动关闭"

# --- 脚本 ---

# 日志函数
log_msg() {
    local msg="$1"
    # 作为守护进程，只使用 logger
    logger -t momo_monitor "$msg"
}

# 1. 检查 'curl'
if ! command -v curl >/dev/null 2>&1; then
    log_msg "错误: 'curl' 未安装。"
    exit 1
fi

# --- 应用启动延迟 ---
log_msg "Momo 监控服务已启动, 等待 ${BOOT_DELAY} 秒 (开机宽限期)..."
sleep ${BOOT_DELAY}
log_msg "启动宽限期结束, 开始正式监控..."

# 内部状态变量
NET_FAILURE_COUNT=0

# 2. 开始主循环
while true
do
    # 3. 检查 momo 服务状态
    if /etc/init.d/momo status | grep -q "running"; then
        # 状态: Momo 正在运行
        
        # 4. 检查互联网连接
        if curl -s -o /dev/null --connect-timeout ${CONNECT_TIMEOUT} --max-time ${MAX_TIME} ${CHECK_URL}; then
            # 互联网连接正常 (curl 返回 0)
            
            # 如果之前有失败计数，打印一条恢复日志
            if [ $NET_FAILURE_COUNT -gt 0 ]; then
                log_msg "互联网连接已恢复。"
            fi
            NET_FAILURE_COUNT=0 # 重置计数器
            sleep ${NET_CHECK_INTERVAL}
            
        else
            # 互联网连接失败 (curl 返回非 0)
            NET_FAILURE_COUNT=$((NET_FAILURE_COUNT + 1))
            log_msg "互联网连接失败 (第 $NET_FAILURE_COUNT 次 / 共需 $FAILURE_THRESHOLD 次)"
            
            if [ $NET_FAILURE_COUNT -ge $FAILURE_THRESHOLD ]; then
                log_msg "已达到连续失败阈值。正在停止 momo..."

                # 发送通知
                curl -s "${NOTIFY_API}/${NOTIFY_TITLE}/${NOTIFY_BODY}" >/dev/null 2>&1

                /etc/init.d/momo stop
                NET_FAILURE_COUNT=0 # 停止后重置计数器
                sleep ${MOMO_CHECK_INTERVAL} # 进入 momo 停止后的检查周期
            else
                # 未达到阈值，等待 5 秒后重试
                sleep ${NET_CHECK_INTERVAL}
            fi
        fi
    else
        # 状态: Momo 未运行
        if [ $NET_FAILURE_COUNT -gt 0 ]; then
            log_msg "Momo 未运行, 重置网络失败计数器。"
            NET_FAILURE_COUNT=0 # momo 停止了，重置计数器
        fi
        sleep ${MOMO_CHECK_INTERVAL}
    fi
done
