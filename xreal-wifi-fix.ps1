<#
.SYNOPSIS
    Stops XREAL glasses from knocking a Windows laptop off Wi-Fi.

.DESCRIPTION
    XREAL glasses (tested on the One Pro) expose a USB network adapter
    (UsbNcm / CDC ECM) alongside the display. Windows treats it as a wired
    connection, so on machines where Group Policy sets "Minimize the number of
    simultaneous connections" (fMinimizeConnections) Wi-Fi is dropped as soon
    as the glasses are plugged in, and "Prohibit connection to non-domain
    networks" (fBlockNonDomain) blocks reconnecting.

    This script disables (or re-enables) only the glasses' network interfaces.
    Display, audio and buttons keep working.

.PARAMETER Action
    Status  - show the XREAL network interfaces and the relevant policies (default)
    Disable - disable the interfaces of the connected glasses (admin)
    Enable  - re-enable them, e.g. before a firmware update over USB (admin)

.EXAMPLE
    .\xreal-wifi-fix.ps1
    .\xreal-wifi-fix.ps1 -Action Disable
    .\xreal-wifi-fix.ps1 -Action Enable
#>
[CmdletBinding()]
param(
    [ValidateSet('Status', 'Disable', 'Enable')]
    [string]$Action = 'Status'
)

$XrealVendorId = 'VID_3318'

function Get-XrealNetDevice {
    param([switch]$PresentOnly)
    Get-PnpDevice -PresentOnly:$PresentOnly |
        Where-Object {
            $_.InstanceId -match $XrealVendorId -and
            ($_.Class -eq 'Net' -or $_.FriendlyName -match 'NCM|ECM|RNDIS')
        }
}

function Test-Admin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).
        IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if ($Action -eq 'Status') {
    $policy = Get-ItemProperty 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WcmSvc\GroupPolicy' -ErrorAction SilentlyContinue
    Write-Host "Connection policies (HKLM\SOFTWARE\Policies\Microsoft\Windows\WcmSvc\GroupPolicy):"
    Write-Host "  fMinimizeConnections : $(if ($null -ne $policy.fMinimizeConnections) { $policy.fMinimizeConnections } else { 'not set' })  (3 = prevent Wi-Fi when on Ethernet)"
    Write-Host "  fBlockNonDomain      : $(if ($null -ne $policy.fBlockNonDomain) { $policy.fBlockNonDomain } else { 'not set' })  (1 = block non-domain networks)"
    Write-Host ""
    $devices = Get-XrealNetDevice
    if (-not $devices) { Write-Host "No XREAL network interfaces found. Plug in the glasses and run again."; return }
    $devices | Select-Object Status, Present, Class, FriendlyName, InstanceId | Format-Table -AutoSize -Wrap
    return
}

if (-not (Test-Admin)) {
    Write-Error "Run this from an elevated PowerShell (Run as administrator)."
    exit 1
}

$devices = Get-XrealNetDevice -PresentOnly
if (-not $devices) {
    Write-Error "No connected XREAL network interfaces found. Plug in the glasses first; Windows can't change a device that isn't present."
    exit 1
}

foreach ($d in $devices) {
    if ($Action -eq 'Disable') { $d | Disable-PnpDevice -Confirm:$false } else { $d | Enable-PnpDevice -Confirm:$false }
    Write-Host "$($Action)d: $($d.FriendlyName)  [$($d.InstanceId)]"
}

if ($Action -eq 'Disable') {
    Write-Host "`nDone. Reconnect to Wi-Fi. If you later use a USB port you haven't used before, run this again with the glasses connected."
}
