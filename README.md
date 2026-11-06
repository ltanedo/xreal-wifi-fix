# xreal-wifi-fix

Stops XREAL glasses from disconnecting a Windows laptop from Wi-Fi.

## The problem

On some work laptops, plugging in XREAL glasses (seen on the One Pro) drops Wi-Fi immediately. Reconnecting fails with a message about not being able to connect to two networks, or that the network is blocked by Group Policy.

## Why it happens

The glasses expose a USB network adapter (`UsbNcm Host Device` / `CDC ECM`) in addition to the display, audio and buttons. Windows treats that adapter as a wired Ethernet connection.

Many managed laptops have these Group Policy settings (Windows Connection Manager):

| Setting | Registry value | Effect |
|---|---|---|
| Minimize the number of simultaneous connections | `fMinimizeConnections = 3` | Disconnects Wi-Fi when a wired connection appears |
| Prohibit connection to non-domain networks when connected to domain authenticated network | `fBlockNonDomain = 1` | Blocks reconnecting to Wi-Fi |

Both live under `HKLM\SOFTWARE\Policies\Microsoft\Windows\WcmSvc\GroupPolicy`.

The `Microsoft-Windows-WLAN-AutoConfig/Operational` event log shows it:

- *"The network is disconnected due to a policy disabling auto connect on this interface."*
- *"The wireless network is blocked by the group policy."*

## The fix

Disable only the glasses' network interfaces. The display, audio and buttons keep working.

1. Plug in the glasses.
2. Open PowerShell **as administrator**.
3. Run:

```powershell
.\xreal-wifi-fix.ps1 -Action Disable
```

4. Reconnect to Wi-Fi.

Other commands:

```powershell
.\xreal-wifi-fix.ps1                  # show the XREAL interfaces and the policy values
.\xreal-wifi-fix.ps1 -Action Enable   # undo, e.g. before a firmware update over USB
```

If script execution is blocked, run it with:

```powershell
powershell -ExecutionPolicy Bypass -File .\xreal-wifi-fix.ps1 -Action Disable
```

### One-liner without the script

From an elevated PowerShell with the glasses connected:

```powershell
Get-PnpDevice -PresentOnly | ? { $_.InstanceId -match 'VID_3318' -and ($_.Class -eq 'Net' -or $_.FriendlyName -match 'NCM|ECM|RNDIS') } | Disable-PnpDevice -Confirm:$false
```

## Notes

- **Requires admin rights.** Without them you'll need your IT team to disable the adapter or adjust the policy.
- **"Generic failure" from `Disable-PnpDevice`** usually means the glasses aren't connected. Windows can't disable a device that isn't present.
- **Each USB port creates its own copy of the device.** If you plug into a port you haven't used before, run the script again while the glasses are connected.
- **Firmware updates** that go over the USB network link need the adapter enabled. Run `-Action Enable` first, then disable it again afterwards.
- The script matches XREAL's USB vendor ID (`VID_3318`). It has only been tested with the One Pro.
