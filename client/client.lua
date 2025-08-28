local function toggleNuiFrame(shouldShow)
  SetNuiFocus(shouldShow, shouldShow)
  SendReactMessage('setVisible', shouldShow)
end

RegisterCommand((Config and Config.OpenCommand) or 'cruiseControl', function()
  toggleNuiFrame(true)
  debugPrint('Show NUI frame')
end)

RegisterNUICallback('hideFrame', function(_, cb)
  toggleNuiFrame(false)
  debugPrint('Hide NUI frame')
  cb({})
end)

RegisterNUICallback('getClientData', function(data, cb)
  debugPrint('Data sent by React', json.encode(data))

-- Lets send back client coords to the React frame for use
  local curCoords = GetEntityCoords(PlayerPedId())

  local retData <const> = { x = curCoords.x, y = curCoords.y, z = curCoords.z }
  cb(retData)
end)

-- NUI -> client: request configuration for NUI (min/max/unit)
RegisterNUICallback('getCruiseConfig', function(_, cb)
  local unit = (Config and Config.Unit) or 'mph'
  local minSpeed = (Config and Config.MinSpeed) or 0
  local maxSpeed = (Config and Config.MaxSpeed) or 300
  cb({ unit = unit, minSpeed = minSpeed, maxSpeed = maxSpeed })
end)

-- Speed limiter state
local speedLimiterEnabled = false
local speedLimiterMax = 0.0 -- meters per second

local function disableSpeedLimiter()
  speedLimiterEnabled = false
  speedLimiterMax = 0.0
  -- re-enable acceleration control when disabled
  EnableControlAction(0, 71, true)
end

local function startSpeedLimiterForVehicle(veh, maxSpeedMps)
  if speedLimiterEnabled then
    -- If already enabled, just update the max and keep running
    speedLimiterMax = maxSpeedMps or speedLimiterMax
    return
  end

  local ped = PlayerPedId()
  if not IsPedInAnyVehicle(ped, false) then return end

  -- ensure vehicle has forward gear if required by config
  if (not Config or Config.RequireForwardGear ~= false) and GetVehicleCurrentGear(veh) <= 0 then return end

  speedLimiterMax = maxSpeedMps or GetEntitySpeed(veh)
  if speedLimiterMax <= 0.0 then return end

  speedLimiterEnabled = true

  CreateThread(function()
    while speedLimiterEnabled do
      Wait(0)
      local pedNow = PlayerPedId()
      if not IsPedInAnyVehicle(pedNow, false) then
        disableSpeedLimiter()
        break
      end
      local vehNow = GetVehiclePedIsIn(pedNow, false)
      if vehNow ~= veh then
        -- vehicle changed, stop limiter
        disableSpeedLimiter()
        break
      end

      local curSpeed = GetEntitySpeed(veh)
      if curSpeed > speedLimiterMax then
        -- disable forward throttle input
        DisableControlAction(0, 71, true)
      else
        EnableControlAction(0, 71, true)
      end

      -- if configured, pressing handbrake cancels limiter
      local hbControl = (Config and Config.HandbrakeControl) or 73
      if (not Config or Config.DisableOnHandbrake ~= false) and IsControlJustPressed(0, hbControl) then
        disableSpeedLimiter()
        break
      end
    end
    -- ensure controls restored
    if (not Config or Config.RestoreControlsOnExit ~= false) then
      EnableControlAction(0, 71, true)
    end
  end)
end

-- NUI -> client: set cruise settings (payload: { enabled, speed, limitEnabled, limitSpeed })
RegisterNUICallback('setCruiseSettings', function(data, cb)
  -- data comes from the React UI; expected numbers are in same units as UI (mph)
  -- We'll expect speed values in Mph and convert to meters per second for native functions
  local ok, payload = pcall(function() return data end)
  if not ok or not payload then
    cb({ ok = false, error = 'invalid_payload' })
    return
  end

  local enabled = payload.enabled
  local targetSpeed = tonumber(payload.speed) or 0
  local limitEnabled = payload.limitEnabled
  local limitSpeed = tonumber(payload.limitSpeed) or 0

  -- If limitEnabled, use limitSpeed as max, otherwise use targetSpeed
  local chosenMph = (limitEnabled and limitSpeed > 0) and limitSpeed or targetSpeed
  -- Convert Mph to m/s: 1 mph = 0.44704 m/s
  local chosenMps = chosenMph * 0.44704

  if enabled and chosenMps > 0 then
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then
      local veh = GetVehiclePedIsIn(ped, false)
      if speedLimiterEnabled then
        -- Adjust on-the-fly without disabling
        speedLimiterMax = chosenMps
      else
        startSpeedLimiterForVehicle(veh, chosenMps)
      end
      cb({ ok = true })
      return
    end
  else
    disableSpeedLimiter()
    cb({ ok = true })
    return
  end

  cb({ ok = false, error = 'not_in_vehicle' })
end)
