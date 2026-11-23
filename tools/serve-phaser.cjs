// Secure local dev server for Phaser idle RPG
// Binds 127.0.0.1 only, GET/HEAD, no path traversal, restricted routes

const http = require('http');
const fs = require('fs');
const path = require('path');

const PORT = parseInt(process.env.PORT || '4173', 10);
const HOST = '127.0.0.1';
const ROOT = path.resolve(__dirname, '..');

const MIME = {
 '.html': 'text/html; charset=utf-8',
 '.css': 'text/css; charset=utf-8',
 '.js': 'application/javascript; charset=utf-8',
 '.mjs': 'application/javascript; charset=utf-8',
 '.json': 'application/json; charset=utf-8',
 '.png': 'image/png',
 '.jpg': 'image/jpeg',
 '.jpeg': 'image/jpeg',
 '.gif': 'image/gif',
 '.svg': 'image/svg+xml',
 '.ico': 'image/x-icon'
};

const ALLOWED_DIRS = [
 path.join(ROOT, 'phaser'),
 path.join(ROOT, 'assets'),
 path.join(ROOT, 'node_modules', 'phaser', 'dist')
];

function isPathInside(filePath, dir) {
 const rel = path.relative(dir, filePath);
 return rel && !rel.startsWith('..') && !path.isAbsolute(rel);
}

function safeResolve(reqUrl) {
 // Reject backslashes in raw URL (encoded or not)
 if (/\\/.test(reqUrl)) return null;
 // Reject encoded dot-dot sequences in raw URL
 if (/%2e%2e/i.test(reqUrl) || /%252e/i.test(reqUrl)) return null;

 let pathname;
 try {
 const parsed = new URL(reqUrl, `http://${HOST}:${PORT}`);
 pathname = decodeURIComponent(parsed.pathname);
 } catch {
 return null; // malformed URL
 }

 // Normalize to forward slashes for matching, but use path.normalize for resolution
 const normalized = pathname.replace(/\\/g, '/');

 // Reject any remaining .. after decode
 if (/\.\./.test(normalized)) return null;

 // Root redirect
 if (normalized === '/' || normalized === '') {
 return { redirect: '/phaser/' };
 }

 // Map routes to filesystem
 let resolvedFile = null;

 if (normalized === '/phaser/' || normalized === '/phaser') {
 resolvedFile = path.join(ROOT, 'phaser', 'index.html');
 } else if (normalized.startsWith('/phaser/')) {
 const rel = normalized.slice('/phaser/'.length);
 if (!rel) return { redirect: '/phaser/' };
 resolvedFile = path.join(ROOT, 'phaser', rel);
 } else if (normalized.startsWith('/assets/')) {
 const rel = normalized.slice('/assets/'.length);
 if (!rel) return null;
 resolvedFile = path.join(ROOT, 'assets', rel);
 } else if (normalized === '/vendor/phaser.js') {
 resolvedFile = path.join(ROOT, 'node_modules', 'phaser', 'dist', 'phaser.js');
 } else {
 return null; // unknown route
 }

 // Normalize and validate containment
 const absPath = path.normalize(resolvedFile);
 const inAllowed = ALLOWED_DIRS.some(dir => isPathInside(absPath, dir));
 if (!inAllowed) return null;

 return { file: absPath };
}

const server = http.createServer((req, res) => {
 // Method check
 if (req.method !== 'GET' && req.method !== 'HEAD') {
 res.writeHead(405, { 'Content-Type': 'text/plain' });
 res.end('Method Not Allowed');
 return;
 }

 const result = safeResolve(req.url);

 if (!result) {
 res.writeHead(404, { 'Content-Type': 'text/plain' });
 res.end('Not Found');
 return;
 }

 if (result.redirect) {
 res.writeHead(302, { 'Location': result.redirect });
 res.end();
 return;
 }

 const filePath = result.file;
 const ext = path.extname(filePath).toLowerCase();
 const contentType = MIME[ext] || 'application/octet-stream';

 if (req.method === 'HEAD') {
 try {
 const stat = fs.statSync(filePath);
 res.writeHead(200, {
 'Content-Type': contentType,
 'Content-Length': stat.size,
 'Cache-Control': 'no-cache'
 });
 res.end();
 } catch {
 res.writeHead(404, { 'Content-Type': 'text/plain' });
 res.end('Not Found');
 }
 return;
 }

 fs.readFile(filePath, (err, data) => {
 if (err) {
 if (err.code === 'ENOENT') {
 res.writeHead(404, { 'Content-Type': 'text/plain' });
 res.end('Not Found');
 } else {
 res.writeHead(500, { 'Content-Type': 'text/plain' });
 res.end('Internal Server Error');
 }
 return;
 }
 res.writeHead(200, {
 'Content-Type': contentType,
 'Content-Length': data.length,
 'Cache-Control': 'no-cache'
 });
 res.end(data);
 });
});

server.listen(PORT, HOST, () => {
 console.log(`AFK Arena Phaser server: http://${HOST}:${PORT}/phaser/`);
 console.log(`Serving from: ${ROOT}`);
});

server.on('error', (err) => {
 if (err.code === 'EADDRINUSE') {
 console.error(`Port ${PORT} in use. Set PORT env to override.`);
 } else {
 console.error('Server error:', err.message);
 }
 process.exit(1);
});