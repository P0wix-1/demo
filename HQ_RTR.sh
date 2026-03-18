#!/bin/bash

# Проверка на права root
if [ "$EUID" -ne 0 ]; then 
  echo "Пожалуйста, запустите скрипт от имени root"
  exit
fi

# Настройка портов
read -p "Введите названия портов (ens** ens** ens**): " -a ports

# Создание директорий (для всех трех интерфейсов)
mkdir -p /etc/net/ifaces/${ports[0]}
mkdir -p /etc/net/ifaces/${ports[1]}
mkdir -p /etc/net/ifaces/${ports[2]}

# Настройка IP и маршрутов
echo '172.16.1.2/28' > /etc/net/ifaces/${ports[0]}/ipv4address
echo 'default via 172.16.1.1' > /etc/net/ifaces/${ports[0]}/ipv4route
echo '192.168.100.1/27' > /etc/net/ifaces/${ports[1]}/ipv4address
echo '192.168.200.1/28' > /etc/net/ifaces/${ports[2]}/ipv4address

# Создание конфигурационных файлов options
for port in "${ports[@]}"; do
    cat << EOF > "/etc/net/ifaces/$port/options"
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
hostnamectl set-hostname HQ-SRV.au-team.irpo
sysctl -w net.ipv4.ip_forward=1
systemctl restart network

# Настройка Firewall
apt-get update && apt-get -y install firewalld
systemctl enable --now firewalld

firewall-cmd --permanent --zone=public --add-interface=${ports[0]}
firewall-cmd --permanent --zone=trusted --add-interface=${ports[1]}
firewall-cmd --permanent --zone=trusted --add-interface=${ports[2]}
firewall-cmd --permanent --zone=public --add-masquerade
firewall-cmd --complete-reload

# Создание учетной записи
useradd -m -u 2026 net_admin
echo "Введите пароль для пользователя sshuser:"
passwd net_admin

mkdir /etc/net/ifaces/ens34.100
mkdir /etc/net/ifaces/ens35.200
mkdir /etc/net/ifaces/ens33.999

cat << EOF > "/etc/net/ifaces/{ports[0]}.100/options"
TYPE=vlan
HOST={ports[0]}
VID=100
DISABLED=no
BOOTPROTO=static
ONBOOT=yes
CONFIG_IPV4=yes
EOF
done

cat << EOF > "/etc/net/ifaces/{ports[0]}.200/options"
TYPE=vlan
HOST={ports[0]}
VID=200
DISABLED=no
BOOTPROTO=static
ONBOOT=yes
CONFIG_IPV4=yes
EOF
done

cat << EOF > "/etc/net/ifaces/{ports[0]}.999/options"
TYPE=vlan
HOST={ports[0]}
VID=999
DISABLED=no
BOOTPROTO=static
ONBOOT=yes
CONFIG_IPV4=yes
EOF
done

echo "192.168.10.1/27" > /etc/net/ifaces/ens34.100/ipv4address
echo "192.168.20.1/28" > /etc/net/ifaces/ens35.200/ipv4address
echo "192.168.99.1/29" > /etc/net/ifaces/ens33.999/ipv4address

# Настройка DHCP
apt-get install -y dhcp-server
# Предполагается, что файл dhcpd.conf лежит в текущей директории
if [ -f "dhcpd.conf" ]; then
    cp -pf dhcpd.conf /etc/dhcp/
else
    echo "Внимание: dhcpd.conf не найден в текущей директории!"
fi

echo "DHCPDARGS=${ports[1]}" > /etc/sysconfig/dhcpd
systemctl enable dhcpd
systemctl restart dhcpd

echo "Настройка завершена успешно!"
