-- Shared top and bottom bars for the lite build.
-- Top bar: model name, TX voltage and TX battery icon.
-- Bottom bar: T1, clock and T2.

local CORE = assert(rawget(_G, "VB_CORE"), "VB bars: VB_CORE missing")
local UI = assert(CORE.UI, "VB bars: CORE.UI missing")

local BAR = rawget(_G, "VB_BAR") or rawget(_G, "BAR")
if type(BAR) ~= "table" then
  BAR = {}
end

local RIGHT = RIGHT or 0x0400
local CENTER = CENTER or 0x0200
local SMLSIZE = SMLSIZE or 0x0200
local INVERS = INVERS or 0x0100

local TX_BAT_MIN = 6.6
local TX_BAT_MAX = 8.4

local TOP_BAR_Y = 0
local BOTTOM_BAR_Y = 56

local MODEL_X = 1
local TXV_X = 111
local TX_BATT_X = 113

local T_LEFT_X = 1
local CLOCK_X = 65
local T_RIGHT_X = 128


local function clamp(value, min_value, max_value)
  if value < min_value then
    return min_value
  end
  if value > max_value then
    return max_value
  end
  return value
end


local function inverse_flags(extra)
  if UI._invert then
    return extra or 0
  end
  return (extra or 0) + INVERS
end


local function draw_small(x, y, text, flags)
  lcd.drawText(x, y, text or "", (flags or 0) + SMLSIZE)
end


local function two_digits(value)
  if value < 10 then
    return "0" .. tostring(value)
  end
  return tostring(value)
end


local function format_mmss(seconds)
  local value = tonumber(seconds or 0) or 0
  if value < 0 then
    value = -value
  end

  local minutes = math.floor(value / 60)
  local secs = value % 60
  return two_digits(minutes) .. ":" .. two_digits(secs)
end


local function read_tx_voltage()
  local value = getValue("tx-voltage")
  if type(value) ~= "number" or value <= 0 then
    return nil
  end

  -- EdgeTX may expose pack voltage in different scales depending on target.
  if value > 20 and value < 200 then
    value = value / 10
  elseif value >= 200 and value < 2000 then
    value = value / 100
  end

  return value
end


local function tx_voltage_percent(voltage)
  if not voltage then
    return 0
  end

  local percent = (voltage - TX_BAT_MIN) * 100 / (TX_BAT_MAX - TX_BAT_MIN)
  return clamp(math.floor(percent + 0.5), 0, 100)
end


local function bar_cache()
  if CORE and type(CORE.bar_cache) == "function" then
    return CORE.bar_cache()
  end
  return nil
end


local function draw_battery_icon(x, y, percent)
  local shown_percent = clamp(percent or 0, 0, 100)
  local inner_x = x + 1
  local inner_y = y + 1
  local segment_w = 2
  local segment_h = 4
  local step = 3

  local fill_flags = UI._invert and 0 or INVERS
  local clear_flags = UI._invert and INVERS or 0

  lcd.drawFilledRectangle(x, y, 13, 6)
  lcd.drawFilledRectangle(x - 1, y + 2, 1, 2)

  for index = 0, 3 do
    lcd.drawFilledRectangle(inner_x + index * step, inner_y, segment_w, segment_h, clear_flags)
  end

  local shown_segments =
    (shown_percent >= 75) and 4 or
    (shown_percent >= 50) and 3 or
    (shown_percent >= 25) and 2 or
    (shown_percent >= 5) and 1 or 0

  for index = 0, 3 do
    local x_pos = inner_x + index * step
    local is_on = index >= 4 - shown_segments
    if UI._invert then
      is_on = not is_on
    end

    local segment_flags
    if UI._invert then
      segment_flags = is_on and clear_flags or fill_flags
    else
      segment_flags = is_on and fill_flags or clear_flags
    end

    lcd.drawFilledRectangle(x_pos, inner_y, segment_w, segment_h, segment_flags)
  end
end


local function read_timer(timer_index)
  local timer_name = "T" .. tostring(timer_index)
  local cache = bar_cache()
  if cache then
    local cached_name = (timer_index == 1) and cache.timer1_name or cache.timer2_name
    local cached_value = (timer_index == 1) and cache.timer1 or cache.timer2
    if type(cached_name) == "string" and cached_name ~= "" then
      timer_name = cached_name
    end
    if type(cached_value) == "number" then
      return timer_name .. " " .. format_mmss(cached_value)
    end
  end

  if not (model and type(model.getTimer) == "function") then
    return timer_name .. " 00:00"
  end

  local timer = model.getTimer(timer_index - 1) or {}
  local name = timer.name
  if type(name) == "string" and name ~= "" then
    timer_name = name
  end

  local value = 0
  if type(timer.value) == "number" then
    value = math.floor(timer.value)
  end

  return timer_name .. " " .. format_mmss(value)
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


local function draw_clock()
  local cache = bar_cache()
  local hour = cache and cache.clock_hour or nil
  local minute = cache and cache.clock_min or nil

  if hour == nil or minute == nil then
    if type(getDateTime) ~= "function" then
      draw_small(CLOCK_X, BOTTOM_BAR_Y + 1, "--:--", CENTER + inverse_flags())
      return
    end

    local dt = getDateTime() or {}
    hour = tonumber(dt.hour or 0) or 0
    minute = tonumber(dt.min or 0) or 0
  end

  draw_small(CLOCK_X, BOTTOM_BAR_Y + 1, two_digits(hour % 24) .. ":" .. two_digits(minute), CENTER + inverse_flags())
end


function BAR.setup()
  local cache = bar_cache()
  BAR.model_name = (cache and cache.model_name) or read_model_name()
  BAR._ready = true
  return BAR
end


function BAR.draw_top()
  lcd.drawFilledRectangle(0, TOP_BAR_Y, 128, 8, 0)
  local cache = bar_cache()
  local model_name = (cache and cache.model_name) or BAR.model_name or read_model_name()
  draw_small(MODEL_X, TOP_BAR_Y + 1, model_name, inverse_flags())

  local voltage = (cache and cache.tx_voltage) or read_tx_voltage()
  local text = "--.-V"
  if voltage then
    local blink_on = ((getTime() // 64) % 2) == 0
    if not (voltage <= TX_BAT_MIN and blink_on) then
      text = string.format("%.1fV", voltage)
    end
  end

  draw_small(TXV_X, TOP_BAR_Y + 1, text, RIGHT + inverse_flags())
  draw_battery_icon(TX_BATT_X, TOP_BAR_Y + 1, tx_voltage_percent(voltage))
end


function BAR.draw_bottom()
  lcd.drawFilledRectangle(0, BOTTOM_BAR_Y, 128, 8, 0)
  draw_small(T_LEFT_X, BOTTOM_BAR_Y + 1, read_timer(1), inverse_flags())
  draw_clock()
  draw_small(T_RIGHT_X, BOTTOM_BAR_Y + 1, read_timer(2), RIGHT + inverse_flags())
end


rawset(_G, "VB_BAR", BAR)
rawset(_G, "BAR", BAR)

return BAR
