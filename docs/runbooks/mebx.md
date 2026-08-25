# Runbook: MEBx

Steps for how I configure MEBx on a Lenovo M920q

## Step 1 — BIOS settings

- `Advanced → Intel Manageability`:
 - `Intel Manageability Control`: **Enabled**
 - `Intel Manageability Reset`: **Enabled**
 - `Press <Ctrl-P> to Enter MEBx`: **Enabled**
- Press `F10` to save and exit

## Step 1 — MEBx settings

- `Intel AMT Configuration`:
 - `User Consent`: **NONE**
 - `Network Setup`:
   - `Intel ME Network Name Settings`:
     - `Host Name`: `mebx<N>`
     - `Domain Name`: `home.arpa`
     - `Shared/Dedicated FQDN`: **Dedicated**
   - `TCP/IP Settings → Wired LAN IPV4 Configuration`: 
     - `DHCP Mode`: **Disabled**
     - `IPV4 Address`: `X.X.X.X`
     - `Default Gateway Address`: `X.X.X.X`
     - `Preferred DNS Address`: `X.X.X.X`
     - `Alternate DNS Address`: `1.1.1.1`
- Exit