#!/usr/bin/env bash

docker compose exec ollama ollama pull gpt-oss:20b &&
    docker compose exec ollama ollama pull gpt-oss:120b &&
    echo "=== Done ==="
