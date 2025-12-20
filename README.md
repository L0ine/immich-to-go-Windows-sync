# Immich-Go Tray Automation (Windows)

A simple PowerShell-based system tray application to automate your Immich backups using `immich-go`. It monitors your local folders and ensures new photos are uploaded to your Immich server automatically.

## Features
- **Auto-Sync**: Background sync triggered by file system changes (real-time).
- **Tray Icon**: Minimalist interface that stays out of your way.
- **Manual Control**: Start visible or background syncs manually from the tray menu.
- **Configuration**: Easy-to-use GUI for settings.

## Getting Started

1. **Prerequisites**:
   - [immich-go.exe](https://github.com/simulot/immich-go) must be in the same folder as the script.
   - PowerShell 5.1 or higher (standard on Windows).

2. **Installation**:
   - Download this repository.
   - Run `immich-tray.vbs` to start the app silently (without a permanent PowerShell window).

3. **Configuration**:
   - Right-click the tray icon -> **Settings**.
   - Enter your Server URL, API Key, and Source Folder.

---

## Technical Documentation
Hier ist die technische Erklärung der internen Abläufe.

### Verwendete Parameter
Alle Befehle nutzen die Werte aus der `config.json`:
- **Server:** `--server="URL"`
- **API-Key:** `--api-key="KEY"`
- **Quelle:** `--recursive "PFAD"`

---

### Menü-Einträge & Befehle

#### 1. Run Sync (Visible)
Öffnet ein sichtbares PowerShell-Fenster für Fortschrittskontrolle.
```powershell
powershell.exe -NoExit -Command "Set-Location -Path '...'; & '.\immich-go.exe' upload from-folder ..."
```

#### 2. Run Sync (Background)
Läuft unsichtbar im Hintergrund.
```powershell
Start-Process "immich-go.exe" -ArgumentList "..." -WindowStyle Hidden
```

#### 3. Stop Current Syncs
Beendet alle laufenden Instanzen von `immich-go.exe`.

#### 4. Settings
Aktualisiert die `config.json` und passt das Timer-Intervall an.

---

## License
Distributed under the MIT License. See `LICENSE.md` for more information.
