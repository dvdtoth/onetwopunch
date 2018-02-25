#!/bin/bash

# Colors
ESC="\e["
RESET=$ESC"39m"
RED=$ESC"31m"
GREEN=$ESC"32m"
BLUE=$ESC"34m"

function banner {
echo "                        _    ,-,    _                                                        "
echo "                 ,--, /: :\\/': :\`\\/: :\                                           _        "
echo "  ___  _ __   __|\`;  ' \`,'   \`.;    \`: |___      _____    _ __  _   _ _ __   ___| |__  /\\"
echo " / _ \| '_ \ / _|    |     |  '  |     |_\ \ /\ / / _ \  | '_ \| | | | '_ \ / __| '_ \/ /"
echo "| (_) | | | |  _| :  |     |     |     |_ \ V  V / (_) | | |_) | |_| | | | | (__| | |/\/ "
echo " \___/|_| |_|\__| :. |  :  |  :  |  :  |_| \_/\_/ \___/  | .__/ \__,_|_| |_|\___|_| |\/   "
echo "                 \\__/: :.. : :.. | :.. |  )              |_|              == V.2 == "
echo "                      \`---',\\___/,\\___/ /'                             by superkojiman"
echo "                           \`==._ .. . /'                            customized by dvdtoth"
echo "                                \`-::-'                                                       "
}

function usage {
    echo "Usage: $0 [-t targets.txt|-s 127.0.0.1] [-p tcp/udp/all] [-i interface] [-n nmap-options] [-o output_folder] [-h]"
    echo "       -h: Help"
    echo "       -t: File containing ip addresses to scan."
    echo "       -s: Single IP address to scan"
    echo "       -p: Protocol. Defaults to all"
    echo "       -i: Network interface. Defaults to eth0"
    echo "       -n: NMAP options (-A, -O, etc). Defaults to -Pn -sV"
    echo "       -o: Output results to location"
}

banner

if [[ ! $(id -u) == 0 ]]; then
    echo -e "${RED}[!]${RESET} This script must be run as root"
    exit 1
fi

if [[ -z $(which nmap) ]]; then
    echo -e "${RED}[!]${RESET} Unable to find nmap. Install it and make sure it's in your PATH environment"
    exit 1
fi

if [[ -z $(which unicornscan) ]]; then
    echo -e "${RED}[!]${RESET} Unable to find unicornscan. Install it and make sure it's in your PATH environment"
    exit 1
fi

if [[ -z $1 ]]; then
    usage
    exit 0
fi

# commonly used default options
proto="all"
iface="eth0"
nmap_opt="-Pn -sV"
targets=""
date="$(date "+%Y%m%d-%H%M%S")"

while getopts "p:i:t:s:n:o:h" OPT; do
    case $OPT in
        p) proto=${OPTARG};;
        i) iface=${OPTARG};;
        t) targets=${OPTARG};;
        s) ip=${OPTARG};;
        n) nmap_opt=${OPTARG};;
        o) output=${OPTARG};;
        h) usage; exit 0;;
        *) usage; exit 0;;
    esac
done

if [[ -z $targets && -z $ip ]]; then
    echo "[!] No target file or IP [-t|-s] provided"
    usage
    exit 1
fi

if [[ ${proto} != "tcp" && ${proto} != "udp" && ${proto} != "all" ]]; then
    echo "[!] Unsupported protocol"
    usage
    exit 1
fi

start=`date +%s`

# scan single ip if no targets file specified
if [[ -z $targets ]]; then
    scantarget=$ip
else
    scantartget=$targets
fi

echo -e "${BLUE}[+]${RESET} Protocol : ${proto}"
echo -e "${BLUE}[+]${RESET} Interface: ${iface}"
echo -e "${BLUE}[+]${RESET} Nmap opts: ${nmap_opt}"
echo -e "${BLUE}[+]${RESET} Targets  : ${scantarget}"
echo -e "${BLUE}[+]${RESET} Output   : ${output}/${date}"


# Prepare folder for results
if [[ -z $output ]]; then
    log_dir="${HOME}/.onetwopunch/${date}"
else
    log_dir="$output/${date}"
fi

mkdir -p "${log_dir}"

function scan {
    echo -e "${BLUE}[+]${RESET} Scanning $ip for $proto ports..."

    # unicornscan identifies all open TCP ports
    if [[ $proto == "tcp" || $proto == "all" ]]; then
        echo -e "${BLUE}[+]${RESET} Obtaining all open TCP ports using unicornscan..."
        echo -e "${BLUE}[+]${RESET} unicornscan -i ${iface} -mT ${ip}:a -l ${log_dir}/${ip}-tcp.txt"
        unicornscan -i ${iface} -mT ${ip}:a -l ${log_dir}/${ip}-tcp.txt
        ports=$(cat "${log_dir}/${ip}-tcp.txt" | grep open | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',')
        if [[ ! -z $ports ]]; then
            # nmap follows up
            echo -e "${GREEN}[*]${RESET} TCP ports for nmap to scan: $ports"
            echo -e "${BLUE}[+]${RESET} nmap -e ${iface} ${nmap_opt} -oA ${log_dir}/${ip}-tcp -p ${ports} ${ip}"
            nmap -e ${iface} ${nmap_opt} -oA ${log_dir}/${ip}-tcp -p ${ports} ${ip}
        else
            echo -e "${RED}[!]${RESET} No TCP ports found"
        fi
    fi

    # unicornscan identifies all open UDP ports
    if [[ $proto == "udp" || $proto == "all" ]]; then
        echo -e "${BLUE}[+]${RESET} Obtaining all open UDP ports using unicornscan..."
        echo -e "${BLUE}[+]${RESET} unicornscan -i ${iface} -mU ${ip}:a -l ${log_dir}/${ip}-udp.txt"
        unicornscan -i ${iface} -mU ${ip}:a -l ${log_dir}/${ip}-udp.txt
        ports=$(cat "${log_dir}/${ip}-udp.txt" | grep open | cut -d"[" -f2 | cut -d"]" -f1 | sed 's/ //g' | tr '\n' ',')
        if [[ ! -z $ports ]]; then
            # nmap follows up
            echo -e "${GREEN}[*]${RESET} UDP ports for nmap to scan: $ports"
            echo -e "${BLUE}[+]${RESET} nmap -e ${iface} ${nmap_opt} -sU -oA ${log_dir}/${ip}-udp -p ${ports} ${ip}"
            nmap -e ${iface} ${nmap_opt} -sU -oA ${log_dir}/${ip}-udp -p ${ports} ${ip}
        else
            echo -e "${RED}[!]${RESET} No UDP ports found"
        fi
    fi
}

if [[ ! -z $targets ]]; then
    while read ip; do
        scan
    done < $targets
else
    scan
fi

end=`date +%s`

secs=$((end-start))
runtime=$(printf '%dh:%dm:%ds\n' $(($secs/3600)) $(($secs%3600/60)) $(($secs%60)))
echo -e "${BLUE}[+]${RESET} Scans completed in ${runtime}"
echo -e "${BLUE}[+]${RESET} Results saved to ${log_dir}"
