#!/bin/sh
# update.sh - for firmware 30May-immortalwrt-qualcommax-ipq807x-arcadyan_aw1000-squashfs-sysupgrade.bin
sed -i "s/DISTRIB_DESCRIPTION=.*/DISTRIB_DESCRIPTION='ImmortalWrt 23.05.2-SNAPSHOT v4.0 by NevermoreSSH'/g" /etc/openwrt_release;
echo "src/gz custom_packages https://github.com/NevermoreSSH/aw1000_script_update/releases/download/aw1000_immo23" >> /etc/opkg/customfeeds.conf;
opkg update;opkg install luci-app-modeminfo luci-app-sqm luci-app-tailscale luci-app-passwall2 luci-theme-alpha luci-app-alpha-config;
echo "# Release RAM Every 6 hours" >> /etc/crontabs/root;
echo "0 */6 * * * sync && echo 3 > /proc/sys/vm/drop_caches" >> /etc/crontabs/root;
uci set cpufreq.cpufreq.governor0='schedutil';
uci set cpufreq.global.set='1';
uci commit cpufreq;
# Update Xray binary
rm -r /usr/bin/xray && cd /tmp && curl -L https://github.com/NevermoreSSH/aw1000_script_update/releases/download/aw1000_immo23/Xray-linux-arm64-v8a-v25.3.31.zip > Xray-linux-arm64-v8a-v25.3.31.zip && unzip *.zip && mv xray /usr/bin && chmod +x /usr/bin/xray && rm *.zip *.dat LICENSE README.md && xray version;
wget -q -O /etc/config/alpha "https://github.com/NevermoreSSH/aw1000_script_update/releases/download/aw1000_immo23/alpha";
wget -q -O /etc/config/tailscale "https://github.com/NevermoreSSH/aw1000_script_update/releases/download/aw1000_immo23/tailscale";
wget -q -O /etc/rc.local "https://github.com/NevermoreSSH/aw1000_script_update/releases/download/aw1000_immo23/rc.local";
cd;rm -r installer2.sh;sleep 5;reboot
