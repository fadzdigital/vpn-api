const express = require('express');
const { execFile } = require('child_process');
const path = require('path');
const fs = require('fs');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const os = require('os');

// Inisialisasi aplikasi Express
const app = express();
const PORT = process.env.PORT || 5888;
const NODE_ENV = process.env.NODE_ENV || 'production';
const API_VERSION = '1.2.0';

// ===============================================
// KONFIGURASI LOGGING DENGAN WARNA DAN FORMAT
// ===============================================
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  dim: '\x1b[2m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  magenta: '\x1b[35m',
  cyan: '\x1b[36m',
  white: '\x1b[37m'
};

/**
 * Fungsi logging profesional dengan level dan timestamp
 * @param {string} level - Level log (INFO, WARN, ERROR, DEBUG, SUCCESS)
 * @param {string} message - Pesan yang ingin di-log
 * @param {any} data - Data tambahan (opsional)
 */
function log(level, message, data = '') {
  const timestamp = new Date().toISOString();
  const pid = process.pid;
  
  const colorMap = {
    INFO: colors.blue,
    WARN: colors.yellow,
    ERROR: colors.red,
    DEBUG: colors.cyan,
    SUCCESS: colors.green
  };
  
  const color = colorMap[level] || colors.reset;
  const resetColor = colors.reset;
  
  // Format output yang lebih profesional
  let logMessage = `${color}[${timestamp}] [PID:${pid}] ${level}${resetColor}: ${message}`;
  
  if (data && typeof data === 'object') {
    console.log(logMessage, JSON.stringify(data, null, 2));
  } else if (data) {
    console.log(logMessage, data);
  } else {
    console.log(logMessage);
  }
}

// ===============================================
// KONFIGURASI KEAMANAN MIDDLEWARE
// ===============================================

// Helmet untuk security headers
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"]
    }
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
    preload: true
  }
}));

// Rate limiting yang lebih canggih dengan multiple tier
const createRateLimit = (windowMs, max, message) => {
  return rateLimit({
    windowMs,
    max,
    message: {
      status: 'error',
      message,
      retry_after: `${windowMs / 1000 / 60} minutes`,
      timestamp: new Date().toISOString()
    },
    standardHeaders: true,
    legacyHeaders: false,
    handler: (req, res) => {
      log('WARN', `Rate limit exceeded for IP: ${req.ip}`, {
        endpoint: req.path,
        method: req.method,
        userAgent: req.get('User-Agent')?.substring(0, 50)
      });
      res.status(429).json({
        status: 'error',
        message,
        retry_after: `${windowMs / 1000 / 60} minutes`,
        timestamp: new Date().toISOString()
      });
    }
  });
};

// Rate limit untuk endpoint umum (100 req/15 menit)
const generalLimiter = createRateLimit(
  15 * 60 * 1000, 
  100, 
  'Terlalu banyak request dari IP ini, coba lagi nanti'
);

// Rate limit untuk endpoint create (20 req/5 menit) - lebih ketat
const createLimiter = createRateLimit(
  5 * 60 * 1000, 
  20, 
  'Terlalu banyak pembuatan akun dari IP ini, coba lagi dalam 5 menit'
);

app.use(generalLimiter);

// ===============================================
// MIDDLEWARE BODY PARSER DAN REQUEST
// ===============================================

// Body parser dengan limit yang aman
app.use(express.json({ 
  limit: '1mb',
  strict: true
}));
app.use(express.urlencoded({ 
  extended: true, 
  limit: '1mb',
  parameterLimit: 20
}));

// Trust proxy untuk mendapatkan IP yang benar
app.set('trust proxy', 1);

// ===============================================
// KONFIGURASI PATH SCRIPT DAN VALIDASI
// ===============================================

// Mapping path script dengan validasi keberadaan
const SCRIPTS = {
  vmess: '/opt/vpn-api/scripts/createvmess.sh',
  ssh: '/opt/vpn-api/scripts/createssh.sh',
  vless: '/opt/vpn-api/scripts/createvless.sh',
  trojan: '/opt/vpn-api/scripts/createtrojan.sh'
};

// Konstanta untuk validasi
const VALIDATION_RULES = {
  user: { 
    required: true, 
    pattern: /^[a-zA-Z0-9_-]{3,20}$/, 
    message: 'Username harus 3-20 karakter, hanya huruf, angka, underscore, atau dash' 
  },
  pass: { 
    required: false, 
    minLength: 6, 
    maxLength: 50, 
    message: 'Password harus 6-50 karakter' 
  },
  exp: { 
    required: true, 
    pattern: /^\d+$/, 
    min: 1, 
    max: 365, 
    message: 'Masa berlaku harus angka antara 1-365 hari' 
  },
  quota: { 
    required: true, 
    pattern: /^\d+$/, 
    min: 1, 
    max: 1000, 
    message: 'Kuota harus angka antara 1-1000 GB' 
  },
  iplimit: { 
    required: true, 
    pattern: /^\d+$/, 
    min: 1, 
    max: 10, 
    message: 'Batas IP harus angka antara 1-10' 
  },
  auth: { 
    required: true, 
    exact: 'fadznewbie_do', 
    message: 'Kunci otentikasi tidak valid' 
  }
};

/**
 * Validasi keberadaan dan permission script saat startup
 * Fungsi ini memastikan semua script yang diperlukan ada dan dapat dieksekusi
 */
function validateScripts() {
  log('INFO', 'Memvalidasi script files...');
  
  const missingScripts = [];
  const unexecutableScripts = [];
  
  Object.entries(SCRIPTS).forEach(([type, scriptPath]) => {
    try {
      if (!fs.existsSync(scriptPath)) {
        missingScripts.push(`${type}: ${scriptPath}`);
      } else {
        const stats = fs.statSync(scriptPath);
        if (!(stats.mode & parseInt('111', 8))) {
          unexecutableScripts.push(`${type}: ${scriptPath}`);
        }
      }
    } catch (error) {
      log('ERROR', `Error saat validasi script ${scriptPath}:`, error.message);
      missingScripts.push(`${type}: ${scriptPath} (Error: ${error.message})`);
    }
  });
  
  if (missingScripts.length > 0) {
    log('ERROR', 'Script files tidak ditemukan:', missingScripts);
  }
  
  if (unexecutableScripts.length > 0) {
    log('WARN', 'Script files mungkin tidak executable:', unexecutableScripts);
  }
  
  if (missingScripts.length === 0 && unexecutableScripts.length === 0) {
    log('SUCCESS', 'Semua script files tervalidasi dengan baik');
  }
}

// ===============================================
// MIDDLEWARE LOGGING REQUEST
// ===============================================

/**
 * Enhanced middleware untuk logging request dengan detail lengkap
 * Mencatat setiap request masuk beserta informasi penting
 */
app.use((req, res, next) => {
  const startTime = Date.now();
  const requestId = Math.random().toString(36).substring(2, 10).toUpperCase();
  
  // Mendapatkan IP address yang akurat
  const clientIP = req.ip || 
                   req.connection?.remoteAddress || 
                   req.socket?.remoteAddress ||
                   req.headers['x-forwarded-for']?.split(',')[0]?.trim() ||
                   'unknown';
  
  // Attach request ID untuk tracking
  req.requestId = requestId;
  
  // Log incoming request
  log('INFO', `[${requestId}] ${req.method} ${req.originalUrl || req.url}`, {
    ip: clientIP,
    userAgent: req.get('User-Agent')?.substring(0, 100) || 'unknown',
    query: Object.keys(req.query).length > 0 ? Object.keys(req.query) : [],
    contentType: req.get('Content-Type') || 'none',
    contentLength: req.get('Content-Length') || '0'
  });

  // Override res.json untuk menambahkan request_id otomatis
  const originalJson = res.json;
  res.json = function(body) {
    if (typeof body === 'object' && body !== null) {
      body.request_id = requestId;
      body.timestamp = new Date().toISOString();
    }
    return originalJson.call(this, body);
  };

  // Log response saat selesai
  res.on('finish', () => {
    const duration = Date.now() - startTime;
    const level = res.statusCode >= 400 ? 'ERROR' : 'INFO';
    
    log(level, `[${requestId}] Response ${res.statusCode} - ${duration}ms`, {
      contentLength: res.get('Content-Length') || '0',
      contentType: res.get('Content-Type') || 'unknown'
    });
  });

  next();
});

// ===============================================
// FUNGSI VALIDASI DAN SANITASI INPUT
// ===============================================

/**
 * Fungsi untuk validasi dan sanitasi input yang ketat
 * @param {Object} input - Object input yang akan divalidasi
 * @param {string} type - Tipe endpoint (vmess, ssh, vless, trojan)
 * @return {Object} - Object berisi sanitized data dan errors
 */
function validateAndSanitizeInput(input, type) {
  const sanitized = {};
  const errors = [];

  // Validasi setiap field berdasarkan rules
  Object.entries(input).forEach(([key, value]) => {
    const rule = VALIDATION_RULES[key];
    
    if (rule) {
      // Check required field
      if (rule.required && (!value || value.toString().trim() === '')) {
        errors.push(`Parameter '${key}' wajib diisi`);
        return;
      }

      if (value !== undefined && value !== null && value.toString().trim() !== '') {
        const strValue = value.toString().trim();
        
        // Check exact match (untuk auth key)
        if (rule.exact && strValue !== rule.exact) {
          errors.push(rule.message);
          return;
        }

        // Check regex pattern
        if (rule.pattern && !rule.pattern.test(strValue)) {
          errors.push(rule.message);
          return;
        }

        // Check minimum length
        if (rule.minLength && strValue.length < rule.minLength) {
          errors.push(rule.message);
          return;
        }
        
        // Check maximum length
        if (rule.maxLength && strValue.length > rule.maxLength) {
          errors.push(rule.message);
          return;
        }

        // Check numeric range
        if (rule.min !== undefined || rule.max !== undefined) {
          const numValue = parseInt(strValue, 10);
          if (isNaN(numValue)) {
            errors.push(rule.message);
            return;
          }
          if (rule.min !== undefined && numValue < rule.min) {
            errors.push(rule.message);
            return;
          }
          if (rule.max !== undefined && numValue > rule.max) {
            errors.push(rule.message);
            return;
          }
        }

        sanitized[key] = strValue;
      }
    } else {
      // Parameter tidak dikenal, tapi tetap sanitasi untuk keamanan
      if (value !== undefined && value !== null) {
        sanitized[key] = value.toString().trim().substring(0, 100); // Batasi panjang
      }
    }
  });

  return { sanitized, errors };
}

// ===============================================
// ENDPOINT HANDLERS
// ===============================================

// Endpoint untuk VMESS - dengan rate limiting khusus
app.get('/createvmess', createLimiter, (req, res) => {
  handleScriptRequest(req, res, 'vmess', ['user', 'exp', 'quota', 'iplimit', 'auth']);
});

// Endpoint untuk SSH - dengan rate limiting khusus
app.get('/createssh', createLimiter, (req, res) => {
  handleScriptRequest(req, res, 'ssh', ['user', 'pass', 'exp', 'quota', 'iplimit', 'auth']);
});

// Endpoint untuk VLESS - dengan rate limiting khusus
app.get('/createvless', createLimiter, (req, res) => {
  handleScriptRequest(req, res, 'vless', ['user', 'exp', 'quota', 'iplimit', 'auth']);
});

// Endpoint untuk TROJAN - dengan rate limiting khusus
app.get('/createtrojan', createLimiter, (req, res) => {
  handleScriptRequest(req, res, 'trojan', ['user', 'exp', 'quota', 'iplimit', 'auth']);
});

// ===============================================
// FUNGSI UTAMA HANDLER REQUEST
// ===============================================

/**
 * Fungsi utama untuk menangani semua request ke script
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @param {string} scriptType - Tipe script (vmess, ssh, vless, trojan)
 * @param {Array} requiredParams - Array parameter yang wajib ada
 */
function handleScriptRequest(req, res, scriptType, requiredParams) {
  const requestId = req.requestId;
  const startTime = Date.now();
  
  log('DEBUG', `[${requestId}] Memproses request ${scriptType.toUpperCase()}`);

  const query = req.query;

  // Validasi parameter wajib
  const missingParams = requiredParams.filter(param => {
    return !query[param] || query[param].toString().trim() === '';
  });
  
  if (missingParams.length > 0) {
    log('WARN', `[${requestId}] Parameter tidak lengkap untuk ${scriptType}:`, missingParams);
    return res.status(400).json({
      status: 'error',
      message: `Parameter wajib tidak lengkap: ${missingParams.join(', ')}`,
      missing_parameters: missingParams,
      example: getExampleUsage(scriptType),
      help: `Gunakan endpoint /docs untuk dokumentasi lengkap`
    });
  }

  // Validasi dan sanitasi input
  const { sanitized, errors } = validateAndSanitizeInput(query, scriptType);
  
  if (errors.length > 0) {
    log('WARN', `[${requestId}] Validasi gagal untuk ${scriptType}:`, errors);
    return res.status(400).json({
      status: 'error',
      message: 'Validasi input gagal',
      errors: errors,
      help: 'Periksa format parameter yang dikirim'
    });
  }

  // Validasi auth key
  if (sanitized.auth !== 'fadznewbie_do') {
    log('WARN', `[${requestId}] Auth key tidak valid untuk ${scriptType}`);
    return res.status(403).json({
      status: 'error',
      message: 'Kunci otentikasi tidak valid',
      code: 'INVALID_AUTH'
    });
  }

  // Check keberadaan script
  const scriptPath = SCRIPTS[scriptType];
  if (!fs.existsSync(scriptPath)) {
    log('ERROR', `[${requestId}] Script tidak ditemukan: ${scriptPath}`);
    return res.status(503).json({
      status: 'error',
      message: 'Layanan sementara tidak tersedia',
      code: 'SERVICE_UNAVAILABLE'
    });
  }

  // Build query string untuk environment variable
  const queryString = Object.entries(sanitized)
    .filter(([key]) => key !== 'auth') // Jangan masukkan auth key ke query string
    .map(([key, val]) => `${key}=${encodeURIComponent(val)}`)
    .join('&');

  log('DEBUG', `[${requestId}] Menjalankan script ${scriptType} dengan parameter tervalidasi`);

  // Execute script dengan konfigurasi yang lebih aman
  const childProcess = execFile(scriptPath, [], {
    env: {
      ...process.env,
      REQUEST_METHOD: 'GET',
      QUERY_STRING: queryString,
      SCRIPT_TYPE: scriptType.toUpperCase(),
      REQUEST_ID: requestId
    },
    timeout: 45000, // 45 detik timeout
    maxBuffer: 2 * 1024 * 1024, // 2MB buffer
    killSignal: 'SIGTERM'
  }, (error, stdout, stderr) => {
    const processingTime = Date.now() - startTime;
    const output = stdout ? stdout.toString().trim() : '';
    const errorOutput = stderr ? stderr.toString().trim() : '';

    if (error) {
      // Handle berbagai jenis error
      let errorMessage = 'Terjadi kesalahan internal';
      let statusCode = 500;
      
      if (error.code === 'TIMEOUT') {
        errorMessage = 'Request timeout, coba lagi nanti';
        statusCode = 504;
        log('ERROR', `[${requestId}] Script timeout setelah 45 detik untuk ${scriptType}`);
      } else if (error.signal === 'SIGTERM') {
        errorMessage = 'Proses dihentikan karena timeout';
        statusCode = 504;
        log('ERROR', `[${requestId}] Script terminated untuk ${scriptType}`);
      } else {
        log('ERROR', `[${requestId}] Error eksekusi script ${scriptType}:`, {
          error: error.message,
          code: error.code,
          signal: error.signal,
          stderr: errorOutput,
          processingTime: `${processingTime}ms`
        });
      }
      
      return res.status(statusCode).json({
        status: 'error',
        message: errorMessage,
        code: error.code || 'EXECUTION_ERROR',
        processing_time: `${processingTime}ms`,
        details: NODE_ENV === 'development' ? {
          error: error.message,
          stderr: errorOutput
        } : undefined
      });
    }

    // Coba parsing JSON response
    try {
      const result = JSON.parse(output);
      const statusCode = result.status === 'error' ? 400 : 200;
      
      // Tambahkan metadata
      result.processing_time = `${processingTime}ms`;
      result.script_type = scriptType;
      
      const logLevel = result.status === 'error' ? 'WARN' : 'SUCCESS';
      log(logLevel, `[${requestId}] ${scriptType.toUpperCase()} request selesai - Status: ${result.status} - ${processingTime}ms`);
      
      return res.status(statusCode).json(result);
      
    } catch (parseError) {
      // Jika bukan JSON, cek apakah output kosong
      if (!output && !errorOutput) {
        log('ERROR', `[${requestId}] Script ${scriptType} tidak menghasilkan output`);
        return res.status(500).json({
          status: 'error',
          message: 'Script tidak menghasilkan response',
          processing_time: `${processingTime}ms`
        });
      }
      
      // Return raw output jika bukan JSON
      log('DEBUG', `[${requestId}] Response non-JSON dari ${scriptType} script`);
      return res.status(200).send(output || errorOutput);
    }
  });

  // Handle process errors
  childProcess.on('error', (processError) => {
    log('ERROR', `[${requestId}] Process error untuk ${scriptType}:`, {
      error: processError.message,
      code: processError.code
    });
  });

  // Handle process exit
  childProcess.on('exit', (code, signal) => {
    if (code !== 0) {
      log('WARN', `[${requestId}] Script ${scriptType} exit dengan code ${code}, signal: ${signal || 'none'}`);
    }
  });
}

// ===============================================
// FUNGSI HELPER
// ===============================================

/**
 * Generate contoh penggunaan API untuk setiap endpoint
 * @param {string} scriptType - Tipe script
 * @return {string} - URL contoh
 */
function getExampleUsage(scriptType) {
  const baseUrl = `http://localhost:${PORT}/create${scriptType}`;
  const authParam = 'auth=fadznewbie_do';
  
  const examples = {
    vmess: `${baseUrl}?user=testuser&exp=30&quota=10&iplimit=2&${authParam}`,
    ssh: `${baseUrl}?user=sshuser&pass=sshpass123&exp=30&quota=5&iplimit=1&${authParam}`,
    vless: `${baseUrl}?user=vlessuser&exp=30&quota=15&iplimit=3&${authParam}`,
    trojan: `${baseUrl}?user=trojanuser&exp=30&quota=20&iplimit=2&${authParam}`
  };
  
  return examples[scriptType] || `${baseUrl}?${authParam}`;
}

// ===============================================
// ENDPOINT TAMBAHAN
// ===============================================

/**
 * Health check endpoint yang komprehensif
 */
app.get('/health', (req, res) => {
  const uptime = process.uptime();
  const memUsage = process.memoryUsage();
  
  const health = {
    status: 'healthy',
    service: 'VPN API Service',
    version: API_VERSION,
    environment: NODE_ENV,
    timestamp: new Date().toISOString(),
    uptime: {
      seconds: Math.floor(uptime),
      human: `${Math.floor(uptime / 3600)}h ${Math.floor((uptime % 3600) / 60)}m ${Math.floor(uptime % 60)}s`
    },
    memory: {
      used_mb: Math.round(memUsage.heapUsed / 1024 / 1024),
      total_mb: Math.round(memUsage.heapTotal / 1024 / 1024),
      usage_percent: Math.round((memUsage.heapUsed / memUsage.heapTotal) * 100)
    },
    system: {
      platform: os.platform(),
      arch: os.arch(),
      node_version: process.version,
      cpu_count: os.cpus().length
    },
    services: Object.keys(SCRIPTS)
  };

  // Check status script
  const scriptStatus = {};
  let allScriptsOk = true;
  
  Object.entries(SCRIPTS).forEach(([type, scriptPath]) => {
    const exists = fs.existsSync(scriptPath);
    let executable = false;
    
    if (exists) {
      try {
        const stats = fs.statSync(scriptPath);
        executable = !!(stats.mode & parseInt('111', 8));
      } catch (error) {
        executable = false;
      }
    }
    
    scriptStatus[type] = {
      exists,
      executable,
      status: exists && executable ? 'ready' : 'unavailable'
    };
    
    if (!exists || !executable) {
      allScriptsOk = false;
    }
  });
  
  health.scripts = scriptStatus;
  health.status = allScriptsOk ? 'healthy' : 'degraded';
  
  const statusCode = allScriptsOk ? 200 : 503;
  res.status(statusCode).json(health);
});

/**
 * API documentation endpoint dengan format yang lebih baik
 */
app.get('/docs', (req, res) => {
  const docs = {
    title: 'VPN API Service - Dokumentasi Lengkap',
    version: API_VERSION,
    description: 'API untuk membuat akun VPN berbagai protokol (VMESS, SSH, VLESS, TROJAN)',
    base_url: `http://localhost:${PORT}`,
    authentication: {
      type: 'API Key',
      parameter: 'auth',
      required: true,
      description: 'Kunci otentikasi yang diperlukan untuk semua endpoint create'
    },
    rate_limits: {
      general: '100 requests per 15 minutes',
      create_endpoints: '20 requests per 5 minutes'
    },
    endpoints: {
      'POST/GET /createvmess': {
        description: 'Membuat akun VMESS baru',
        method: 'GET',
        parameters: {
          user: { 
            type: 'string', 
            required: true, 
            description: 'Username (3-20 karakter, hanya huruf, angka, _, -)',
            example: 'user123'
          },
          exp: { 
            type: 'integer', 
            required: true, 
            description: 'Masa berlaku dalam hari (1-365)',
            example: 30
          },
          quota: { 
            type: 'integer', 
            required: true, 
            description: 'Kuota dalam GB (1-1000)',
            example: 100
          },
          iplimit: { 
            type: 'integer', 
            required: true, 
            description: 'Batas IP simultan (1-10)',
            example: 2
          },
          auth: { 
            type: 'string', 
            required: true, 
            description: 'Kunci otentikasi API'
          }
        },
        example: getExampleUsage('vmess'),
        response_format: {
          success: {
            status: 'success',
            message: 'Akun VMESS berhasil dibuat',
            data: {
              username: 'user123',
              config: '...',
              expires: '2024-xx-xx'
            }
          },
          error: {
            status: 'error',
            message: 'Deskripsi error',
            errors: ['Detail error jika ada']
          }
        }
      },
      'POST/GET /createssh': {
        description: 'Membuat akun SSH baru',
        method: 'GET',
        parameters: {
          user: { 
            type: 'string', 
            required: true, 
            description: 'Username SSH (3-20 karakter)',
            example: 'sshuser'
          },
          pass: { 
            type: 'string', 
            required: true, 
            description: 'Password SSH (6-50 karakter)',
            example: 'mypassword123'
          },
          exp: { 
            type: 'integer', 
            required: true, 
            description: 'Masa berlaku dalam hari (1-365)',
            example: 30
          },
          quota: { 
            type: 'integer', 
            required: true, 
            description: 'Kuota dalam GB (1-1000)',
            example: 25
          },
          iplimit: { 
            type: 'integer', 
            required: true, 
            description: 'Batas IP simultan (1-10)',
            example: 1
          },
          auth: { 
            type: 'string', 
            required: true, 
            description: 'Kunci otentikasi API'
          }
        },
        example: getExampleUsage('ssh')
      },
      'POST/GET /createvless': {
        description: 'Membuat akun VLESS baru',
        method: 'GET',
        parameters: {
          user: { 
            type: 'string', 
            required: true, 
            description: 'Username VLESS (3-20 karakter)',
            example: 'vlessuser'
          },
          exp: { 
            type: 'integer', 
            required: true, 
            description: 'Masa berlaku dalam hari (1-365)',
            example: 30
          },
          quota: { 
            type: 'integer', 
            required: true, 
            description: 'Kuota dalam GB (1-1000)',
            example: 75
          },
          iplimit: { 
            type: 'integer', 
            required: true, 
            description: 'Batas IP simultan (1-10)',
            example: 3
          },
          auth: { 
            type: 'string', 
            required: true, 
            description: 'Kunci otentikasi API'
          }
        },
        example: getExampleUsage('vless')
      },
      'POST/GET /createtrojan': {
        description: 'Membuat akun TROJAN baru',
        method: 'GET',
        parameters: {
          user: { 
            type: 'string', 
            required: true, 
            description: 'Username TROJAN (3-20 karakter)',
            example: 'trojanuser'
          },
          exp: { 
            type: 'integer', 
            required: true, 
            description: 'Masa berlaku dalam hari (1-365)',
            example: 30
          },
          quota: { 
            type: 'integer', 
            required: true, 
            description: 'Kuota dalam GB (1-1000)',
            example: 20
          },
          iplimit: { 
            type: 'integer', 
            required: true, 
            description: 'Batas IP simultan (1-10)',
            example: 2
          },
          auth: { 
            type: 'string', 
            required: true, 
            description: 'Kunci otentikasi API'
          }
        },
        example: getExampleUsage('trojan')
      },
      'GET /health': {
        description: 'Cek status kesehatan API dan sistem',
        method: 'GET',
        parameters: {},
        example: `http://localhost:${PORT}/health`,
        description_detail: 'Endpoint ini memberikan informasi lengkap tentang status API, penggunaan memori, uptime, dan status script'
      },
      'GET /docs': {
        description: 'Dokumentasi API lengkap',
        method: 'GET',
        parameters: {},
        example: `http://localhost:${PORT}/docs`
      }
    },
    error_codes: {
      400: 'Bad Request - Parameter tidak valid atau tidak lengkap',
      403: 'Forbidden - Kunci otentikasi tidak valid',
      429: 'Too Many Requests - Rate limit terlampaui',
      500: 'Internal Server Error - Kesalahan sistem',
      503: 'Service Unavailable - Script tidak tersedia',
      504: 'Gateway Timeout - Request timeout'
    },
    common_errors: {
      invalid_auth: 'Pastikan parameter auth berisi kunci yang benar',
      missing_parameters: 'Periksa semua parameter wajib sudah diisi',
      invalid_format: 'Periksa format parameter sesuai dengan aturan validasi',
      rate_limit: 'Tunggu beberapa menit sebelum mencoba lagi'
    },
    contact: {
      description: 'Untuk bantuan teknis atau pertanyaan',
      note: 'Simpan request_id dari response untuk troubleshooting'
    }
  };
  
  res.json(docs);
});

/**
 * Endpoint status yang lebih ringan untuk monitoring
 */
app.get('/status', (req, res) => {
  res.json({
    status: 'online',
    timestamp: new Date().toISOString(),
    version: API_VERSION,
    uptime_seconds: Math.floor(process.uptime())
  });
});

/**
 * Endpoint untuk statistik dasar (tanpa data sensitif)
 */
app.get('/stats', (req, res) => {
  const memUsage = process.memoryUsage();
  
  res.json({
    service: 'VPN API Service',
    version: API_VERSION,
    uptime_hours: Math.round(process.uptime() / 3600 * 100) / 100,
    memory_usage_mb: Math.round(memUsage.heapUsed / 1024 / 1024),
    available_services: Object.keys(SCRIPTS),
    node_version: process.version,
    environment: NODE_ENV
  });
});

// ===============================================
// ERROR HANDLERS
// ===============================================

/**
 * Handler untuk endpoint yang tidak ditemukan (404)
 */
app.use((req, res) => {
  log('WARN', `404 - Endpoint tidak ditemukan: ${req.method} ${req.originalUrl}`, {
    ip: req.ip,
    userAgent: req.get('User-Agent')?.substring(0, 50)
  });
  
  res.status(404).json({
    status: 'error',
    message: 'Endpoint tidak ditemukan',
    requested_endpoint: `${req.method} ${req.originalUrl}`,
    available_endpoints: [
      'GET /createvmess - Membuat akun VMESS',
      'GET /createssh - Membuat akun SSH', 
      'GET /createvless - Membuat akun VLESS',
      'GET /createtrojan - Membuat akun TROJAN',
      'GET /health - Status kesehatan sistem',
      'GET /docs - Dokumentasi API lengkap',
      'GET /status - Status singkat API',
      'GET /stats - Statistik sistem'
    ],
    help: 'Gunakan /docs untuk dokumentasi lengkap'
  });
});

/**
 * Global error handler untuk menangani error yang tidak tertangani
 */
app.use((err, req, res, next) => {
  const requestId = req.requestId || 'unknown';
  
  log('ERROR', `[${requestId}] Unhandled error:`, {
    message: err.message,
    stack: err.stack,
    url: req.originalUrl,
    method: req.method,
    ip: req.ip
  });
  
  // Jangan expose error details di production
  const errorResponse = {
    status: 'error',
    message: 'Terjadi kesalahan internal server',
    code: 'INTERNAL_ERROR'
  };
  
  if (NODE_ENV === 'development') {
    errorResponse.details = {
      message: err.message,
      stack: err.stack
    };
  }
  
  res.status(500).json(errorResponse);
});

// ===============================================
// STARTUP DAN SHUTDOWN HANDLERS
// ===============================================

/**
 * Validasi script saat startup
 */
validateScripts();

/**
 * Start server dengan error handling
 */
const server = app.listen(PORT, (err) => {
  if (err) {
    log('ERROR', 'Gagal memulai server:', err);
    process.exit(1);
  }
  
  log('SUCCESS', `🚀 VPN API Service v${API_VERSION} berhasil dimulai`);
  log('INFO', `📡 Server berjalan di port ${PORT}`);
  log('INFO', `🌍 Environment: ${NODE_ENV}`);
  log('INFO', '📋 Endpoint yang tersedia:');
  log('INFO', `   • VMESS:    http://localhost:${PORT}/createvmess`);
  log('INFO', `   • SSH:      http://localhost:${PORT}/createssh`);
  log('INFO', `   • VLESS:    http://localhost:${PORT}/createvless`);
  log('INFO', `   • TROJAN:   http://localhost:${PORT}/createtrojan`);
  log('INFO', `   • Health:   http://localhost:${PORT}/health`);
  log('INFO', `   • Docs:     http://localhost:${PORT}/docs`);
  log('INFO', `   • Status:   http://localhost:${PORT}/status`);
  log('INFO', `   • Stats:    http://localhost:${PORT}/stats`);
  log('INFO', '🔒 Security: Rate limiting aktif, Helmet headers enabled');
  log('INFO', '📊 Monitoring: Request logging dan error tracking aktif');
});

/**
 * Enhanced graceful shutdown handler
 */
function gracefulShutdown(signal) {
  log('WARN', `🛑 Menerima signal ${signal}, memulai graceful shutdown...`);
  
  // Stop menerima request baru
  server.close((err) => {
    if (err) {
      log('ERROR', 'Error saat menutup server:', err);
    } else {
      log('SUCCESS', '🔴 Server berhasil ditutup');
    }
    
    // Tunggu proses yang sedang berjalan selesai
    setTimeout(() => {
      log('INFO', '👋 Proses shutdown selesai');
      process.exit(err ? 1 : 0);
    }, 1000);
  });

  // Force shutdown jika tidak selesai dalam 15 detik
  setTimeout(() => {
    log('ERROR', '⚠️ Forced shutdown karena timeout');
    process.exit(1);
  }, 15000);
}

// Register signal handlers
process.on('SIGTERM', gracefulShutdown);
process.on('SIGINT', gracefulShutdown);

/**
 * Handler untuk uncaught exception
 */
process.on('uncaughtException', (err) => {
  log('ERROR', '💥 Uncaught Exception - Server akan shutdown:', {
    message: err.message,
    stack: err.stack
  });
  
  // Graceful shutdown
  gracefulShutdown('uncaughtException');
});

/**
 * Handler untuk unhandled promise rejection
 */
process.on('unhandledRejection', (reason, promise) => {
  log('ERROR', '💥 Unhandled Promise Rejection:', {
    reason: reason,
    promise: promise.toString()
  });
  
  // Tidak shutdown untuk unhandled rejection, hanya log
});

/**
 * Handler untuk warning (seperti deprecated functions)
 */
process.on('warning', (warning) => {
  log('WARN', `⚠️ Node.js Warning:`, {
    name: warning.name,
    message: warning.message,
    stack: warning.stack
  });
});

// ===============================================
// EXPORT MODULE (untuk testing)
// ===============================================

module.exports = {
  app,
  server,
  validateAndSanitizeInput,
  handleScriptRequest,
  log
};
