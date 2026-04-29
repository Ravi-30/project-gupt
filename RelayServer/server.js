const WebSocket = require('ws');
const http = require('http');

const PORT = Number(process.env.PORT || 3900);
const MAX_PAYLOAD_BYTES = Number(process.env.MAX_PAYLOAD_BYTES || 12 * 1024 * 1024);
const HEARTBEAT_INTERVAL_MS = Number(process.env.HEARTBEAT_INTERVAL_MS || 5000);
const ROOM_CODE_PATTERN = /^[A-Za-z0-9_-]{6,32}$/;

// Room shape: { host: WebSocket | null, client: WebSocket | null }
const rooms = new Map();

const server = http.createServer((req, res) => {
    if (req.url === '/healthz') {
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({
            status: 'ok',
            rooms: rooms.size,
            clients: wss.clients.size
        }));
        return;
    }

    res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8' });
    res.end("GUPT Relay Server is running!\n");
});

const wss = new WebSocket.Server({
    server,
    maxPayload: MAX_PAYLOAD_BYTES
});

function heartbeat() {
    this.isAlive = true;
}

const interval = setInterval(() => {
    wss.clients.forEach((ws) => {
        if (ws.isAlive === false) {
            console.log("[-] Disconnecting stale WebSocket");
            ws.terminate();
            return;
        }

        ws.isAlive = false;
        ws.ping();
    });
}, HEARTBEAT_INTERVAL_MS);

wss.on('close', () => {
    clearInterval(interval);
});

wss.on('connection', (ws, req) => {
    ws.isAlive = true;
    ws.on('pong', heartbeat);

    const path = req.url || '';
    console.log(`[+] New connection attempt: ${path}`);

    const parts = path.split('/').filter(Boolean);
    if (parts.length !== 2) {
        console.error("[-] Invalid path. Must be /host/CODE or /client/CODE");
        ws.close(1008, "Invalid path");
        return;
    }

    const [type, roomCode] = parts;
    if ((type !== 'host' && type !== 'client') || !ROOM_CODE_PATTERN.test(roomCode)) {
        ws.close(1008, "Invalid room code or peer type");
        return;
    }

    if (!rooms.has(roomCode)) {
        rooms.set(roomCode, { host: null, client: null });
    }

    const room = rooms.get(roomCode);
    if (type === 'host') {
        if (room.host) {
            console.warn(`[!] Host already exists for room ${roomCode}. Replacing...`);
            room.host.close(1012, "Host replaced");
        }
        room.host = ws;
    } else {
        if (room.client) {
            console.warn(`[!] Client already exists for room ${roomCode}. Replacing...`);
            room.client.close(1012, "Client replaced");
        }
        room.client = ws;
    }

    ws.binaryType = 'nodebuffer';
    let msgCount = 0;

    ws.on('message', (message) => {
        msgCount += 1;

        if (message.length > MAX_PAYLOAD_BYTES) {
            console.warn(`[!] Payload too large from ${type} in room ${roomCode}`);
            ws.close(1009, "Payload too large");
            return;
        }

        if (msgCount <= 5 || msgCount % 100 === 0) {
            console.log(`[RELAY] ${type}→peer in room ${roomCode} | msg #${msgCount} | ${message.length} bytes`);
        }

        if (type === 'host' && room.client && room.client.readyState === WebSocket.OPEN) {
            room.client.send(message);
        } else if (type === 'client' && room.host && room.host.readyState === WebSocket.OPEN) {
            room.host.send(message);
        }
    });

    ws.on('close', () => {
        console.log(`[-] Disconnected ${type.toUpperCase()} from room ${roomCode}`);

        if (type === 'host') {
            room.host = null;
            if (room.client) {
                room.client.close(1001, "Host disconnected");
            }
            rooms.delete(roomCode);
            return;
        }

        room.client = null;
        if (!room.host) {
            rooms.delete(roomCode);
        }
    });

    ws.on('error', (err) => {
        console.error(`Error on ${type} in room ${roomCode}:`, err.message);
    });
});

server.listen(PORT, () => {
    console.log(`🚀 GUPT WebSocket Relay Server running on port ${PORT}`);
});

server.on('error', (error) => {
    console.error(`Relay server failed to start on port ${PORT}:`, error.message);
    process.exitCode = 1;
});

function shutdown(signal) {
    console.log(`[!] Received ${signal}. Closing relay server...`);
    wss.clients.forEach((client) => {
        try {
            client.close(1001, "Server shutting down");
        } catch (error) {
            console.error("Failed to close client cleanly:", error.message);
        }
    });
    server.close(() => process.exit(0));
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
