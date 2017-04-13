#!/bin/bash
# Set this to run every minute via cron
# You have to create the ramdisk by adding it to your fstab.  You also have to change the path to pi_client.rb.
[ -f /ramdisk/ping ] || echo 0 > /ramdisk/ping
ping_timestamp=$(< /ramdisk/ping)
current_timestamp=$(date +%s)
age=`expr $current_timestamp - $ping_timestamp`
if (( age > 12 )); then
  pkill pi_client.rb
  sleep 1
  pkill -9 pi_client.rb
  sleep 1
  /home/pi/.rbenv/shims/ruby /home/pi/pi_client/pi_client.rb &
fi
