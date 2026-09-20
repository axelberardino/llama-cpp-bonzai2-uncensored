#!/usr/bin/env bash
# Download the Bonsai model if missing, build llama-cli if missing, then chat with the model in the terminal.
set -euo pipefail
cd "$(dirname "$0")"

MODEL_FILE="Bonsai-2-27B-PQ2_0-CRACK.gguf"
MODEL_URL="https://huggingface.co/dealignai/Bonsai-2-27B-Ternary-CRACK-GGUF/resolve/main/${MODEL_FILE}"
CLI_BIN="./build/bin/llama-cli"

if [ ! -f "$MODEL_FILE" ]; then
    echo "downloading $MODEL_FILE ..."
    curl -L --fail --retry 3 -C - -o "$MODEL_FILE.part" "$MODEL_URL"
    mv "$MODEL_FILE.part" "$MODEL_FILE"
fi

if [ ! -x "$CLI_BIN" ]; then
    echo "building llama-cli ..."
    JOBS=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)
    cmake -B build -DCMAKE_BUILD_TYPE=Release
    cmake --build build --target llama-cli -j "$JOBS"
fi

exec "$CLI_BIN" -m "$MODEL_FILE" \
    -ngl 99 -fa on -c 32768 \
    --temp 1.0 --top-p 0.95 --top-k 20 \
    --jinja \
    "$@"
