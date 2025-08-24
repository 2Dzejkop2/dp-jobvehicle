# jobvehicle

FiveM resource that adds a /jobvehicle command. It asks for confirmation via ox_lib alertDialog and updates the vehicle's job in your database to your current job.

## Requirements
- ox_lib
- oxmysql
- ESX (es_extended) or QB-Core (qb-core) or your own framework logic

## Installation
1. Put the `jobvehicle` folder in your server resources.
2. Ensure dependencies are started before this resource: `oxmysql`, `ox_lib`, and your framework.
3. Configure `config.lua` to match your framework and DB columns. For ESX, the default matches your provided schema (owned_vehicles with a `job` column).
4. Add `ensure jobvehicle` to your server.cfg.

## Usage
- Type `/jobvehicle` while seated as the driver. A confirmation dialog will appear showing your job (e.g., POLICE). Confirm to set the vehicle's DB `job` to your current job.
- Default keybind also registered: F9

## Database
Example ESX schema you provided includes a `job` column:

```sql
CREATE TABLE IF NOT EXISTS `owned_vehicles` (
  `owner` varchar(60) DEFAULT NULL,
  `plate` varchar(12) NOT NULL,
  `vehicle` longtext DEFAULT NULL,
  `type` varchar(20) NOT NULL DEFAULT 'car',
  `job` varchar(20) DEFAULT NULL,
  `stored` tinyint(4) NOT NULL DEFAULT 0,
  `parking` varchar(60) DEFAULT NULL,
  `pound` varchar(60) DEFAULT NULL,
  `mileage` float DEFAULT 0,
  `photos` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT '[]' CHECK (json_valid(`photos`)),
  `flipper_installed` tinyint(1) DEFAULT 0,
  `glovebox` longtext DEFAULT NULL,
  `trunk` longtext DEFAULT NULL,
  `alarm` int(1) NOT NULL DEFAULT 0,
  `in_garage` tinyint(1) DEFAULT 0,
  `garage_id` varchar(50) DEFAULT 'A',
  `garage_type` varchar(50) DEFAULT 'car',
  `job_personalowned` varchar(50) DEFAULT '',
  `property` int(10) DEFAULT 0,
  `impound` int(10) DEFAULT 0,
  `impound_data` longtext DEFAULT '',
  `adv_stats` longtext DEFAULT '{"plate":"nil","mileage":0.0,"maxhealth":1000.0}',
  PRIMARY KEY (`plate`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;
```

This resource will run:
- ESX: `UPDATE owned_vehicles SET job = ? WHERE plate = ?`
- QB:  `UPDATE player_vehicles SET job = ? WHERE plate = ?`

Adjust columns in `config.lua` if needed.

## Notes
- The confirmation dialog uses ox_lib's `lib.alertDialog` with custom labels and Czech text.
- The plate is trimmed of spaces before DB update.
- If `Config.EnableDatabaseUpdate = false`, it will only simulate and notify.
 - Ownership gating: set `Config.RequireOwnership = true` (default in this resource) and ensure `ownerColumn` is correct in `config.lua`. ESX uses `owner` (identifier), QB uses `citizenid`.
