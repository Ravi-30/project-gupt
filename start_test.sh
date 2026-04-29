#!/bin/bash
set -euo pipefail

echo "=========================================="
echo "🚀 Starting GUPT Local Test Environment"
echo "=========================================="

# 1. Start the Relay Server
echo "📡 [1/3] Booting Relay Server on port 3900..."

if ! command -v node >/dev/null 2>&1; then
    echo "❌ Error: Node.js is not installed! The Relay Server requires Node.js."
    echo "Please install it from https://nodejs.org/ and try again."
    exit 1
fi

cd RelayServer
npm install ws --silent > /dev/null 2>&1 || true
# Ensure no ghost node server is hogging port 3900
lsof -ti:3900 | xargs kill -9 2>/dev/null || true
node server.js > /dev/null 2>&1 &
RELAY_PID=$!
cd ..
echo "✅ Relay Server running in background (PID: $RELAY_PID)"

# 2. Build the App
echo "🔨 [2/3] Compiling GUPT.app... (This may take a minute)"
./build_app.sh > build.log 2>&1 || {
    echo "❌ Build failed! Check build.log for details."
    kill $RELAY_PID
    exit 1
}
echo "✅ Build complete."

# 3. Clear Quarantine and Launch
echo "🖥️ [3/3] Bypassing Gatekeeper and Launching Application..."
xattr -cr GUPT.app
open GUPT.app

echo "=========================================="
echo "✨ GUPT is now running! The Relay Server is active in the background."
echo "🛑 Press Ctrl+C in this terminal window when you are done testing to safely shut down the server."
echo "=========================================="

# Clean up the background server process on exit
trap "echo -e '\n🛑 Shutting down relay server...'; kill $RELAY_PID; exit" INT TERM
wait $RELAY_PID
