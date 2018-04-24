#!/bin/bash
# --------------------------------------------------------
# Author: glender
# --------------------------------------------------------

pids=$(pidof dirb nmap nikto infGather)

for p in $pids; do
	kill -9 $p
done
