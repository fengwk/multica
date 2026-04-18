#!/bin/sh
set -eu

echo "Running database migrations..."
./migrate up

echo "Starting backend on port ${BACKEND_PORT:-8080}..."
PORT="${BACKEND_PORT:-8080}" ./server &
backend_pid=$!

echo "Starting web on port ${PORT:-3000}..."
node apps/web/server.js &
web_pid=$!

cleanup() {
  kill "$backend_pid" "$web_pid" 2>/dev/null || true
  wait "$backend_pid" 2>/dev/null || true
  wait "$web_pid" 2>/dev/null || true
}

trap cleanup INT TERM EXIT

while kill -0 "$backend_pid" 2>/dev/null && kill -0 "$web_pid" 2>/dev/null; do
  sleep 2
done

if ! kill -0 "$backend_pid" 2>/dev/null; then
  echo "Backend process exited unexpectedly"
fi

if ! kill -0 "$web_pid" 2>/dev/null; then
  echo "Web process exited unexpectedly"
fi

exit 1
