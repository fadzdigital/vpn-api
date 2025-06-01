#!/bin/bash
#  ·· 
#  System Request  Debian 9+/Ubuntu 18.04+/20+
#  Develovers  MikkuChan
#  Email       fadztechs2@gmail.com
#  telegram    https://t.me/fadzdigital
#  whatsapp    wa.me/+6285727035336
#  ·· 

# ==================== KONFIGURASI HTTP ====================
# Jika dipanggil via web server (http), set output sebagai JSON
if [[ "$REQUEST_METHOD" == "GET" ]]; then
  # Ambil parameter dari query string
  user=$(echo "$QUERY_STRING" | grep -oE '(^|&)user=[^&]*' | cut -d= -f2)
  uuid_arg=$(echo "$QUERY_STRING" | grep -oE '(^|&)uuid=[^&]*' | cut -d= -f2)
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
  if [[ -z "$user" || -z "$masaaktif" || -z "$Quota" || -z "$iplimit" ]]; then
    echo -e "Content-Type: application/json\r\n"
    echo '{"status": "error", "message": "Missing required parameters"}'
    exit 1
  fi
  
  # Generate UUID jika auto atau kosong
  if [[ "$uuid_arg" == "auto" || -z "$uuid_arg" ]]; then
    uuid=$(cat /proc/sys/kernel/random/uuid)
  else
    # Validasi format UUID
    if [[ ${#uuid_arg} -ne 36 || ! "$uuid_arg" =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
      echo -e "Content-Type: application/json\r\n"
      echo '{"status": "error", "message": "Invalid UUID format"}'
      exit 1
    fi
    uuid="$uuid_arg"
  fi
  
  # Set flag non-interactive
  non_interactive=true
fi

# ==================== KONFIGURASI AWAL ====================
RRED="\033[31m"
YELLOW="\033[33m"
NC='\e[0m'
YELL='\033[0;33m'
BRED='\033[1;31m'
GREEN='\033[0;32m'
ORANGE='\033[33m'
BGWHITE='\e[0;100;37m'

# Warna ANSI untuk tampilan terminal
RED='\033[1;91m'
GREEN='\033[1;92m'
YELLOW='\033[1;93m'
BLUE='\033[1;94m'
CYAN='\033[1;96m'
WHITE='\033[1;97m'
NC='\033[0m' # Reset warna

# ==================== VALIDASI SCRIPT ====================
# Hanya jalankan validasi jika tidak dalam mode non-interactive
if [[ "$non_interactive" != "true" ]]; then
  clear
  echo -e "\e[32mloading...\e[0m"
  clear
  
  # Validasi permission VPS
  echo -e "${CYAN}${NC}"
  echo -e " ${WHITE}MEMERIKSA PERMISSION VPS...${NC}"
  echo -e "${CYAN}${NC}"
  echo -e " ${GREEN}Mengambil IP VPS${NC}"
  ipsaya=$(curl -sS ipv4.icanhazip.com)
  echo -e " ${GREEN}Mengambil Data Server${NC}"
  data_server=$(curl -v --insecure --silent https://google.com/ 2>&1 | grep Date | sed -e 's/< Date: //')
  date_list=$(date +"%Y-%m-%d" -d "$data_server")
  data_ip="https://raw.githubusercontent.com/MikkuChan/instalasi/main/register"

  checking_sc() {
    useexp=$(wget -qO- $data_ip | grep $ipsaya | awk '{print $3}')
    if [[ $date_list < $useexp ]]; then
      echo -ne
    else
      clear
      echo -e "${RED}${NC}"
      echo -e " ${WHITE}PERMISSION DENIED!${NC}"
      echo -e "${RED}${NC}"
      echo -e " VPS Anda: $ipsaya"
      echo -e " Status: ${RED}Diblokir${NC}"
      echo -e ""
      echo -e " Hubungi admin untuk membeli akses."
      echo -e "${RED}${NC}"
      exit 0
    fi
  }
  checking_sc
  clear
fi

# ==================== KONFIGURASI DOMAIN ====================
source /var/lib/kyt/ipvps.conf
if [[ "$IP" = "" ]]; then
  domain=$(cat /etc/xray/domain)
else
  domain=$IP
fi

# ==================== PROSES PEMBUATAN AKUN ====================
# Jika dalam mode non-interactive, langsung buat akun tanpa prompt
if [[ "$non_interactive" == "true" ]]; then
  # Validasi username tidak boleh kosong
  if [[ -z "$user" ]]; then
    echo -e "Content-Type: application/json\r\n"
    echo '{"status": "error", "message": "Username cannot be empty"}'
    exit 1
  fi
  
  # Validasi karakter username (hanya alphanumeric, dash, underscore)
  if [[ ! "$user" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo -e "Content-Type: application/json\r\n"
    echo '{"status": "error", "message": "Username hanya boleh menggunakan huruf, angka, - dan _"}'
    exit 1
  fi

  # Cek duplikasi username
  user_exists_config=false
  if grep -q "\"email\"[[:space:]]*:[[:space:]]*\"$user\"" /etc/xray/config.json; then
    user_exists_config=true
  fi

  user_exists_db=false
  if [[ -f "/etc/vmess/.vmess.db" ]]; then
    if grep -q "^### $user " /etc/vmess/.vmess.db; then
      user_exists_db=true
    fi
  fi

  if [[ "$user_exists_config" == "true" ]] || [[ "$user_exists_db" == "true" ]]; then
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
  exp=$(date -d "$masaaktif days" +"%Y-%m-%d")
  
  # Proses pembuatan akun VMESS
  sed -i '/#vmess$/a\### '"$user $exp"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json
  sed -i '/#vmessgrpc$/a\### '"$user $exp"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json

  # Buat konfigurasi VMESS
  asu=`cat<<EOF
      {
      "v": "2",
      "ps": "${user}",
      "add": "${domain}",
      "port": "443",
      "id": "${uuid}",
      "aid": "0",
      "net": "ws",
      "path": "/vmess",
      "type": "none",
      "host": "${domain}",
      "tls": "tls"
}
EOF`
  ask=`cat<<EOF
      {
      "v": "2",
      "ps": "${user}",
      "add": "${domain}",
      "port": "80",
      "id": "${uuid}",
      "aid": "0",
      "net": "ws",
      "path": "/vmess",
      "type": "none",
      "host": "${domain}",
      "tls": "none"
}
EOF`
  grpc=`cat<<EOF
      {
      "v": "2",
      "ps": "${user}",
      "add": "${domain}",
      "port": "443",
      "id": "${uuid}",
      "aid": "0",
      "net": "grpc",
      "path": "vmess-grpc",
      "type": "none",
      "host": "${domain}",
      "tls": "tls"
}
EOF`
  
  vmesslink1="vmess://$(echo $asu | base64 -w 0)"
  vmesslink2="vmess://$(echo $ask | base64 -w 0)"
  vmesslink3="vmess://$(echo $grpc | base64 -w 0)"
  
  # Restart layanan
  systemctl restart xray > /dev/null 2>&1
  service cron restart > /dev/null 2>&1

  # Buat file konfigurasi
  cat >/var/www/html/vmess-$user.txt <<-END
           # FORMAT OpenClash #

# Format Vmess WS TLS
- name: Vmess-$user-WS TLS
  type: vmess
  server: ${domain}
  port: 443
  uuid: ${uuid}
  alterId: 0
  cipher: auto
  udp: true
  tls: true
  skip-cert-verify: true
  servername: ${domain}
  network: ws
  ws-opts:
    path: /vmess
    headers:
      Host: ${domain}

# Format Vmess WS Non TLS
- name: Vmess-$user-WS Non TLS
  type: vmess
  server: ${domain}
  port: 80
  uuid: ${uuid}
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  skip-cert-verify: false
  servername: ${domain}
  network: ws
  ws-opts:
    path: /vmess
    headers:
      Host: ${domain}

# Format Vmess gRPC
- name: Vmess-$user-gRPC (SNI)
  server: ${domain}
  port: 443
  type: vmess
  uuid: ${uuid}
  alterId: 0
  cipher: auto
  network: grpc
  tls: true
  servername: ${domain}
  skip-cert-verify: true
  grpc-opts:
    grpc-service-name: vmess-grpc

              #  VMESS WS TLS #
${vmesslink1}

         # VMESS WS NON TLS #
${vmesslink2}

           # VMESS WS gRPC #
${vmesslink3}
END

  # Set limit IP jika diperlukan
  if [[ $iplimit -gt 0 ]]; then
    mkdir -p /etc/kyt/limit/vmess/ip
    echo -e "$iplimit" > /etc/kyt/limit/vmess/ip/$user
  fi

  # Set quota jika diperlukan
  if [ -z ${Quota} ]; then
    Quota="0"
  fi

  c=$(echo "${Quota}" | sed 's/[^0-9]*//g')
  d=$((${c} * 1024 * 1024 * 1024))

  if [[ ${c} != "0" ]]; then
    echo "${d}" >/etc/vmess/${user}
  fi

  # Update database
  DATADB=$(cat /etc/vmess/.vmess.db | grep "^###" | grep -w "${user}" | awk '{print $2}')
  if [[ "${DATADB}" != '' ]]; then
    sed -i "/\b${user}\b/d" /etc/vmess/.vmess.db
  fi
  echo "### ${user} ${exp} ${uuid} ${Quota} ${iplimit}" >>/etc/vmess/.vmess.db

  # Kirim notifikasi Telegram (jika ada konfigurasi)
  if [ -f "/etc/telegram_bot/bot_token" ] && [ -f "/etc/telegram_bot/chat_id" ]; then
    BOT_TOKEN=$(cat /etc/telegram_bot/bot_token)
    CHAT_ID=$(cat /etc/telegram_bot/chat_id)
    
    location=$(curl -s ipinfo.io/json)
    CITY=$(echo "$location" | jq -r '.city')
    ISP=$(echo "$location" | jq -r '.org')
    MYIP=$(curl -s ifconfig.me)
    
    CITY=${CITY:-"Unknown"}
    ISP=${ISP:-"Unknown"}
    
    TEXT="<b>━━━━━━ 𝙑𝙈𝙀𝙎𝙎 𝙋𝙍𝙀𝙈𝙄𝙐𝙈 ━━━━━</b>

<b>👤 𝙐𝙨𝙚𝙧 𝘿𝙚𝙩𝙖𝙞𝙡𝙨</b>
┣ <b>Username</b>   : <code>$user</code>
┣ <b>UUID</b>       : <code>$uuid</code>
┣ <b>Quota</b>      : <code>${Quota} GB</code>
┣ <b>Status</b>     : <code>Aktif $masaaktif hari</code>
┣ <b>Dibuat</b>     : <code>$tnggl</code>
┗ <b>Expired</b>    : <code>$expe</code>

<b>🌎 𝙎𝙚𝙧𝙫𝙚𝙧 𝙄𝙣𝙛𝙤</b>
┣ <b>Domain</b>     : <code>$domain</code>
┣ <b>IP</b>         : <code>$MYIP</code>
┣ <b>Location</b>   : <code>$CITY</code>
┗ <b>ISP</b>        : <code>$ISP</code>

<b>🔗 𝘾𝙤𝙣𝙣𝙚𝙘𝙩𝙞𝙤𝙣</b>
┣ <b>TLS Port</b>        : <code>400-900</code>
┣ <b>Non-TLS Port</b>    : <code>80, 8080, 8081-9999</code>
┣ <b>Network</b>         : <code>ws, grpc</code>
┣ <b>Path</b>            : <code>/vmess</code>
┣ <b>gRPC Service</b>    : <code>vmess-grpc</code>
┣ <b>Security</b>        : <code>auto</code>
┗ <b>alterId</b>         : <code>0</code>

<b>━━━━━ 𝙑𝙈𝙀𝙎𝙎 𝙋𝙧𝙚𝙢𝙞𝙪𝙢 𝙇𝙞𝙣𝙠𝙨 ━━━━━</b>
<b>📍 𝙒𝙎 𝙏𝙇𝙎</b>
<pre>$vmesslink1</pre>
<b>📍 𝙒𝙎 𝙉𝙤𝙣-𝙏𝙇𝙎</b>
<pre>$vmesslink2</pre>
<b>📍 𝙜𝙍𝙋𝘾</b>
<pre>$vmesslink3</pre>

<b>📥 𝘾𝙤𝙣𝙛𝙞𝙜 𝙁𝙞𝙡𝙚 (Clash/OpenClash):</b>
➤ https://${domain}:81/vmess-$user.txt

<b>✨ 𝙏𝙤𝙤𝙡𝙨 & 𝙍𝙚𝙨𝙤𝙪𝙧𝙘𝙚𝙨</b>
┣  https://vpntech.my.id/converteryaml
┗  https://vpntech.my.id/auto-configuration

<b>❓ 𝘽𝙪𝙩𝙪𝙝 𝘽𝙖𝙣𝙩𝙪𝙖𝙣?</b>
➤ https://wa.me/6285727035336

<b>━━━━━━━━━ 𝙏𝙝𝙖𝙣𝙠 𝙔𝙤𝙪 ━━━━━━━━</b>
"
    TEXT_ENCODED=$(echo "$TEXT" | jq -sRr @uri)
    curl -s -d "chat_id=$CHAT_ID&disable_web_page_preview=1&text=$TEXT_ENCODED&parse_mode=html" "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" > /dev/null 2>&1
  fi

  # Output JSON untuk response HTTP
  echo -e "Content-Type: application/json\r\n"
  echo "{
    \"status\": \"success\",
    \"username\": \"$user\",
    \"uuid\": \"$uuid\",
    \"domain\": \"$domain\",
    \"expired\": \"$exp\",
    \"quota_gb\": \"$Quota\",
    \"ip_limit\": \"$iplimit\",
    \"created\": \"$tnggl\",
    \"ws_tls\": \"$vmesslink1\",
    \"ws_ntls\": \"$vmesslink2\",
    \"grpc\": \"$vmesslink3\"
  }"
  exit 0
fi

# ==================== MODE INTERAKTIF (ORIGINAL SCRIPT) ====================
# Jika tidak dipanggil via HTTP, jalankan mode interaktif seperti biasa
# (Kode original script Anda di sini, mulai dari bagian " START: Buat Akun VMESS " sampai akhir)

#  START: Buat Akun VMESS 
# Proses membuat akun VMESS dengan konfigurasi otomatis
clear
echo -e "${CYAN}${NC}"
echo -e " ${WHITE}MEMBUAT AKUN VMESS${NC}"
echo -e "${CYAN}${NC}"

#  START: Validasi Username 
# Mengecek agar username tidak duplikat di config Xray dan database
# Jika sudah ada, minta input ulang sampai dapat username yg blm terdaftar
# 
while true; do
    echo -ne "${WHITE} Masukkan Username:${NC} "
    read -e user
    
    # Validasi input tidak boleh kosong
    if [[ -z "$user" ]]; then
        echo -e "${RED}${NC}"
        echo -e "  ${WHITE}Username tidak boleh kosong!${NC}"
        echo -e "${RED}${NC}"
        continue
    fi
    
    # Validasi karakter username (hanya alphanumeric, dash, underscore)
    if [[ ! "$user" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo -e "${RED}${NC}"
        echo -e "  ${WHITE}Username hanya boleh menggunakan huruf, angka, - dan _${NC}"
        echo -e "${RED}${NC}"
        continue
    fi

    # Cek apakah file konfigurasi Xray ada
    if [[ ! -f "/etc/xray/config.json" ]]; then
        echo -e "${RED}${NC}"
        echo -e " ${WHITE}File konfigurasi Xray tidak ditemukan!${NC}"
        echo -e "${RED}${NC}"
        exit 1
    fi

    # Cek duplikasi di file konfigurasi Xray (multiple pattern check)
    user_exists_config=false
    
    # Pattern 1: Cek dengan format "email": "username"
    if grep -q "\"email\"[[:space:]]*:[[:space:]]*\"$user\"" /etc/xray/config.json; then
        user_exists_config=true
    fi
    
    # Pattern 2: Cek dengan format alternatif
    if grep -q "\"email\":[[:space:]]*\"$user\"" /etc/xray/config.json; then
        user_exists_config=true
    fi
    
    # Pattern 3: Cek dengan format tanpa spasi
    if grep -q "\"email\":\"$user\"" /etc/xray/config.json; then
        user_exists_config=true
    fi

    # Cek duplikasi di database VMESS (jika file database ada)
    user_exists_db=false
    if [[ -f "/etc/vmess/.vmess.db" ]]; then
        if grep -q "^### $user " /etc/vmess/.vmess.db; then
            user_exists_db=true
        fi
    fi

    # Jika username sudah ada di salah satu tempat
    if [[ "$user_exists_config" == "true" ]] || [[ "$user_exists_db" == "true" ]]; then
        echo -e "${RED}${NC}"
        echo -e "  ${WHITE}Username '${YELLOW}$user${WHITE}' sudah terdaftar!${NC}"
        
        # Tampilkan lokasi duplikasi untuk debugging
        if [[ "$user_exists_config" == "true" ]]; then
            echo -e " ${WHITE}Ditemukan di: ${RED}Konfigurasi Xray${NC}"
        fi
        if [[ "$user_exists_db" == "true" ]]; then
            echo -e " ${WHITE}Ditemukan di: ${RED}Database VMESS${NC}"
        fi
        
        echo -e "${RED}${NC}"
        echo -e " ${WHITE}Silahkan coba username lain Onii-Chan${NC}"
        echo
    else
        echo -e "${GREEN} Username '$user' tersedia! Lanjut...${NC}"
        break
    fi
done
#  END: Validasi Username 

#  START: Pilih Jenis UUID 
# Menentukan jenis UUID yang akan digunakan untuk akun
# User dapat memilih UUID acak (generate otomatis) atau UUID custom (input manual)
# UUID digunakan sebagai identitas unik akun VPN di Xray
# 
echo -e "${CYAN}${NC}"
echo -e " ${WHITE}KONFIGURASI UUID${NC}"
echo -e "${CYAN}${NC}"
echo -e " ${YELLOW}Pilihan UUID${NC}"
echo -e ""
echo -e " 1 ${GREEN}Random UUID${NC} ${WHITE}(Otomatis)${NC}"
echo -e " 2 ${BLUE}Custom UUID${NC} ${WHITE}(Manual)${NC}"
echo -e ""
echo -e " ${WHITE}Pilihan Anda:${NC}"
echo -e ""

while true; do
    echo -ne "${WHITE} Masukkan pilihan [1/2]:${NC}  "
    read uuid_type
    case $uuid_type in
        1)
            uuid=$(cat /proc/sys/kernel/random/uuid)
            echo -e " ${GREEN}UUID Random: ${WHITE}$uuid${NC}"
            break
            ;;
        2)
            while true; do
                echo -ne "${WHITE} Masukkan UUID Custom:${NC}  "
                read uuid                
                if [[ ${#uuid} -eq 36 && $uuid =~ ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$ ]]; then
                    echo -e " ${GREEN}UUID Valid: ${WHITE}$uuid${NC}"
                    break 2
                else
                    echo -e " ${RED}Format UUID tidak valid! Contoh: 12345678-1234-1234-1234-123456789abc${NC}"
                fi
            done
            ;;
        *)
            echo -e " ${RED}Pilihan tidak valid! Silakan pilih 1 atau 2${NC}"
            ;;
    esac
done
#  END: Pilih Jenis UUID 

#  START: Masukkan Durasi Akun 
# Menentukan masa aktif akun dalam hitungan hari
# Durasi ini akan digunakan untuk menghitung tanggal kadaluarsa akun
# Jika input tidak valid (bukan angka), akan diminta ulang
# 
echo -e ""
echo -e "${CYAN}${NC}"
echo -e " ${WHITE}KONFIGURASI MASA AKTIF${NC}"
echo -e "${CYAN}${NC}"
echo -e " ${YELLOW}Durasi Akun${NC}"
echo -e ""
echo -e "  ${WHITE}Contoh: 7, 30, 365${NC}"
echo -e "  ${GREEN}Rekomendasi: 30 hari${NC}"
echo -e ""
echo -e " ${WHITE}Masa aktif akun:${NC}"
echo -e ""

while true; do
    echo -ne "${WHITE} Expired (hari):${NC}  "
read masaaktif
    if [[ $masaaktif =~ ^[0-9]+$ && $masaaktif -gt 0 ]]; then
        exp_date=$(date -d "$masaaktif days" +"%d %b %Y")
        echo -e " ${GREEN}Akun akan expired pada: ${WHITE}$exp_date${NC}"
        break
    else
        echo -e " ${RED}Masukkan angka yang valid (lebih dari 0)${NC}"
    fi
done
#  END: Masukkan Durasi Akun 


#  START: Batas Kuota & IP 
# Menentukan batas pemakaian akun dalam hal kuota (dalam GB) dan jumlah IP (device)
# Kuota digunakan untuk membatasi total data yang bisa dipakai akun
# IP limit digunakan untuk membatasi jumlah perangkat yang bisa menggunakan akun
# Input '0' berarti tidak ada batasan (unlimited)
# Jika input tidak valid (bukan angka), akan diminta ulang
# 
echo -e ""
echo -e "${CYAN}${NC}"
echo -e " ${WHITE}KONFIGURASI BATASAN AKSES${NC}"
echo -e "${CYAN}${NC}"
echo -e " ${YELLOW}Pengaturan Kuota & Limit${NC}"
echo -e ""
echo -e "  ${WHITE}Limit Data: 0 = Unlimited${NC}"
echo -e "  ${WHITE}Limit IP: 0 = Unlimited${NC}"
echo -e "  ${GREEN}Rekomendasi Data: 50-100 GB${NC}"
echo -e "  ${GREEN}Rekomendasi IP: 2-5 Device${NC}"
echo -e ""
echo -e " ${WHITE}Konfigurasi:${NC}"
echo -e ""

#  SES: Limit DATA 
while true; do
    echo -ne "${WHITE} Limit Data (GB) [0=Unlimited]: ${NC}  "
read Quota
    if [[ $Quota =~ ^[0-9]+$ ]]; then
        if [[ $Quota -eq 0 ]]; then
            echo -e " ${GREEN}Data: ${WHITE}Unlimited${NC}"
        else
            echo -e " ${GREEN}Data Limit: ${WHITE}${Quota} GB${NC}"
        fi
        break
    else
        echo -e " ${RED}Masukkan angka yang valid (0 atau lebih)${NC}"
    fi
done

#  SES: Limit IP 
while true; do
    echo -ne "${WHITE} Limit IP [0=Unlimited]:${NC}  "
read iplimit
    if [[ $iplimit =~ ^[0-9]+$ ]]; then
        if [[ $iplimit -eq 0 ]]; then
            echo -e " ${GREEN}IP: ${WHITE}Unlimited${NC}"
        else
            echo -e " ${GREEN}IP Limit: ${WHITE}${iplimit} Device${NC}"
        fi
        break
    else
        echo -e " ${RED}Masukkan angka yang valid (0 atau lebih)${NC}"
    fi
done
#  END: Batas Kuota & IP 

#  START: Hitung Tanggal Kedaluwarsa 
# Menghitung tanggal kedaluwarsa akun berdasarkan durasi aktif (dalam hari)
# Format output biasanya YYYY-MM-DD dan akan digunakan untuk mencatat info akun
# Tanggal ini penting untuk proses auto-deletion atau penonaktifan otomatis
# 
tgl=$(date -d "$masaaktif days" +"%d")
bln=$(date -d "$masaaktif days" +"%b")
thn=$(date -d "$masaaktif days" +"%Y")
expe="$tgl $bln, $thn"
tgl2=$(date +"%d")
bln2=$(date +"%b")
thn2=$(date +"%Y")
tnggl="$tgl2 $bln2, $thn2"
exp=`date -d "$masaaktif days" +"%Y-%m-%d"`
#  END: Hitung Tanggal Kedaluwarsa 


#  START: Simpan ke Konfigurasi Xray 
# Menambahkan detail akun (username, UUID, batas kuota/IP, masa aktif, dll)
# ke dalam file konfigurasi Xray (`config.json`)
# Data ini dibutuhkan Xray agar akun bisa dikenali dan digunakan oleh client
# Pastikan format JSON tetap valid saat menyisipkan entri baru
# Biasanya disisipkan sebelum tanda tutup array ] dari inbounds atau clients
# 
sed -i '/#vmess$/a\### '"$user $exp"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json
exp=`date -d "$masaaktif days" +"%Y-%m-%d"`
sed -i '/#vmessgrpc$/a\### '"$user $exp"'\
},{"id": "'""$uuid""'","alterId": '"0"',"email": "'""$user""'"' /etc/xray/config.json

asu=`cat<<EOF
      {
      "v": "2",
      "ps": "${user}",
      "add": "${domain}",
      "port": "443",
      "id": "${uuid}",
      "aid": "0",
      "net": "ws",
      "path": "/vmess",
      "type": "none",
      "host": "${domain}",
      "tls": "tls"
}
EOF`
ask=`cat<<EOF
      {
      "v": "2",
      "ps": "${user}",
      "add": "${domain}",
      "port": "80",
      "id": "${uuid}",
      "aid": "0",
      "net": "ws",
      "path": "/vmess",
      "type": "none",
      "host": "${domain}",
      "tls": "none"
}
EOF`
grpc=`cat<<EOF
      {
      "v": "2",
      "ps": "${user}",
      "add": "${domain}",
      "port": "443",
      "id": "${uuid}",
      "aid": "0",
      "net": "grpc",
      "path": "vmess-grpc",
      "type": "none",
      "host": "${domain}",
      "tls": "tls"
}
EOF`
vmess_base641=$( base64 -w 0 <<< $vmess_json1)
vmess_base642=$( base64 -w 0 <<< $vmess_json2)
vmess_base643=$( base64 -w 0 <<< $vmess_json3)
vmesslink1="vmess://$(echo $asu | base64 -w 0)"
vmesslink2="vmess://$(echo $ask | base64 -w 0)"
vmesslink3="vmess://$(echo $grpc | base64 -w 0)"
systemctl restart xray > /dev/null 2>&1
service cron restart > /dev/null 2>&1

cat >/var/www/html/vmess-$user.txt <<-END

           # FORMAT OpenClash #

# Format Vmess WS TLS

- name: Vmess-$user-WS TLS
  type: vmess
  server: ${domain}
  port: 443
  uuid: ${uuid}
  alterId: 0
  cipher: auto
  udp: true
  tls: true
  skip-cert-verify: true
  servername: ${domain}
  network: ws
  ws-opts:
    path: /vmess
    headers:
      Host: ${domain}

# Format Vmess WS Non TLS

- name: Vmess-$user-WS Non TLS
  type: vmess
  server: ${domain}
  port: 80
  uuid: ${uuid}
  alterId: 0
  cipher: auto
  udp: true
  tls: false
  skip-cert-verify: false
  servername: ${domain}
  network: ws
  ws-opts:
    path: /vmess
    headers:
      Host: ${domain}

# Format Vmess gRPC

- name: Vmess-$user-gRPC (SNI)
  server: ${domain}
  port: 443
  type: vmess
  uuid: ${uuid}
  alterId: 0
  cipher: auto
  network: grpc
  tls: true
  servername: ${domain}
  skip-cert-verify: true
  grpc-opts:
    grpc-service-name: vmess-grpc

              #  VMESS WS TLS #

${vmesslink1}

         # VMESS WS NON TLS #

${vmesslink2}

           # VMESS WS gRPC #

${vmesslink3}


END
if [ ! -e /etc/vmess ]; then
  mkdir -p /etc/vmess
fi

if [[ $iplimit -gt 0 ]]; then
mkdir -p /etc/kyt/limit/vmess/ip
echo -e "$iplimit" > /etc/kyt/limit/vmess/ip/$user
else
echo > /dev/null
fi

if [ -z ${Quota} ]; then
  Quota="0"
fi

c=$(echo "${Quota}" | sed 's/[^0-9]*//g')
d=$((${c} * 1024 * 1024 * 1024))

if [[ ${c} != "0" ]]; then
  echo "${d}" >/etc/vmess/${user}
fi
DATADB=$(cat /etc/vmess/.vmess.db | grep "^###" | grep -w "${user}" | awk '{print $2}')
if [[ "${DATADB}" != '' ]]; then
  sed -i "/\b${user}\b/d" /etc/vmess/.vmess.db
fi
echo "### ${user} ${exp} ${uuid} ${Quota} ${iplimit}" >>/etc/vmess/.vmess.db
#  END: Simpan ke Konfigurasi Xray 
#  END: Buat Akun VMESS 
clear

# Sesi Baca
BOT_TOKEN=$(cat /etc/telegram_bot/bot_token)
CHAT_ID=$(cat /etc/telegram_bot/chat_id)

# Logging untuk debug
echo "$(date): Checking Telegram credentials" >> /var/log/telegram_debug.log
echo "Bot Token: $BOT_TOKEN" >> /var/log/telegram_debug.log
echo "Chat ID: $CHAT_ID" >> /var/log/telegram_debug.log

# Nilai Info
location=$(curl -s ipinfo.io/json)
CITY=$(echo "$location" | jq -r '.city')
ISP=$(echo "$location" | jq -r '.org')
MYIP=$(curl -s ifconfig.me)

# Logging info location
echo "$(date): Location Info" >> /var/log/telegram_debug.log
echo "City: $CITY" >> /var/log/telegram_debug.log
echo "ISP: $ISP" >> /var/log/telegram_debug.log
echo "IP: $MYIP" >> /var/log/telegram_debug.log

# Pengecekan Variabel
CITY=${CITY:-"Saya Gatau"}
ISP=${ISP:-"Saya Gatau"}

# URL API Telegram
URL="https://api.telegram.org/bot$BOT_TOKEN/sendMessage"

TEXT="<b>━━━━━━ 𝙑𝙈𝙀𝙎𝙎 𝙋𝙍𝙀𝙈𝙄𝙐𝙈 ━━━━━</b>

<b>👤 𝙐𝙨𝙚𝙧 𝘿𝙚𝙩𝙖𝙞𝙡𝙨</b>
┣ <b>Username</b>   : <code>$user</code>
┣ <b>UUID</b>       : <code>$uuid</code>
┣ <b>Quota</b>      : <code>${Quota} GB</code>
┣ <b>Status</b>     : <code>Aktif $masaaktif hari</code>
┣ <b>Dibuat</b>     : <code>$tnggl</code>
┗ <b>Expired</b>    : <code>$expe</code>

<b>🌎 𝙎𝙚𝙧𝙫𝙚𝙧 𝙄𝙣𝙛𝙤</b>
┣ <b>Domain</b>     : <code>$domain</code>
┣ <b>IP</b>         : <code>$MYIP</code>
┣ <b>Location</b>   : <code>$CITY</code>
┗ <b>ISP</b>        : <code>$ISP</code>

<b>🔗 𝘾𝙤𝙣𝙣𝙚𝙘𝙩𝙞𝙤𝙣</b>
┣ <b>TLS Port</b>        : <code>400-900</code>
┣ <b>Non-TLS Port</b>    : <code>80, 8080, 8081-9999</code>
┣ <b>Network</b>         : <code>ws, grpc</code>
┣ <b>Path</b>            : <code>/vmess</code>
┣ <b>gRPC Service</b>    : <code>vmess-grpc</code>
┣ <b>Security</b>        : <code>auto</code>
┗ <b>alterId</b>         : <code>0</code>

<b>━━━━━ 𝙑𝙈𝙀𝙎𝙎 𝙋𝙧𝙚𝙢𝙞𝙪𝙢 𝙇𝙞𝙣𝙠𝙨 ━━━━━</b>
<b>📍 𝙒𝙎 𝙏𝙇𝙎</b>
<pre>$vmesslink1</pre>
<b>📍 𝙒𝙎 𝙉𝙤𝙣-𝙏𝙇𝙎</b>
<pre>$vmesslink2</pre>
<b>📍 𝙜𝙍𝙋𝘾</b>
<pre>$vmesslink3</pre>

<b>📥 𝘾𝙤𝙣𝙛𝙞𝙜 𝙁𝙞𝙡𝙚 (Clash/OpenClash):</b>
➤ https://${domain}:81/vmess-$user.txt

<b>✨ 𝙏𝙤𝙤𝙡𝙨 & 𝙍𝙚𝙨𝙤𝙪𝙧𝙘𝙚𝙨</b>
┣  https://vpntech.my.id/converteryaml
┗  https://vpntech.my.id/auto-configuration

<b>❓ 𝘽𝙪𝙩𝙪𝙝 𝘽𝙖𝙣𝙩𝙪𝙖𝙣?</b>
➤ https://wa.me/6285727035336

<b>━━━━━━━━━ 𝙏𝙝𝙖𝙣𝙠 𝙔𝙤𝙪 ━━━━━━━━</b>
"

# Encode text untuk menghindari masalah karakter
TEXT_ENCODED=$(echo "$TEXT" | jq -sRr @uri)

# Kirim Pesan ke Telegram dengan logging
echo "$(date): Sending Telegram message" >> /var/log/telegram_debug.log
RESPONSE=$(curl -v -d "chat_id=$CHAT_ID&disable_web_page_preview=1&text=$TEXT_ENCODED&parse_mode=html" $URL 2>&1)
echo "Telegram API Response: $RESPONSE" >> /var/log/telegram_debug.log

# Test koneksi ke API Telegram
TEST_RESPONSE=$(curl -s "https://api.telegram.org/bot$BOT_TOKEN/getMe")
echo "Telegram Bot Test Response: $TEST_RESPONSE" >> /var/log/telegram_debug.log

# Restart layanan
systemctl restart xray
systemctl restart nginx
clear
clear
log_file="/etc/user-create/user.log"

# Fungsi untuk menulis ke log dan echo ke terminal dengan format khusus
log_echo() {
  local message="$1"
  echo -e "$message" | tee -a "$log_file"
}

# Fungsi untuk membuat garis pembatas
separator() {
  log_echo "   "
}

separator
log_echo "  "
log_echo " Username   : $user"
log_echo " UUID       : $uuid"
log_echo " Quota      : ${Quota} GB"
log_echo " Status     : Aktif $masaaktif hari"
log_echo " Dibuat     : $tnggl"
log_echo " Expired    : $expe"

log_echo ""
log_echo "  "
log_echo " Domain     : $domain"
log_echo " IP         : $MYIP"
log_echo " Location   : $CITY"
log_echo " ISP        : $ISP"

log_echo ""
log_echo " "
log_echo " TLS Port        : 400-900"
log_echo " Non-TLS Port    : 80, 8080, 8081-9999"
log_echo " Network         : ws, grpc"
log_echo " Path            : /vmess"
log_echo " gRPC Service    : vmess-grpc"
log_echo " Security        : auto"
log_echo " alterId         : 0"

log_echo ""
log_echo "    "
log_echo "  "
log_echo "$vmesslink1"
log_echo ""
log_echo "  -"
log_echo "$vmesslink2"
log_echo ""
log_echo " "
log_echo "$vmesslink3"

log_echo ""
log_echo "   (Clash/OpenClash)"
log_echo " https://${domain}:81/vmess-$user.txt"

log_echo ""
log_echo "  & "
log_echo " https://vpntech.my.id/converteryaml"
log_echo " https://vpntech.my.id/auto-configuration"

log_echo ""
log_echo "  "
log_echo " https://wa.me/6285727035336"

log_echo ""
log_echo "   "

read -p "Onii-chan, Press Any Key To Back On Menu"
m-vmess
