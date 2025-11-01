#!/usr/bin/env bash

ollama serve &
pid=$!
sleep 5
ollama pull gpt-oss:20b &&
    echo "🟢 Done!"

wait $pid
