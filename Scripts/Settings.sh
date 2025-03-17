#!/bin/bash

# 修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")

# 修改 immortalwrt.lan 关联 IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/192.168.88.1/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")

# 添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

CFG_FILE="./package/base-files/files/bin/config_generate"
# 修改默认 IP 地址为 192.168.88.1
sed -i "s/192\.168\.[0-9]*\.[0-9]*/192.168.88.1/g" $CFG_FILE
# 修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

# 配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

# 手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
    echo -e "$WRT_PACKAGE" >> ./.config
fi

# 配置网口
CFG_FILE="./package/base-files/files/bin/config_generate"

# 配置 eth0 和 eth3 绑定为 br-lan 网桥
if ! grep -q "option ifname 'eth0 eth3'" $CFG_FILE; then
    sed -i "/config interface 'lan'/a\    option ifname 'eth0 eth3'" $CFG_FILE
fi
if ! grep -q "option type 'bridge'" $CFG_FILE; then
    sed -i "/config interface 'lan'/a\    option type 'bridge'" $CFG_FILE
fi

# 配置 eth1 为 WAN 口，拨号模式 (假设使用 PPPoE)
if ! grep -q "option ifname 'eth1'" $CFG_FILE; then
    sed -i "/config interface 'wan'/a\    option ifname 'eth1'" $CFG_FILE
fi
if ! grep -q "option proto 'pppoe'" $CFG_FILE; then
    sed -i "/config interface 'wan'/a\    option proto 'pppoe'" $CFG_FILE
fi
if [ -n "$WRT_WAN_USER" ] && [ -n "$WRT_WAN_PASSWORD" ]; then
    sed -i "/config interface 'wan'/a\    option username '$WRT_WAN_USER'" $CFG_FILE
    sed -i "/config interface 'wan'/a\    option password '$WRT_WAN_PASSWORD'" $CFG_FILE
fi

# 配置 eth2 为 WAN1 口，拨号模式 (假设使用 PPPoE)
if ! grep -q "option ifname 'eth2'" $CFG_FILE; then
    sed -i "/config interface 'wan1'/a\    option ifname 'eth2'" $CFG_FILE
fi
if ! grep -q "option proto 'pppoe'" $CFG_FILE; then
    sed -i "/config interface 'wan1'/a\    option proto 'pppoe'" $CFG_FILE
fi
if [ -n "$WRT_WAN1_USER" ] && [ -n "$WRT_WAN1_PASSWORD" ]; then
    sed -i "/config interface 'wan1'/a\    option username '$WRT_WAN1_USER'" $CFG_FILE
    sed -i "/config interface 'wan1'/a\    option password '$WRT_WAN1_PASSWORD'" $CFG_FILE
fi

# 配置 LAN 口 DHCP 从 192.168.88.10 开始
if ! grep -q "option start '10'" $CFG_FILE; then
    sed -i "/config interface 'lan'/a\    option start '10'" $CFG_FILE
fi
if ! grep -q "option limit '100'" $CFG_FILE; then
    sed -i "/config interface 'lan'/a\    option limit '100'" $CFG_FILE
fi
if ! grep -q "option leasetime '12h'" $CFG_FILE; then
    sed -i "/config interface 'lan'/a\    option leasetime '12h'" $CFG_FILE
fi
