#!/bin/bash
#
# This is a simple bash script that monitor the server high cpu, ram usage, the hard disk free space, postgresql status, apache2 status and check the systemctl services status.
# If the ram or cpu usage is greather then limit or a service is failed, send a message to telegram user.
#
# Require telegram bot and telegram user
# Require pg_isready included within postgresql-client
#
# Based on the script by Alfio Salanitri https://github.com/alfiosalanitri/server-guardian

##########################
# Functions
##########################
display_help() {
cat << EOF
SERVER GUARDIAN

Usage: $(basename $0) --server-name servername --warn-every 60 --watch-services 1 --watch-cpu 1 --watch-ram 1 --watch-hard-disk 1 --watch-apache2 1 --watch-postgresql 1 --cpu-warning-level low --memory-limit 70 --disk-space-limit 80 --url http://example.com --pg_host 127.0.0.1 --pg_database example --pg_port 5432 --pg_user postgres --config /path/to/.custom-config --config-telegram-variable-token TELEGRAM_TOKEN --config-telegram-variable-chatid CHAT_ID

Options
--server-name
    Custom server name

--warn-every
    Minutes number between each alert

--watch-cpu
    1 to enable or 0 to disable the high cpu usage

--watch-ram
    1 to enable or 0 to disable the high ram usage

--watch-services
    1 to enable or 0 to disable the services failed alert

--watch-hard-disk
    1 to enable or 0 to disable the hard disk free space alert

--watch-apache2
    1 to enable or 0 to disable the services failed alert

--watch-postgresql
    1 to enable or 0 to disable the services failed alert

--url
    URL used by curl to check apache2 service

--pg_host
    Host to check postgresql service

--pg_database
    Database to check postgresql service

--pg_port
    Port to check postgresql service

--pg_user
    User to check postgresql service

--cpu-warning-level
    high: to receive an alert if the load average of last minute is greater than cpu core number.
    medium: watch the value of the latest 5 minutes. (default)
    low: watch the value of the latest 15 minuts.

--memory-limit
    Memory percentage limit

--disk-space-limit
    disk space percentage limit

--config
    path to custom config file with telegram bot key and telegram chat id options

--config-telegram-variable-token
    the token variable name (not the token key) stored in custom config file (ex: TELEGRAM_TOKEN)

--config-telegram-variable-chatid
    the chat id variable name (not the id) stored in custom config file (ex: TELEGRAM_CHAT_ID)

-h, --help
    show this help
-------------
EOF
exit 0
}
send_message() {
  telegram_message="\`$1\`"
  date=$(date '+%Y-%m-%d %H:%M:%S')
  ip=$(ip -4 a |grep inet|grep "scope global"|grep -P -o "inet \d+.\d+.\d+.\d+"|grep -o -P "\d+.\d+.\d+.\d+")

  #store top results to file
  top -n1 -b > $top_report_file
  telegram_message="${telegram_message}."
  report=$(echo -e "\n\n"See top results here: $top_report_file)

  curl -s -X POST "https://api.telegram.org/bot$telegram_bot_token/sendMessage" -F chat_id=$telegram_user_chat_id -F text="$date $telegram_title $ip $telegram_message $report" -F parse_mode="Markdown"

}

##########################
# Default options
##########################
server_name=""
current_path=`dirname "$0"`
top_report_file="$current_path/top-report.txt"
config_file=""
send_alert_every_minutes=""
watch_cpu=""
cpu_warning_level=""
watch_ram=""
memory_perc_limit=""
watch_services=""
watch_hard_disk=""
disk_space_perc_limit=""
telegram_variable_token="telegram_bot_token"
telegram_variable_chatid="telegram_user_chat_id"
watch_apache2=""
url=""
watch_postgresql=""
pg_host=""
pg_database=""
pg_port=""
pg_user=""
send_sysinfo=""

##########################
# Get options from cli
##########################
while [ $# -gt 0 ] ; do
  case $1 in
    -h | --help) display_help ;;
    --server-name)
      server_name=$2
      ;;
    --warn-every)
      send_alert_every_minutes=$2
      ;;
    --watch-cpu)
      watch_cpu=$2
      ;;
    --watch-ram)
      watch_ram=$2
      ;;
    --watch-services)
      watch_services=$2
      ;;
    --watch-hard-disk)
      watch_hard_disk=$2
      ;;
    --watch-apache2)
      watch_apache2=$2
      ;;
    --watch-postgresql)
      watch_postgresql=$2
      ;;
    --cpu-warning-level)
      cpu_warning_level=$2
      ;;
    --memory-limit)
      memory_perc_limit=$2
      ;;
    --disk-space-limit)
      disk_space_perc_limit=$2
      ;;
    --url)
      url=$2
      ;;
    --pg-host)
      pg_host=$2
      ;;
    --pg-database)
      pg_database=$2
      ;;
    --pg-port)
      pg_port=$2
      ;;
    --pg-user)
      pg_user=$2
      ;;
    --config)
      if [ ! -f $2 ]; then
        printf "Sorry but this config file not exists.\n"
        exit 1
      fi
      config_file=$2
      ;;
    --config-telegram-variable-token)
      telegram_variable_token=$2
      ;;
    --config-telegram-variable-chatid)
      telegram_variable_chatid=$2
      ;;
  esac
  shift
done

##########################
# Check options and config
##########################
if [ "" == "$config_file" ]; then
  config_file="$current_path/.config"
fi
if [ ! -f $config_file ]; then
  printf "Sorry but the config file is required. \n"
  exit 1
fi

if [ "" == "$send_alert_every_minutes" ]; then
  send_alert_every_minutes=$(awk -F'=' '/^send_alert_every_minutes=/ { print $2 }' $config_file)
fi
if [ "" == "$send_alert_every_minutes" ]; then
  printf "Pass the --warn-every variable from cli or add send_alert_every_minutes variable to config file.\n"
  exit 1
fi

if [ "" == "$watch_cpu" ]; then
  watch_cpu=$(awk -F'=' '/^watch_cpu=/ { print $2 }' $config_file)
fi
if [ "" == "$watch_cpu" ]; then
  printf "Pass the --watch-cpu variable from cli or add watch_cpu variable to config file.\n"
  exit 1
fi
if [ "" == "$cpu_warning_level" ]; then
  cpu_warning_level=$(awk -F'=' '/^cpu_warning_level=/ { print $2 }' $config_file)
fi
if [ "" == "$cpu_warning_level" ] && [ "1" == "$watch_cpu" ]; then
  printf "Pass the --cpu-warning-level variable from cli or add cpu_warning_level variable to config file.\n"
  exit 1
fi

if [ "" == "$watch_ram" ]; then
  watch_ram=$(awk -F'=' '/^watch_ram=/ { print $2 }' $config_file)
fi
if [ "" == "$watch_ram" ]; then
  printf "Pass the --watch-ram variable from cli or add watch_ram variable to config file.\n"
  exit 1
fi
if [ "" == "$memory_perc_limit" ]; then
  memory_perc_limit=$(awk -F'=' '/^memory_perc_limit=/ { print $2 }' $config_file)
fi
if [ "" == "$memory_perc_limit" ] && [ "1" == "$watch_ram" ]; then
  printf "Pass the --memory-limit variable from cli or add memory_perc_limit variable to config file.\n"
  exit 1
fi

if [ "" == "$watch_services" ]; then
  watch_services=$(awk -F'=' '/^watch_services=/ { print $2 }' $config_file)
fi
if [ "" == "$watch_services" ]; then
  printf "Pass the --watch-services variable from cli or add watch_services variable to config file.\n"
  exit 1
fi

if [ "" == "$watch_hard_disk" ]; then
  watch_hard_disk=$(awk -F'=' '/^watch_hard_disk=/ { print $2 }' $config_file)
fi
if [ "" == "$watch_hard_disk" ]; then
  printf "Pass the --watch-hard-disk variable from cli or add watch_hard_disk variable to config file.\n"
  exit 1
fi
if [ "" == "$disk_space_perc_limit" ]; then
  disk_space_perc_limit=$(awk -F'=' '/^disk_space_perc_limit=/ { print $2 }' $config_file)
fi
if [ "" == "$disk_space_perc_limit" ] && [ "1" == "$watch_hard_disk" ]; then
  printf "Pass the --disk-space-limit variable from cli or add disk_space_perc_limit variable to config file.\n"
  exit 1
fi

# Check telegram bot key and chat id
telegram_bot_token=$(awk -F'=' '/^'$telegram_variable_token'=/ { print $2 }' $config_file)
if [ "" == "$telegram_bot_token" ]; then
  printf "The variable $telegram_variable_token not exists into config file or is empty.\n"
  exit 1
fi
telegram_user_chat_id=$(awk -F'=' '/^'$telegram_variable_chatid'=/ { print $2 }' $config_file)
if [ "" == "$telegram_user_chat_id" ]; then
  printf "The variable $telegram_user_chat_id not exists into config file or is empty.\n"
  exit 1
fi

# Postgresql
if [ "" == "$watch_postgresql" ]; then
  watch_postgresql=$(awk -F'=' '/^watch_postgresql=/ { print $2 }' $config_file)
fi
if [ "" == "$watch_postgresql" ]; then
  printf "Pass the --watch-postgresql variable from cli or add watch_postgresql variable to config file.\n"
  exit 1
fi
if [ "" == "$pg_host" ]; then
  pg_host=$(awk -F'=' '/^pg_host=/ { print $2 }' $config_file)
fi
if [ "" == "$pg_host" ] && [ "1" == "$watch_postgresql" ]; then
  pg_host=127.0.0.1
  printf "Default the pg_host is 127.0.0.1 \n"
  printf "Pass the --pg-host variable from cli or add server_name variable to config file.\n"
fi
if [ "" == "$pg_database" ]; then
  pg_database=$(awk -F'=' '/^pg_database=/ { print $2 }' $config_file)
fi
if [ "" == "$pg_database" ] && [ "1" == "$watch_postgresql" ]; then
  printf "Pass the --pg-database variable from cli or add server_name variable to config file.\n"
  exit 1
fi
if [ "" == "$pg_port" ]; then
  pg_port=$(awk -F'=' '/^pg_port=/ { print $2 }' $config_file)
fi
if [ "" == "$pg_port" ] && [ "1" == "$watch_postgresql" ]; then
  pg_port=5432
  printf "Default the pg_port is 5432 \n"
  printf "Pass the --pg-port variable from cli or add server_name variable to config file.\n"
fi
if [ "" == "$pg_user" ]; then
  pg_user=$(awk -F'=' '/^pg_user=/ { print $2 }' $config_file)
fi
if [ "" == "$pg_user" ] && [ "1" == "$watch_postgresql" ]; then
  printf "Pass the --pg-user variable from cli or add server_name variable to config file.\n"
  exit 1
fi

# Apache2
if [ "" == "$watch_apache2" ]; then
  watch_apache2=$(awk -F'=' '/^watch_apache2=/ { print $2 }' $config_file)
fi
if [ "" == "$watch_apache2" ]; then
  printf "Pass the --watch-apache2 variable from cli or add watch_apache2 variable to config file.\n"
  exit 1
fi
if [ "" == "$url" ]; then
  url=$(awk -F'=' '/^url=/ { print $2 }' $config_file)
fi

if [ "" == "$url" ] && [ "1" == "$watch_apache2" ]; then
  printf "Pass the --url variable from cli or add server_name variable to config file.\n"
  exit 1
fi

# Server name customization or default
if [ "" == "$server_name" ]; then
  server_name=$(awk -F'=' '/^server_name=/ { print $2 }' $config_file)
fi

if [ "" == "$server_name" ]; then
  server_name=$(hostname | sed 's/-//g')
  printf "Default the server-name is the hostname.\n"
  printf "Pass the --server-name variable from cli or add server_name variable to config file.\n"
fi

telegram_title="Server - *$server_name*:"

if [ "" == "$send_sysinfo" ]; then
  send_sysinfo=$(awk -F'=' '/^send_sysinfo=/ { print $2 }' $config_file)
fi
if [ "" == "$send_sysinfo" ]; then
  printf "Add send_sysinfo variable to config file.\n"
  exit 1
fi

send_info() {
  sysinfotxt=$(echo -e "\n\n----System Information---- ")
  sysinfotxt+=$(echo -e "\nHostname:\t\t"`hostname`)
  sysinfotxt+=$(echo -e "\nuptime:\t\t\t"`uptime | awk '{print $3,$4}' | sed 's/,//'`)
  sysinfotxt+=$(echo -e "\nManufacturer:\t\t"`cat /sys/class/dmi/id/chassis_vendor`)
  sysinfotxt+=$(echo -e "\nProduct Name:\t\t"`cat /sys/class/dmi/id/product_name`)
  sysinfotxt+=$(echo -e "\nVersion:\t\t"`cat /sys/class/dmi/id/product_version`)
  sysinfotxt+=$(echo -e "\nSerial Number:\t\t"`cat /sys/class/dmi/id/product_serial`)
  sysinfotxt+=$(echo -e "\nMachine Type:\t\t"`vserver=$(lscpu | grep Hypervisor | wc -l); if [ $vserver -gt 0 ]; then echo "VM"; else echo "Physical"; fi`)
  sysinfotxt+=$(echo -e "\nOperating System:\t"`hostnamectl | grep "Operating System" | sed  's/Operating System: //g'`)
  sysinfotxt+=$(echo -e "\nKernel:\t\t\t"`uname -r`)
  sysinfotxt+=$(echo -e "\nArchitecture:\t\t"`uname -m`)
  sysinfotxt+=$(echo -e "\nProcessor Name:\t\t"`awk -F':' '/^model name/ {print $2}' /proc/cpuinfo | uniq | sed -e 's/^[ \t]*//'`)
  sysinfotxt+=$(echo -e "\nActive User:\t\t"`w | cut -d ' ' -f1 | grep -v USER | xargs -n1`)
  #sysinfotxt+=$(echo -e "\nSystem Main IP:\t\t"`ip -4 a |grep inet|grep "scope global"|grep -P -o "inet \d+.\d+.\d+.\d+"|grep -o -P "\d+.\d+.\d+.\d+"`)
  sysinfotxt+=$(echo -e "\n\n----CPU/Memory Usage----")
  sysinfotxt+=$(echo -e "\nMemory Usage:\t"`free | awk '/Mem/{printf("%.2f"), $3/$2*100}'`%)
  if [ `free | awk '/Swap/{ print $2}'` == 0 ]
  then
      sysinfotxt+=$(echo -e "\nSwap not enabled")
  else
      sysinfotxt+=$(echo -e "\nSwap Usage:\t"`free | awk '/Swap/{printf("%.2f"), $3/$2*100}'`%)
  fi
  sysinfotxt+=$(echo -e "\nCPU Usage:\t"`cat /proc/stat | awk '/cpu/{printf("%.2f\n"), ($2+$4)*100/($2+$4+$5)}' |  awk '{print $0}' | head -1`%)
  sysinfotxt+=$(echo -e "\n\n----Disk Usage >80%----")
  sysinfotxt+=$(echo -e "\n" & df -Ph | sed s/%//g | awk '{ if($5 > 80) print $0;}')
  
  #echo -e "-------------------------------For WWN Details-------------------------------"
  #vserver=$(lscpu | grep Hypervisor | wc -l)
  #if [ $vserver -gt 0 ]
  #then
  #echo "$(hostname) is a VM"
  #else
  #cat /sys/class/fc_host/host?/port_name
  #fi
  #echo ""

  if (( $(cat /etc/*-release | grep -w 'Ubuntu\|Debian' | wc -l) > 0 ))
  then
  sysinfotxt+=$(echo -e "\n\n----Package Updates----")
  sysinfotxt+=$(echo -e "\n" && apt list --upgradable | wc -l)
  sysinfotxt+=$(echo -e "\n")
  else
  sysinfotxt+=$(echo -e "\n\n----Package Updates----")
  sysinfotxt+=$(echo -e "\n" && pacman -Qu | wc -l)
  sysinfotxt+=$(echo -e "\n")
  fi
  sysinfotxt+=$(echo -e "\n----Package Versions----")
  sysinfotxt+=$(echo -e "\n" && (which apache2ctl &> /dev/null && apache2ctl -v | head -1 | awk '{print $3}') || (which apache2 &> /dev/null && apache2 -v | head -1 | awk '{print $3}'))
  sysinfotxt+=$(echo -e "\n" && which nginx &> /dev/null && nginx -v)
  sysinfotxt+=$(echo -e "\n" && which psql &> /dev/null && psql --version)
  sysinfotxt+=$(echo -e "\n" && which mysql &> /dev/null && mysql -V |awk '{print $1,$2,$3,$4,$5}')
  sysinfotxt+=$(echo -e "\n" && which php &> /dev/null && php --version | head -1 | awk '{print $1,$2}')
  sysinfotxt+=$(echo -e "\n" && which java &> /dev/null && java --version | head -1)
  
  send_message "$sysinfotxt" 
}

send=false

while true
do
##########################
# Start monitor
##########################
# Get the load average value and if is greather than 100% send an alert and exit
if [ "1" == "$watch_cpu" ]; then
  server_core=$(lscpu | grep '^CPU(s):' | awk '{print int($2)}')
  load_avg=$(uptime | grep -ohe 'load average[s:][: ].*')
  avg_position='$4' #avg 5min
  case $cpu_warning_level in
    low)
      avg_position='$5' #avg 15min
      ;;
    high)
      avg_position='$3' #avg 1min
      ;;
  esac
  load_avg_for_minutes=$(uptime | grep -ohe 'load average[s:][: ].*' | awk '{ print '$avg_position'}' | sed -e 's/,/./' | sed -e 's/,//' | awk '{print int($1)}')
  load_avg_percentage=$(($load_avg_for_minutes * 100 / $server_core))
  if [ $load_avg_percentage -ge 100 ]; then
    message="High CPU usage: $load_avg_percentage% - $load_avg (1min, 5min, 15min)"
    send_message "$message" "yes"
  fi
fi

# Get the ram usage value and if is greather then limit, send the message and exit
if [ "1" == "$watch_ram" ]; then
  ram_usage=$(free | awk '/Mem/{printf("RAM Usage: %.0f\n"), $3/$2*100}'| awk '{print $3}')
  if [ "$ram_usage" -gt $memory_perc_limit ]; then
    message="High RAM usage: $ram_usage%"
    send_message "$message" "yes"
  fi
fi

# Check the systemctl services and if one or more are failed, send an alert and exit
if [ "1" == "$watch_services" ]; then
  services=$(sudo systemctl --failed | awk '{if (NR!=1) {print}}' | head -2)
  if [[ $services != *"0 loaded"* ]]; then
    message="Systemctl failed services: $services"
    send_message "$message" "no"
  fi
fi

# Check the free disk space
if [ "1" == "$watch_hard_disk" ]; then
  disk_perc_used=$(df / --output=pcent | tr -cd 0-9)
  if [ "$disk_perc_used" -gt $disk_space_perc_limit ]; then
    message="Hard disk full (space used $disk_perc_used%)"
    send_message "$message" "no"
  fi
fi

# Check apache2
if [ "1" == "$watch_apache2" ]; then
  if [ $(curl -s -k -o /dev/null -I -w "%{http_code}" $url) != 200 ]; then
    message="Error Apache not responding"
    send_message "$message"
  fi
fi

# Check postgresql
if [ "1" == "$watch_postgresql" ]; then
  arr=("If the server refuses connections (for example, during startup)" "If there was no response to the connection attempt" "If no attempt was made (eg due to invalid parameters)")
  pg_isready -d $pg_database -h $pg_host -p $pg_port -U $pg_user || send_message "Error in Postgresql: ${arr[$?]}"
fi

if [ "1" == "$send_sysinfo" ]; then
  if [[ (`date +"%a%H"` == mar11 || `date +"%a%H"` == tue11) && $send == false ]]
  then
    send_info
    send=true
  fi

  if [[ !(`date +"%a"` == mar || `date +"%a"` == tue) && $send == true ]]
  then
    send=false
  fi
fi

echo "it's all right."
sleep $(($send_alert_every_minutes*60))
done
