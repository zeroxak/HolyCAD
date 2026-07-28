#!/bin/zsh
set -euo pipefail

APP_DIR="${0:A:h}"
PROJECT_DIR="${APP_DIR:h}"
ISO_PATH="${TEMPLEOS_ISO:-${PROJECT_DIR}/TempleOS.ISO}"
DISK_PATH="${APP_DIR}/HolyCADShare.img"

if command -v qemu-system-x86_64 >/dev/null 2>&1; then
  QEMU_BIN="$(command -v qemu-system-x86_64)"
elif [[ -x /opt/homebrew/bin/qemu-system-x86_64 ]]; then
  QEMU_BIN=/opt/homebrew/bin/qemu-system-x86_64
elif [[ -x /usr/local/bin/qemu-system-x86_64 ]]; then
  QEMU_BIN=/usr/local/bin/qemu-system-x86_64
else
  print -u2 "qemu-system-x86_64 was not found. Install QEMU with Homebrew first."
  exit 1
fi

if [[ ! -f "$ISO_PATH" ]]; then
  print -u2 "TempleOS ISO not found: $ISO_PATH"
  print -u2 "Place TempleOS.ISO one directory above HolyCAD or set TEMPLEOS_ISO."
  exit 1
fi

if [[ ! -f "$DISK_PATH" ]]; then
  if [[ -f "${DISK_PATH}.gz" ]]; then
    print "Unpacking HolyCADShare.img.gz..."
    gzip -dc "${DISK_PATH}.gz" > "$DISK_PATH"
  else
    print -u2 "HolyCAD transfer image not found: $DISK_PATH"
    exit 1
  fi
fi

exec "$QEMU_BIN" \
  -name HolyCAD \
  -machine pc,accel=tcg \
  -cpu qemu64 \
  -smp 1 \
  -m 512 \
  -boot order=d \
  -drive "file.filename=${DISK_PATH},file.locking=off,if=ide,index=0,format=raw" \
  -drive "file.filename=${ISO_PATH},file.locking=off,if=ide,index=2,media=cdrom,readonly=on,format=raw" \
  -vga std \
  -display cocoa \
  -nic none
