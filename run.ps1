$ErrorActionPreference = "Stop"

$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $AppDir
$IsoPath = if ($env:TEMPLEOS_ISO) {
    $env:TEMPLEOS_ISO
} else {
    Join-Path $ProjectDir "TempleOS.ISO"
}
$SourceDiskPath = Join-Path $AppDir "HolyCADShare.img"
$ProjectDiskPath = Join-Path $AppDir "HolyCADProjects.img"
$DiskSize = [Int64]67108864

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
$IsoPath = (Resolve-Path -LiteralPath $IsoPath).Path

function Ensure-DiskImage {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DiskPath,
        [Parameter(Mandatory = $true)]
        [string]$Label,
        [Parameter(Mandatory = $true)]
        [bool]$RefreshFromBundle
    )

    if (Test-Path -LiteralPath $DiskPath) {
        $ActualDiskSize = (Get-Item -LiteralPath $DiskPath).Length
        if (($ActualDiskSize -ne $DiskSize) -and (-not $RefreshFromBundle)) {
            throw "$Label has the wrong size: $ActualDiskSize bytes. Expected $DiskSize bytes. Move or remove the invalid image manually."
        }
        if (-not $RefreshFromBundle) {
            return
        }
    }

    $CompressedDiskPath = "$DiskPath.gz"
    if (-not (Test-Path -LiteralPath $CompressedDiskPath)) {
        throw "$Label was not found at $CompressedDiskPath."
    }

    $TempDiskPath = "$DiskPath.tmp.$([Guid]::NewGuid().ToString('N'))"
    try {
        $InputStream = [System.IO.File]::OpenRead($CompressedDiskPath)
        try {
            $GzipStream = [System.IO.Compression.GZipStream]::new(
                $InputStream,
                [System.IO.Compression.CompressionMode]::Decompress
            )
            try {
                $OutputStream = [System.IO.File]::Create($TempDiskPath)
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

        $ActualDiskSize = (Get-Item -LiteralPath $TempDiskPath).Length
        if ($ActualDiskSize -ne $DiskSize) {
            throw "Unpacked image has the wrong size: $ActualDiskSize bytes. Expected $DiskSize bytes."
        }
        if (Test-Path -LiteralPath $DiskPath) {
            if (-not $RefreshFromBundle) {
                throw "$(Split-Path -Leaf $DiskPath) appeared while unpacking; it was not overwritten."
            }
            $BundledHash = (Get-FileHash -LiteralPath $TempDiskPath -Algorithm SHA256).Hash
            $CurrentHash = (Get-FileHash -LiteralPath $DiskPath -Algorithm SHA256).Hash
            if ($BundledHash -eq $CurrentHash) {
                return
            }
            Write-Host "Refreshing $(Split-Path -Leaf $DiskPath)..."
            Move-Item -LiteralPath $TempDiskPath -Destination $DiskPath -Force
            $TempDiskPath = $null
            return
        }

        Write-Host "Unpacking $(Split-Path -Leaf $CompressedDiskPath)..."
        [System.IO.File]::Move($TempDiskPath, $DiskPath)
        $TempDiskPath = $null
    } finally {
        if ($TempDiskPath -and (Test-Path -LiteralPath $TempDiskPath)) {
            Remove-Item -LiteralPath $TempDiskPath -Force -ErrorAction SilentlyContinue
        }
    }
}

Ensure-DiskImage -DiskPath $SourceDiskPath -Label "HolyCAD source disk" -RefreshFromBundle $true
Ensure-DiskImage -DiskPath $ProjectDiskPath -Label "HolyCAD project disk" -RefreshFromBundle $false

Push-Location $AppDir
try {
    & $QemuPath `
        -name "HolyCAD" `
        -machine "pc,accel=tcg" `
        -cpu "qemu64" `
        -smp "1" `
        -m "512" `
        -boot "order=d" `
        -drive "file.filename=$SourceDiskPath,file.locking=off,if=ide,index=0,format=raw" `
        -drive "file.filename=$ProjectDiskPath,file.locking=off,if=ide,index=1,format=raw" `
        -drive "file.filename=$IsoPath,if=ide,index=2,media=cdrom,readonly=on,format=raw" `
        -vga "std" `
        -display "sdl" `
        -nic "none"
} finally {
    Pop-Location
}
