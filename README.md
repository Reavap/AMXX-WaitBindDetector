# AMXX-WaitBindDetector
AMX Mod X plugin that detects clients using binds with "+jump; wait; -jump" or "+duck; wait; -duck".
These binds mainly gives an advantage in movement based mods.

## Functionality ##
* Notification to admins when a player is detected (default access level *ADMIN_KICK*)
* Punishment on detection
* Logging to file on detection (path: *amxmodx/logs/waitbinds.log*)
* Compatible with AMXX 1.8.2 and 1.8.3

## Cvars ##
#### wbd_punishment ####
* 0 - No action
* 1 - Slay
* 2 - Kick

#### wbd_log_detection ####
* 0 - Don't log
* 1 - Log
