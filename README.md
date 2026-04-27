# clp_realtuner

Produktionsreifes, immersives Hardcore-Tuning- und Mechaniker-System für FiveM / ESX Legacy.
Fokus auf realistische Mechaniker-Simulation mit physischem Teileeinbau, Fahrzeug-Scan, VIN-Persistenz,
dynamischen ox_target-Zonen pro Fahrzeug, NUI-Tablet, ECU-Tuning, Hardcore-Schaden und Skill-System.

## Features

- **VIN + Persistenz pro Fahrzeug** (`vehicles_data` mit engine/transmission/brake/turbo/suspension health,
  `ecu_state`, `installed_parts`, `tuning_data`, `last_service`, `odometer`, `paint_quality`).
- **Modulares Teile-System** – jedes Teil ist ein `ox_inventory` Item. Qualität 1–5 → Fehlerchance,
  Verschleiß und Tuning-Bonus skalieren mit Qualität.
- **Auto-Scan** via `GetNumVehicleMods` + `GetVehicleMod` für jeden verfügbaren Slot eines Modells.
  Freie Slots und alle kompatiblen Upgrades werden automatisch ermittelt – **keine manuelle Konfiguration pro Fahrzeug**.
- **Dynamische ox_target-Zonen** per Bones: `bonnet`, `boot`, `door_dside_f`, `door_pside_f`, `door_dside_r`,
  `door_pside_r`, `wheel_lf/rf/lr/rr`, `exhaust_1`, `grille`, `spoiler`, `roof`. Aktionen sind kontextabhängig
  (Motor aus, Haube offen, Job-Check).
- **Einbau-Flow**: Motor aus, Fahrzeug steht, Werkzeug im Inventar. Progressbar + Animation. Fehler basierend
  auf Mechaniker-Skill × Qualität → Teil kann verschrottet werden.
- **Ausbau**: Teil zurück ins Inventar inkl. Restzustand (Metadata), wiederverwertbar/verkaufbar.
- **ECU-Feintuning**: AFR / Drehmoment / Fuel-Map über Slider. Werte außerhalb Safe-Band → Motorschaden.
- **Hardcore-Schaden**: Überhitzung, Turbo-Überdruck, Getriebe-Redline, Bremsen-Hitze, Fahrwerk bei Sprüngen,
  Rauch + Fehlzündung bei kritischem Motor, Abwürgen bei fast defekt.
- **Dynamisches Fahrverhalten**: `SetVehicleHandlingFloat` auf Baseline-Werten × Komponenten-Health × Tuning.
- **Lackierung**: In Paint-Booth, Lackart (matt / metallic / pearl), Partikel-Nebel (`core/ent_amb_smoke_foundry`),
  Sound, Fehlerchance → Lackqualität wird persistent.
- **Skill-System**: XP pro Einbau/Reparatur/Diagnose/ECU-Flash/Paint. Levels reduzieren Fehlerchance und
  verkürzen Installationszeit.
- **NUI-Tablet**: Diagnose (Statuslabels für normale Spieler, Zahlen für Admins), DTC-Fehlercodes,
  Teileübersicht, Upgrade-Vorschläge, Historie.
- **Admin-Commands**: `/hcmadmin dump|reset|setstat|setvin`.
- **Logging**: vollständiger Audit-Trail in `mechanic_logs`.

## Abhängigkeiten

- `es_extended` (ESX Legacy 1.9+)
- `ox_lib`
- `ox_target`
- `ox_inventory`
- `oxmysql`

## Installation

1. Repo in `resources/[custom]/clp_realtuner` ablegen.
2. SQL einspielen:
   ```
   mysql -u user -p db < INSTALL.sql
   ```
3. `server.cfg`:
   ```
   ensure oxmysql
   ensure es_extended
   ensure ox_lib
   ensure ox_target
   ensure ox_inventory
   ensure clp_realtuner
   ```
4. Items in `ox_inventory/data/items.lua` registrieren – siehe [docs/ox_items.lua](docs/ox_items.lua).
5. Mechaniker-Jobs in `Config.MechanicJobs` hinterlegen.

## Nutzung

- Third-Eye auf Fahrzeug → Optionen erscheinen je nach Zone (Haube, Kofferraum, Räder, Türen).
- Tablet via Item `mechanic_tablet` oder Keybind (`Config.Tablet.OpenKeybind`).
- ECU flashen: Teil `ecu_flasher` + Item in der Haubenzone „ECU flashen“.
- Lackieren: Fahrzeug in Paint-Booth (Koordinaten in `config/locations.lua`), dann Third-Eye „Lackieren“.

## Architektur

```
config/        config.lua, parts.lua, locations.lua
shared/        modtypes.lua (GTA V Mod-Typen), utils.lua (VIN, DTC, Labels)
server/        vin.lua (Persistenz), main.lua (ESX, Callbacks),
               logging.lua (Log + Skill), admin.lua
client/        main.lua (Bridge/Spawn-Hooks), target.lua (dyn. Zonen),
               scan.lua (Auto-Scan), install.lua (Einbau/Ausbau),
               handling.lua (Fahrverhalten), damage.lua (Hardcore-Schaden),
               paint.lua (FX), ecu.lua (Slider), tablet.lua (NUI-Bridge),
               diagnostics.lua (Status + DTC)
html/          index.html, style.css, app.js  (Tablet UI)
```

## Konfiguration

Alle harten Tuning-Parameter in `config/config.lua`:
- `Config.Install.*` — Einbau-Dauer, Fehler, Sicherheit
- `Config.Damage.*` — Schadens-Thresholds
- `Config.Handling.*` — min/max Multiplikatoren
- `Config.Paint.*` — FX, Perfekt-Raten pro Lackart
- `Config.ECU.*` — Safe-Bereiche, Schaden bei Risiko-Flash
- `Config.Skill.*` — XP-Tabelle, Levelkurve, Boni

Teile sauber in `config/parts.lua` erweitern – neue Einträge werden automatisch vom Scan gefunden.

## Hinweise

- Dieses System setzt auf GTA-Mod-Slots + logische Slots (ECU, Öl, Reifen per Position) gleichzeitig.
- `SetVehicleMod` wird nur vom Besitzer-Client gesetzt. Der eigentliche Zustand ist der DB-Record.
- `fInitialDriveMaxFlatVel` verändern erfordert den Besitzer-Client – implementiert via `NetworkGetEntityOwner`.
- Für ordnungsgemäße Persistenz muss das Fahrzeug ein Kennzeichen haben. Dauerhaft bleibt die Nummer auch
  wenn ESX das Fahrzeug neu spawnt.
