#!/bin/bash

echo "Enter current user name:"
read USER

ip link

echo "Enter SBET network interface (example: enp4s0):"
read SBET_INTERFACE

echo "Enter local network interface (example: enp4s0):"
read NETWORK_INTERFACE

function jumpto
{
    label=$1
    cmd=$(sed -n "/$label:/{:a;n;p;ba};" $0 | grep -v ':$')
    eval "$cmd"
    exit
}

critical_fail () {
	echo Failed to setup $2 in step $1
	
	read -p "Retry? [[y]es/[n]o/[s]kip]" -n 1 -r
	echo    # (optional) move to a new line
	if [[ $REPLY =~ ^[Nn]$ ]]
	then
		exit
    	fi
    	
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		jumpto $2
    	fi	
}

start=${1:-"user"}

jumpto $start

user:
echo "********* Check user *********"
getent passwd $USER && echo Complete || critical_fail 1 user

grub:
echo "********* Update GRUB parameters *********"
sed -i "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/g" /etc/default/grub  && echo Complete 1 || critical_fail 1 grub
sed -i 's#^\(GRUB_CMDLINE_LINUX_DEFAULT="quiet\)"$#\1 isolcpus=2,3 intel_idle.max_cstate=0 idle=poll processor.max_cstate=0"#' /etc/default/grub  && echo Complete 2 || critical_fail 2 grub
update-grub  && echo Complete 3 || critical_fail 3 grub

dir:
echo "********* Create user directory *********"
sudo -u $USER mkdir -p /home/$USER/linuxcnc/configs/alterx && echo Complete || critical_fail 1 dir

autologin:
echo "********* Set autologin *********"
sed -i "s/^\#*autologin-user=.*/autologin-user=$USER/g" /etc/lightdm/lightdm.conf  && echo Complete 1 || critical_fail 1 autologin
sed -i "s/^\#*autologin-user-timeout=.*/autologin-user-timeout=0/g" /etc/lightdm/lightdm.conf  && echo Complete 2 || critical_fail 2 autologin

udev:
echo "********* Copy udev rule *********"
cp 51-plugdev.rules /etc/udev/rules.d/ && echo Complete || critical_fail 1 udev
useradd -g $USER plugdev

screensaver:
echo "********* Disable screensaver*********"
mv /etc/xdg/autostart/xscreensaver.desktop /etc/xdg/autostart/.xscreensaver.desktop.bak && echo Complete || critical_fail 1 screensaver

update:
echo "********* Update system *********"
apt update && echo Complete 1 || critical_fail 1 update
apt upgrade && echo Complete 2 || critical_fail 2 update

install:
echo "********* Install packets *********"
apt -y install gvfs-backends gvfs-bin python-serial python-pip net-tools ethtool gedit git vsftpd && echo Complete 1 || critical_fail 1 install
yes | pip install pyudev crcmod pyusb pyqtgraph vtk serial && echo Complete 2 || critical_fail 2 install

clone:
echo "********* Clone interface *********"
git clone https://github.com/uncle-yura/alterx.git /home/$USER && echo Complete 1 || critical_fail 1 clone
git clone https://github.com/uncle-yura/awlsim.git /home/$USER && echo Complete 2 || critical_fail 2 clone

keyboard:
echo "********* Install alterx keyboard *********"
sudo -u $USER cp xmm_table /home/$USER/.xmm_table  && echo Complete 1 || critical_fail 1 keyboard
sudo -u $USER echo /usr/bin/python /home/$USER/linuxcnc/configs/alterx_mini/python/py_usb_reset.py > /home/$USER/.xsessionrc && echo Complete 2 || critical_fail 2 keyboard
sudo -u $USER echo sleep 1 >> /home/$USER/.xsessionrc
sudo -u $USER echo setxkbmap -option grp:switch,grp:alt_shift_toggle us,ru,ua >> /home/$USER/.xsessionrc
sudo -u $USER echo xmodmap /home/$USER/.xmm_table  >> /home/$USER/.xsessionrc

network:
echo "********* Setup network interface *********"
cp setup.network /etc/network/interfaces.d/setup && echo Complete 1 || critical_fail 1 network
sed -i "s/SBET/$SBET_INTERFACE/g" /etc/network/interfaces.d/setup && echo Complete 2 || critical_fail 2 network
sed -i "s/NETWORK/$NETWORK_INTERFACE/g" /etc/network/interfaces.d/setup && echo Complete 3 || critical_fail 3 network

ftp:
echo "********* Setup FTP *********"
sed -i 's/.*listen=.*/listen=YES/g' /etc/vsftpd.conf && echo Complete 1 || critical_fail 1 ftp
sed -i 's/.*listen_ipv6=.*/#listen_ipv6=YES/g' /etc/vsftpd.conf && echo Complete 2 || critical_fail 2 ftp
sed -i 's/.*write_enable=.*/write_enable=YES/g' /etc/vsftpd.conf && echo Complete 3 || critical_fail 3 ftp

logger:
echo "********* Setup LOGGER *********"
sed -i 's/.*FileCreateMode=.*/FileCreateMode=0655/g' /etc/rsyslog.conf && echo Complete 1 || critical_fail 1 logger
sed -i 's/.*DirCreateMode=.*/DirCreateMode=0755/g' /etc/rsyslog.conf && echo Complete 2 || critical_fail 2 logger

sudoers:
echo "********* Update sudoers *********"
poweroff=`grep -i poweroff /etc/sudoers | wc -l`;
if [ $poweroff != 0 ];
then
{
 sed -i 's/.*poweroff.*/'$USER' ALL=NOPASSWD:\/sbin\/poweroff/g' /etc/sudoers && echo Complete 1 || critical_fail 1 sudoers
}
else
{
 echo "$USER ALL=NOPASSWD:/sbin/poweroff" >> /etc/sudoers && echo Complete 2 || critical_fail 2 sudoers
}
fi

autostart:
echo "********* Copy autostart script ********"
cp alterx.desktop /etc/xdg/autostart/ && echo Complete 1 || critical_fail 1 autostart
sed -i "s/USER/$USER/g" /etc/xdg/autostart/alterx.desktop && echo Complete 2 || critical_fail 2 autostart
chown $USER:$USER /etc/xdg/autostart/alterx.desktop && echo Complete 3 || critical_fail 3 autostart
chmod 777 /etc/xdg/autostart/alterx.desktop && echo Complete 4 || critical_fail 4 autostart

sudo -u $USER cp run-linuxcnc.sh /home/$USER/linuxcnc/configs/alterx && echo Complete 5 || critical_fail 5 autostart
sed -i "s/USER/$USER/g" /home/$USER/linuxcnc/configs/alterx/run-linuxcnc.sh && echo Complete 6 || critical_fail 6 autostart
chown $USER:$USER /home/$USER/linuxcnc/configs/alterx/run-linuxcnc.sh && echo Complete 7 || critical_fail 7 autostart
chmod 777 /home/$USER/linuxcnc/configs/alterx/run-linuxcnc.sh && echo Complete 8 || critical_fail 8 autostart
sed -i "s/SBET/$SBET_INTERFACE/g" /home/$USER/linuxcnc/configs/alterx/run-linuxcnc.sh && echo Complete 2 || critical_fail 9 autostart

exit:
echo "********* INSTALLATION COMPLETE *********"
