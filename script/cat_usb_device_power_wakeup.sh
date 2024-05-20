#!/bin/bash
#       author: ut005594

fileName=""
productName=""

for file in /sys/bus/usb/devices/*/uevent; do
        content=$(cat "$file")
        if echo "$content" | grep -q "BUSNUM=$1" && echo "$content" | grep -q "DEVNUM=$2"; then
                fileName="${file%/*}/power/wakeup"
                productName="${file%/*}/product"

                if [ -f "$fileName" ]; then
                        busnum=$(echo "$content" | grep -oE 'BUSNUM=([0-9]+)' | grep -oE '[0-9]+')
                        devnum=$(echo "$content" | grep -oE 'DEVNUM=([0-9]+)' | grep -oE '[0-9]+')

                        result=$(cat "$fileName")
                        productName=$(cat "$productName")
                        printf "Bus %3s Device %3s : %-30s power wakeup: %10s (路径: %s)\n" $busnum $devnum "$productName" $result "${file%/*}/product"
                fi
        fi
done

# 读取用户输入的设备节点和开关状态
read -p "请输入你要修改的设备的节点（例如 1-4.4.2 表示 BUSNUM-DEVNUM）: " modify_device
read -p "请输入 enabled 或 disabled: " switch

# 检查用户输入的开关状态是否正确
if [[ "$switch" != "enabled" && "$switch" != "disabled" ]]; then
    echo "无效输入。请输入 'enabled' 或 'disabled'。"
    exit 1
fi

# 构造设备路径
device_path="/sys/bus/usb/devices/$modify_device/power/wakeup"

# 检查设备路径是否存在
if [ ! -f "$device_path" ]; then
    echo "设备路径不存在或无效: $device_path"
    exit 1
fi

# 修改设备的 power wakeup 状态
echo $switch | sudo tee "$device_path" > /dev/null

# 确认修改结果
new_result=$(cat "$device_path")
echo "设备 $modify_device 的 power wakeup 状态已设置为: $new_result"
