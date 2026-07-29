#!/bin/zsh
set -euo pipefail

APP_DIR="${0:A:h}"
PROJECT_DIR="${APP_DIR:h}"
ISO_PATH="${TEMPLEOS_ISO:-${PROJECT_DIR}/TempleOS.ISO}"
SOURCE_DISK_PATH="${APP_DIR}/HolyCADShare.img"
PROJECT_DISK_PATH="${APP_DIR}/HolyCADProjects.img"
DISK_SIZE=67108864
TEMP_DISK_PATH=""

cleanup_temp_disk() {
  if [[ -n "$TEMP_DISK_PATH" && -f "$TEMP_DISK_PATH" ]]; then
    rm -f -- "$TEMP_DISK_PATH"
  fi
}

trap cleanup_temp_disk EXIT
trap 'exit 1' HUP INT TERM

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

ensure_disk_image() {
  local disk_path="$1"
  local disk_label="$2"
  local refresh_from_bundle="$3"
  local compressed_path="${disk_path}.gz"
  local actual_size

  if [[ -f "$disk_path" ]]; then
    actual_size="$(stat -f '%z' "$disk_path")"
    if [[ "$actual_size" -ne "$DISK_SIZE" &&
          "$refresh_from_bundle" != "yes" ]]; then
      print -u2 "${disk_label} has the wrong size: ${actual_size} bytes"
      print -u2 "Expected ${DISK_SIZE} bytes. Move or remove the invalid image manually."
      exit 1
    fi
    if [[ "$refresh_from_bundle" != "yes" ]]; then
      return
    fi
  fi

  if [[ ! -f "$compressed_path" ]]; then
    print -u2 "${disk_label} was not found: ${compressed_path}"
    exit 1
  fi

  TEMP_DISK_PATH="$(mktemp "${disk_path}.tmp.XXXXXX")"
  gzip -dc "$compressed_path" > "$TEMP_DISK_PATH"
  actual_size="$(stat -f '%z' "$TEMP_DISK_PATH")"
  if [[ "$actual_size" -ne "$DISK_SIZE" ]]; then
    print -u2 "Unpacked image has the wrong size: ${actual_size} bytes"
    print -u2 "Expected ${DISK_SIZE} bytes. The temporary image will be removed."
    exit 1
  fi

  if [[ "$refresh_from_bundle" == "yes" && -f "$disk_path" ]]; then
    if cmp -s "$TEMP_DISK_PATH" "$disk_path"; then
      rm -f -- "$TEMP_DISK_PATH"
      TEMP_DISK_PATH=""
      return
    fi
    print "Refreshing ${disk_path:t}..."
    mv -f "$TEMP_DISK_PATH" "$disk_path"
    TEMP_DISK_PATH=""
    return
  fi

  print "Unpacking ${compressed_path:t}..."
  mv -n "$TEMP_DISK_PATH" "$disk_path"
  if [[ -f "$TEMP_DISK_PATH" ]]; then
    print -u2 "${disk_path:t} appeared while unpacking; it was not overwritten."
    exit 1
  fi
  TEMP_DISK_PATH=""
}

ensure_disk_image "$SOURCE_DISK_PATH" "HolyCAD source disk" "yes"
ensure_disk_image "$PROJECT_DISK_PATH" "HolyCAD project disk" "no"

exec "$QEMU_BIN" \
  -name HolyCAD \
  -machine pc,accel=tcg \
  -cpu qemu64 \
  -smp 1 \
  -m 512 \
  -boot order=d \
  -drive "file.filename=${SOURCE_DISK_PATH},file.locking=off,if=ide,index=0,format=raw" \
  -drive "file.filename=${PROJECT_DISK_PATH},file.locking=off,if=ide,index=1,format=raw" \
  -drive "file.filename=${ISO_PATH},file.locking=off,if=ide,index=2,media=cdrom,readonly=on,format=raw" \
  -vga std \
  -display cocoa \
  -nic none
