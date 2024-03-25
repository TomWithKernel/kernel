#!/bin/bash
#	author: ut005594

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
#			echo -e "Bus $busnum Device $devnum : $productName power wakeup: \t\t\t$result"
			printf "Bus %3s Device %3s : %-30s power wakeup: %10s\n" $busnum $devnum "$productName" $result
		fi
	fi
done