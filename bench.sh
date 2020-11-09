#!/bin/bash
# serverreview-benchmark by @sayem314
# Github: https://github.com/sayem314/serverreview-benchmark

# shellcheck disable=SC1117,SC2086,SC2003,SC1001,SC2116,SC2046,2128,2124

about () {
	echo ""
	echo "  ========================================================= "
	echo "  \             Serverreview Benchmark Script             / "
	echo "  \       Basic system info, I/O test and speedtest       / "
	echo "  \               V 3.0.5 (2020-11-09)                  / "
	echo "  \             Created by Sayem Chowdhury                / "
	echo "  \             Modify by Kevin Tseng                / "
	echo "  ========================================================= "
	echo ""
	echo "  This script is based on bench.sh by camarg from akamaras.com"
	echo "  Later it was modified by dmmcintyre3 on FreeVPS.us"
	echo "  Thanks to Hidden_Refuge for the update of this script"
	echo ""
}

prms () {
	echo "  Arguments:"
	echo "    $(tput setaf 3)-info$(tput sgr0)         - Check basic system information"
	echo "    $(tput setaf 3)-io$(tput sgr0)           - Run I/O test with or w/ cache"
	echo "    $(tput setaf 3)-cdn$(tput sgr0)          - Check download speed from CDN"
	echo "    $(tput setaf 3)-northamercia$(tput sgr0) - Download speed from North America"
	echo "    $(tput setaf 3)-europe$(tput sgr0)       - Download speed from Europe"
	echo "    $(tput setaf 3)-asia$(tput sgr0)         - Download speed from asia"
	echo "    $(tput setaf 3)-a$(tput sgr0)            - Test and check all above things at once"
	echo "    $(tput setaf 3)-b$(tput sgr0)            - System info, CDN speedtest and I/O test"
	echo "    $(tput setaf 3)-ispeed$(tput sgr0)       - Install speedtest-cli (python 2.4-3.4 required)"
	echo "    $(tput setaf 3)-speed$(tput sgr0)        - Check internet speed using speedtest-cli"
	echo "    $(tput setaf 3)-about$(tput sgr0)        - Check about this script"
	echo ""
	echo "  Parameters"
	echo "    $(tput setaf 3)share$(tput sgr0)         - upload results (default to ubuntu paste)"
	echo "    Available option for share:"
	echo "      ubuntu # upload results to ubuntu paste (default)"
	echo "      haste # upload results to hastebin"
	echo "      clbin # upload results to clbin"
	echo "      ptpb # upload results to ptpb"
}

howto () {
	echo ""
	echo "  Wrong parameters. Use $(tput setaf 3)bash $BASH_SOURCE -help$(tput sgr0) to see parameters"
	echo "  ex: $(tput setaf 3)bash $BASH_SOURCE -info$(tput sgr0) (without quotes) for system information"
	echo ""
}

benchinit() {
	if ! hash curl 2>$NULL; then
		echo "missing dependency curl"
		echo "please install curl first"
		exit
	fi
}

CMD="$1"
PRM1="$2"
PRM2="$3"
log="$HOME/bench.log"
ARG="$BASH_SOURCE $@"
benchram="/mnt/tmpbenchram"
NULL="/dev/null"
true > $log

cancel () {
	echo ""
	rm -f test
	echo " Abort"
	if [[ -d $benchram ]]; then
		rm $benchram/zero
		umount $benchram
		rm -rf $benchram
	fi
	exit
}

trap cancel SIGINT

systeminfo () {
	# Systeminfo
	echo "" | tee -a $log
	echo " $(tput setaf 6)### 系統資訊$(tput sgr0)"
	echo " ### 系統資訊" >> $log
	echo "" | tee -a $log

	# OS Information (Name)
	cpubits=$( uname -m )
	if echo $cpubits | grep -q 64; then
		bits=" (64 bit)"
	elif echo $cpubits | grep -q 86; then
		bits=" (32 bit)"
	elif echo $cpubits | grep -q armv5; then
		bits=" (armv5)"
	elif echo $cpubits | grep -q armv6l; then
		bits=" (armv6l)"
	elif echo $cpubits | grep -q armv7l; then
		bits=" (armv7l)"
	else
		bits="unknown"
	fi

	if hash lsb_release 2>$NULL; then
		soalt=$(lsb_release -d)
		echo -e " OS Name     : "${soalt:13} $bits | tee -a $log
	else
		so=$(awk 'NF' /etc/issue)
		pos=$(expr index "$so" 123456789)
		so=${so/\/}
		extra=""
		if [[ "$so" == Debian*9* ]]; then
			extra="(stretch)"
		elif [[ "$so" == Debian*8* ]]; then
			extra="(jessie)"
		elif [[ "$so" == Debian*7* ]]; then
			extra="(wheezy)"
		elif [[ "$so" == Debian*6* ]]; then
			extra="(squeeze)"
		fi
		if [[ "$so" == *Proxmox* ]]; then
			so="Debian 7.6 (wheezy)";
		fi
		otro=$(expr index "$so" \S)
		if [[ "$otro" == 2 ]]; then
			so=$(cat /etc/*-release)
			pos=$(expr index "$so" NAME)
			pos=$((pos-2))
			so=${so/\/}
		fi
		echo -e " OS Name     : "${so:0:($pos+2)}$extra$bits | tr -d '\n' | tee -a $log
		echo "" | tee -a $log
	fi
	sleep 0.1

	#Detect virtualization
	if hash ifconfig 2>$NULL; then
		eth=$(ifconfig)
	fi
	virtualx=$(dmesg)
	if [[ -f /proc/user_beancounters ]]; then
		virtual="OpenVZ"
	elif [[ "$virtualx" == *kvm-clock* ]]; then
		virtual="KVM"
	elif [[ "$virtualx" == *"VMware Virtual Platform"* ]]; then
		virtual="VMware"
	elif [[ "$virtualx" == *"Parallels Software International"* ]]; then
		virtual="Parallels"
	elif [[ "$virtualx" == *VirtualBox* ]]; then
		virtual="VirtualBox"
	elif [[ "$eth" == *eth0* ]];then
		virtual="Dedicated"
	elif [[ -e /proc/xen ]]; then
		virtual="Xen"
	fi

	#Kernel
	echo " Kernel      : $virtual / $(uname -r)" | tee -a $log
	sleep 0.1

	# Hostname
	# echo " Hostname    : $(hostname)" | tee -a $log
	# sleep 0.1

	# CPU Model Name
	cpumodel=$( awk -F: '/model name/ {name=$2} END {print name}' /proc/cpuinfo )
	echo " CPU Model   :$cpumodel" | tee -a $log
	sleep 0.1

	# CPU Cores
	cores=$( awk -F: '/model name/ {core++} END {print core}' /proc/cpuinfo )
	corescache=$( awk -F: '/cache size/ {cache=$2} END {print cache}' /proc/cpuinfo )
	freq=$( awk -F: ' /cpu MHz/ {freq=$2} END {print freq}' /proc/cpuinfo )
	if [[ $cores == "1" ]]; then
		echo " CPU Cores   : $cores core @ $freq MHz" | tee -a $log
	else
		echo " CPU Cores   : $cores cores @ $freq MHz" | tee -a $log
	fi
	sleep 0.1
	echo " CPU Cache   :$corescache" | tee -a $log
	sleep 0.1

	# RAM Information
	tram="$( free -m | grep Mem | awk 'NR=1 {print $2}' ) MiB"
	fram="$( free -m | grep Mem | awk 'NR=1 {print $7}' ) MiB"
	fswap=$( free -m | grep Swap | awk 'NR=1 {print $4}' )MiB
	echo " Total RAM   : $tram (Free $fram)" | tee -a $log
	sleep 0.1

	# Swap Information
	tswap="$( free -m | grep Swap | awk 'NR=1 {print $2}' ) MiB"
	tswap0=$( grep SwapTotal < /proc/meminfo | awk 'NR=1 {print $2$3}' )
	if [[ "$tswap0" == "0kB" ]]; then
		echo " Total SWAP  : SWAP not enabled" | tee -a $log
	else
		echo " Total SWAP  : $tswap (Free $fswap)" | tee -a $log
	fi
	sleep 0.1

	# HDD information
	hdd=$( df -h --total --local -x tmpfs | grep 'total' | awk '{print $2}' )B
	hddfree=$( df -h --total | grep 'total' | awk '{print $5}' )
	echo " Total Space : $hdd ($hddfree used)" | tee -a $log
	sleep 0.1

	# TCP Congestion Control
	tcpctrl=$( sysctl net.ipv4.tcp_congestion_control | awk -F ' ' '{print $3}' )
	echo " TCP CC      : $tcpctrl" | tee -a $log
	sleep 0.1

	# Uptime
	secs=$( awk '{print $1}' /proc/uptime | cut -f1 -d"." )
	if [[ $secs -lt 120 ]]; then
		sysuptime="$secs seconds"
	elif [[ $secs -lt 3600 ]]; then
		sysuptime=$( printf '%d minutes %d seconds\n' $((secs%3600/60)) $((secs%60)) )
	elif [[ $secs -lt 86400 ]]; then
		sysuptime=$( printf '%dhrs %dmin %dsec\n' $((secs/3600)) $((secs%3600/60)) $((secs%60)) )
	else
		sysuptime=$( echo $((secs/86400))"days - "$(date -d "1970-01-01 + $secs seconds" "+%Hhrs %Mmin %Ssec") )
	fi
	echo " Running for : $sysuptime" | tee -a $log
	echo "" | tee -a $log
}

echostyle(){
	if hash tput 2>$NULL; then
		echo " $(tput setaf 6)$1$(tput sgr0)"
		echo " $1" >> $log
	else
		echo " $1" | tee -a $log
	fi
}

FormatBytes() {
	bytes=${1%.*}
	local Mbps=$( printf "%s" "$bytes" | awk '{ printf "%.2f", $0 / 1024 / 1024 * 8 } END { if (NR == 0) { print "error" } }' )
	if [[ $bytes -lt 1000 ]]; then
		printf "%8i B/s |      N/A     "  $bytes
	elif [[ $bytes -lt 1000000 ]]; then
		local KiBs=$( printf "%s" "$bytes" | awk '{ printf "%.2f", $0 / 1024 } END { if (NR == 0) { print "error" } }' )
		printf "%7s KiB/s | %7s Mbps" "$KiBs" "$Mbps"
	else
		# awk way for accuracy
		local MiBs=$( printf "%s" "$bytes" | awk '{ printf "%.2f", $0 / 1024 / 1024 } END { if (NR == 0) { print "error" } }' )
		printf "%7s MiB/s | %7s Mbps" "$MiBs" "$Mbps"

		# bash way
		# printf "%4s MiB/s | %4s Mbps""$(( bytes / 1024 / 1024 ))" "$(( bytes / 1024 / 1024 * 8 ))"
	fi
}

pingtest() {
	# ping one time
	local ping_link=$( echo ${1#*//} | cut -d"/" -f1 )
	local ping_ms=$( ping -w1 -c1 $ping_link | grep 'rtt' | cut -d"/" -f5 )

	# get download speed and print
	if [[ $ping_ms == "" ]]; then
		printf " | ping error!"
	else
		printf " | ping %3i.%sms" "${ping_ms%.*}" "${ping_ms#*.}"
	fi
}

# main function for speed checking
# the report speed are average per file
speed() {
	# print name
	printf "%s" " $1" | tee -a $log

	# get download speed and print
	C_DL=$( curl -m 4 -w '%{speed_download}\n' -o $NULL -s "$2" )
	printf "%s\n" "$(FormatBytes $C_DL) $(pingtest $2)" | tee -a $log
}

# 2 location (200MB)
cdnspeedtest () {
	echo "" | tee -a $log
	echostyle "### CDN測速"
	echo "" | tee -a $log
	speed "CacheFly :" "http://cachefly.cachefly.net/100mb.test"

	# google drive speed test
	TMP_COOKIES="/tmp/cookies.txt"
	TMP_FILE="/tmp/gdrive"
	DRIVE="drive.google.com"
	FILE_ID="0B1MVW1mFO2zmdGhyaUJESWROQkE"

	printf " Google Drive   :"  | tee -a $log
	curl -c $TMP_COOKIES -o $TMP_FILE -s "https://$DRIVE/uc?id=$FILE_ID&export=download"
	D_ID=$( grep "confirm=" < $TMP_FILE | awk -F "confirm=" '{ print $NF }' | awk -F "&amp" '{ print $1 }' )
	C_DL=$( curl -m 4 -Lb $TMP_COOKIES -w '%{speed_download}\n' -o $NULL \
		-s "https://$DRIVE/uc?export=download&confirm=$D_ID&id=$FILE_ID" )
	printf "%s\n" "$(FormatBytes $C_DL) $(pingtest $DRIVE)" | tee -a $log
	echo "" | tee -a $log
}

# 19 location (1.9GB)
northamerciaspeedtest () {
	echo "" | tee -a $log
	echostyle "### 北美洲地區測速"
	echo "" | tee -a $log
	speed "Vultr, US, CA, LAX         :" "http://lax-ca-us-ping.vultr.com/vultr.com.100MB.bin"
	speed "Vultr, US, WA, Seattle     :" "http://wa-us-ping.vultr.com/vultr.com.100MB.bin"
	speed "Vultr, US, TX, Dallas      :" "http://tx-us-ping.vultr.com/vultr.com.100MB.bin"
	speed "Vultr, US, IL, Chicago     :" "http://il-us-ping.vultr.com/vultr.com.100MB.bin"
	speed "Vultr, US, NJ, New Jersey  :" "http://nj-us-ping.vultr.com/vultr.com.100MB.bin"
	speed "Vultr, US, GA, Atlanta     :" "http://ga-us-ping.vultr.com/vultr.com.100MB.bin"
	speed "Vultr, US, FL, Miami       :" "http://fl-us-ping.vultr.com/vultr.com.100MB.bin"
	speed "RamNode, CA, LAX           :" "http://lg.la.ramnode.com/static/100MB.test"
	speed "RamNode, WA, Seattle       :" "http://lg.sea.ramnode.com/static/100MB.test"
	speed "RamNode, GA, Atlanta       :" "http://lg.atl.ramnode.com/static/100MB.test"
	speed "RamNode, NY, NYC           :" "http://lg.nyc.ramnode.com/static/100MB.test"
	speed "Linode, US, CA, Fremont    :" "http://speedtest.fremont.linode.com/100MB-fremont.bin"
	speed "Linode, US, TX, Dallas     :" "http://speedtest.dallas.linode.com/100MB-dallas.bin"
	speed "Linode, US, NJ, Newark     :" "http://speedtest.newark.linode.com/100MB-newark.bin"
	speed "Softlayer, US, CA, San Jose:" "http://speedtest.sjc01.softlayer.com/downloads/test100.zip"
	speed "Softlayer, US, WA, Seattle :" "http://speedtest.sea01.softlayer.com/downloads/test100.zip"
	speed "Softlayer, CA, QC, Montreal:" "http://speedtest.mon01.softlayer.com/downloads/test100.zip"
	speed "OVH, CA, QC, Beauharnois   :" "http://bhs.proof.ovh.net/files/100Mb.dat"
	speed "Vultr, CA, ON, Toronto     :" "http://tor-ca-ping.vultr.com/vultr.com.100MB.bin"
	echo "" | tee -a $log
}

# 11 location (1.1GB)
europespeedtest () {
	echo "" | tee -a $log
	echostyle "### 歐洲地區測速"
	echo "" | tee -a $log
	speed "Vultr, UK, London          :" "http://lon-gb-ping.vultr.com/vultr.com.100MB.bin"
	speed "Vultr, DE, Frankfurt       :" "http://fra-de-ping.vultr.com/vultr.com.100MB.bin"
	speed "Vultr, NL, Amsterdam       :" "http://ams-nl-ping.vultr.com/vultr.com.100MB.bin"
	speed "Linode, UK, London         :" "http://speedtest.london.linode.com/100MB-london.bin"
	speed "Linode, DE, Frankfurt      :" "http://speedtest.frankfurt.linode.com/100MB-frankfurt.bin"
	speed "Psychz, UK, London         :" "https://lg.lon.psychz.net/200MB.test"
	speed "Psychz, NL, Amsterdam      :" "http://172.107.95.246/100.mb"
	speed "OVH, FR, Roubaix           :" "http://rbx.proof.ovh.net/files/100Mb.dat"
	speed "Online.net, FR             :" "http://ping.online.net/100Mb.dat"
	speed "Hetzner, DE                :" "https://speed.hetzner.de/100MB.bin"
	speed "Rackspace, UK, London      :" "http://sandbox.lon3.rackspace.net/128MB.test"
	#speed "DataCamp, AT, Vienna       :" "http://vie.download.datapacket.com/100mb.bin"
	#speed "DataCamp, CZ, Prague       :" "http://war.download.datapacket.com/100mb.bin"
	#speed "DataCamp, ES, Madrid       :" "http://mad.download.datapacket.com/100mb.bin"
	#speed "DataCamp, FR, Paris        :" "http://par.download.datapacket.com/100mb.bin"
	#speed "DataCamp, PL, Warsaw       :" "http://war.download.datapacket.com/100mb.bin"
	#speed "DataCamp, SE, Stockholm    :" "http://sto.download.datapacket.com/100mb.bin"
	echo "" | tee -a $log
}

# 6 location (0.6GB)
exoticpeedtest () {
	echo "" | tee -a $log
	echostyle "### 大洋洲地區測速"
	echo "" | tee -a $log
	speed "Vultr, AU, Sydney          :" "https://syd-au-ping.vultr.com/vultr.com.100MB.bin"
	speed "Softlayer, AU, Sydney      :" "http://speedtest.syd01.softlayer.com/downloads/test100.zip"
	speed "Leaseweb, AU, Sydney       :" "http://mirror.syd10.au.leaseweb.net/speedtest/100mb.bin"
	speed "OVH, AU, Sydney            :" "http://speedtest-syd.apac-tools.ovh/files/100Mb.dat"
	speed "Psychz, AU, Sydney         :" "http://103.126.137.120/100.mb"
	speed "Rackspace, AU, Sydney      :" "http://sandbox.syd2.rackspace.net/128MB.test"
	echo "" | tee -a $log
}

# 27 location (2.8GB)
asiaspeedtest () {
	echo "" | tee -a $log
	echostyle "### 亞洲地區測速"
	echo "" | tee -a $log
	speed "中華電信, TW, 臺北市       :" "http://http.speed.hinet.net/test_100m.zip"
	speed "國網中心, TW, 新竹市       :" "http://free.nchc.org.tw/parrot/misc/100MB.bin"
	speed "Psychz, TW, 臺北市         :" "https://lg.tw.psychz.net/200MB.test"
	speed "Psychz, JP, Tokyo          :" "http://172.107.231.230/100.mb"
	speed "Psychz, KR, Seoul          :" "http://172.107.194.22/100.mb"
	speed "Psychz, IN, Mumbai         :" "http://103.78.121.58/100.mb"
	speed "Vultr, JP, Tokyo           :" "http://hnd-jp-ping.vultr.com/vultr.com.100MB.bin"
	speed "Vultr, KR, Seoul           :" "http://sel-kor-ping.vultr.com/vultr.com.100MB.bin"
	speed "Vultr, Singapore           :" "http://sgp-ping.vultr.com/vultr.com.100MB.bin"
	speed "DataCamp, JP, Tokyo        :" "http://tyo.download.datapacket.com/100mb.bin"
	speed "DataCamp, Hong Kong        :" "http://hkg.download.datapacket.com/100mb.bin"
	speed "DataCamp, Singapore        :" "http://sgp.download.datapacket.com/100mb.bin"
	speed "Softlayer, JP, Tokyo       :" "http://speedtest.tok02.softlayer.com/downloads/test100.zip"
	speed "Softlayer, Hong Kong       :" "http://speedtest.hkg02.softlayer.com/downloads/test100.zip"
	speed "Softlayer, Singapore       :" "http://speedtest.sng01.softlayer.com/downloads/test100.zip"
	speed "Linode, JP, Tokyo          :" "http://speedtest.tokyo2.linode.com/100MB-tokyo2.bin"
	speed "Linode, Singapore          :" "http://speedtest.singapore.linode.com/100MB-singapore.bin"
	speed "Linode, IN, Mumbai         :" "http://speedtest.mumbai1.linode.com/100MB-mumbai.bin"
	speed "Leaseweb, Hong Kong        :" "http://mirror.hk.leaseweb.net/speedtest/100mb.bin"
	speed "Leaseweb, Singapore        :" "http://mirror.sg.leaseweb.net/speedtest/100mb.bin"
	speed "HostUS, Hong Kong          :" "https://hk-lg.hostus.us/100MB.test"
	speed "HostUS, Singapore          :" "https://sgp-lg.hostus.us/100MB.test"
	speed "Nexus Bytes, JP, Tokyo     :" "http://lgjp.nexusbytes.com/100MB.test"
	speed "Nexus Bytes, Singapore     :" "http://lgsg.nexusbytes.com/100MB.test"
	speed "HostHatch, Hong Kong       :" "http://103.73.67.192/100.mb"
	speed "Rackspace, Hong Kong       :" "http://sandbox.hkg1.rackspace.net/128MB.test"
	speed "OVH, Singapore             :" "http://speedtest-sgp.apac-tools.ovh/files/100Mb.dat"
	echo "" | tee -a $log
}

# 61 location (6.1GB)
usaspeedtest () {
	echo "" | tee -a $log
	echostyle "### 全美國地區測速"
	echo "" | tee -a $log
	speed "Vultr, CA, LAX             :" "http://lax-ca-us-ping.vultr.com/vultr.com.100MB.bin"
	speed "Vultr, WA, Seattle         :" "http://wa-us-ping.vultr.com/vultr.com.100MB.bin"
	speed "Vultr, TX, Dallas          :" "http://tx-us-ping.vultr.com/vultr.com.100MB.bin"
	speed "Vultr, IL, Chicago         :" "http://il-us-ping.vultr.com/vultr.com.100MB.bin"
	speed "Vultr, GA, Atlanta         :" "http://ga-us-ping.vultr.com/vultr.com.100MB.bin"
	speed "Vultr, NJ, New Jersey      :" "http://nj-us-ping.vultr.com/vultr.com.100MB.bin"
	speed "DigitalOcean, CA, SFO 01   :" "http://speedtest-sfo1.digitalocean.com/100mb.test"
	speed "DigitalOcean, CA, SFO 02   :" "http://speedtest-sfo2.digitalocean.com/100mb.test"
	speed "DigitalOcean, CA, SFO 03   :" "http://speedtest-sfo3.digitalocean.com/100mb.test"
	speed "DigitalOcean, NY, NYC 01   :" "http://speedtest-nyc1.digitalocean.com/100mb.test"
	speed "DigitalOcean, NY, NYC 02   :" "http://speedtest-nyc2.digitalocean.com/100mb.test"
	speed "DigitalOcean, NY, NYC 03   :" "http://speedtest-nyc3.digitalocean.com/100mb.test"
	speed "DataCamp, CA, LAX          :" "http://lax.download.datapacket.com/100mb.bin"
	#speed "DataCamp, WA, Seattle      :" "http://sea.download.datapacket.com/100mb.bin"
	speed "DataCamp, CO, Denver       :" "http://den.download.datapacket.com/100mb.bin"
	speed "DataCamp, TX, Dallas       :" "http://dal.download.datapacket.com/100mb.bin"
	speed "DataCamp, IL, Chicago      :" "http://chi.download.datapacket.com/100mb.bin"
	speed "DataCamp, NY, NYC          :" "http://nyc.download.datapacket.com/100mb.bin"
	speed "DataCamp, FL, Miami        :" "http://mia.download.datapacket.com/100mb.bin"
	speed "Linode, CA, Fremont        :" "http://speedtest.fremont.linode.com/100MB-fremont.bin"
	speed "Linode, TX, Dallas         :" "http://speedtest.dallas.linode.com/100MB-dallas.bin"
	speed "Linode, GA, Atlanta        :" "http://speedtest.atlanta.linode.com/100MB-atlanta.bin"
	speed "Linode, NJ, Newark         :" "http://speedtest.newark.linode.com/100MB-newark.bin"
	speed "RamNode, CA, LAX           :" "http://lg.la.ramnode.com/static/100MB.test"
	speed "RamNode, WA, Seattle       :" "http://lg.sea.ramnode.com/static/100MB.test"
	speed "RamNode, GA, Atlanta       :" "http://lg.atl.ramnode.com/static/100MB.test"
	speed "RamNode, NY, NYC           :" "http://lg.nyc.ramnode.com/static/100MB.test"
	speed "Softlayer, CA, San Jose    :" "http://speedtest.sjc01.softlayer.com/downloads/test100.zip"
	speed "Softlayer, WA, Seattle     :" "http://speedtest.sea01.softlayer.com/downloads/test100.zip"
	speed "Softlayer, TX, Houston     :" "http://speedtest.hou02.softlayer.com/downloads/test100.zip"
	speed "Leaseweb, CA, SFO          :" "http://mirror.sfo12.us.leaseweb.net/speedtest/100mb.bin"
	speed "Leaseweb, TX, Dallas       :" "http://mirror.dal10.us.leaseweb.net/speedtest/100mb.bin"
	speed "Leaseweb, Washington DC    :" "http://mirror.wdc1.us.leaseweb.net/speedtest/1000mb.bin"
	speed "Psychz, CA, LAX            :" "http://23.91.21.131/100.mb"
	speed "Psychz, TX, Dallas         :" "http://45.35.221.50/100.mb"
	speed "Psychz, IL, Chicago        :" "http://172.107.202.151/100.mb"
	speed "HostUS, CA, LAX 01         :" "https://la-lg.hostus.us/100MB.test"
	#speed "HostUS, CA, LAX 02         :" "http://la02-lg.hostus.us/100MB.file"
	speed "HostUS, CA, LAX 03         :" "http://la03-lg.hostus.us/100MB.tf"
	speed "HostUS, TX, DAL 01         :" "http://dal-lg.hostus.us/100MB.test"
	speed "HostUS, TX, DAL 02         :" "http://dal02-lg.hostus.us/100MB.test"
	speed "HostUS, GA, Atlanta        :" "https://atl-lg.hostus.us/100MB.test"
	speed "HostUS, NC, Charlotte      :" "http://clt-lg.hostus.us/100MB.test"
	speed "HostUS, Washington DC      :" "http://wdc-lg.hostus.us/100MB.test"
	speed "Rackspace, TX, Dallas      :" "http://sandbox.dfw1.rackspace.net/128MB.test"
	speed "Rackspace, IL, Chicago     :" "http://sandbox.ord1.rackspace.net/128MB.test"
	speed "Rackspace, Washington DC   :" "http://sandbox.iad3.rackspace.net/256MB.test"
	speed "HostHatch, CA, LAX         :" "http://31.220.30.5/100.mb"
	speed "HostHatch, IL, Chicago     :" "http://45.132.73.140/100.mb"
	speed "HostHatch, NJ, Secaucus    :" "http://185.213.26.112/100.mb"
	speed "Nexus Bytes, CA, LAX       :" "http://lgla.nexusbytes.com/100MB.test"
	speed "Nexus Bytes, NY, NYC       :" "http://lgny.nexusbytes.com/100MB.test"
	speed "Nexus Bytes, FL, Miami     :" "http://lgmi.nexusbytes.com/100MB.test"
	speed "UltraVPS.eu, CA, LAX       :" "http://lg.lax.us.ultravps.eu/100MB.test"
	speed "UltraVPS.eu, TX, Dallas    :" "http://lg.dal.us.ultravps.eu/100MB.test"
	speed "BuyVM, NV, Las Vegas       :" "https://speedtest.lv.buyvm.net/100MB.test"
	speed "BuyVM, NY, NYC             :" "https://speedtest.ny.buyvm.net/100MB.test"
	speed "Tier.Net, OR, Bend         :" "http://lg.or.tier.net/100MB.test"
	speed "1GServers, AZ, Phoenix     :" "http://speedtest.1gservers.com/100MB.test"
	speed "Pivo, AZ, Phoenix          :" "http://162.216.242.209/100.test"
	speed "Choopa, NY, New Jersey     :" "http://speedtest.choopa.net/100MBtest.bin"
	echo "" | tee -a $log
}

# 27 location (2.8GB)
usawestcoastspeedtest () {
	echo "" | tee -a $log
	echostyle "### 美國西岸地區測速"
	echo "" | tee -a $log
	speed "Vultr, CA, LAX             :" "http://lax-ca-us-ping.vultr.com/vultr.com.100MB.bin"
	speed "Vultr, CA, Silicon Valley  :" "https://sjo-ca-us-ping.vultr.com/vultr.com.100MB.bin"
	speed "Vultr, WA, Seattle         :" "http://wa-us-ping.vultr.com/vultr.com.100MB.bin"
	speed "DigitalOcean, CA, SFO 01   :" "http://speedtest-sfo1.digitalocean.com/100mb.test"
	speed "DigitalOcean, CA, SFO 02   :" "http://speedtest-sfo2.digitalocean.com/100mb.test"
	speed "DigitalOcean, CA, SFO 03   :" "http://speedtest-sfo3.digitalocean.com/100mb.test"
	speed "Softlayer, CA, San Jose 01 :" "http://speedtest.sjc01.softlayer.com/downloads/test100.zip"
	speed "Softlayer, CA, San Jose 03 :" "http://speedtest.sjc03.softlayer.com/downloads/test100.zip"
	speed "Softlayer, WA, Seattle     :" "http://speedtest.sea01.softlayer.com/downloads/test100.zip"
	speed "ColoCrossing, CA, LAX      :" "http://lg.la.colocrossing.com/100MB.test"
	speed "ColoCrossing, CA, San Jose :" "http://lg.sj.colocrossing.com/100MB.test"
	speed "ColoCrossing, WA, Seattle  :" "http://lg.sea.colocrossing.com/100MB.test"
	speed "HostUS, CA, LAX 01         :" "https://la-lg.hostus.us/100MB.test"
	#speed "HostUS, CA, LAX 02         :" "http://la02-lg.hostus.us/100MB.file"
	speed "HostUS, CA, LAX 03         :" "http://la03-lg.hostus.us/100MB.tf"
	speed "RamNode, CA, LAX           :" "http://lg.la.ramnode.com/static/100MB.test"
	speed "RamNode, WA, Seattle       :" "http://lg.sea.ramnode.com/static/100MB.test"
	speed "DataCamp, CA, LAX          :" "http://lax.download.datapacket.com/100mb.bin"
	#speed "DataCamp, WA, Seattle      :" "http://sea.download.datapacket.com/100mb.bin"
	speed "Leaseweb, CA, SFO          :" "http://mirror.sfo12.us.leaseweb.net/speedtest/100mb.bin"
	speed "Linode, CA, Fremont        :" "http://speedtest.fremont.linode.com/100MB-fremont.bin"
	speed "HostHatch, CA, LAX         :" "http://31.220.30.5/100.mb"
	speed "Psychz, CA, LAX            :" "https://lg.lax.psychz.net/200MB.test"
	speed "IntoVPS, CA, Fremont       :" "https://lg.fre.hosterion.com/100MB.test"
	speed "UltraVPS.eu, CA, LAX       :" "http://lg.lax.us.ultravps.eu/100MB.test"
	speed "Nexus Bytes, CA, LAX       :" "http://lgla.nexusbytes.com/100MB.test"
	speed "Tier.Net, OR, Bend         :" "http://lg.or.tier.net/100MB.test"
	echo "" | tee -a $log
}

# 16 location (16GB)
gigabitspeedtest () {
	echo "" | tee -a $log
	echostyle "### 1GB檔案測速"
	echo "" | tee -a $log
	speed "Vultr, CA, LAX             :" "http://lax-ca-us-ping.vultr.com/vultr.com.1000MB.bin"
	speed "Vultr, CA, Silicon Valley  :" "http://sjo-ca-us-ping.vultr.com/vultr.com.1000MB.bin"
	speed "Vultr, WA, Seattle         :" "http://wa-us-ping.vultr.com/vultr.com.1000MB.bin"
	speed "DigitalOcean, CA, SFO 01   :" "http://speedtest-sfo1.digitalocean.com/1gb.test"
	speed "DigitalOcean, CA, SFO 02   :" "http://speedtest-sfo2.digitalocean.com/1gb.test"
	speed "DigitalOcean, CA, SFO 03   :" "http://speedtest-sfo3.digitalocean.com/1gb.test"
	speed "ColoCrossing, CA, LAX      :" "http://lg.la.colocrossing.com/1000MB.test"
	speed "ColoCrossing, CA, San Jose :" "http://lg.sj.colocrossing.com/1000MB.test"
	speed "ColoCrossing, WA, Seattle  :" "http://lg.sea.colocrossing.com/1000MB.test"
	speed "RamNode, CA, LAX           :" "http://lg.la.ramnode.com/static/1000MB.test"
	speed "RamNode, WA, Seattle       :" "http://lg.sea.ramnode.com/static/1000MB.test"
	speed "DataCamp, CA, LAX          :" "http://lax.download.datapacket.com/1000mb.bin"
	speed "Leaseweb, CA, SFO          :" "http://mirror.sfo12.us.leaseweb.net/speedtest/1000mb.bin"
	speed "HostHatch, CA, LAX         :" "http://31.220.30.5/1000.mb"
	speed "Nexus Bytes, CA, LAX       :" "http://lgla.nexusbytes.com/1024MB.test"
	speed "Tier.Net, OR, Bend         :" "http://lg.or.tier.net/1024MB.test"
	echo "" | tee -a $log
}

# 8 location (0.9GB)
taiwanspeedtest () {
	echo "" | tee -a $log
	echostyle "### 中華民國地區測速"
	echo "" | tee -a $log
	speed "中華電信, 臺北市           :" "http://http.speed.hinet.net/test_100m.zip"
	speed "國網中心, 新竹市           :" "http://free.nchc.org.tw/parrot/misc/100MB.bin"
	speed "Psychz, TW, 臺北市         :" "https://lg.tw.psychz.net/200MB.test"
	speed "HostingInside, 臺北市      :" "http://103.98.74.47/100.mb"
	speed "Serverfield, 臺北市        :" "http://lg.tpe.serverfield.com.tw/100MB.test"
	speed "威達雲端電訊, 臺中市       :" "http://speed.vee.com.tw/100mb.bin"
	speed "台灣之星, 臺北市           :" "http://tstarkh1.vibo.net.tw/speedtest/100M.jpg"
	speed "台灣大寬頻, 臺北市         :" "http://speed.anet.net.tw/100M.dat"
	echo "" | tee -a $log
}

# 8 location (0.8GB)
singaporespeedtest () {
	echo "" | tee -a $log
	echostyle "### 新加坡地區測速"
	echo "" | tee -a $log
	speed "Vultr, Singapore           :" "http://sgp-ping.vultr.com/vultr.com.100MB.bin"
	speed "DataCamp, Singapore        :" "http://sgp.download.datapacket.com/100mb.bin"
	speed "Softlayer, Singapore       :" "http://speedtest.sng01.softlayer.com/downloads/test100.zip"
	speed "Linode, Singapore          :" "http://speedtest.singapore.linode.com/100MB-singapore.bin"
	speed "Leaseweb, Singapore        :" "http://mirror.sg.leaseweb.net/speedtest/100mb.bin"
	speed "HostUS, Singapore          :" "https://sgp-lg.hostus.us/100MB.test"
	speed "Nexus Bytes, Singapore     :" "http://lgsg.nexusbytes.com/100MB.test"
	speed "OVH, Singapore             :" "http://speedtest-sgp.apac-tools.ovh/files/100Mb.dat"
	echo "" | tee -a $log
}

# 6 location (0.6GB)
japanspeedtest () {
	echo "" | tee -a $log
	echostyle "### 日本地區測速"
	echo "" | tee -a $log
	speed "Psychz, JP, Tokyo          :" "http://172.107.231.230/100.mb"
	speed "Vultr, JP, Tokyo           :" "http://hnd-jp-ping.vultr.com/vultr.com.100MB.bin"
	speed "DataCamp, JP, Tokyo        :" "http://tyo.download.datapacket.com/100mb.bin"
	speed "Softlayer, JP, Tokyo       :" "http://speedtest.tok02.softlayer.com/downloads/test100.zip"
	speed "Linode, JP, Tokyo          :" "http://speedtest.tokyo2.linode.com/100MB-tokyo2.bin"
	speed "Nexus Bytes, JP, Tokyo     :" "http://lgjp.nexusbytes.com/100MB.test"
	echo "" | tee -a $log
}

dryrun () {
	echo "" | tee -a $log
	echostyle "### 測試運行"
	echo "" | tee -a $log
	speed "CacheFly                   :" "http://cachefly.cachefly.net/100mb.test"
	speed "國網中心, 新竹市           :" "http://free.nchc.org.tw/parrot/misc/100MB.bin"
	speed "Psychz, TW, 臺北市         :" "https://lg.tw.psychz.net/200MB.test"
	echo "" | tee -a $log
}

freedisk() {
	# check free space
	freespace=$( df -m . | awk 'NR==2 {print $4}' )
	if [[ $freespace -ge 1024 ]]; then
		printf "%s" $((1024*2))
	elif [[ $freespace -ge 512 ]]; then
		printf "%s" $((512*2))
	elif [[ $freespace -ge 256 ]]; then
		printf "%s" $((256*2))
	elif [[ $freespace -ge 128 ]]; then
		printf "%s" $((128*2))
	else
		printf 1
	fi
}

averageio() {
	ioraw1=$( echo $1 | awk 'NR==1 {print $1}' )
		[ "$(echo $1 | awk 'NR==1 {print $2}')" == "GB/s" ] && ioraw1=$( awk 'BEGIN{print '$ioraw1' * 1024}' )
	ioraw2=$( echo $2 | awk 'NR==1 {print $1}' )
		[ "$(echo $2 | awk 'NR==1 {print $2}')" == "GB/s" ] && ioraw2=$( awk 'BEGIN{print '$ioraw2' * 1024}' )
	ioraw3=$( echo $3 | awk 'NR==1 {print $1}' )
		[ "$(echo $3 | awk 'NR==1 {print $2}')" == "GB/s" ] && ioraw3=$( awk 'BEGIN{print '$ioraw3' * 1024}' )
	ioall=$( awk 'BEGIN{print '$ioraw1' + '$ioraw2' + '$ioraw3'}' )
	ioavg=$( awk 'BEGIN{printf "%.1f", '$ioall' / 3}' )
	printf "%s" "$ioavg"
}

cpubench() {
	if hash $1 2>$NULL; then
		io=$( ( dd if=/dev/zero bs=512K count=$2 | $1 ) 2>&1 | grep 'copied' | awk -F, '{io=$NF} END { print io}' )
		if [[ $io != *"."* ]]; then
			printf "  %4i %s" "${io% *}" "${io##* }"
		else
			printf "%4i.%s" "${io%.*}" "${io#*.}"
		fi
	else
		printf " %s not found on system." "$1"
	fi
}

iotest () {
	echo "" | tee -a $log
	echostyle "### IO測試"
	echo "" | tee -a $log

	# start testing
	writemb=$(freedisk)
	if [[ $writemb -gt 512 ]]; then
		writemb_size="$(( writemb / 2 / 2 ))MB"
		writemb_cpu="$(( writemb / 2 ))"
	else
		writemb_size="$writemb"MB
		writemb_cpu=$writemb
	fi

	# CPU Speed test
	printf " ## CPU 速度:\n" | tee -a $log
	printf "    bzip2 %s -" "$writemb_size" | tee -a $log
	printf "%s\n" "$( cpubench bzip2 $writemb_cpu )" | tee -a $log 
	printf "   sha256 %s -" "$writemb_size" | tee -a $log
	printf "%s\n" "$( cpubench sha256sum $writemb_cpu )" | tee -a $log
	printf "   md5sum %s -" "$writemb_size" | tee -a $log
	printf "%s\n\n" "$( cpubench md5sum $writemb_cpu )" | tee -a $log

	# Disk test
	echo " ## 磁碟速度 ($writemb_size):" | tee -a $log
	if [[ $writemb != "1" ]]; then
		io=$( ( dd bs=512K count=$writemb if=/dev/zero of=test; rm -f test ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
		echo "   I/O Speed  -$io" | tee -a $log

		io=$( ( dd bs=512K count=$writemb if=/dev/zero of=test oflag=dsync; rm -f test ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
		echo "   I/O Direct -$io" | tee -a $log
	else
		echo "   磁碟空間剩餘不足" | tee -a $log
	fi
	echo "" | tee -a $log

	# RAM Speed test
	# set ram allocation for mount
	tram_mb="$( free -m | grep Mem | awk 'NR=1 {print $2}' )"
	if [[ tram_mb -gt 1900 ]]; then
		sbram=1024M
		sbcount=2048
	else
		sbram=$(( tram_mb / 2 ))M
		sbcount=$tram_mb
	fi
	[[ -d $benchram ]] || mkdir $benchram
	mount -t tmpfs -o size=$sbram tmpfs $benchram/
	printf " ## 記憶體速度 (%sB):\n" "$sbram" | tee -a $log
	iow1=$( ( dd if=/dev/zero of=$benchram/zero bs=512K count=$sbcount ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
	ior1=$( ( dd if=$benchram/zero of=$NULL bs=512K count=$sbcount; rm -f test ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
	iow2=$( ( dd if=/dev/zero of=$benchram/zero bs=512K count=$sbcount ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
	ior2=$( ( dd if=$benchram/zero of=$NULL bs=512K count=$sbcount; rm -f test ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
	iow3=$( ( dd if=/dev/zero of=$benchram/zero bs=512K count=$sbcount ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
	ior3=$( ( dd if=$benchram/zero of=$NULL bs=512K count=$sbcount; rm -f test ) 2>&1 | awk -F, '{io=$NF} END { print io}' )
	echo "   Avg. write - $(averageio "$iow1" "$iow2" "$iow3") MB/s" | tee -a $log
	echo "   Avg. read  - $(averageio "$ior1" "$ior2" "$ior3") MB/s" | tee -a $log
	rm $benchram/zero
	umount $benchram
	rm -rf $benchram
	echo "" | tee -a $log
}

speedtestresults () {
	#Testing Speedtest
	if hash python 2>$NULL; then
		curl -Lso speedtest-cli https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py
		python speedtest-cli --share | tee -a $log
		rm -f speedtest-cli
		echo ""
	else
		echo " Python is not installed."
		echo " First install python, then re-run the script."
		echo ""
	fi
}

startedon() {
	echo "\$ $ARG" >> $log
	echo "" | tee -a $log
	benchstart=$(date +"%d-%b-%Y %H:%M:%S")
	start_seconds=$(date +%s)
	echo " Benchmark started on $benchstart" | tee -a $log
}

finishedon() {
	end_seconds=$(date +%s)
	echo " Benchmark finished in $((end_seconds-start_seconds)) seconds" | tee -a $log
	echo "   results saved on $log"
	echo "" | tee -a $log
}

sharetest() {
	case $1 in
	'ubuntu')
		share_link=$( curl -v --data-urlencode "content@$log" -d "poster=bench.log" -d "syntax=text" "https://paste.ubuntu.com" 2>&1 | \
			grep "Location" | awk '{print $3}' );;
	'haste' )
		share_link=$( curl -X POST -s -d "$(cat $log)" https://hastebin.com/documents | awk -F '"' '{print "https://hastebin.com/"$4}' );;
	'clbin' )
		share_link=$( curl -sF 'clbin=<-' https://clbin.com < $log );;
	'ptpb' )
		share_link=$( curl -sF c=@- https://ptpb.pw/?u=1 < $log );;
	esac

	# print result info
	echo " Share result:"
	echo " $share_link"
	echo ""

}

case $CMD in
	'-info'|'-information'|'--info'|'--information' )
		clear; systeminfo;;
	'-io'|'-drivespeed'|'--io'|'--drivespeed' )
		clear; iotest;;
	'-northamercia'|'-na'|'--northamercia'|'--na' )
		clear; benchinit; startedon; northamerciaspeedtest; finishedon;;
	'-europe'|'-eu'|'--europe'|'--eu' )
		clear; benchinit; startedon; europespeedtest; finishedon;;
	'-exotic'|'--exotic' )
		clear; benchinit; startedon; exoticpeedtest; finishedon;;
	'-asia'|'--asia' )
		clear; benchinit; startedon; asiaspeedtest; finishedon;;
	'-usa'|'--usa' )
		clear; benchinit; startedon; usaspeedtest; finishedon;;
	'-westcoast'|'--westcoast' )
		clear; benchinit; startedon; usawestcoastspeedtest; finishedon;;
	'-taiwan'|'--taiwan' )
		clear; benchinit; startedon; taiwanspeedtest; finishedon;;
	'-singapore'|'--singapore' )
		clear; benchinit; startedon; singaporespeedtest; finishedon;;
	'-japan'|'--japan' )
		clear; benchinit; startedon; japanspeedtest; finishedon;;
	'-1gbps'|'--1gbps' )
		clear; benchinit; startedon; gigabitspeedtest; finishedon;;
	'-dryrun'|'--dryrun' )
		clear; benchinit; startedon; dryrun; finishedon;;
	'-cdn'|'--cdn' )
		clear; benchinit; cdnspeedtest;;
	'-b'|'--b' )
		clear; benchinit; startedon; systeminfo; cdnspeedtest; iotest; finishedon;;
	'-a'|'-all'|'-bench'|'--a'|'--all'|'--bench' )
		clear; benchinit; startedon; systeminfo; cdnspeedtest; northamerciaspeedtest;
		europespeedtest; exoticpeedtest; asiaspeedtest; iotest; finishedon;;
	'-speed'|'-speedtest'|'-speedcheck'|'--speed'|'--speedtest'|'--speedcheck' )
		clear; benchinit; speedtestresults;;
	'-help'|'--help'|'help' )
		clear; prms;;
	'-about'|'--about'|'about' )
		clear; about;;
	*)
		howto;;
esac

case $PRM1 in
	'-share'|'--share'|'share' )
		if [[ $PRM2 == "" ]]; then
			sharetest ubuntu
		else
			sharetest $PRM2
		fi
		;;
esac

# ring a bell
printf '\007'
