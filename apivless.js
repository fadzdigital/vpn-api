const express = require('express');
const { execFile } = require('child_process');
const path = require('path');

const app = express();
const PORT = 5888;

// Ganti dengan path lengkap ke createvmess.sh kamu
const SCRIPT_PATH = '/opt/vpn-api/scripts/createvless.sh';

app.get('/createvmess', (req, res) => {
  const query = req.query;

  // Validasi parameter wajib
  const requiredParams = ['user', 'exp', 'quota', 'iplimit', 'auth'];
  const missingParams = requiredParams.filter(p => !query[p]);
  if (missingParams.length > 0) {
    return res.status(400).json({
      status: 'error',
      message: `Missing required parameter(s): ${missingParams.join(', ')}`
    });
  }

  // Bangun QUERY_STRING seperti CGI
  const queryString = Object.entries(query)
    .map(([key, val]) => `${key}=${val}`)
    .join('&');

  // Jalankan bash script
  execFile(SCRIPT_PATH, {
    env: {
      ...process.env,
      REQUEST_METHOD: 'GET',
      QUERY_STRING: queryString
    }
  }, (error, stdout, stderr) => {
    const trimmedOutput = stdout.trim();

    try {
      // Coba parsing output sebagai JSON
      const result = JSON.parse(trimmedOutput);

      // Kalau error terdeteksi oleh script, kirim status 400
      if (result.status === 'error') {
        return res.status(400).json(result);
      }

      // Jika sukses
      return res.json(result);
    } catch (e) {
      // Jika output bukan JSON
      return res.status(error ? 500 : 200).send(trimmedOutput || stderr || error.message);
    }
  });
});

app.listen(PORT, () => {
  console.log(`✅ createvmess API aktif di http://localhost:${PORT}`);
});
