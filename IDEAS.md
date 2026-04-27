# Roadmap / Verbesserungs-Ideen

Sammlung für künftige Iterationen des `clp_realtuner`-Systems.
Priorisiert nach Impact / Aufwand. Alles was hier steht, passt architektonisch in
das bestehende Modul-Layout (Parts, Scan, Target, Damage, Handling, Tablet).

## Quick Wins (kurzfristig)

- **OBD-Live-HUD im Cockpit**: toggelbarer Overlay (RPM, Wasser-Temp, Öldruck,
  Ladedruck). Daten kommen direkt aus dem vorhandenen Record – nur UI-Schicht
  nötig.
- **Kalt-/Warmstart-System**: Fahrzeug braucht 30-60 Sekunden Warmlauf. Hohe
  Drehzahl im kalten Zustand → zusätzlicher Engine-Wear. Ein `temperature`-Feld
  zur Vehicle-Record-Persistenz hinzufügen.
- **Reifen-Tread-System**: jedes Reifen-Teil zählt ein Profil-Wert (mm) runter
  abhängig von gefahrener Strecke und Fahrstil. Unter Schwellwert → Grip-Malus
  und "Reifen Abgefahren"-DTC.
- **Batterie/Zündung**: Fahrzeug muss explizit gestartet werden; leere Batterie
  → Startet nicht, Jumpstart-Item nötig.
- **Wetter-Einfluss**: `GetRainLevel` + Reifentyp → Grip dynamisch anpassen.
  Bei nasser Straße verliert Semi-Slick mehr als Street-Reifen.
- **Fuel-Bridge**: Optional Adapter für `ox_fuel` / `cdn_fuel` / `LegacyFuel`,
  damit falscher Kraftstoff Leistung kostet.

## Mittel­fristig

- **Dyno-Run-Minigame**: echter Beschleunigungs-Test 0-100 / ¼ Meile, Messung
  über `GetEntitySpeed` + Zeit, Diagramm im Tablet (Canvas), Historie pro VIN.
- **NOS/Nitro**: eigenständiges Teil mit begrenzten Flaschen (Inventory-Count),
  Druckknopf-Burst, erhöht `fDriveForce` temporär, konsumiert Bottle.
- **Motor-Swap zwischen Modellen**: anderer Sound via
  `ForceVehicleEngineAudio(veh, 'hash_of_other_model')`, eigener modType-Slot.
- **Diff/LSD Tuning**: `SetVehicleHandlingFloat('fTractionBiasFront')` +
  `fTractionLossMult` – eigene Dialog-UI im Tablet.
- **Stance/Camber**: `SetVehicleWheelXOffset`, `SetVehicleWheelYRotation`,
  `SetVehicleWheelTireColliderSize` – visuelles Tune mit Grip-Tradeoff.
- **Teil-Qualität-Drift**: aggressive Fahrzone per GPS-Logging erkennen
  (harte Beschleunigung/Brems-Spikes), Verschleiß entsprechend skalieren.
- **Auftrags-System (NPC-Customer)**: zufällige Aufträge („Motor gestartet nicht
  mehr", „Rauch aus dem Kofferraum"), Fahrzeug spawnt vor der Werkstatt,
  Mechaniker muss Diagnose + Reparatur ausführen, Bezahlung skaliert mit
  Qualität & Zeit.
- **Werkstatt-Ownership**: Shop kaufbar, Mitarbeiter-Permissions, Teile-Stock
  in eigener Table, Einnahmen-Dashboard im Admin-NUI.
- **VIN-Etching / Diebstahl-Detektion**: geklaute Fahrzeuge haben abweichende
  VIN auf Motorblock vs. Chassis → Polizei kann es via Diagnose erkennen.
- **Teile-Crafting**: `Scrap + Metall + Blueprint` → craftbares Teil. Blueprint
  droppt aus rare spawns / Racing-Events.
- **Mobile Mechaniker-Van**: Fahrzeug-Item "abschleppen/Deploy Workshop" an
  beliebigem Ort – Paint/Diagnose außerhalb der Haupt-Werkstatt.
- **Drag-Strip / Dyno-Wette**: Zwei Spieler gehen ein Duell ein, Result wird in
  eigener `mechanic_races`-Table persistiert.

## Langfristig / Deep-Game

- **Integration clp_hds**: verstecktes Fach im Fahrzeug (eigener `secret_stash`-
  Slot), der beim Mechaniker-Scan optional entdeckt werden kann.
- **Versicherungs-/Totalverlust-System**: pro Fahrzeug Versicherung + Claims;
  unter Versicherungssumme wird abgeschleppt und verschrottet.
- **Skill-Spezialisierungen**: Bremsmeister, Motor-Profi, Lackierer – jeder Pfad
  bekommt eigene Boni, Wahl beim Level 5.
- **Live-Streamed Telemetrie**: WebSocket aus der Resource in ein externes
  Dashboard, damit Admins ohne Ingame-NUI mitschauen können.
- **Crashrekonstruktion**: beim Unfall wird der letzte `odometer`/`engine_health`
  -Delta im Log gespeichert – Reparatur-Kostenvoranschlag ist dann exakt.

## Technik / Quality-of-Life

- **Smart Target**: `canInteract` mit Cache (30 frames), damit das UI nicht bei
  jedem Target-Tick den gesamten Record durchforstet.
- **Record-Compression**: `installed_parts`/`tuning_data`-Delta-Packing statt
  vollem JSON auf jeder Auto-Save-Flanke.
- **Schema-Migrations-Loader**: einfacher Migrationsordner `migrations/*.sql`
  mit `schema_version`-Table, statt einer monolithischen INSTALL.sql.
- **Unit-Testing des Scans**: Headless-Test mit gemockten `GetNumVehicleMods`,
  damit Parts-Hinzufügen keine Regressions verursacht.

## Weitere Inspirations-Quellen (benchmarked)

- `lsscript_mechanicjob` (LSScripts) – Werkstatt-Workflow-Pattern
- `Realistic Vehicle Failure` (standalone) – Damage-Formel-Referenz
- `qb-customs`/`esx_customs` – Paint-Booth-UX
- `dropsVisualDamage` / `ultimate-car-inventory` – Schaden-Rendering
