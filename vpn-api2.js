const express = require('express');
const { execFile } = require('child_process');
const path = require('path');

const app = express();
const PORT = 5888; // Port utama

// Path ke script-shell
const SCRIPTS = {
  vmess: '/opt/vpn-api/scripts/createvmess.sh',
  ssh: '/opt/vpn-api/scripts/createssh.sh'
};

// Middleware untuk log request
app.use((req, res, next) => {
  console.log(`[${new Date().toISOString()}] ${req.method} ${req.path}`);
  next();
});

// Endpoint untuk VMESS
app.get('/createvmess', (req, res) => {
  handleScriptRequest(req, res, 'vmess', ['user', 'exp', 'quota', 'iplimit', 'auth']);
});

// Endpoint untuk SSH
app.get('/createssh', (req, res) => {
  handleScriptRequest(req, res, 'ssh', ['user', 'pass', 'exp', 'quota', 'iplimit', 'auth']);
});

// Fungsi utama untuk handle request
function handleScriptRequest(req, res, scriptType, requiredParams) {
  const query = req.query;

  // Validasi parameter
  const missingParams = requiredParams.filter(p => !query[p]);
  if (missingParams.length > 0) {
    return res.status(400).json({
      status: 'error',
      message: `Missing required parameter(s): ${missingParams.join(', ')}`,
      example: getExampleUsage(scriptType)
    });
  }

  // Validasi auth key
  if (query.auth !== 'fadznewbie_do') {
    return res.status(403).json({
      status: 'error',
      message: 'Invalid authentication key'
    });
  }

  // Bangun QUERY_STRING
  const queryString = Object.entries(query)
    .map(([key, val]) => `${key}=${encodeURIComponent(val)}`)
    .join('&');

  // Jalankan script
  execFile(SCRIPTS[scriptType], {
    env: {
      ...process.env,
      REQUEST_METHOD: 'GET',
      QUERY_STRING: queryString
    }
  }, (error, stdout, stderr) => {
    const output = stdout.toString().trim();
    const err = stderr.toString().trim();

    try {
      const result = JSON.parse(output);
      return res.status(result.status === 'error' ? 400 : 200).json(result);
    } catch (e) {
      if (error) {
        console.error(`[ERROR] ${scriptType}:`, error);
        return res.status(500).json({
          status: 'error',
          message: 'Internal server error',
          details: err || error.message
        });
      }
      return res.status(200).send(output);
    }
  });
}

// Contoh penggunaan API
function getExampleUsage(scriptType) {
  const baseUrl = `http://localhost:${PORT}/${scriptType === 'vmess' ? 'createvmess' : 'createssh'}`;
  
  if (scriptType === 'vmess') {
    return `${baseUrl}?user=testuser&exp=30&quota=10&iplimit=2&auth=fadznewbie_do`;
  } else {
    return `${baseUrl}?user=sshuser&pass=sshpass&exp=30&quota=5&iplimit=1&auth=fadznewbie_do`;
  }
}

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    services: Object.keys(SCRIPTS),
    timestamp: new Date().toISOString()
  });
});

// Handle 404
app.use((req, res) => {
  res.status(404).json({
    status: 'error',
    message: 'Endpoint not found',
    available_endpoints: [
      'GET /createvmess',
      'GET /createssh',
      'GET /health'
    ]
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 VPN API Service running on port ${PORT}`);
  console.log(`Available endpoints:`);
  console.log(`- VMESS: http://localhost:${PORT}/createvmess`);
  console.log(`- SSH:   http://localhost:${PORT}/createssh`);
  console.log(`- Health: http://localhost:${PORT}/health`);
});

// Handle shutdown gracefully
process.on('SIGTERM', () => {
  console.log('🛑 Received SIGTERM, shutting down gracefully');
  server.close(() => {
    console.log('🔴 Server closed');
    process.exit(0);
  });
});
