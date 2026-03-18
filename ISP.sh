#!/bin/bash

# Настройка портов
read -p "Введите названия портов (ens** ens** ens**): " -a ports

# Проверка, что введено 3 порта (ports[0], ports[1], ports[2])
if [ ${#ports[@]} -lt 3 ]; then
    echo "Ошибка: Нужно ввести минимум 3 порта."
    exit 1
fi

# Настройка интерфейсов (ports[1] и ports[2])
# Используем цикл, так как настройки идентичны
for i in 1 2; do
    IFACE=${ports[$i]}
    IP="192.168.$i.1/24"
    
    mkdir -p "/etc/net/ifaces/$IFACE"
    echo "$IP" > "/etc/net/ifaces/$IFACE/ipv4address"
    
    cat << EOF > "/etc/net/ifaces/$IFACE/options"
BOOTPROTO=static
TYPE=eth
CONFIG_WIRELESS=no
SYSTEMD_BOOTPROTO=static
CONFIG_IPV4=yes
DISABLED=no
NM_CONTROLLED=no
SYSTEMD_CONTROLLED=no
EOF
done

# Мелкая настройка
hostnamectl set-hostname ISP
sysctl -w net.ipv4.ip_forward=1
systemctl restart network

# Настройка Firewall
apt-get update && apt-get -y install firewalld
systemctl enable --now firewalld

firewall-cmd --permanent --zone=public --add-interface="${ports[0]}"
firewall-cmd --permanent --zone=trusted --add-interface="${ports[1]}"
firewall-cmd --permanent --zone=trusted --add-interface="${ports[2]}"
firewall-cmd --permanent --zone=public --add-masquerade
firewall-cmd --complete-reload

echo "Настройка завершена!"