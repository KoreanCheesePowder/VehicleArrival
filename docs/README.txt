C.P Vehicle Arrival Edge v1.4.1 - Online Recovery

For already registered devices, run UPDATE-EXISTING.cmd.
Retains the existing packageKey (cp-vehicle-arrival), hub, channel, device ID, profile VID, custom capabilities and existing routines.

Change list:
- Online health restored on successful NAS TCP connection and incoming messages.
- Device goes offline after actual TCP disconnection / connection failure; automatic reconnect retries every 5s.
- Heartbeat reasserts online health every 60s while a TCP connection is active.
- Default NAS IP for new devices updated to 192.168.1.53 (existing settings are NOT overwritten).
- Existing vehicle events, entry/exit switches, 30s pulses and CONFIG/family plate handling unchanged.
- Installer avoids re-creating capabilities and device presentation (no duplicate profile/VID).
- Reuse existing driver package key and channel, not a new driver package.

IMPORTANT: An existing device set to NAS IP 192.168.1.92 must be manually updated to 192.168.1.53 in the SmartThings settings; packaged profile defaults do not override saved preferences.
TCP port stays 19093 unless the NAS service is configured differently.

Validation: local Lua syntax and ZIP integrity; live SmartThings hub deployment must be verified on site.
