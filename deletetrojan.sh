#!/bin/bash
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Script untuk menghapus user Trojan via CLI atau API
# Support pemanggilan HTTP GET dengan parameter:
# Contoh: ./deletetrojan.sh?user=namauser&auth=fadznewbie_do
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# Definisi warna untuk tampilan terminal
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
NC='\e[0m'               # No Color (reset warna)
BGWHITE='\e[0;100;37m'   # Background putih dengan teks hitam

# Konfigurasi autentikasi
valid_auth="fadznewbie_do"

# Fungsi untuk menampilkan bantuan
tampilkan_bantuan() {
    echo -e "${YELLOW}Penggunaan:${NC}"
    echo -e "  CLI : ./deletetrojan.sh (interaktif)"
    echo -e "  HTTP: ./deletetrojan.sh?user=USERNAME&auth=KUNCI"
}

# Fungsi untuk validasi autentikasi
validasi_auth() {
    local auth=$1
    
    if [[ "$auth" != "$valid_auth" ]]; then
        # Jika dipanggil via HTTP
        if [ -n "$QUERY_STRING" ]; then
            echo -e "Content-Type: application/json\r\n"
            echo '{"status": "error", "message": "Invalid authentication key"}'
        else
            # Jika dipanggil via CLI
            echo -e "${RED}Error: Kunci autentikasi salah!${NC}"
        fi
        exit 1
    fi
}

# Fungsi untuk menghapus user Trojan
hapus_user_trojan() {
    local username=$1
    local via_api=$2
    
    # Cari tanggal expired user dari config.json
    expired_date=$(grep -wE "^#! ${username}" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)
    
    # Validasi apakah user ditemukan
    if [ -z "$expired_date" ]; then
        if [ "$via_api" = true ]; then
            echo -e "Content-Type: application/json\r\n"
            echo -e "{\"status\":\"error\",\"message\":\"User ${username} tidak ditemukan\"}"
        else
            echo -e "${RED}Gagal: User ${username} tidak ditemukan!${NC}"
            read -p "Tekan enter untuk mencoba lagi"
        fi
        return 1
    fi
    
    # 1. Hapus konfigurasi user dari file config xray
    sed -i "/^#! ${username} ${expired_date}/,/^},{/d" /etc/xray/config.json
    
    # 2. Hapus data user dari database trojan
    sed -i "/### ${username} ${expired_date}/,/^},{/d" /etc/trojan/.trojan.db
    
    # 3. Hapus folder user dari direktori trojan
    rm -rf "/etc/trojan/${username}"
    
    # 4. Hapus data limit IP user
    rm -rf "/etc/kyt/limit/trojan/ip/${username}"
    
    # 5. Restart service xray untuk menerapkan perubahan
    systemctl restart xray > /dev/null 2>&1
    
    # Response berdasarkan mode
    if [ "$via_api" = true ]; then
        echo -e "Content-Type: application/json\r\n"
        echo -e "{\"status\":\"success\",\"message\":\"User ${username} berhasil dihapus\",\"expired_date\":\"${expired_date}\"}"
    else
        clear
        echo -e "${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo -e "» Akun Trojan Berhasil Di Hapus!"
        echo -e "${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo -e "Client Name : ${username}"
        echo -e "Expired On  : ${expired_date}"
        echo -e "${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        read -p "Tekan Tombol Apapun Untuk Kembali"
    fi
    return 0
}

# Fungsi untuk mode interaktif (CLI)
mode_interaktif() {
    # Cek jumlah user yang ada
    jumlah_user=$(grep -c -E "^#! " "/etc/xray/config.json")
    
    # Jika tidak ada user
    if [[ ${jumlah_user} == '0' ]]; then
        clear
        echo -e "${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo -e "${BGWHITE}         Hapus Akun Trojan         ${NC}"
        echo -e "${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        echo ""
        echo "Anda Tidak Memiliki Member Trojan"
        echo ""
        echo -e "${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
        read -p "Tekan tombol apapun untuk kembali"
        return
    fi
    
    # Tampilkan daftar user
    clear
    echo -e "${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "${BGWHITE}         Hapus Akun Trojan         ${NC}"
    echo -e "${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    echo -e "USER          EXPIRED  " 
    echo -e "${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    grep -e "^#! " "/etc/xray/config.json" | cut -d ' ' -f 2-3 | column -t | sort | uniq
    echo -e "${NC}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m"
    
    # Minta input username
    read -p "Ketik Usernamenya : " username
    
    # Validasi input
    if [ -z "$username" ]; then
        echo -e "${RED}Error: Username tidak boleh kosong!${NC}"
        read -p "Tekan enter untuk mencoba lagi"
        mode_interaktif
        return
    fi
    
    # Proses penghapusan
    hapus_user_trojan "$username" false
}

# ===== MAIN PROGRAM =====

# Cek apakah dipanggil via HTTP GET (QUERY_STRING ada)
if [ -n "$QUERY_STRING" ]; then
    # Parse parameter dari QUERY_STRING
    declare -A params
    IFS='&' read -ra pairs <<< "$QUERY_STRING"
    for pair in "${pairs[@]}"; do
        IFS='=' read -r key value <<< "$pair"
        params["$key"]=$value
    done
    
    # Cek parameter wajib
    if [ -z "${params[user]}" ] || [ -z "${params[auth]}" ]; then
        echo -e "Content-Type: application/json\r\n"
        echo '{"status":"error","message":"Parameter user dan auth diperlukan"}'
        exit 1
    fi
    
    # Validasi auth key
    validasi_auth "${params[auth]}"
    
    # Jalankan penghapusan user via API
    hapus_user_trojan "${params[user]}" true
    
else
    # Jalankan mode interaktif (CLI)
    mode_interaktif
fi
