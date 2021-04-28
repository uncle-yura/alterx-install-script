#!/bin/bash
sudo ifdown SBET
sudo ifup SBET
xset -dpms s 0 0 s noblank s noexpose s off
sleep 10
/usr/bin/linuxcnc /home/USER/linuxcnc/configs/alterx/alterx.ini
