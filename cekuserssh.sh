#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# System Request : Debian 9+/Ubuntu 18.04+/20+
# Develovers » Gemilangkinasih࿐
# Email      » gemilangkinasih@gmail.com
# telegram   » https://t.me/gemilangkinasih
# whatsapp   » wa.me/+628984880039
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Script untuk mengecek daftar user SSH/OpenVPN
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Definisi warna untuk tampilan terminal
RED='\e[1;31m'
GREEN='\e[0;32m'
YELLOW='\e[0;33m'
NC='\e[0m'
BGWHITE='\e[0;100;37m'

# Fungsi untuk output JSON
output_json() {
    echo -e "Content-Type: application/json\n"
    echo -e "$1"
    exit $2
}

# Cek jika dipanggil via HTTP GET
if [ "$REQUEST_METHOD" = "GET" ]; then
    # Mode non-interaktif (HTTP GET)
    interactive_mode=false
else
    # Mode interaktif (terminal)
    interactive_mode=true
fi

# Inisialisasi array untuk menyimpan data user
users=()

# Loop untuk membaca setiap baris dari file /etc/passwd
while read expired
do
    # Mengambil nama akun dari kolom pertama (sebelum tanda :)
    AKUN="$(echo $expired | cut -d: -f1)"
    
    # Mengambil ID user dari kolom ketiga
    ID="$(echo $expired | grep -v nobody | cut -d: -f3)"
    
    # Hanya proses user dengan ID >= 1000 (user biasa, bukan system user)
    if [[ $ID -ge 1000 ]]; then
        # Mengecek tanggal expired akun menggunakan command chage
        exp="$(chage -l $AKUN | grep "Account expires" | awk -F": " '{print $2}')"
        
        # Mengecek status password akun (aktif/terkunci)
        status="$(passwd -S $AKUN | awk '{print $2}' )"
        
        # Tambahkan ke array
        users+=("{\"username\":\"$AKUN\",\"expired\":\"$exp\",\"status\":\"$status\"}")
    fi
done < /etc/passwd  # Input dari file passwd

# Format output berdasarkan mode
if [ "$interactive_mode" = false ]; then
    # Output JSON untuk HTTP GET
    output_json "{\"status\":\"success\",\"users\":[$(IFS=,; echo "${users[*]}")]}" 0
else
    # Output untuk terminal
    clear
    
    # Menampilkan header dengan warna orange
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "${YELLOW}${BGWHITE}            MEMBER SSH OPENVPN            ${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

    # Menampilkan header kolom
    echo "USERNAME          EXP DATE          "
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"

    # Tampilkan data user
    for user in "${users[@]}"; do
        username=$(echo "$user" | jq -r '.username')
        exp=$(echo "$user" | jq -r '.expired')
        status=$(echo "$user" | jq -r '.status')
        
        if [[ "$status" = "L" ]]; then
            printf "%-17s %2s %-17s %2s \n" "$username" "$exp     "
        else
            printf "%-17s %2s %-17s %2s \n" "$username" "$exp     "
        fi
    done

    # Menampilkan footer
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
fi
