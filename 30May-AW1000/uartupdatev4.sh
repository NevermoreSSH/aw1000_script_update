#!/bin/bash

# Update Script Installer
# For firmware 30May-immortalwrt-qualcommax-ipq807x-arcadyan_aw1000
# Created by: NevermoreSSH

if [ "$(id -u)" != "0" ]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

function update_description() {
  echo "Updating New ImmortalWrt version string"
  sed -i "s/DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION='ImmortalWrt 23.05.2-Updated v4.0 by NevermoreSSH'/g" /etc/openwrt_release
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
  opkg update
  opkg install luci-app-modeminfo luci-app-sqm luci-app-tailscale luci-app-passwall2 luci-theme-alpha luci-app-alpha-config
}

function setup_ram_release() {
  echo "Setup RAM release every 6h"
  if ! grep -q "drop_caches" /etc/crontabs/root; then
    echo "# Release RAM Every 6 hours" >> /etc/crontabs/root
    echo "0 */6 * * * sync && echo 3 > /proc/sys/vm/drop_caches" >> /etc/crontabs/root
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

function create_restart_wg_script() {
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

function setup_cron_restart_wg() {
  echo "Setup WireGuard restart cronjob"
  if ! grep -q "restart_wg" /etc/crontabs/root; then
    echo "#* * * * * sh /root/restart_wg" >> /etc/crontabs/root
  else
    echo "Cron job for restart_wg already exists"
  fi
}

function update_at_commands() {
  echo "Updating AT Commands presets"

  rm -r /etc/modem/atcommands.user  && cat << 'EOF' >> /etc/modem/atcommands.user
Show MT Identification Information ? ATI;ATI
Show IMSI ? AT+CIMI;AT+CIMI
Change IMEI ? AT+EGMR=1,7,"IMEI NUMBER";AT+EGMR=1,7,"861932058397409"
Show current preferred mode ? AT+QNWPREFCFG="mode_pref”;AT+QNWPREFCFG="mode_pref"
Set LTE/4G preferred mode ? AT+QNWPREFCFG="mode_pref",LTE;AT+QNWPREFCFG="mode_pref",LTE
Set NR/5G preferred mode ? AT+QNWPREFCFG="mode_pref",NR5G:LTE;AT+QNWPREFCFG="mode_pref",NR5G:LTE
Set AUTO preferred mode ? AT+QNWPREFCFG="mode_pref",AUTO;AT+QNWPREFCFG="mode_pref",AUTO
Setting Lock PCI ? AT+QNWLOCK=?;AT+QNWLOCK=?
Lock 4G PCI ? AT+QNWLOCK="common/4g",(0-10),<freq>,<pci>;AT+QNWLOCK="common/4g",(0-10),<freq>,<pci>
Lock 5G PCI ? AT+QNWLOCK="common/5g",<pci>,<earfcn>,<scs>,<band>;AT+QNWLOCK="common/5g",<pci>,<earfcn>,<scs>,<band>
Show neighbour cell ? AT+QENG="neighbourcell”; AT+QENG="neighbourcell"
Show CA Status ? AT+QCAINFO;AT+QCAINFO
Show Protocol using ? AT+QCFG="usbnet";AT+QCFG="usbnet"
Use QMI Protocol ? AT+QCFG="usbnet",0;AT+QCFG="usbnet",0
Use USB0 Protocol ? AT+QCFG="usbnet",1;AT+QCFG="usbnet",1
Use MBIM ? AT+QCFG="usbnet",2;AT+QCFG="usbnet",2
Switch off modem ? AT+CFUN=0;AT+CFUN=0
Switch on modem ? AT+CFUN=1;AT+CFUN=1
Airplane mode modem ? AT+CFUN=4;AT+CFUN=4
EOF

  rm -r /etc/modem/atcmmds.user && cat << 'EOF' >> /etc/modem/atcmmds.user
Show MT Identification Information ? ATI;ATI
Show IMSI ? AT+CIMI;AT+CIMI
Change IMEI ? AT+EGMR=1,7,"IMEI NUMBER";AT+EGMR=1,7,"861932058397409"
Show current preferred mode ? AT+QNWPREFCFG="mode_pref”;AT+QNWPREFCFG="mode_pref"
Set LTE/4G preferred mode ? AT+QNWPREFCFG="mode_pref",LTE;AT+QNWPREFCFG="mode_pref",LTE
Set NR/5G preferred mode ? AT+QNWPREFCFG="mode_pref",NR5G:LTE;AT+QNWPREFCFG="mode_pref",NR5G:LTE
Set AUTO preferred mode ? AT+QNWPREFCFG="mode_pref",AUTO;AT+QNWPREFCFG="mode_pref",AUTO
Setting Lock PCI ? AT+QNWLOCK=?;AT+QNWLOCK=?
Lock 4G PCI ? AT+QNWLOCK="common/4g",(0-10),<freq>,<pci>;AT+QNWLOCK="common/4g",(0-10),<freq>,<pci>
Lock 5G PCI ? AT+QNWLOCK="common/5g",<pci>,<earfcn>,<scs>,<band>;AT+QNWLOCK="common/5g",<pci>,<earfcn>,<scs>,<band>
Show neighbour cell ? AT+QENG="neighbourcell”; AT+QENG="neighbourcell"
Show CA Status ? AT+QCAINFO;AT+QCAINFO
Show Protocol using ? AT+QCFG="usbnet";AT+QCFG="usbnet"
Use QMI Protocol ? AT+QCFG="usbnet",0;AT+QCFG="usbnet",0
Use USB0 Protocol ? AT+QCFG="usbnet",1;AT+QCFG="usbnet",1
Use MBIM ? AT+QCFG="usbnet",2;AT+QCFG="usbnet",2
Switch off modem ? AT+CFUN=0;AT+CFUN=0
Switch on modem ? AT+CFUN=1;AT+CFUN=1
Airplane mode modem ? AT+CFUN=4;AT+CFUN=4
EOF

  echo "AT Commands lists updated."
}

function download_config_files() {
  echo "Downloading updated config files"
  wget -q -O /etc/config/alpha "https://github.com/NevermoreSSH/aw1000_script_update/releases/download/aw1000_immo23/alpha"
  wget -q -O /etc/config/tailscale "https://github.com/NevermoreSSH/aw1000_script_update/releases/download/aw1000_immo23/tailscale"
  wget -q -O /etc/config/passwall2 "https://github.com/NevermoreSSH/aw1000_script_update/releases/download/aw1000_immo23/passwall2"
  wget -q -O /etc/rc.local "https://github.com/NevermoreSSH/aw1000_script_update/releases/download/aw1000_immo23/rc.local"
}


function finish() {
  echo "Installation completed successfully!"
  echo "Reboot your device to apply all changes."
}

function main() {
  update_description
  addcustom_feed
  install_packages
  setup_ram_release
  configure_cpufreq
  install_xray_binary
  create_restart_wg_script
  setup_cron_restart_wg
  update_at_commands
  download_config_files
  finish
}

main
