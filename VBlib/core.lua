-- Shared helpers for VB Telemetry Lite.
-- This module contains only logic required by the monochrome main screen,
-- menu and settings screens.

local M = {}

local VB_DOFILE = rawget(_G, "VB_DOFILE") or dofile

local RIGHT = RIGHT or 0x0400
local CENTER = CENTER or 0x0200
local SMLSIZE = SMLSIZE or 0x0200
local INVERS = INVERS or 0x0100

local LCD_W = 128
local LCD_H = 64
local SETTINGS_FILE_PATH = "/LOGS/VB_settings.lua"

local FAST_PERIOD = 8
local MEDIUM_PERIOD = 24
local STATE_PERIOD = 12
local BAR_PERIOD = 24
local CLOCK_PERIOD = 100

local FAST_SENSORS = { "TQly", "TRSS", "TSNR", "RQly", "1RSS", "2RSS", "RSNR" }
local MEDIUM_SENSORS = { "FM", "RxBt", "TPWR", "RFMD" }

local UI = rawget(_G, "UI")
if type(UI) ~= "table" then
  UI = {}
end


local function is_array_pos(pos)
  return type(pos) == "table" and pos[1] ~= nil
end


local function x_anchor_code(pos)
  if is_array_pos(pos) then
    return tonumber(pos[3] or 0) or 0
  end

  local anchor = (pos and (pos.anchor_x or pos.anchor)) or "left"
  if anchor == "right" then
    return 2
  end
  if anchor == "center" then
    return 1
  end
  return 0
end


local function y_anchor_code(pos)
  if is_array_pos(pos) then
    local x_code = tonumber(pos[3] or 0) or 0
    local y_code = pos[4]
    if y_code == nil then
      return (x_code == 1) and 1 or 0
    end
    return tonumber(y_code) or 0
  end

  local anchor = (pos and (pos.anchor_y or pos.anchor)) or "top"
  if anchor == "bottom" then
    return 2
  end
  if anchor == "center" then
    return 1
  end
  return 0
end


local function pos_x(pos)
  local x
  if is_array_pos(pos) then
    x = tonumber(pos[1] or 0) or 0
  else
    x = (pos and pos.x) or 0
  end

  local anchor = x_anchor_code(pos)
  if anchor == 2 then
    return LCD_W + x
  end
  if anchor == 1 then
    return math.floor(LCD_W / 2) + x
  end
  return x
end


local function pos_y(pos)
  local y
  if is_array_pos(pos) then
    y = tonumber(pos[2] or 0) or 0
  else
    y = (pos and pos.y) or 0
  end

  local anchor = y_anchor_code(pos)
  if anchor == 2 then
    return LCD_H + y
  end
  if anchor == 1 then
    return math.floor(LCD_H / 2) + y
  end
  return y
end


local function add_common_text_flags(flags)
  local out = tonumber(flags or 0) or 0
  if UI._use_small then
    out = out + SMLSIZE
  end
  if UI._invert then
    out = out + INVERS
  end
  return out
end


function UI.set_invert(enabled)
  UI._invert = not not enabled
end


function UI.inverted()
  return UI._invert == true
end


function UI.set_small(enabled)
  UI._use_small = not not enabled
end


function UI.small()
  UI._use_small = true
end


function UI.align_flags(pos)
  local anchor = x_anchor_code(pos)
  if anchor == 2 then
    return RIGHT
  end
  if anchor == 1 then
    return CENTER
  end
  return 0
end


function UI.flags(base)
  local flags = 0
  if type(base) == "number" then
    flags = base
  elseif type(base) == "table" then
    flags = tonumber(base.flags or base[5] or 0) or 0
  end
  return add_common_text_flags(flags)
end


function UI.pos_xy(pos)
  return pos_x(pos), pos_y(pos)
end


function UI.text(pos, y_or_text, text_or_flags, flags)
  if not (lcd and lcd.drawText) then
    return
  end

  if type(pos) == "number" then
    local x = pos
    local y = tonumber(y_or_text or 0) or 0
    local text = tostring(text_or_flags or "")
    lcd.drawText(x, y, text, add_common_text_flags(flags))
    return
  end

  local text = tostring(y_or_text or "")
  local base_flags = tonumber(text_or_flags or 0) or 0
  if type(pos) == "table" then
    local extra = pos.flags
    if extra == nil and is_array_pos(pos) then
      extra = pos[5]
    end
    base_flags = base_flags + (tonumber(extra or 0) or 0)
  end

  lcd.drawText(pos_x(pos), pos_y(pos), text, add_common_text_flags(base_flags) + UI.align_flags(pos))
end


function UI.frame_begin(inverted)
  UI.set_small(false)
  UI.set_invert(inverted)

  if lcd and lcd.clear then
    lcd.clear()
  end
  if UI._invert and lcd and lcd.drawFilledRectangle then
    lcd.drawFilledRectangle(0, 0, LCD_W, LCD_H, INVERS)
  end
end


function UI.frame_end()
end


local UTIL = {}


function UTIL.now()
  if type(getTime) == "function" then
    return getTime() or 0
  end
  return 0
end


function UTIL.clamp(value, min_value, max_value)
  if value < min_value then
    return min_value
  end
  if value > max_value then
    return max_value
  end
  return value
end


function UTIL.ui_inverted()
  local settings = rawget(_G, "SET")
  if type(settings) == "table" and settings.UI_INVERT ~= nil then
    return settings.UI_INVERT == true
  end
  return UI.inverted()
end


function UTIL.gc_light()
  if type(collectgarbage) == "function" then
    collectgarbage("step", 64)
  end
end


function UTIL.gc_full()
  if type(collectgarbage) == "function" then
    collectgarbage("collect")
  end
end


function UTIL.text_width_small(text)
  local value = tostring(text or "")
  if lcd and type(lcd.getTextWidth) == "function" then
    local ok, width = pcall(lcd.getTextWidth, SMLSIZE, value)
    if ok and type(width) == "number" then
      return width
    end

    ok, width = pcall(lcd.getTextWidth, value)
    if ok and type(width) == "number" then
      return width
    end
  end
  return #value * 6
end


function UTIL.draw_header(title, inverted)
  if not (lcd and lcd.drawFilledRectangle and lcd.drawText) then
    return
  end

  local text = tostring(title or "")
  lcd.drawFilledRectangle(0, 0, LCD_W, 8, 0)

  local flags = SMLSIZE
  if not inverted then
    flags = flags + INVERS
  end

  local width = UTIL.text_width_small(text)
  local x = math.floor((LCD_W - width) / 2 + 0.5)
  if x < 0 then
    x = 0
  end

  lcd.drawText(x, 1, text, flags)
end


function UTIL.scroll_to_focus(focus, scroll, total, visible)
  local out = tonumber(scroll or 0) or 0
  if focus < (out + 1) then
    out = focus - 1
  elseif focus > (out + visible) then
    out = focus - visible
  end

  if out < 0 then
    out = 0
  end

  local max_scroll = total - visible
  if max_scroll < 0 then
    max_scroll = 0
  end
  if out > max_scroll then
    out = max_scroll
  end

  return out
end


function UTIL.draw_qr_bitmap(bitmap, x0, y0, scale, inverted)
  if type(bitmap) ~= "table" then
    return false, 0, 0
  end

  local hex = bitmap.hex
  local width_cells = tonumber(bitmap.w) or 0
  local height_cells = tonumber(bitmap.h) or 0
  local dot_size = tonumber(scale or 2) or 2

  if type(hex) ~= "string" or hex == "" or width_cells <= 0 or height_cells <= 0 then
    return false, 0, 0
  end

  local dot_flags = inverted and (ERASE or 0) or 0
  local hex_index = 1
  local current_byte = tonumber(string.sub(hex, hex_index, hex_index + 1), 16) or 0
  local bit_index = 0

  for y = 0, height_cells - 1 do
    for x = 0, width_cells - 1 do
      if (current_byte % 2) == 1 then
        lcd.drawFilledRectangle(x0 + x * dot_size, y0 + y * dot_size, dot_size, dot_size, dot_flags)
      end

      current_byte = math.floor(current_byte / 2)
      bit_index = bit_index + 1

      if bit_index == 8 then
        bit_index = 0
        hex_index = hex_index + 2
        current_byte = tonumber(string.sub(hex, hex_index, hex_index + 1), 16) or 0
      end
    end
  end

  return true, width_cells * dot_size, height_cells * dot_size
end


local function safe_get_value(name)
  if type(getValue) ~= "function" then
    return nil
  end

  local ok, value = pcall(getValue, name)
  if ok then
    return value
  end
  return nil
end


local function normalize_source_name(source)
  if type(source) ~= "string" then
    source = tostring(source or "SA")
  end

  source = string.upper(source)
  if source == "" then
    return "SA"
  end

  local logical_id = tonumber(string.match(source, "^LS0*(%d+)$"))
  if not logical_id then
    logical_id = tonumber(string.match(source, "^L0*(%d+)$"))
  end
  if logical_id and logical_id >= 1 and logical_id <= 64 then
    return string.format("L%02d", logical_id)
  end

  return source
end


local function read_switch_value(source)
  source = normalize_source_name(source or "SA")

  local logical_id = string.match(source, "^L(%d%d)$")
  if logical_id and type(getLogicalSwitchValue) == "function" then
    local index = tonumber(logical_id)
    if index then
      local ok, value = pcall(getLogicalSwitchValue, index - 1)
      if ok and value ~= nil then
        return value and 1024 or 0
      end
    end
  end

  if type(getSwitchIndex) == "function" and type(getSwitchValue) == "function" then
    local ok_index, index = pcall(getSwitchIndex, source)
    if ok_index and index and index ~= 0 then
      local ok_value, value = pcall(getSwitchValue, index)
      if ok_value and value ~= nil then
        if type(value) == "boolean" then
          return value and 1024 or 0
        end
        return value
      end
    end
  end

  if type(getSwitchPosition) == "function" then
    local ok, value = pcall(getSwitchPosition, source)
    if ok and value ~= nil then
      return value
    end
  end

  return safe_get_value(source) or 0
end


local function normalize_switch_position(raw)
  raw = tonumber(raw or 0) or 0
  if raw > 0 then
    return 1
  end
  if raw < 0 then
    return -1
  end
  return 0
end


function UTIL.src_val(source)
  local invert = false
  if type(source) == "string" and string.sub(source, 1, 1) == "!" then
    invert = true
    source = string.sub(source, 2)
  end

  source = normalize_source_name(source or "SA")
  local raw = read_switch_value(source)
  local position

  if string.match(source, "^L%d%d$") then
    position = (tonumber(raw or 0) ~= 0) and 1 or 0
  else
    position = normalize_switch_position(raw)
  end

  if invert then
    if string.match(source, "^L%d%d$") then
      position = (position == 0) and 1 or 0
    else
      position = -position
    end
  end

  return position
end


function UTIL.is_enter(event)
  return event == EVT_ENTER_BREAK or event == EVT_VIRTUAL_ENTER
end


function UTIL.is_exit(event)
  return event == EVT_EXIT_BREAK or event == EVT_VIRTUAL_EXIT or event == EVT_RTN_FIRST
end


function UTIL.is_next(event)
  return event == EVT_ROT_RIGHT or event == EVT_PAGE_DOWN
    or event == EVT_PLUS_FIRST or event == EVT_PLUS_REPT
    or event == EVT_DOWN_FIRST or event == EVT_DOWN_REPT
    or event == EVT_VIRTUAL_NEXT
end


function UTIL.is_prev(event)
  return event == EVT_ROT_LEFT or event == EVT_PAGE_UP
    or event == EVT_MINUS_FIRST or event == EVT_MINUS_REPT
    or event == EVT_UP_FIRST or event == EVT_UP_REPT
    or event == EVT_VIRTUAL_PREV
end


function UTIL.new_input_latch()
  return {
    ignore_until = 0,
    await_release = false,
    last_enter_t = -100000,
    last_exit_t = -100000,
  }
end


function UTIL.latch_reset(latch, delay, await_release)
  latch = latch or UTIL.new_input_latch()
  latch.ignore_until = UTIL.now() + (tonumber(delay or 0) or 0)
  latch.await_release = not not await_release
  latch.last_enter_t = -100000
  latch.last_exit_t = -100000
  return latch
end


function UTIL.latch_arm_release(latch, delay)
  latch = latch or UTIL.new_input_latch()
  latch.ignore_until = UTIL.now() + (tonumber(delay or 0) or 0)
  latch.await_release = true
  return latch
end


function UTIL.latch_apply(latch, event)
  latch = latch or UTIL.new_input_latch()

  local e = event or 0
  if UTIL.now() <= (latch.ignore_until or 0) then
    e = 0
  end

  if latch.await_release then
    if e ~= 0 then
      return 0
    end
    latch.await_release = false
  end

  return e
end


function UTIL.latch_enter_ok(latch, min_delta)
  latch = latch or UTIL.new_input_latch()

  local timestamp = UTIL.now()
  local gap = tonumber(min_delta or 18) or 18
  if (timestamp - (latch.last_enter_t or -100000)) < gap then
    return false
  end

  latch.last_enter_t = timestamp
  return true
end


function UTIL.latch_exit_ok(latch, min_delta)
  latch = latch or UTIL.new_input_latch()

  local timestamp = UTIL.now()
  local gap = tonumber(min_delta or 12) or 12
  if (timestamp - (latch.last_exit_t or -100000)) < gap then
    return false
  end

  latch.last_exit_t = timestamp
  return true
end



local function settings_path()
  local cached = rawget(_G, "VB_SETTINGS_PATH")
  if type(cached) == "string" and cached ~= "" then
    return cached
  end

  cached = SETTINGS_FILE_PATH
  rawset(_G, "VB_SETTINGS_PATH", cached)
  return cached
end


local function load_settings_file()
  local cached = rawget(_G, "VB_SETTINGS_RAW")
  if type(cached) == "table" then
    return cached
  end

  local ok, data = pcall(VB_DOFILE, settings_path())
  if ok and type(data) == "table" then
    rawset(_G, "VB_SETTINGS_RAW", data)
    return data
  end

  return {}
end


local DEFAULT_SETTINGS = {
  ARM_SRC = "SA",
  TURTLE_SRC = "SD",
  BEEP_SRC = "SE",
  UI_INVERT = false,
}


local function normalize_loaded_settings(raw)
  if type(raw) ~= "table" then
    raw = {}
  end

  return {
    ARM_SRC = raw.ARM_SRC or raw.ARM_SWITCH or DEFAULT_SETTINGS.ARM_SRC,
    TURTLE_SRC = raw.TURTLE_SRC or raw.TURTLE_SWITCH or DEFAULT_SETTINGS.TURTLE_SRC,
    BEEP_SRC = raw.BEEP_SRC or raw.BEEP_SWITCH or DEFAULT_SETTINGS.BEEP_SRC,
    UI_INVERT = (raw.UI_INVERT ~= nil) and (raw.UI_INVERT == true) or (raw.UI_INVERT_DEFAULT == true),
  }
end


function M.ensure_settings()
  local cached = rawget(_G, "SET")
  if type(cached) == "table" then
    return cached
  end

  cached = rawget(_G, "VB_SETTINGS")
  if type(cached) == "table" then
    rawset(_G, "SET", cached)
    return cached
  end

  local normalized = normalize_loaded_settings(load_settings_file())
  rawset(_G, "VB_SETTINGS", normalized)
  rawset(_G, "SET", normalized)
  return normalized
end


function M.settings_path()
  return settings_path()
end


function M.settings_raw()
  return load_settings_file()
end


function M.reload_settings()
  local purge = rawget(_G, "VB_PURGE")
  if type(purge) == "function" then
    pcall(purge, settings_path())
  end

  rawset(_G, "VB_SETTINGS_RAW", nil)
  rawset(_G, "VB_SETTINGS", nil)
  rawset(_G, "SET", nil)
  return M.ensure_settings()
end


local function bool_to_lua(value)
  return value and "true" or "false"
end


local function serialize_settings(data)
  return table.concat({
    "return {\n",
    string.format("  ARM_SWITCH = %q,\n", data.ARM_SWITCH),
    string.format("  TURTLE_SWITCH = %q,\n", data.TURTLE_SWITCH),
    string.format("  BEEP_SWITCH = %q,\n", data.BEEP_SWITCH),
    string.format("  UI_INVERT_DEFAULT = %s,\n", bool_to_lua(data.UI_INVERT_DEFAULT)),
    "}\n",
  })
end


local function write_file(path, payload)
  if not (io and type(io.open) == "function") then
    return false
  end

  local handle = io.open(path, "w")
  if not handle then
    return false
  end

  local ok
  if io and type(io.write) == "function" then
    ok = pcall(io.write, handle, payload)
  elseif type(handle.write) == "function" then
    ok = pcall(handle.write, handle, payload)
  else
    ok = false
  end

  if io and type(io.close) == "function" then
    pcall(io.close, handle)
  elseif type(handle.close) == "function" then
    pcall(handle.close, handle)
  end

  if not ok and os and type(os.remove) == "function" then
    pcall(os.remove, path)
  end

  return ok == true
end


function M.update_settings(patch)
  if type(patch) ~= "table" then
    return false
  end

  local raw = load_settings_file()
  if type(raw) ~= "table" then
    raw = {}
  end

  for key, value in pairs(patch) do
    raw[key] = value
  end

  local serialized = serialize_settings({
    ARM_SWITCH = raw.ARM_SWITCH or raw.ARM_SRC or DEFAULT_SETTINGS.ARM_SRC,
    TURTLE_SWITCH = raw.TURTLE_SWITCH or raw.TURTLE_SRC or DEFAULT_SETTINGS.TURTLE_SRC,
    BEEP_SWITCH = raw.BEEP_SWITCH or raw.BEEP_SRC or DEFAULT_SETTINGS.BEEP_SRC,
    UI_INVERT_DEFAULT = (raw.UI_INVERT_DEFAULT ~= nil) and (raw.UI_INVERT_DEFAULT == true) or (raw.UI_INVERT == true),
  })

  if not write_file(settings_path(), serialized) then
    return false
  end

  rawset(_G, "VB_SETTINGS_RAW", nil)
  rawset(_G, "VB_SETTINGS", nil)
  rawset(_G, "SET", nil)
  M.ensure_settings()
  return true
end




local function read_tx_voltage()
  local value = safe_get_value("tx-voltage")
  if type(value) ~= "number" or value <= 0 then
    return nil
  end

  if value > 20 and value < 200 then
    value = value / 10
  elseif value >= 200 and value < 2000 then
    value = value / 100
  end

  return value
end


local function read_model_name()
  if type(getModelName) == "function" then
    local name = getModelName()
    if type(name) == "string" and name ~= "" then
      return name
    end
  end

  if type(model) == "table" and type(model.getInfo) == "function" then
    local info = model.getInfo()
    if type(info) == "table" and type(info.name) == "string" and info.name ~= "" then
      return info.name
    end
  end

  return "Model"
end


local function read_timer_value(timer_index)
  if not (model and type(model.getTimer) == "function") then
    return 0
  end

  local timer = model.getTimer(timer_index - 1) or {}
  if type(timer.value) == "number" then
    return math.floor(timer.value)
  end

  return 0
end


local function read_timer_name(timer_index)
  if not (model and type(model.getTimer) == "function") then
    return "T" .. tostring(timer_index)
  end

  local timer = model.getTimer(timer_index - 1) or {}
  local name = timer.name
  if type(name) == "string" and name ~= "" then
    return name
  end

  return "T" .. tostring(timer_index)
end



local function read_clock_value()
  if type(getDateTime) ~= "function" then
    return nil, nil
  end

  local dt = getDateTime() or {}
  local hour = tonumber(dt.hour or 0) or 0
  local minute = tonumber(dt.min or 0) or 0
  return hour % 24, minute
end


local BAR_CACHE = rawget(_G, "VB_BAR_CACHE")
if type(BAR_CACHE) ~= "table" then
  BAR_CACHE = {}
  rawset(_G, "VB_BAR_CACHE", BAR_CACHE)
end


local function update_bar_cache(timestamp, force)
  if force or BAR_CACHE.model_name == nil then
    BAR_CACHE.model_name = read_model_name()
  end

  if force or timestamp >= (BAR_CACHE.next_tx_voltage or 0) then
    BAR_CACHE.tx_voltage = read_tx_voltage()
    BAR_CACHE.next_tx_voltage = timestamp + BAR_PERIOD
  end

  if force or timestamp >= (BAR_CACHE.next_timers or 0) then
    BAR_CACHE.timer1_name = read_timer_name(1)
    BAR_CACHE.timer2_name = read_timer_name(2)
    BAR_CACHE.timer1 = read_timer_value(1)
    BAR_CACHE.timer2 = read_timer_value(2)
    BAR_CACHE.next_timers = timestamp + BAR_PERIOD
  end

  if force or timestamp >= (BAR_CACHE.next_clock or 0) then
    BAR_CACHE.clock_hour, BAR_CACHE.clock_min = read_clock_value()
    BAR_CACHE.next_clock = timestamp + CLOCK_PERIOD
  end
end


local function update_sensor_list(sensor_names)
  for index = 1, #sensor_names do
    M.gv(sensor_names[index])
  end
end


local TLM_CACHE = rawget(_G, "VB_TLM_CACHE")
if type(TLM_CACHE) ~= "table" then
  TLM_CACHE = {}
  rawset(_G, "VB_TLM_CACHE", TLM_CACHE)
end


function M.gv(name)
  if type(name) ~= "string" or name == "" then
    return nil
  end

  local value = safe_get_value(name)
  if value ~= nil then
    TLM_CACHE[name] = value
    return value
  end

  return TLM_CACHE[name]
end


function M.peek(name, default)
  if type(name) ~= "string" or name == "" then
    return default
  end

  local value = TLM_CACHE[name]
  if value == nil then
    return default
  end

  return value
end


function M.tlm_cache()
  return TLM_CACHE
end


function M.bar_cache()
  return BAR_CACHE
end


function M.is_armed()
  local settings = M.ensure_settings()
  local source = (type(settings) == "table" and settings.ARM_SRC) or DEFAULT_SETTINGS.ARM_SRC
  local value = UTIL.src_val(source)
  return value == 1 or value == true
end


function M.has_telemetry()
  local lq = tonumber(M.peek("RQly"))
  local tx_rssi = tonumber(M.peek("TRSS"))
  local rx_rssi = tonumber(M.peek("1RSS"))
  if rx_rssi == nil then
    rx_rssi = tonumber(M.peek("2RSS"))
  end

  if lq and lq > 0 then
    return true
  end
  if tx_rssi and tx_rssi < 0 and tx_rssi > -200 then
    return true
  end
  if rx_rssi and rx_rssi < 0 and rx_rssi > -200 then
    return true
  end
  return false
end


function M.update_tlm(force)
  local state = rawget(_G, "VB_TLM_STATE")
  if type(state) ~= "table" then
    state = {}
    rawset(_G, "VB_TLM_STATE", state)
  end

  local timestamp = UTIL.now()
  force = force == true

  if force or timestamp >= (state.next_fast or 0) then
    update_sensor_list(FAST_SENSORS)
    state.next_fast = timestamp + FAST_PERIOD
  end

  if force or timestamp >= (state.next_medium or 0) then
    update_sensor_list(MEDIUM_SENSORS)
    state.next_medium = timestamp + MEDIUM_PERIOD
  end

  update_bar_cache(timestamp, force)

  if force or timestamp >= (state.next_state or 0) or state.telemetry_ok == nil then
    state.telemetry_ok = M.has_telemetry()
    state.last_armed = M.is_armed()
    state.next_state = timestamp + STATE_PERIOD
    rawset(_G, "VB_ARMED", state.last_armed)
  end

  return state.telemetry_ok == true
end


function M.background_tick()
  return M.update_tlm()
end


M.UI = UI
M.UTIL = UTIL

rawset(_G, "UI", UI)
rawset(_G, "VB_UTIL", UTIL)

return M
