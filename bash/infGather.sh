#!/bin/bash
# --------------------------------------------------------
# Author: glender
# --------------------------------------------------------

OPTION=0
OUTFILE="$PWD/ips.txt"
declare -a pids
iplist=()
MAX_PARALLEL=10
MAX_SLEEP=5.0
WORDLIST=""
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

check_installs()
{
	if [ ! type nmap &> /dev/null ]; then
		echo "Please install nmap before you can proceed."
		exit 0
	fi
	
	if [ ! type nikto &> /dev/null ]; then
		echo "Please install nikto before you can proceed."
		exit 0
	fi

	if [ ! type dirb &> /dev/null ]; then
		echo "Please install dirb before you can proceed."
		exit 0
	fi
}

display_usage()
{
	echo "Usage: ${0} [options...]"
	echo ""
        echo "		-f, --file		Read a file of IPs instead of scanning for alive boxes"
        echo "		-h, --help		Help information"
	echo "	[**]	-i, --ip		The IP triple to scan or the full IP to scan (i.e. 10.11.1 OR 10.11.1.1)"
	echo "		-m, --max		Maximum parallel processes to run (Default is set to $MAX_PARALLEL)"
	echo "		-s, --single		Scan a single IP address"
	echo "		-w, --wlist		Wordlist to use (Default will be infGatherWordList.txt)"
	echo "		-z, --ztime		Maximum sleep time between checking if PID completed (Default is set to $MAX_SLEEP s)"
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
		sleep $MAX_SLEEP
	done
	reset
}

scans()
{
	location="/$USER/nmap/$1"
	mkdir -p $location

	today=`date '+%Y_%m_%d__%H_%M_%S'`
	nmap -n -sn -T4 $1 -o "$location/$1.$today.nmapHostDiscovery" > /dev/null &
	pids[$!]=$!
	check_running 
	nmap -n -sL $1 -o "$location/$1.$today.nmapListScan" > /dev/null &
	pids[$!]=$!
	check_running

	nmap -Pn -sV -T4 $1 -o "$location/$1.$today.nmapServiceDiscovery" > /dev/null &
	pids[$!]=$!
	check_running
	nikto_scan $! $location $1 &
	pids[$!]=$!
	check_running
	pids[$!]=$!
	check_running

	nmap -Pn -T4 -sS -p139,445 --script=smb-enum-users $1 -o "$location/$1.$today.nmapSmbEnumUsers" > /dev/null &
	pids[$!]=$!
	check_running
	
	nmap -Pn -T4 -sS -p139,445 --script=smb-enum-groups $1 -o "$location/$1.$today.nmapSmbEnumGroups" > /dev/null &
	pids[$!]=$!
	check_running
	
	nmap -Pn -T4 -sS -p139,445 --script=smb-enum-shares $1 -o "$location/$1.$today.nmapSmbEnumShares" > /dev/null & 
	pids[$!]=$!
	check_running

	dirb_scan $1 80 "0" &
	pids[$!]=$!
	check_running

	dirb_scan $1 443 "1" &
	pids[$!]=$!
	check_running
}

nikto_scan()
{
	location="/$USER/nikto/$3"
	mkdir -p $location

	# wait for our main nmap scan to complete, our service detection
	while [ -e /proc/$1 ]; do
		sleep $MAX_SLEEP
	done

	# get ports other than the normal HTTP (80) and HTTPS (443) 
	httpPorts=$(grep -i http $2/*nmap* | grep open | grep -v "80/" | grep -v "443/" | awk -F: '{ print $2 }' | awk -F/ '{ print $1 }')
	
	# get the HTTPS ports
	httpsPorts=$(grep -i http $2/*nmap* | grep open | grep ssl | grep -v "80/" | grep -v "443/" | awk -F: '{ print $2 }' | awk -F/ '{ print $1 }')
	httpsPorts+=$(grep -i https $2/*nmap* | grep open | grep -v "80/" | grep -v "443/" | awk -F: '{ print $2 }' | awk -F/ '{ print $1 }')

	# ensure that they are unique entries
	httpPorts=($(echo "${httpPorts[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
	httpsPorts=($(echo "${httpsPorts[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

	# check the normal HTTPS port for our host
	nikto -host $3 -port 443 -ssl -output $location/nikto_https_$3.html
	
	# check the normal HTTP port for our host
	nikto -host $3 -port 80 -output $location/nikto_http_$3.html

	# remove the https ports from our http ports
	for target in "${httpsPorts[@]}"; do
  		for i in "${!httpPorts[@]}"; do
    			if [[ ${httpPorts[i]} = "${httpsPorts[0]}" ]]; then
      				unset 'httpPorts[i]'
    			fi
  		done
	done

	# process the https ports that we have found
	for port in "${httpsPorts[@]}"; do
		nikto -host $3 -port $port -ssl -output $location/nikto_https_$3_$port.html
		dirb_scan $3 $port "0" &
		pids[$!]=$!
		check_running
	done

	# process the http ports that we have found
	for port in "${httpPorts[@]}"; do
		nikto -host $3 -port $port -output $location/nikto_http_$3_$port.html
		dirb_scan $3 $port "1" &
		pids[$!]=$!
		check_running
	done

}

dirb_scan()
{
	location="/$USER/dirb/$1"
	mkdir -p $location

	# did the user supply a wordlist?
	if [ "$WORDLIST" == "" ]; then
		WORDLIST=$(find /$USER/ -name infGatherWordList.txt)
		# InfGather wordlist installed?
		if [ "$WORDLIST" == "" ]; then
			echo "Please install the InfGather wordlist, $USER."
			exit 0
		fi

	else
		# does the wordlist exist?
		if [ ! -f $WORDLIST ]; then
			echo "You supplied a wordlist that does not exist...shame on you!"
			exit 0
		fi
	fi

	if [ "$3" -eq "0" ]; then
		dirb http://$1:$2/ $WORDLIST -o $location/dirb_http_$2.txt -w &
		pids[$!]=$!
		check_running
	else
		dirb https://$1:$2/ $WORDLIST -o $location/dirb_https_$2.txt -w &
		pids[$!]=$!
		check_running
	fi

}

read_file_and_scan()
{
	cat $OUTFILE | while read ip; do
		scans $ip
	done
}

# check to make sure the user has the proper programs installed 
check_installs

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
		# set the maximum sleep time between checking PID completion
		-z|--ztime)
			arg=$((i+1))
			MAX_SLEEP="${!arg}"
			shift # past - option
			;;
		-w|--wlist)
			arg=$((i+1))
			WORDLIST="${!arg}"
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
