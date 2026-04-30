#!/usr/bin/env bash

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env-bootstrap.sh"
cd "$DEV_WORKSPACE_DIR"

sh "$DEV_SCRIPTS_DIR/terminal-service-stop.sh"
