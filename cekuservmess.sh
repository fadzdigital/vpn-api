#!/bin/bash

# Script untuk mengecek dan menampilkan daftar user Vmess dalam format JSON
# File: cekuservmess.sh

# Fungsi utama untuk mengecek dan menampilkan daftar user
cek_daftar_user() {
    # Inisialisasi array untuk menyimpan data user
    local users=()
    local total_user=0
    
    # Cek jika file config.json ada
    if [ ! -f "/etc/xray/config.json" ]; then
        echo '{"status":"error","message":"File config.json tidak ditemukan"}' >&2
        return 1
    fi
    
    # Hitung jumlah user dan kumpulkan data
    total_user=$(grep -c -E "^### " "/etc/xray/config.json")
    
    # Jika tidak ada user
    if [[ ${total_user} == '0' ]]; then
        echo '{"status":"success","total_user":0,"users":[],"message":"Tidak ada user Vmess"}' >&2
        return 0
    fi
    
    # Proses setiap user
    while IFS= read -r line; do
        # Ekstrak username dan expired date
        local username=$(echo "$line" | awk '{print $2}')
        local expired=$(echo "$line" | awk '{print $3}')
        
        # Tambahkan ke array
        users+=("{\"username\":\"$username\",\"expired\":\"$expired\"}")
    done < <(grep -e "^### " "/etc/xray/config.json" | sort | uniq)
    
    # Gabungkan data user menjadi JSON array
    local user_json=$(IFS=,; echo "[${users[*]}]")
    
    # Output JSON
    echo "{\"status\":\"success\",\"total_user\":$total_user,\"users\":$user_json}"
    return 0
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Jika dijalankan langsung dari terminal (bukan via HTTP)
    if [ -t 0 ]; then
        cek_daftar_user | jq '.' 2>/dev/null || cek_daftar_user
        read -p "Tekan tombol apapun untuk kembali ke menu"
    else
        # Jika dipanggil via HTTP (misal dari API)
        cek_daftar_user
    fi
fi
