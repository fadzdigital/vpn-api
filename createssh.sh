#!/bin/bash
# ─────────────────※ ·❆· ※─────────────────
# 𓈃 System Request ➠ Debian 9+/Ubuntu 18.04+/20+
# 𓈃 Develovers ➠ MikkuChan
# 𓈃 Email      ➠ fadztechs2@gmail.com
# 𓈃 telegram   ➠ https://t.me/fadzdigital
# 𓈃 whatsapp   ➠ wa.me/+6285727035336
# ─────────────────※ ·❆· ※─────────────────

# ==================== KONFIGURASI HTTP ====================
# Jika dipanggil via web server (http), set output sebagai JSON
if [[ "$REQUEST_METHOD" == "GET" ]]; then
  # Ambil parameter dari query string
  Login=$(echo "$QUERY_STRING" | grep -oE '(^|&)user=[^&]*' | cut -d= -f2)
  Pass=$(echo "$QUERY_STRING" | grep -oE '(^|&)pass=[^&]*' | cut -d= -f2)
  masaaktif=$(echo "$QUERY_STRING" | grep -oE '(^|&)exp=[^&]*' | cut -d= -f2)
  Quota=$(echo "$QUERY_STRING" | grep -oE '(^|&)quota=[^&]*' | cut -d= -f2)
  iplimit=$(echo "$QUERY_STRING" | grep -oE '(^|&)iplimit=[^&]*' | cut -d= -f2)
  auth=$(echo "$QUERY_STRING" | grep -oE '(^|&)auth=[^&]*' | cut -d= -f2)
  
  # Validasi auth key
  valid_auth="fadznewbie_do"
  if [[ "$auth" != "$valid_auth" ]]; then
    echo -e "Content-Type: application/json\r\n"
    echo '{"status": "error", "message": "Invalid authentication key"}'
    exit 1
  fi
  
  # Validasi parameter wajib
  if [[ -z "$Login" || -z "$Pass" || -z "$masaaktif" || -z "$Quota" || -z "$iplimit" ]]; then
    echo -e "Content-Type: application/json\r\n"
    echo '{"status": "error", "message": "Missing required parameters"}'
    exit 1
  fi
  
  # Set flag non-interactive
  non_interactive=true
fi

RED='\033[0;31m'
NC='\033[0m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHT='\033[0;37m'
BGWHITE='\e[0;100;37m'

# Getting
CHATID=$(cat /etc/telegram_bot/chat_id)
KEY=$(cat /etc/telegram_bot/bot_token)
export TIME="10"
export URL="https://api.telegram.org/bot$KEY/sendMessage"

# Hanya jalankan validasi jika tidak dalam mode non-interactive
if [[ "$non_interactive" != "true" ]]; then
  clear
  echo -e "\e[32mloading...\e[0m"
  clear
  
  # // Valid Script
  ipsaya=$(curl -sS ipv4.icanhazip.com)
  data_server=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
  date_list=$(date +"%Y-%m-%d" -d "$data_server")
  data_ip="https://raw.githubusercontent.com/MikkuChan/instalasi/main/register"
  checking_sc() {
    useexp=$(wget -qO- $data_ip | grep $ipsaya | awk '{print $3}')
    if [[ $date_list < $useexp ]]; then
      echo -ne
    else
      echo -e "\033[1;93m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
      echo -e "\033[42m          404 NOT FOUND AUTOSCRIPT          \033[0m"
      echo -e "\033[1;93m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
      echo -e ""
      echo -e "            ${RED}PERMISSION DENIED !${NC}"
      echo -e "   \033[0;33mYour VPS${NC} $ipsaya \033[0;33mHas been Banned${NC}"
      echo -e "     \033[0;33mBuy access permissions for scripts${NC}"
      echo -e "\033[1;93m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
      exit 0
    fi
  }
  checking_sc
  clear
fi

export TIME="10"
IP=$(curl -sS ipv4.icanhazip.com)
ISP=$(cat /etc/xray/isp)
CITY=$(cat /etc/xray/city)
domain=$(cat /etc/xray/domain)

# Jika dalam mode non-interactive, langsung buat akun tanpa prompt
if [[ "$non_interactive" == "true" ]]; then
  # Validasi username tidak boleh kosong
  if [[ -z "$Login" ]]; then
    echo -e "Content-Type: application/json\r\n"
    echo '{"status": "error", "message": "Username cannot be empty"}'
    exit 1
  fi
  
  # Validasi karakter username (hanya alphanumeric, dash, underscore)
  if [[ ! "$Login" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo -e "Content-Type: application/json\r\n"
    echo '{"status": "error", "message": "Username hanya boleh menggunakan huruf, angka, - dan _"}'
    exit 1
  fi

  # Cek duplikasi username
  if grep -q "^#ssh# $Login " /etc/ssh/.ssh.db; then
    echo -e "Content-Type: application/json\r\n"
    echo '{"status": "error", "message": "Username already exists"}'
    exit 1
  fi
  
  # Validasi masa aktif
  if ! [[ "$masaaktif" =~ ^[0-9]+$ ]] || [[ "$masaaktif" -le 0 ]]; then
    echo -e "Content-Type: application/json\r\n"
    echo '{"status": "error", "message": "Masa aktif harus angka positif"}'
    exit 1
  fi
  
  # Validasi quota
  if ! [[ "$Quota" =~ ^[0-9]+$ ]]; then
    echo -e "Content-Type: application/json\r\n"
    echo '{"status": "error", "message": "Quota harus angka"}'
    exit 1
  fi
  
  # Validasi iplimit
  if ! [[ "$iplimit" =~ ^[0-9]+$ ]]; then
    echo -e "Content-Type: application/json\r\n"
    echo '{"status": "error", "message": "IP limit harus angka"}'
    exit 1
  fi
  
  # Hitung tanggal kadaluarsa
  tgl=$(date -d "$masaaktif days" +"%d")
  bln=$(date -d "$masaaktif days" +"%b")
  thn=$(date -d "$masaaktif days" +"%Y")
  expe="$tgl $bln, $thn"
  tgl2=$(date +"%d")
  bln2=$(date +"%b")
  thn2=$(date +"%Y")
  tnggl="$tgl2 $bln2, $thn2"
  expi=$(date -d "$masaaktif days" +"%Y-%m-%d")
else
  # Mode interaktif
  echo -e " ${NC} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e " ${NC} ${BGWHITE}     Create SSH OPENVPN Account    ${NC}"
  echo -e " ${NC} ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  read -p "  Username : " Login
  read -p "  Password : " Pass
  read -p "  Limit IP SSH   : " iplimit
  read -p "  Limit Quota    : " Quota
  read -p "  Expired (Days) : " masaaktif

  # Hitung tanggal kadaluarsa
  tgl=$(date -d "$masaaktif days" +"%d")
  bln=$(date -d "$masaaktif days" +"%b")
  thn=$(date -d "$masaaktif days" +"%Y")
  expe="$tgl $bln, $thn"
  tgl2=$(date +"%d")
  bln2=$(date +"%b")
  thn2=$(date +"%Y")
  tnggl="$tgl2 $bln2, $thn2"
  expi=$(date -d "$masaaktif days" +"%Y-%m-%d")
fi

# limitip
if [[ $iplimit -gt 0 ]]; then
  mkdir -p /etc/kyt/limit/ssh/ip
  echo -e "$iplimit" > /etc/kyt/limit/ssh/ip/$Login
else
  echo > /dev/null
fi

useradd -e `date -d "$masaaktif days" +"%Y-%m-%d"` -s /bin/false -M $Login
echo -e "$Pass\n$Pass\n"|passwd $Login &> /dev/null

if [ ! -e /etc/ssh ]; then
  mkdir -p /etc/ssh
fi

if [ -z ${Quota} ]; then
  Quota="0"
fi

c=$(echo "${Quota}" | sed 's/[^0-9]*//g')
d=$((${c} * 1024 * 1024 * 1024))

if [[ ${c} != "0" ]]; then
  echo "${d}" >/etc/ssh/${Login}
fi

DATADB=$(cat /etc/ssh/.ssh.db | grep "^#ssh#" | grep -w "${Login}" | awk '{print $2}')
if [[ "${DATADB}" != '' ]]; then
  sed -i "/\b${Login}\b/d" /etc/ssh/.ssh.db
fi
echo "#ssh# ${Login} ${Pass} ${Quota} ${iplimit} ${expe}" >>/etc/ssh/.ssh.db

cat > /var/www/html/ssh-$Login.txt <<-END
                     # SSH LOGIN DETAILED #
####### USER DETAIL #######
Username   : $Login

 Password   : $Pass

Login :   $domain:80@$Login:$Pass

Quota      : ${Quota} GB

Status     : Aktif $masaaktif hari

Dibuat     : $tnggl

Expired    : $expe

####### SERVER INFO#######
Domain     : $domain

IP         : $IP

Location   : $CITY

ISP        : $ISP

####### CONNECTION #######
Port OpenSSH     : 443, 80, 22

Port Dropbear    : 443, 109

Port SSH WS      : 80,8080,8081-9999

Port SSH SSL WS  : 443

Port SSH UDP     : 1-65535

Port SSL/TLS     : 400-900

Port OVPN WS SSL : 443

Port OVPN TCP    : 1194

Port OVPN UDP    : 2200

BadVPN UDP       : 7100,7300,7300

####### PAYLOAD WS#######
GET / HTTP/1.1[crlf]Host: [host][crlf]Connection: Upgrade[crlf]User-Agent: [ua][crlf]Upgrade: websocket[crlf][crlf]

####### PAYLOAD WSS #######
GET wss://BUG.COM/ HTTP/1.1[crlf]Host: $domain[crlf]Upgrade: websocket[crlf][crlf]

####### OVPN DOWNLOAD #######
https://$domain:81/

####### SAVE ACCOUNT #######
https://$domain:81/ssh-$Login.txt

####### ARIGATOU #######
END

TEXT="<b>━━━━━ 𝙎𝙎𝙃/𝙊𝙑𝙋𝙉 𝙋𝙍𝙀𝙈𝙄𝙐𝙈 ━━━━━</b>

<b>👤 𝙐𝙨𝙚𝙧 𝘿𝙚𝙩𝙖𝙞𝙡𝙨</b>
┣ <b>Username</b>   : <code>$Login</code>
┣ <b>Password</b>   : <code>$Pass</code>
┣ <b>Login</b>  : <code>$domain:80@$Login:$Pass</code>
┣ <b>Quota</b>      : <code>${Quota} GB</code>
┣ <b>Status</b>     : <code>Aktif $masaaktif hari</code>
┣ <b>Dibuat</b>     : <code>$tnggl</code>
┗ <b>Expired</b>    : <code>$expe</code>

<b>🌎 𝙎𝙚𝙧𝙫𝙚𝙧 𝙄𝙣𝙛𝙤</b>
┣ <b>Domain</b>     : <code>$domain</code>
┣ <b>IP</b>         : <code>$IP</code>
┣ <b>Location</b>   : <code>$CITY</code>
┗ <b>ISP</b>        : <code>$ISP</code>

<b>🔌 𝘾𝙤𝙣𝙣𝙚𝙘𝙩𝙞𝙤𝙣</b>
┣ <b>Port OpenSSH</b>     : <code>443, 80, 22</code>
┣ <b>Port Dropbear</b>    : <code>443, 109</code>
┣ <b>Port SSH WS</b>      : <code>80,8080,8081-9999</code>
┣ <b>Port SSH SSL WS</b>  : <code>443</code>
┣ <b>Port SSH UDP</b>     : <code>1-65365</code>
┣ <b>Port SSL/TLS</b>     : <code>400-900</code>
┣ <b>Port OVPN WS SSL</b> : <code>443</code>
┣ <b>Port OVPN TCP</b>    : <code>1194</code>
┣ <b>Port OVPN UDP</b>    : <code>2200</code>
┗ <b>BadVPN UDP</b>       : <code>7100,7300,7300</code>

<b>⚡ �𝙖𝙮𝙡𝙤𝙖𝙙 𝙒𝙎</b>
<code>GET / HTTP/1.1[crlf]Host: [host][crlf]Connection: Upgrade[crlf]User-Agent: [ua][crlf]Upgrade: websocket[crlf][crlf]</code>

<b>⚡ 𝙋𝙖𝙮𝙡𝙤𝙖𝙙 𝙒𝙎𝙎</b>
<code>GET wss://BUG.COM/ HTTP/1.1[crlf]Host: $domain[crlf]Upgrade: websocket[crlf][crlf]</code>

<b>📥 𝙊𝙑𝙋𝙉 𝘿𝙤𝙬𝙣𝙡𝙤𝙖𝙙</b>
✎ https://$domain:81/

<b>📝 𝙎𝙖𝙫𝙚 𝙇𝙞𝙣𝙠 𝘼𝙠𝙪𝙣</b>
✎ https://$domain:81/ssh-$Login.txt

<b>━━━━━━━━━ 𝙏𝙝𝙖𝙣𝙠 𝙔𝙤𝙪 ━━━━━━━━</b>
"

# Kirim notifikasi ke Telegram baik untuk mode interaktif maupun non-interaktif
curl -s --max-time $TIME -d "chat_id=$CHATID&disable_web_page_preview=1&text=$TEXT&parse_mode=html" $URL >/dev/null

# Jika dalam mode non-interactive, kirim response JSON
if [[ "$non_interactive" == "true" ]]; then
  echo -e "Content-Type: application/json\r\n"
  echo "{
    \"status\": \"success\",
    \"username\": \"$Login\",
    \"password\": \"$Pass\",
    \"expired\": \"$expi\",
    \"quota_gb\": \"$Quota\",
    \"ip_limit\": \"$iplimit\",
    \"created\": \"$tnggl\",
    \"domain\": \"$domain\",
    \"login_url\": \"$domain:80@$Login:$Pass\",
    \"account_file\": \"https://$domain:81/ssh-$Login.txt\",
    \"telegram_sent\": true
  }"
  exit 0
fi

# Jika mode interaktif, tampilkan output seperti biasa
clear
echo ""
echo -e "${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a /etc/user-create/user.log
echo -e "CREATE SSH OPENVPN SUCCESS" | tee -a /etc/user-create/user.log
echo -e "${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a /etc/user-create/user.log
echo -e "Username         : $Login" | tee -a /etc/user-create/user.log
echo -e "Password         : $Pass"  | tee -a /etc/user-create/user.log
echo -e "${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a /etc/user-create/user.log
echo -e "Location         : $CITY"| tee -a /etc/user-create/user.log
echo -e "ISP Server       : $ISP" | tee -a /etc/user-create/user.log
echo -e "IP Server        : $IP" | tee -a /etc/user-create/user.log
echo -e "Host Server      : $domain" | tee -a /etc/user-create/user.log
echo -e "${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a /etc/user-create/user.log
echo -e "Limit Quota      : $Quota GB" | tee -a /etc/user-create/user.log
echo -e "Limit Ip         : ${iplimit} User" | tee -a /etc/user-create/user.log
echo -e "Port OpenSSH     : 443, 80, 22" | tee -a /etc/user-create/user.log
echo -e "Port SSH UDP     : 1-65535" | tee -a /etc/user-create/user.log
echo -e "Port Dropbear    : 443, 109" | tee -a /etc/user-create/user.log
echo -e "Port SSH WS      : 80, 8080, 8880, 2082" | tee -a /etc/user-create/user.log
echo -e "Port SSH SSL WS  : 443" | tee -a /etc/user-create/user.log
echo -e "Port SSL/TLS     : 400-900" | tee -a /etc/user-create/user.log
echo -e "BadVPN UDP       : 7100, 7300, 7300" | tee -a /etc/user-create/user.log
echo -e "${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a /etc/user-create/user.log
echo -e "Payload WS       : GET / HTTP/1.1[crlf]Host: [host][crlf]Connection: Upgrade[crlf]User-Agent: [ua][crlf]Upgrade: websocket[crlf][crlf]" | tee -a /etc/user-create/user.log
echo -e "${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a /etc/user-create/user.log
echo -e "Payload WSS      : GET wss://BUG.COM/ HTTP/1.1[crlf]Host: $domain[crlf]Upgrade: websocket[crlf][crlf]" | tee -a /etc/user-create/user.log
echo -e "${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a /etc/user-create/user.log
echo -e "Aktif Selama     : $masaaktif Hari" | tee -a /etc/user-create/user.log
echo -e "Dibuat Pada      : $tnggl" | tee -a /etc/user-create/user.log
echo -e "Expired On       : $expe" | tee -a /etc/user-create/user.log
echo -e "${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a /etc/user-create/user.log
echo -e "" | tee -a /etc/user-create/user.log
read -p "Press Any Key To Back On Menu"
m-sshws
