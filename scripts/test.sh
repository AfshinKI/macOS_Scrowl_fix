#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/module-cache
xcrun swiftc -module-cache-path "$PWD/build/module-cache" Sources/ScrollPolicy.swift Tests/main.swift -o build/policy-tests
build/policy-tests
xcrun swiftc -typecheck -target "$(uname -m)-apple-macos13.0" -module-cache-path "$PWD/build/module-cache" Sources/ScrollPolicy.swift Sources/main.swift
