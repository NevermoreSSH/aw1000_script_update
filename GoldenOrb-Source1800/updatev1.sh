#!/bin/bash

# Update Script Installer
# For firmware GoldenOrb-Source1800-immortalwrt-qualcommax-ipq807x-arcadyan_aw1000
# Created by: NevermoreSSH

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

function update_preset() {
  echo "Updating New ImmortalWrt version string"
  sed -i "s/DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION='GoldenOrb-Source1800-26-May-2024 ( Updated )'/g" /etc/openwrt_release
  sed -i 's/option check_signature/# option check_signature/g' /etc/opkg.conf
  uci set system.@system[0].timezone='MYT-8'
  uci set system.@system[0].zonename='Asia/Kuala Lumpur'
  uci commit system
  uci set atinout.general.atc_port='/dev/ttyUSB2'
  uci -q commit atinout
  uci set dhcp.lan.leasetime='168h'
  uci commit dhcp
  >/usr/share/passwall/rules/proxy_ip
>/usr/share/passwall/rules/proxy_host
>/usr/share/passwall/rules/domains_excluded
>/usr/share/passwall/rules/direct_ip
>/usr/share/passwall/rules/direct_host
>/usr/share/passwall/rules/block_ip
>/usr/share/passwall/rules/block_host
>/usr/share/passwall/rules/gfwlist
>/usr/share/passwall/rules/chnroute6
>/usr/share/passwall/rules/chnroute
>/usr/share/passwall/rules/chnlist
uci set firewall.@defaults[0].flow_offloading='0'
uci set firewall.@defaults[0].flow_offloading_hw='0'
uci commit firewall
}

function new_repo() {
rm -r /etc/opkg/distfeeds.conf;cat <<'EOF' >>/etc/opkg/distfeeds.conf
## Remote package repositories
src/gz immortalwrt_base https://downloads.immortalwrt.org/releases/23.05.2/packages/aarch64_cortex-a53/base
src/gz immortalwrt_luci https://downloads.immortalwrt.org/releases/23.05.2/packages/aarch64_cortex-a53/luci
src/gz immortalwrt_packages https://downloads.immortalwrt.org/releases/23.05.2/packages/aarch64_cortex-a53/packages
src/gz immortalwrt_routing https://downloads.immortalwrt.org/releases/23.05.2/packages/aarch64_cortex-a53/routing
src/gz immortalwrt_telephony https://downloads.immortalwrt.org/releases/23.05.2/packages/aarch64_cortex-a53/telephony
src/gz immortalwrt_kmods2 https://github.com/NevermoreSSH/snapshot-package/releases/download/kmod-ipq807x-6.6.29-1-55a62e5583a43b5e864d5270379b266e

EOF
sleep 1
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

function install_packages() {
  echo "Updating opkg and installing packages"
  curl -LO https://github.com/NevermoreSSH/aw1000_script_update/releases/download/golden_orb_source18/atinout_0.9.1_aarch64_cortex-a53.ipk
  curl -LO https://github.com/NevermoreSSH/aw1000_script_update/releases/download/golden_orb_source18/luci-app-atinout_0.1.0-r6_all.ipk
  opkg update
  opkg install luci-app-modeminfo luci-app-sqm luci-app-tailscale luci-app-passwall2 luci-theme-alpha luci-app-alpha-config luci-app-adblock luci-app-watchcat luci-app-vnstat luci-app-atinout atinout
}

function setup_crontab() {
  echo "Setup RAM release every 6h"
  if ! grep -q "drop_caches" /etc/crontabs/root; then
    echo "# Release RAM Every 6 hours" >> /etc/crontabs/root
    echo "0 */6 * * * sync && echo 3 > /proc/sys/vm/drop_caches" >> /etc/crontabs/root
	echo "# Reboot Router Every Week 5AM Sunday" >> /etc/crontabs/root
    echo "0 5 * * 0 reboot" >> /etc/crontabs/root
	echo "# Adblock Reload Every 1Hour" >> /etc/crontabs/root
    echo "0 * * * * /etc/init.d/adblock reload" >> /etc/crontabs/root
  else
    echo "Cron job already exists"
  fi
}

function configure_cpufreq() {
  echo "Configuring CPU from Performance to Efficient mode"
  uci set cpufreq.cpufreq.governor0='schedutil'
  uci set cpufreq.global.set='1'
  uci commit cpufreq
}

function install_xray_binary() {
  echo "Installing New Xray-core v25 Multipath"
  rm -rf /usr/bin/xray
  cd /tmp || exit
  curl -L -o Xray.zip https://github.com/NevermoreSSH/aw1000_script_update/releases/download/aw1000_immo23/Xray-linux-arm64-v8a-v25.3.31.zip
  unzip *.zip
  mv xray /usr/bin
  chmod +x /usr/bin/xray
  rm -f *.zip *.dat LICENSE README.md
  echo "Xray version installed:"
  xray version
}

function restart_wg_script() {
  echo "Creating WireGuard autoreconnect script"
  cat << 'EOF' > /root/restart_wg
#!/bin/sh
# Restart WG when DC

# Interface WG
wgname=$(wg show | grep 'interface' | awk '{print $2}')

# Ping CF DNS server 10 times
ping -c 10 1.1.1.1

# Check if the last command (ping) was successful
if [ $? -ne 0 ]; then
  # Ping failed, restart wireguard interface
  ifdown $wgname
  ifup $wgname
  logger "CustomSC - (WireGuard) Restart after failed ping 10 times"
fi
EOF
  chmod +x /root/restart_wg
}

function cron_restart_wg() {
  echo "Setup WireGuard restart cronjob"
  if ! grep -q "restart_wg" /etc/crontabs/root; then
    echo "#* * * * * sh /root/restart_wg" >> /etc/crontabs/root
  else
    echo "Cron job for restart_wg already exists"
  fi
}

function update_atcommands() {
  echo "Updating AT Commands & others presets"

  rm -r /etc/atcommands.user;cat << 'EOF' >> /etc/atcommands.user
Show Attention Identify ;ATI
Show IMSI ;AT+CIMI
Change IMEI ;AT+EGMR=1,7,"IMEI NUMBER"
 ;
Show current preferred mode ;AT+QNWPREFCFG="mode_pref"
Set LTE/4G preferred mode ;AT+QNWPREFCFG="mode_pref",LTE
Set NR/5G preferred mode ;AT+QNWPREFCFG="mode_pref",NR5G:LTE
Set AUTO preferred mode ;AT+QNWPREFCFG="mode_pref",AUTO
 ;
Show neighbour cell ;AT+QENG="neighbourcell"
Show CA Status ;AT+QCAINFO
 ;
Switch off modem ;AT+CFUN=0
Switch on modem ;AT+CFUN=1
Airplane mode modem ;AT+CFUN=4
EOF
sleep 1

  echo "AT Commands lists updated."
}

function download_config_files() {
  echo "Downloading updated config files"
  wget -q -O /etc/config/alpha "https://github.com/NevermoreSSH/aw1000_script_update/releases/download/aw1000_immo23/alpha"
  wget -q -O /etc/config/tailscale "https://github.com/NevermoreSSH/aw1000_script_update/releases/download/aw1000_immo23/tailscale"
  wget -q -O /etc/config/passwall2 "https://github.com/NevermoreSSH/aw1000_script_update/releases/download/aw1000_immo23/passwall2"
  wget -q -O /etc/rc.local "https://github.com/NevermoreSSH/aw1000_script_update/releases/download/aw1000_immo23/rc.local"
  wget -q -O /usr/lib/lua/luci/view/rooter/net_status.htm "https://github.com/NevermoreSSH/openwrt-packages2/releases/download/arca_presetv2/net_status.htm"
}


function finish() {
  echo "Installation completed successfully!"
  mkdir -p /etc/vnstat/;sed -i 's|DatabaseDir "/var/lib/vnstat"|DatabaseDir "/etc/vnstat"|g' /etc/vnstat.conf;/etc/init.d/vnstat restart
  uci delete watchcat.@watchcat[0];uci commit watchcat;
  sed -i "s/option udp_proxy_drop_ports '80,443'/option udp_proxy_drop_ports 'disable'/g" /etc/config/passwall
  cd;rm -r *.ipk
  echo "Reboot your device to apply all changes."
}

function main() {
  update_preset
  new_repo
  addcustom_feed
  install_packages
  setup_crontab
  #configure_cpufreq
  install_xray_binary
  restart_wg_script
  cron_restart_wg
  update_atcommands
  download_config_files
  finish
}

main
