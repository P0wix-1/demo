#!/bin/bash

# Проверка на права root
if [ "$EUID" -ne 0 ]; then 
  echo "Пожалуйста, запустите скрипт от имени root"
  exit 1
fi

# Настройка портов (ручной ввод, как вы просили)
read -p "Введите названия портов (ens** ens**): " -a ports

# Проверка количества введённых интерфейсов
if [ ${#ports[@]} -lt 2 ]; then
    echo "Ошибка: Нужно ввести минимум 2 порта (внешний и внутренний)."
    exit 1
fi

# Создание директорий и настройка IP
# ports[0] - Внешний (192.168.2.2)
# ports[1] - Внутренний (192.168.5.1)
mkdir -p "/etc/net/ifaces/${ports[0]}"
mkdir -p "/etc/net/ifaces/${ports[1]}"

echo '192.168.2.2/24' > "/etc/net/ifaces/${ports[0]}/ipv4address"
echo '192.168.5.1/24' > "/etc/net/ifaces/${ports[1]}/ipv4address"

# Создание конфигурационных файлов options через цикл
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
hostnamectl set-hostname HQ-RTR.au-team.irpo
sysctl -w net.ipv4.ip_forward=1
systemctl restart network

# Настройка Firewall
apt-get update && apt-get -y install firewalld
systemctl enable --now firewalld

firewall-cmd --permanent --zone=public --add-interface="${ports[0]}"
firewall-cmd --permanent --zone=trusted --add-interface="${ports[1]}"
firewall-cmd --permanent --zone=public --add-masquerade
firewall-cmd --complete-reload

# Создание учетной записи (как в предыдущем варианте)
useradd -m -u 2026 net_admin
echo "Введите пароль для пользователя sshuser:"
useradd -m -u 2026 net_admin

echo "Настройка HQ-RTR завершена успешно!"
