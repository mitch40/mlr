#!/bin/bash

test -f /opt/configured

if [ $? -eq 0 ];then
	echo "Routeur already initialised"
else
	# Désactivation de l'IPV6 et de la non prédication du nom des interfaces réseaux
	perl -p -i -e 's/(?<=GRUB_CMDLINE_LINUX=).+/"ipv6.disable=1 net.ifnames=0 biosdevname=0"/g' /etc/default/grub
	update-grub

	# Chaque interface réseaux disposera désormais de son propre fichier de configuration
	mkdir "/etc/network/interfaces.d" 2>/dev/null
fi

	# On charge tous les éventuels fichiers des interfaces réseaux depuis le fichier originel

cat > /etc/network/interfaces << EOF
source /etc/network/interfaces.d/*
# The loopback network interface
auto lo
iface lo inet loopback
# Other network interfaces are declared in /etc/network/interfaces.d/
EOF

	# Autologin root au boot
	mkdir -p "/etc/systemd/system/getty@tty1.service.d/" 2>/dev/null
	
	cat > "/etc/systemd/system/getty@tty1.service.d/override.conf" << EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I 38400 linux
EOF
	systemctl enable getty@tty1.service

	DEBIAN_FRONTEND=noninteractive
	export DEBIAN_FRONTEND

	apt update && apt install -y \
	        bind9 \
		htop \
		isc-dhcp-relay \
		net-tools \
		ntp \
		supervisor \
		tcpdump

	# Dossier dans lequel seront stockés les éventuels fichiers PCAP
	mkdir "/opt/fpc/" 2>/dev/null

	# Supervisor permettra de lancer automatiquement un SimpleHTTPServer pour que les PCAP soient récupérables facilement

cat > /etc/supervisor/conf.d/webserver.conf << EOF
[program:webserver]
command=python -m SimpleHTTPServer
directory=/opt/fpc/
stdout_logfile=/var/log/webserver.log
stderr_logfile=/var/log/webserver.log
autostart=true
autorestart=true
startsecs=5
stopwaitsecs=600
stopsignal=KILL
killasgroup=true
stopasgroup=true
EOF

# Lancement automatiquement du screen principal
cp mlr /usr/local/bin
chmod +x "/usr/local/bin/mlr" 2>/dev/null
grep "mlr" "/root/.bashrc" >/dev/null 2>&1
if [ $? -eq 1 ];then
	echo "/bin/bash /usr/local/bin/mlr" >> "/root/.bashrc"
fi

# Activation du mode routeur
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# Suppression de ce fichier, car le script n'est pas prévu pour être exécuté plusieurs fois.
rm "$0"

# Reboot, pour la prise en compte des différentes modifications
reboot
