-- Preferences are stored on each player's FiveM client and survive server restarts.
local preferences = { speed = 60, limitSpeed = 120, limitEnabled = false, unit = (Config and Config.Unit) or 'mph' }
local stored = GetResourceKvpString('cruisePreferences')
if stored then
  local ok, saved = pcall(json.decode, stored)
  if ok and type(saved) == 'table' then
    if type(saved.speed) == 'number' and saved.speed > 0 then preferences.speed = saved.speed end
    if type(saved.limitSpeed) == 'number' and saved.limitSpeed > 0 then preferences.limitSpeed = saved.limitSpeed end
    preferences.limitEnabled = saved.limitEnabled == true
    if saved.unit == 'mph' or saved.unit == 'kmh' then preferences.unit = saved.unit end
  end
end

local speedLimiterEnabled = false
local speedLimiterMax = 0.0
local selectedSpeedMps = (preferences.limitEnabled and preferences.limitSpeed or preferences.speed) * 0.44704
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
  local unit = preferences.unit
  local minSpeed = (Config and Config.MinSpeed) or 0
  local maxSpeed = (Config and Config.MaxSpeed) or 300
  cb({ unit = unit, minSpeed = minSpeed, maxSpeed = maxSpeed, boundsUnit = (Config and Config.Unit) or 'mph', speed = preferences.speed, limitSpeed = preferences.limitSpeed, limitEnabled = preferences.limitEnabled, enabled = speedLimiterEnabled })
end)

-- Speed limiter state is initialized from saved preferences above.

local function notifyCruise(description, notificationType)
  lib.notify({
    id = 'uk-cruisecontrol-status',
    title = 'Cruise Control',
    description = description,
    type = notificationType or 'info'
  })
end

local function disableSpeedLimiter(reason)
  local wasEnabled = speedLimiterEnabled
  speedLimiterEnabled = false
  SendReactMessage('setCruiseEnabled', false)
  speedLimiterMax = 0.0
  -- re-enable acceleration control when disabled
  EnableControlAction(0, 71, true)
  if wasEnabled then
    notifyCruise(reason or 'Cruise control disabled.')
  end
end

local function startSpeedLimiterForVehicle(veh, maxSpeedMps)
  local ped = PlayerPedId()
  local failure
  if not IsPedInAnyVehicle(ped, false) or GetVehiclePedIsIn(ped, false) ~= veh then
    failure = 'You must be driving a vehicle to enable cruise control.'
  elseif GetPedInVehicleSeat(veh, -1) ~= ped then
    failure = 'Only the driver can enable cruise control.'
  elseif (not Config or Config.RequireForwardGear ~= false) and GetVehicleCurrentGear(veh) <= 0 then
    failure = 'Use a forward gear to enable cruise control.'
  end
  if failure then
    if speedLimiterEnabled then disableSpeedLimiter() end
    SendReactMessage('setCruiseEnabled', false)
    notifyCruise(failure, 'error')
    return false, failure
  end
  if speedLimiterEnabled then
    speedLimiterMax = maxSpeedMps or speedLimiterMax
    return true
  end
  speedLimiterMax = maxSpeedMps or GetEntitySpeed(veh)
  if speedLimiterMax <= 0.0 then return end

  speedLimiterEnabled = true
  SendReactMessage('setCruiseEnabled', true)
  local displaySpeed = speedLimiterMax / (preferences.unit == 'kmh' and (1 / 3.6) or 0.44704)
  notifyCruise(('Cruise control enabled at %d %s.'):format(math.floor(displaySpeed + 0.5), preferences.unit == 'kmh' and 'km/h' or 'MPH'), 'success')

  CreateThread(function()
    while speedLimiterEnabled do
      Wait(0)
      local pedNow = PlayerPedId()
      if not IsPedInAnyVehicle(pedNow, false) then
        disableSpeedLimiter('Cruise control disabled: you left the vehicle.')
        break
      end
      local vehNow = GetVehiclePedIsIn(pedNow, false)
      if vehNow ~= veh or GetPedInVehicleSeat(vehNow, -1) ~= pedNow then
        -- vehicle changed, stop limiter
        disableSpeedLimiter('Cruise control disabled: vehicle changed.')
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
      local hbControl = (Config and Config.HandbrakeControl) or 76
      if (not Config or Config.DisableOnHandbrake ~= false) and IsControlJustPressed(0, hbControl) then
        disableSpeedLimiter('Cruise control disabled: handbrake applied.')
        break
      end
    end
    -- ensure controls restored
    if (not Config or Config.RestoreControlsOnExit ~= false) then
      EnableControlAction(0, 71, true)
    end
  end)
  return true
end

local toggleCommand = (Config and Config.ToggleCommand) or 'toggleCruiseControl'

RegisterCommand(toggleCommand, function()
  if speedLimiterEnabled then
    disableSpeedLimiter()
    return
  end

  local ped = PlayerPedId()
  if not IsPedInAnyVehicle(ped, false) then
    notifyCruise('You must be driving a vehicle to enable cruise control.', 'error')
    return
  end

  local veh = GetVehiclePedIsIn(ped, false)
  if GetPedInVehicleSeat(veh, -1) ~= ped then
    notifyCruise('Only the driver can enable cruise control.', 'error')
    return
  end

  startSpeedLimiterForVehicle(veh, selectedSpeedMps)
end, false)

RegisterKeyMapping(toggleCommand, 'Toggle cruise control', 'keyboard', (Config and Config.ToggleKey) or 'Y')

-- NUI -> client: set cruise settings (payload: { enabled, speed, limitEnabled, limitSpeed })
RegisterNUICallback('setCruiseSettings', function(data, cb)
  -- data comes from the React UI; expected numbers are in same units as UI (mph)
  -- We'll expect speed values in Mph and convert to meters per second for native functions
  local payload = data
  if type(payload) ~= 'table' then
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
  preferences.speed = targetSpeed
  preferences.limitSpeed = limitSpeed
  preferences.limitEnabled = limitEnabled == true
  if payload.unit == 'mph' or payload.unit == 'kmh' then preferences.unit = payload.unit end
  SetResourceKvp('cruisePreferences', json.encode(preferences))
  if chosenMps > 0 then
    selectedSpeedMps = chosenMps
  end

  if enabled and chosenMps > 0 then
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    local ok, errorMessage = startSpeedLimiterForVehicle(veh, chosenMps)
    cb({ ok = ok == true, enabled = speedLimiterEnabled, error = errorMessage })
  else
    disableSpeedLimiter()
    cb({ ok = true, enabled = false })
  end
end)