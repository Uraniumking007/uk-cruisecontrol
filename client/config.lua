-- Configuration for uk-cruisecontrol

Config = {}

-- UI
Config.OpenCommand = 'cc'           -- chat/console command to open UI
Config.DebugModeConvar = 'uk-cruisecontrol-debugMode' -- convar name to toggle debug prints (1 to enable)

-- Controls
Config.ToggleCommand = 'toggleCruiseControl'    -- command to toggle limiter at NUI-selected speed
Config.ToggleKey = 'Y'                         -- default key; rebind in FiveM key bindings
Config.DisableOnHandbrake = true               -- disable limiter when handbrake pressed
Config.HandbrakeControl = 76                   -- default control code to detect handbrake/cancel

-- Units
Config.Unit = 'mph'                            -- 'mph' or 'kmh' for UI and inputs

-- Limits
Config.MinSpeed = 5                            -- minimum selectable speed in chosen unit
Config.MaxSpeed = 200                          -- maximum selectable speed in chosen unit

return Config


