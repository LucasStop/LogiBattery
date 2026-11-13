#!/usr/bin/env bash
# Compila e roda a sonda do QCY dentro de um .app assinado (ad-hoc).
# O bundle não é enfeite: CoreBluetooth aborta o processo (SIGABRT) sem NSBluetoothAlwaysUsageDescription.
# Uso: tools/qcyctl/run.sh [--seconds 8] [--anc off|anc|outdoor|transparency] [--ldac on|off]
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
out=${TMPDIR:-/tmp}/qcyctl
app="$out/QCYCTL.app"

rm -rf "$out"
mkdir -p "$app/Contents/MacOS"
swiftc -O "$here/main.swift" "$root"/LogiBattery/Core/BLE/*.swift -o "$app/Contents/MacOS/QCYCTL"

cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>QCYCTL</string>
  <key>CFBundleIdentifier</key><string>com.lucasstop.QCYCTL</string>
  <key>CFBundleName</key><string>QCYCTL</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSBluetoothAlwaysUsageDescription</key><string>Para ler a bateria do fone.</string>
</dict>
</plist>
PLIST

codesign --force --sign - --identifier com.lucasstop.QCYCTL "$app" >/dev/null 2>&1
log="$out/qcyctl.log"
: > "$log"

# `open` não herda o ambiente do shell, então o caminho do log vai por argumento.
open -W -n "$app" --args --log "$log" "$@"
cat "$log"
