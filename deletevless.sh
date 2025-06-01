#!/bin/bash

# Script untuk menghapus user VLess via HTTP GET
# Cara pakai: http://server/deletevless?user=USERNAME&auth=API_KEY

# ==================================================
# KONFIGURASI
valid_auth="fadznewbie_do"  # Ganti dengan auth key Anda

# ==================================================
# FUNGSI UTAMA

# Cek jika dipanggil via HTTP GET
if [ "$REQUEST_METHOD" = "GET" ]; then
  # Ambil parameter dari query string
  user=$(echo "$QUERY_STRING" | sed -n 's/^.*user=\([^&]*\).*$/\1/p')
  auth=$(echo "$QUERY_STRING" | sed -n 's/^.*auth=\([^&]*\).*$/\1/p')

  # Validasi auth key
  if [ "$auth" != "$valid_auth" ]; then
    echo -e "Content-Type: application/json\r\n"
    echo '{"status": "error", "message": "Invalid authentication key"}'
    exit 1
  fi

  # Validasi username
  if [ -z "$user" ]; then
    echo -e "Content-Type: application/json\r\n"
    echo '{"status": "error", "message": "Username is required"}'
    exit 1
  fi

  # Cari user di config.json
  exp=$(grep -wE "^#& $user" "/etc/xray/config.json" | cut -d ' ' -f 3 | sort | uniq)

  # Jika user tidak ditemukan
  if [ -z "$exp" ]; then
    echo -e "Content-Type: application/json\r\n"
    echo '{"status": "error", "message": "User not found"}'
    exit 1
  fi

  # Proses penghapusan user
  sed -i "/^#& $user $exp/,/^},{/d" /etc/xray/config.json
  sed -i "/^#& $user $exp/,/^},{/d" /etc/vless/.vless.db
  rm -rf "/etc/vless/$user"
  rm -rf "/etc/kyt/limit/vless/ip/$user"
  systemctl restart xray > /dev/null 2>&1

  # Berikan response sukses
  echo -e "Content-Type: application/json\r\n"
  echo '{"status": "success", "message": "User deleted successfully", "username": "'$user'", "expired": "'$exp'"}'
  exit 0
fi

# Jika dijalankan via CLI (bukan HTTP)
echo "Script ini dirancang untuk dijalankan via HTTP request"
echo "Contoh penggunaan:"
echo "http://localhost/deletevless?user=USERNAME&auth=API_KEY"
exit 1
