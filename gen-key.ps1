$ErrorActionPreference = "Stop"
$keyPath = Join-Path $HOME ".ssh\id_ed25519_github"
Write-Output "Generating key at: $keyPath"
$result = ssh-keygen -t ed25519 -C "colaQAQ@outlook.com" -f $keyPath -N "" 2>&1
Write-Output "Exit code: $LASTEXITCODE"
Write-Output $result
