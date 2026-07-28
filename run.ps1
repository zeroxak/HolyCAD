$ErrorActionPreference = "Stop"

$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $AppDir
$IsoPath = if ($env:TEMPLEOS_ISO) {
    $env:TEMPLEOS_ISO
} else {
    Join-Path $ProjectDir "TempleOS.ISO"
}
$DiskPath = Join-Path $AppDir "HolyCADShare.img"
$CompressedDiskPath = "$DiskPath.gz"

$QemuCommand = Get-Command "qemu-system-x86_64.exe" -ErrorAction SilentlyContinue
if ($QemuCommand) {
    $QemuPath = $QemuCommand.Source
} else {
    $QemuPath = "C:\Program Files\qemu\qemu-system-x86_64.exe"
}

if (-not (Test-Path $QemuPath)) {
    throw "qemu-system-x86_64.exe was not found on PATH or in C:\Program Files\qemu."
}
if (-not (Test-Path $IsoPath)) {
    throw "TempleOS ISO not found at $IsoPath. Place TempleOS.ISO one directory above HolyCAD or set TEMPLEOS_ISO."
}
if (-not (Test-Path $DiskPath)) {
    if (-not (Test-Path $CompressedDiskPath)) {
        throw "Neither HolyCADShare.img nor HolyCADShare.img.gz was found."
    }

    Write-Host "Unpacking HolyCADShare.img.gz..."
    $InputStream = [System.IO.File]::OpenRead($CompressedDiskPath)
    try {
        $GzipStream = [System.IO.Compression.GZipStream]::new(
            $InputStream,
            [System.IO.Compression.CompressionMode]::Decompress
        )
        try {
            $OutputStream = [System.IO.File]::Create($DiskPath)
            try {
                $GzipStream.CopyTo($OutputStream)
            } finally {
                $OutputStream.Dispose()
            }
        } finally {
            $GzipStream.Dispose()
        }
    } finally {
        $InputStream.Dispose()
    }
}

Push-Location $AppDir
try {
    & $QemuPath `
        -name "HolyCAD" `
        -machine "pc,accel=tcg" `
        -cpu "qemu64" `
        -smp "1" `
        -m "512" `
        -boot "order=d" `
        -drive "file=HolyCADShare.img,if=ide,index=0,format=raw" `
        -drive "file=..\TempleOS.ISO,if=ide,index=2,media=cdrom,readonly=on,format=raw" `
        -vga "std" `
        -display "sdl" `
        -nic "none"
} finally {
    Pop-Location
}
