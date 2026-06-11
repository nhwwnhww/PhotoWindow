#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

swiftc \
  -o /tmp/PhotoWindowVerifyCore \
  $(find PhotoWindow/Models PhotoWindow/Repositories PhotoWindow/Services -name '*.swift' ! -name 'NotificationService.swift' | sort) \
  Scripts/VerifyCore.swift

/tmp/PhotoWindowVerifyCore
