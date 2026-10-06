local CP_MONITOR_META = { driver_name = "C.P Vehicle Arrival", driver_version = "v1.4.0", package_key = "cp-vehicle-arrival", target_name = "Vehicle NAS Logger", host_pref = "nasIp", port_pref = "nasPort", transport = "tcp", direct_monitor_pref = "nasIp" }
local cp_monitor = require "cp_monitor"
local capabilities = require "st.capabilities"
local Driver = require "st.driver"
local log = require "log"
local socket = require "cosock.socket"
local json = require "st.json"

local DRIVER_VERSION = "v1.4.0"
local AUTHOR = "치즈가루"
local DEVICE_DNI = "cp-vehicle-arrival"
local DEVICE_PROFILE = "cp-vehicle-arrival"

local entry_cap = capabilities["buildbook37604.vehicleArrivalEntry"]
local exit_cap = capabilities["buildbook37604.vehicleArrivalExit"]
local trigger_cap = capabilities["buildbook37604.vehicleArrivalSummary"]
local info_cap = capabilities["buildbook37604.driverInformation"]

local connections = {}
local generations = {}
local monitor_timers = {}
local entry_pulse_generation = 0
local exit_pulse_generation = 0

local function find_by_dni(driver, dni)
  for _, d in ipairs(driver:get_devices()) do
    if d.device_network_id == dni then
      return d
    end
  end
  return nil
end

local function ensure_device(driver)
  if find_by_dni(driver, DEVICE_DNI) then
    log.info("Vehicle Arrival device already exists")
    return
  end

  local metadata = {
    type = "LAN",
    device_network_id = DEVICE_DNI,
    label = "차량 감지",
    profile = DEVICE_PROFILE,
    manufacturer = "C.P",
    model = "Wallpad Vehicle Arrival",
    vendor_provided_label = "차량 감지"
  }

  log.info("Creating Vehicle Arrival device")
  local ok, err = driver:try_create_device(metadata)
  if ok == false then
    log.error("try_create_device failed: " .. tostring(err))
  end
end

local function discovery_handler(driver, opts, should_continue)
  log.info("Vehicle Arrival discovery requested")
  ensure_device(driver)
end

local function force_current_profile(device)
  if DEVICE_PROFILE then
    device:try_update_metadata({ profile = DEVICE_PROFILE })
  end
end

local function emit_info(device)
  if info_cap then
    device:emit_event(info_cap.author(AUTHOR))
    device:emit_event(info_cap.driverVersion(DRIVER_VERSION))
  end
end

local function emit_component_switch(device, component_id, event)
  local component = device.profile.components[component_id]
  if not component then
    log.error("Missing component: " .. tostring(component_id))
    return false
  end

  device:emit_component_event(component, event)
  return true
end

local function emit_defaults(device)
  if entry_cap then
    device:emit_event(entry_cap.plate("-"))
    device:emit_event(entry_cap.eventTime("-"))
  end
  if exit_cap then
    device:emit_event(exit_cap.plate("-"))
    device:emit_event(exit_cap.eventTime("-"))
  end
  if trigger_cap then
    device:emit_event(trigger_cap.eventType("idle"))
  end

  emit_component_switch(device, "entryTrigger", capabilities.switch.switch.off())
  emit_component_switch(device, "exitTrigger", capabilities.switch.switch.off())

  emit_info(device)
end

local function emit_switch_pulse(device, direction)
  local component_id
  local generation
  local label

  if direction == "IN" then
    component_id = "entryTrigger"
    entry_pulse_generation = entry_pulse_generation + 1
    generation = entry_pulse_generation
    label = "ENTRY"
  else
    component_id = "exitTrigger"
    exit_pulse_generation = exit_pulse_generation + 1
    generation = exit_pulse_generation
    label = "EXIT"
  end

  -- Standard SmartThings switch capability.
  -- Every passage is independent: OFF -> ON is emitted immediately,
  -- even for repeated IN/IN or OUT/OUT events.
  emit_component_switch(
    device,
    component_id,
    capabilities.switch.switch.off({ state_change = true })
  )

  emit_component_switch(
    device,
    component_id,
    capabilities.switch.switch.on({ state_change = true })
  )

  log.info(string.format("Routine %s trigger #%d: ON", label, generation))

  -- Keep ON long enough for SmartThings cloud routines.
  device.thread:call_with_delay(30.0, function()
    local current = direction == "IN" and entry_pulse_generation or exit_pulse_generation
    if current == generation then
      emit_component_switch(
        device,
        component_id,
        capabilities.switch.switch.off({ state_change = true })
      )
      log.info(string.format("Routine %s trigger #%d: OFF", label, generation))
    end
  end, string.format("vehicle-%s-off-%d", label, generation))
end

local function emit_vehicle_event(device, evt)
  local status = tostring(evt.status or "")
  local plate = tostring(evt.plate or "-")
  local event_time = tostring(evt.event_time or evt.time or "-")
  local kind = tostring(evt.type or "")

  log.info(string.format(
    "Vehicle event type=%s status=%s plate=%s time=%s",
    kind, status, plate, event_time
  ))

  emit_info(device)

  if status == "IN" then
    if entry_cap then
      device:emit_event(entry_cap.plate(plate, { state_change = true }))
      device:emit_event(entry_cap.eventTime(event_time, { state_change = true }))
    end

    emit_switch_pulse(device, "IN")

  elseif status == "OUT" then
    if exit_cap then
      device:emit_event(exit_cap.plate(plate, { state_change = true }))
      device:emit_event(exit_cap.eventTime(event_time, { state_change = true }))
    end

    emit_switch_pulse(device, "OUT")
  else
    log.warn("Unknown vehicle status: " .. status)
  end
end

local function close_connection(device)
  local id = device.id
  generations[id] = (generations[id] or 0) + 1

  local tcp = connections[id]
  connections[id] = nil
  if tcp then
    pcall(function() tcp:close() end)
  end
end

local function start_connection(device)
  close_connection(device)

  local id = device.id
  local my_generation = generations[id]

  device.thread:call_with_delay(2.0, function()
    while generations[id] == my_generation do
      local ip = tostring(device.preferences.nasIp or "192.168.1.92")
      local port = tonumber(device.preferences.nasPort) or 19093
      local plates = tostring(device.preferences.familyPlates or "")

      log.info(string.format("Connecting NAS %s:%d", ip, port))

      local tcp = socket.tcp()
      tcp:settimeout(5)
      local ok, err = tcp:connect(ip, port)

      if ok then
        connections[id] = tcp
        tcp:settimeout(3600)
        pcall(cp_monitor.connection, device, "connected")
        log.info("NAS connected - persistent receive mode")
        emit_info(device)

        local sent, send_err = tcp:send("CONFIG|" .. plates .. "\n")
        if sent then
          pcall(cp_monitor.tx, device, #( "CONFIG|" .. plates .. "\n"), "CONFIG")
          log.info("Family plates synchronized")
        else
          log.warn("CONFIG send failed: " .. tostring(send_err))
        end

        while generations[id] == my_generation do
          local line, recv_err = tcp:receive("*l")
          if not line then
            log.warn("NAS disconnected: " .. tostring(recv_err))
            break
          end

          pcall(cp_monitor.rx, device, #line, "NAS RX")
          if line:sub(1, 6) == "EVENT|" then
            local parsed, evt = pcall(json.decode, line:sub(7))
            if parsed and evt and evt.event == "car" then
              emit_vehicle_event(device, evt)
            else
              log.warn("Invalid EVENT JSON")
            end
          elseif line == "CONFIG_OK" then
            log.info("NAS CONFIG_OK")
          elseif line:sub(1, 6) == "HELLO|" then
            log.info("NAS HELLO received")
          end
        end
      else
        pcall(cp_monitor.connection, device, "disconnected", tostring(err))
        log.warn("NAS connect failed: " .. tostring(err))
      end

      if connections[id] == tcp then
        connections[id] = nil
      end
      pcall(function() tcp:close() end)

      if generations[id] == my_generation then
        log.info("Retrying NAS connection in 5 seconds")
        socket.sleep(5)
      end
    end
  end, "nas-connection-loop")
end

local function start_info_heartbeat(device)
  device.thread:call_on_schedule(
    30,
    function()
      emit_info(device)
    end,
    "driver-info-heartbeat"
  )
end

local function stop_monitor_heartbeat(driver, device)
  local id = device and device.id
  if not id then return end
  local timer = monitor_timers[id]
  if timer then
    pcall(function() driver:cancel_timer(timer) end)
    monitor_timers[id] = nil
  end
end

local function start_monitor_heartbeat(driver, device)
  if not driver or not device then return end

  -- Vehicle Arrival keeps a long-lived NAS receive coroutine on device.thread.
  -- Run telemetry on the Driver timer queue instead so the periodic heartbeat
  -- is independent of that persistent receive loop.
  stop_monitor_heartbeat(driver, device)

  -- The Driver-level timer is separate from cp_monitor.start(), so inject
  -- metadata explicitly before the first send. Without this, the telemetry
  -- payload falls back to "C.P Edge Driver" / packageKey "unknown".
  pcall(cp_monitor.configure, device, CP_MONITOR_META)

  pcall(cp_monitor.send, device)
  pcall(function()
    driver:call_with_delay(2, function()
      pcall(cp_monitor.send, device)
    end, "cp-vehicle-monitor-initial")
  end)

  local ok, timer_or_err = pcall(function()
    return driver:call_on_schedule(60, function()
      pcall(cp_monitor.send, device)
    end, "cp-vehicle-monitor-heartbeat")
  end)

  if ok and timer_or_err then
    monitor_timers[device.id] = timer_or_err
    log.info("Vehicle monitor heartbeat scheduled on driver timer")
  else
    log.error("Vehicle monitor heartbeat schedule failed: " .. tostring(timer_or_err))
  end
end

local function activate_device(driver, device)
  log.info("Vehicle Arrival activate " .. DRIVER_VERSION)

  -- Force existing device onto the currently packaged profile/VID.
  -- SmartThings can retain an older LAN device profile after driver updates.
  device:try_update_metadata({profile = DEVICE_PROFILE})

  emit_defaults(device)
  emit_info(device)

  -- Retry after profile migration so driverInformation is re-emitted
  -- after SmartThings finishes switching the existing device profile.
  device.thread:call_with_delay(3.0, function()
    emit_info(device)
  end, "vehicle-info-refresh-3s")

  device.thread:call_with_delay(10.0, function()
    emit_info(device)
  end, "vehicle-info-refresh-10s")

  start_info_heartbeat(device)
  start_connection(device)
  start_monitor_heartbeat(driver, device)
end

local function start_driver_info_heartbeat(device)
  device.thread:call_on_schedule(
    15,
    function()
      force_current_profile(device)
      emit_info(device)
    end,
    "driver-info-heartbeat-v135"
  )
end

local function added(driver, device)
  force_current_profile(device)
  emit_info(device)
  start_driver_info_heartbeat(device)
  activate_device(driver, device)
end

local function init(driver, device)
  force_current_profile(device)
  emit_info(device)
  start_driver_info_heartbeat(device)
  activate_device(driver, device)
end

local function info_changed(driver, device, event, args)
  local old_prefs = (args and args.old_st_store and args.old_st_store.preferences) or {}
  local changed = false

  for id, value in pairs(device.preferences or {}) do
    if old_prefs[id] ~= value then
      log.info("Preference changed: " .. tostring(id))
      changed = true
    end
  end

  emit_info(device)

  if changed then
    start_connection(device)
  end
  force_current_profile(device)
  emit_info(device)
end

local function removed(driver, device)
  stop_monitor_heartbeat(driver, device)
  close_connection(device)
end

local function refresh_handler(driver, device, command)
  emit_info(device)
  start_connection(device)
  force_current_profile(device)
  emit_info(device)
end

log.info("C.P Vehicle Arrival Edge Driver " .. DRIVER_VERSION .. " loading")

local driver = Driver("cp-vehicle-arrival", {
  discovery = discovery_handler,
  lifecycle_handlers = {
    added = added,
    init = init,
    infoChanged = info_changed,
    removed = removed
  },
  capability_handlers = {
    [capabilities.refresh.ID] = {
      [capabilities.refresh.commands.refresh.NAME] = refresh_handler
    }
  }
})

driver:run()
