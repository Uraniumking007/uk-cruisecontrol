<h2 align="center">uk-cruisecontrol</h2>

<div align="center">
A lightweight Speed Limiter / Cruise Control resource for FiveM with a clean React NUI.
</div>

## Features

- **Open UI via command**: default `cc` (configurable)
- **Enable/disable cruise control** with a target speed
- **Unit selection**: MPH or KM/H (configurable and switchable in UI)
- **Clamp speeds** between configurable min/max
- **Handbrake cancel**: pressing handbrake cancels limiter (configurable)
- **Per-vehicle session**: limiter stops when you exit or switch vehicles
- **Debug prints** via convar

## How it works (overview)

- The NUI is served from `web/build/index.html` as declared in `fxmanifest.lua`.
- Run the open command (default `cc`) to show the UI. The UI calls back into the client using NUI callbacks.
- When enabled, the script limits acceleration once vehicle speed exceeds the chosen target (in meters/second), effectively capping speed.
- Limiter auto-disables if you exit the vehicle, switch vehicles, or press the configured handbrake cancel control.

## Installation

1. Place this folder in your server `resources` directory.
2. Ensure it in your `server.cfg` after any dependency resources:

```cfg
ensure uk-cruisecontrol
```

3. (Optional) Enable debug logs:

```cfg
setr uk-cruisecontrol-debugMode 1
```

The resource ships with a prebuilt UI under `web/build`, so no build is required to use it.

## Usage

- Press **Y** while driving to enable the limiter at the speed selected in the NUI (default 60 MPH); press again to disable it. Rebind **Toggle cruise control** in FiveM key bindings if desired.
- The Enabled toggle follows Y and automatic cancellation. Speed and unit preferences are saved per FiveM client across server restarts; cruise starts disabled after reconnecting.
- In-game, type the configured command (default `cc`) in chat or console to open the UI.
- Toggle **Enabled** and set your desired speed using the slider, buttons, or number input.
- Switch units between MPH and KM/H; values are converted appropriately.
- Click **Cancel** or press Escape to close the UI; cruise state persists until disabled or cancelled by conditions below.

### Cancel/disable conditions

- Pressing the configured handbrake control (default control code `76`)
- Exiting the current vehicle
- Switching to another vehicle
- Manually disabling via the UI

## Configuration

Edit `client/config.lua`:

```lua
-- UI
Config.OpenCommand = 'cc'                 -- chat/console command to open UI
Config.DebugModeConvar = 'uk-cruisecontrol-debugMode' -- convar name (1 to enable)

-- Controls
Config.DisableOnHandbrake = true          -- disable limiter when handbrake pressed
Config.HandbrakeControl = 76              -- control code to detect handbrake/cancel

-- Units
Config.Unit = 'mph'                       -- 'mph' or 'kmh' for UI and inputs

-- Limits
Config.MinSpeed = 5                       -- minimum selectable speed in chosen unit
Config.MaxSpeed = 200                     -- maximum selectable speed in chosen unit
```

Notes:
- UI always sends MPH to Lua; if UI is set to KM/H, it converts under the hood.
- Internally, the limiter uses meters/second for native functions.

## Commands

- `cc` (default): Opens the Speed Limiter UI. Change via `Config.OpenCommand`.

## NUI callbacks (for reference)

- `hideFrame` → hides the UI
- `getCruiseConfig` → returns `{ unit, minSpeed, maxSpeed }` from config
- `setCruiseSettings` → payload `{ enabled, speed, limitEnabled, limitSpeed, unit }`
  - Script uses `enabled` and selected speed; values are expected in MPH.

## Development

The UI is a small React + TypeScript app under `web/`.

- Run in-browser for UI work:

```sh
cd web
npm i
npm run dev
```

- Build production UI (writes to `web/build` used by the resource):

```sh
cd web
npm run build
```

Restart the resource after building to see changes in-game.

## Troubleshooting

- UI not opening: ensure the resource is started and use the correct command defined in `Config.OpenCommand`.
- No effect when enabled: you must be in a vehicle and have a positive target speed.
- Limiter cancels immediately: check if handbrake control is being detected; set `Config.DisableOnHandbrake = false` to test.
- Units/min/max seem off: verify `Config.Unit`, `Config.MinSpeed`, and `Config.MaxSpeed`, then restart the resource.
- Need logs: set `setr uk-cruisecontrol-debugMode 1` and watch console for messages.

## Credits

- Original boilerplate inspiration: project-error React/Lua NUI patterns
- Resource author: UraniumKing
