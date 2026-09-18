#!/usr/bin/env bash
# Download the Bonsai model if missing, build llama-server if missing, then start a plain local server.
set -euo pipefail
cd "$(dirname "$0")"

MODEL_FILE="Bonsai-2-27B-PQ2_0-CRACK.gguf"
MODEL_URL="https://huggingface.co/dealignai/Bonsai-2-27B-Ternary-CRACK-GGUF/resolve/main/${MODEL_FILE}"
SERVER_BIN="./build/bin/llama-server"

if [ ! -f "$MODEL_FILE" ]; then
    echo "downloading $MODEL_FILE ..."
    curl -L --fail --retry 3 -C - -o "$MODEL_FILE.part" "$MODEL_URL"
    mv "$MODEL_FILE.part" "$MODEL_FILE"
fi

if [ ! -x "$SERVER_BIN" ]; then
    echo "building llama-server ..."
    JOBS=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)
    cmake -B build -DCMAKE_BUILD_TYPE=Release -DLLAMA_BUILD_TESTS=OFF
    cmake --build build --target llama-server -j "$JOBS"
fi

exec "$SERVER_BIN" -m "$MODEL_FILE" \
    -ngl 99 -fa on -c 32768 \
    --temp 1.0 --top-p 0.95 --top-k 20 --host 127.0.0.1 \
    --port 8080 \
    --jinja \
    "$@"
