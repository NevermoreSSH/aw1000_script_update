#!/bin/bash

# Update Script Installer
# For firmware -
# Created by: NevermoreSSH

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

function update_description() {
  echo "Updating New ImmortalWrt version string"
  sed -i "s/DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION='ImmortalWRT 24.10.1-4 Updated by NevermoreSSH'/g" /etc/openwrt_release
}

function addcustom_feed() {
  local feed_url="https://github.com/NevermoreSSH/aw1000_script_update/releases/download/aw1000_immo23"
  if ! grep -q "$feed_url" /etc/opkg/customfeeds.conf; then
    echo "Adding custom package feed"
    echo "src/gz custom_packages $feed_url" >> /etc/opkg/customfeeds.conf
  else
    echo "Custom feed already added"
  fi
}

function autoreconnect_v1() {
  echo "Create iface reconnect-script"
  cat << 'EOF' > /etc/hotplug.d/iface/88-autoreconnect
#!/bin/sh

log () {
	modlog "$@"
}

[ "$ACTION" = ifup -o "$ACTION" = ifupdate ] || exit 0
	sleep 2
	sh /etc/config/reconnect_wwan
  logger "CustomSC - AutoReconnect when $INTERFACE ($DEVICE) is now up"
	fi
fi
EOF
  sleep 2
}

function config_rc() {
  echo "Create config interface"

  cat << 'EOF' >> /etc/config/reconnect_wwan
#!/bin/sh
# script checking internet running or timeout.
# default settings : checking 30s, max attempts 5,

MAX_ATTEMPTS=5
DELAY=10

while true; do
  ATTEMPT=1
  SUCCESS=0

  while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    ip1=$(curl -s ifconfig.io)
    ip2=$(curl -s google.com)
    ip3=$(curl -s github.com)
    ip4=$(curl -s youtube.com)

    if [ -n "$ip1" ] || [ -n "$ip2" ] || [ -n "$ip3" ] || [ -n "$ip4" ]; then
      SUCCESS=1
      echo "[STATUS] WWAN0 OK. Internet detected. Checking again in 30 seconds..."
      break
    fi

    echo "Attempt $ATTEMPT: No connection. Retrying in $DELAY seconds..."
    logger "CustomSC - Attempt $ATTEMPT: No internet. Retrying in $DELAY seconds..."
    sleep $DELAY
    ATTEMPT=$((ATTEMPT + 1))
  done

  if [ $SUCCESS -eq 0 ]; then
    echo "[ACTION] Restarting wwan0..."
    logger "CustomSC - Restarting wan/wwan0 after $MAX_ATTEMPTS failed attempts"
    ifup wan
    ifup wwan0
    sleep 10

    ip5=$(curl -s ifconfig.io)
    ip6=$(curl -sS ifconfig.me; echo)

    if [ -n "$ip5" ] || [ -n "$ip6" ]; then
      echo "CustomSC - Success, internet detected, current public IP: $ip5 , $ip6"
      logger "CustomSC - Success, internet detected, current public IP: $ip5 , $ip6"
    else
      echo "CustomSC - Success, internet detected, but failed to detect public IP"
      logger "CustomSC - Success, internet detected, but failed to detect public IP"
    fi
  fi

  sleep 30
done

EOF

  echo "Done created config autoreconnect."
}



function finish() {
  echo "Installation completed successfully!"
  echo "Reboot in 10sec, thank you."
  rm -r /root/rc1.sh
  sleep 10
  reboot
}

function main() {
  #update_description
  #addcustom_feed
  autoreconnect_v1
  config_rc
  finish
}

main
