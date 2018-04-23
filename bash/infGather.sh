#!/bin/bash
# --------------------------------------------------------
# Author: glender
# --------------------------------------------------------

OPTION=0
OUTFILE="$PWD/ips.txt"
declare -a pids
iplist=()
MAX_PARALLEL=10
COUNT=0

check_outfile()
{
	if [[ -f $OUTFILE && -s $OUTFILE ]]; then
		# clear the file
		> "${OUTFILE}"
	else
		touch "${OUTFILE}"
	fi
}

display_usage()
{
	echo "Usage: ${0} [options...]"
	echo ""
        echo "		-f, --file		Read a file of IPs instead of scanning for alive boxes"
        echo "		-h, --help		Help information"
	echo "	[**]	-i, --ip		The IP triple to scan or the full IP to scan (i.e. 10.11.1 OR 10.11.1.1)"
	echo "		-m, --max		Maximum parallel processes to run (Default is set to 10)"
	echo "		-s, --single		Scan a single IP address"
	echo ""
	echo "	[**] is required to run the script"
	echo ""
}

check_ip()
{
	local ip=$1
	local split=(${ip//./ })

	# is the passed in arg of the format ###.###.###?
	if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		# is each number less than or equal to 255?
		if [[ ${split[0]} -le 255 && ${split[1]} -le 255 && ${split[2]} -le 255 ]]; then
			echo -e "You provided a correct IP... \nMoving on... \n\n"
		else 
			echo -e "Incorrect IP! \n Your IP was out of range! \n\n"
			exit 0
		fi
	fi
}

check_ip_full()
{
	local ip=$1
	local split=(${ip//./ })

	# is the passed in arg of the format ###.###.###?
	if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
		# is each number less than or equal to 255?
		if [[ ${split[0]} -le 255 && ${split[1]} -le 255 && ${split[2]} -le 255 && ${split[3]} -le 255 ]]; then
			echo -e "You provided a correct IP... \nMoving on... \n\n"
		else 
			echo -e "Incorrect IP! \n Your IP was out of range! \n\n"
			exit 0
		fi
	fi
}

ping_sweep()
{
	check_outfile
	# iterate from 1..255
	for i in `seq 1 255`; do
		# ping to see if it is alive, save into temporary file
		ping -c 1 $1.$i | grep "bytes from" | cut -d " " -f 4 | cut -d ":" -f 1 >> $OUTFILE &
	done
}

check_running()
{
	sp="/-\|"
	i=1
	echo -n ' '
	while [ ${#pids[@]} -ge $MAX_PARALLEL ]; do
		printf "\b${sp:i++%${#sp}:1}"
		for PID in "${pids[@]}"; do
			if [ -e /proc/${PID} ]; then
				# PID is still running
				continue
			else
				# the PID is no longer running, remove it
				echo "Removing pid: $PID"
				delete=( $PID )
    				if [[ ${pids[PID]} = "${delete[0]}" ]]; then
      					unset 'pids[PID]'
					echo "PID was removed, we can continue now..."
    				fi
			fi
		done
	done
}

wait_for_completion()
{
	echo "Waiting for completion. Size is ${#pids[@]}"
	sp="/-\|"
	i=1
	echo -n ' '
	while [ ${#pids[@]} -gt 0 ]; do
		printf "\b${sp:i++%${#sp}:1}"
		for PID in "${pids[@]}"; do
			if [ -e /proc/${PID} ]; then
				# PID is still running
				continue
			else
				# the PID is no longer running, remove it
				delete=( $PID )
    				if [[ ${pids[PID]} = "${delete[0]}" ]]; then
      					unset 'pids[PID]'
    				fi
			fi
		done
	done
	reset
}

scans()
{
	location="/$USER/nmap/$1"
	mkdir -p $location

	today=`date '+%Y_%m_%d__%H_%M_%S'`
	nmap -n -sn -T4 $1 -oA "$location/$1.$today.nmapHostDiscovery" > /dev/null &
	pids[$!]=$!
	check_running
	nmap -n -sL $1 -oA "$location/$1.$today.nmapListScan" > /dev/null &
	pids[$!]=$!
	check_running

	nmap -Pn -sV -T4 $1 -oA "$location/$1.$today.nmapServiceDiscovery" > /dev/null &
	pids[$!]=$!
	check_running

	nmap -Pn -T4 -sS -p139,445 --script=smb-enum-users $1 -oA "$location/$1.$today.nmapSmbEnumUsers" > /dev/null &
	pids[$!]=$!
	check_running 
	
	nmap -Pn -T4 -sS -p139,445 --script=smb-enum-groups $1 -oA "$location/$1.$today.nmapSmbEnumGroups" > /dev/null &
	pids[$!]=$!
	check_running 
	
	nmap -Pn -T4 -sS -p139,445 --script=smb-enum-shares $1 -oA "$location/$1.$today.nmapSmbEnumShares" > /dev/null & 
	pids[$!]=$!
	check_running 
}

read_file_and_scan()
{
	cat $OUTFILE | while read ip; do
		scans $ip
	done
}

# Get the command line options
for (( i=1; i<=$#; i++)); do
	case "${!i}" in
		# file to read IPs from
		-f|--file)
			arg=$((i+1))
			OUTFILE="${!arg}"
			OPTION=1
			shift # past - option
			;;
		# IP address to sweep
		-i|--ip)
			arg=$((i+1))
			IP="${!arg}"
			OPTION=2
			shift # past - option
			;;
		# single IP address scan
		-s|--single)
			arg=$((i+1))
			IP="${!arg}"
			OPTION=3
			shift # past - option
			;;
		# set maximum parallel processes
		-m|--max)
			arg=$((i+1))
			MAX_PARALLEL="${!arg}"
			shift # past - option
			;;
		# did the user ask for help?
		-h|--help)
			display_usage
			exit 0
			;;
		*)
			display_usage
			exit 0
			;;
	esac
done

# did the user supply the IP or the file?
if [ "$OPTION" -eq "0"  ]; then
	display_usage
	exit 0
else
	case "$OPTION" in
		"1")
			read_file_and_scan
			wait_for_completion
			;;
		"2")
			# is the IP address proper?
			check_ip $IP
			# sweep the IP address given
			ping_sweep $IP
			# wait for all of the spawned processes to finish
			wait
			read_file_and_scan
			wait_for_completion
			;;
		"3")
			# single IP
			check_ip_full $IP
			scans $IP
			wait_for_completion
			;;
	
	esac
	
fi
