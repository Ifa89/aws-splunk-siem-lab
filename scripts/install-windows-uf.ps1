<#
.SYNOPSIS
  Install the Splunk Universal Forwarder on Windows Server 2019 and forward the
  Application, System and Security event logs to the wineventlog index.

.USAGE
  Run in an elevated 64-bit "Windows PowerShell" (not the x86 one):

    Set-ExecutionPolicy -Scope Process Bypass -Force
    .\install-windows-uf.ps1 -SplunkServer 172.31.40.91

  -SplunkServer must be the Splunk Server's PRIVATE IP.
  Create the wineventlog index on the Splunk Server first, or the events are dropped.

.NOTES
  If the download returns 404, copy the current 64-bit .msi link from splunk.com
  (Universal Forwarder > Windows) and pass it with -MsiUrl.
  Use a password with letters and numbers only; symbols can break the msiexec argument string.
#>
param(
  [Parameter(Mandatory = $true)] [string] $SplunkServer,
  [string] $Version = '10.6.1.1',
  [string] $Build   = 'b2ae2962645c',
  [string] $MsiUrl,
  [string] $AdminUser = 'admin'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # makes Invoke-WebRequest much faster

if (-not $MsiUrl) {
  $MsiUrl = "https://download.splunk.com/products/universalforwarder/releases/$Version/windows/splunkforwarder-$Version-$Build-windows-x64.msi"
}

$secure = Read-Host 'Choose an admin password for this forwarder (8+ letters/numbers)' -AsSecureString
$AdminPass = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
  [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))
if ($AdminPass.Length -lt 8) { throw 'Password must be at least 8 characters.' }

$msi = Join-Path $env:TEMP 'splunkforwarder.msi'
Write-Host "==> Downloading $MsiUrl"
Invoke-WebRequest -Uri $MsiUrl -OutFile $msi
Get-Item $msi | Select-Object Name, Length

Write-Host '==> Installing silently (service runs as Local System so it can read the Security log)'
$msiArgs = "/i `"$msi`" AGREETOLICENSE=Yes RECEIVING_INDEXER=`"${SplunkServer}:9997`" " +
           "SPLUNKUSERNAME=$AdminUser SPLUNKPASSWORD=$AdminPass USE_LOCAL_SYSTEM=1 LAUNCHSPLUNK=1 /quiet"
$p = Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -PassThru
if ($p.ExitCode -ne 0) { throw "msiexec failed with exit code $($p.ExitCode)" }
Remove-Item $msi -Force

$ufHome  = 'C:\Program Files\SplunkUniversalForwarder'
$splunk  = Join-Path $ufHome 'bin\splunk.exe'
$inputs  = Join-Path $ufHome 'etc\system\local\inputs.conf'

Write-Host '==> Adding Application, System and Security event logs'
$conf = @(
  '',
  '[WinEventLog://Application]', 'disabled = 0', 'index = wineventlog', '',
  '[WinEventLog://System]',      'disabled = 0', 'index = wineventlog', '',
  '[WinEventLog://Security]',    'disabled = 0', 'index = wineventlog', ''
)
Add-Content -Path $inputs -Value $conf -Encoding Ascii
Get-Content $inputs

Write-Host '==> Restarting the forwarder'
& $splunk restart

Write-Host '==> Verifying'
& $splunk list forward-server -auth "${AdminUser}:${AdminPass}"
Get-Service SplunkForwarder

Write-Host ''
Write-Host "Look for '${SplunkServer}:9997' under 'Active forwards'."
Write-Host "Then search in Splunk:  index=wineventlog host=`"$env:COMPUTERNAME`" | stats count by source"
