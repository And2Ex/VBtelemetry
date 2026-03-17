-- VB Telemetry Lite main screen
-- Single-screen telemetry dashboard for the lite build.
-- The lite build keeps only the main telemetry view and loads the shared
-- bars module lazily to keep memory usage stable on small radios.
local VB_DOFILE = rawget(_G, "VB_DOFILE") or dofile
local CORE = rawget(_G, "VB_CORE") or {}
local UI = CORE.UI or {}
local UTIL = CORE.UTIL or {}
local EMPTY = {}
local SET  = CORE.ensure_settings()
local RIGHT   = RIGHT   or 0x0400
local CENTER  = CENTER  or 0x0200
local SMLSIZE = SMLSIZE or 0x0200
local INVERS  = INVERS  or 0x0100

local getValue = getValue
local getTime = getTime
local drawText = lcd.drawText
local drawLine = lcd.drawLine
local drawFilledRectangle = lcd.drawFilledRectangle
local update_tlm = CORE.update_tlm
local util_src_val = UTIL.src_val
local util_gc_light = UTIL.gc_light
local util_is_enter = UTIL.is_enter
local util_is_exit = UTIL.is_exit
local BARS_MODULE_PATH = (rawget(_G, "VB_LIB_DIR") or "VBlib") .. "/bars.luac"

local function src_val(src)
  if src == nil then return nil end
  return util_src_val and util_src_val(src) or getValue(src)
end

local function src_active(src)
  local v = src_val(src)
  return v == 1 or v == true
end

local function refresh_tlm()
  if update_tlm then
    return update_tlm()
  end
end

local function has_telemetry_fallback()
  local S = rawget(_G, "VB_TLM_STATE")
  if type(S) == "table" and S.telemetry_ok ~= nil then
    return S.telemetry_ok == true
  end
  return rawget(_G, "VB_TLM_EVER") == true
end

local ANT_OPTS = { gap_lq_val = 0, gap_val_db = 1 }
local POS = {
main = {
notel = { 0, 14, 1, 0 },
tx = {
ant = { 0, 9, 0, 0 },
db = { -44, 7, 1, 1 },
lq = { -44, 16, 1, 1 },
snr = { -44, -2, 1, 1 },
label = { -46, -11, 1, 1 },
opts = ANT_OPTS,
},
rx = {
ant = { -1, 9, 2, 0 },
db = { 46, 7, 1, 1 },
lq = { 46, 16, 1, 1 },
snr = { 44, -2, 1, 1 },
label = { 46, -11, 1, 1 },
opts = ANT_OPTS,
},
info = {
tpwr = { -18, 14, 1, 0 },
tpwr_cells = { -18, 9, 1, 0 },
rfmd = { 18, 14, 1, 0 },
rfmd_wave = { 17, 9, 1, 0 },
fm = { 0, 39, 1, 0 },
rxbt = { 0, 48, 1, 0 },
},
lines = { 23, 8, 46, 55, 2, 103, 8, 80, 55, 2 },
tags = {
state = { -24, 23, 1, 0, w = 48, h = 12 },
},
},
}


-- RFMD label/rate maps are screen-local (not stored in core.lua to save RAM).
local _RFMD_LABEL = {
  [14] = "D50",
  [13] = "F1000",
  [12] = "F500",
  [11] = "D500",
  [10] = "D250",
  [9]  = "500Hz",
  [8]  = "333HzF",
  [7]  = "250Hz",
  [6]  = "200Hz",
  [5]  = "150Hz",
  [4]  = "100HzF",
  [3]  = "100Hz",
  [2]  = "50Hz",
  [1]  = "25Hz",
}

local _RFMD_RATE = {
  [14] = 50,
  [13] = 1000,
  [12] = 500,
  [11] = 500,
  [10] = 250,
  [9]  = 500,
  [8]  = 333,
  [7]  = 250,
  [6]  = 200,
  [5]  = 150,
  [4]  = 100,
  [3]  = 100,
  [2]  = 50,
  [1]  = 25,
}

local function _rfmd_label(v)
  if type(v) == "string" and v ~= "" then
    return v
  end
  local k = tonumber(v or 0) or 0
  return _RFMD_LABEL[k] or tostring(k)
end

-- RFMD rate-wave and power cells are screen-local (not stored in bars.lua to save RAM).
local _RFMD_RATE_SHAPES = {
  [1000] = { 12, 1, 1 },
  [500]  = { 8, 2, 1 },
  [333]  = { 6, 3, 1 },
  [250]  = { 5, 4, 1 },
  [200]  = { 4, 5, 1 },
  [150]  = { 3, 7, 1 },
  [100]  = { 2, 11, 1 },
  [50]   = { 1, 13, 0 },
  [25]   = { 1, 23, 0 },
}

local _rfmd_wave_cache = { k = nil, segs = nil, segw = nil, gap = nil, total = nil }

local POWER_STEPS = { 10, 25, 50, 100, 250, 500, 1000, 2000 }


local function power_level(mw)
  local lvl = 0
  for i = 1, #POWER_STEPS do
    if mw >= POWER_STEPS[i] then
      lvl = i
    end
  end
  if lvl == 0 and mw > 0 then
    return 1
  end
  return lvl
end


local function draw_power_cells(pos, mw)
  if not pos or mw == nil or not (UI and UI.pos_xy) then
    return
  end

  local mw_num = tonumber(mw)
  if not mw_num then
    local s = tostring(mw)
    mw_num = tonumber(string.match(s, "(%d+)"))
  end
  if not mw_num then
    return
  end

  local cx, cy = UI.pos_xy(pos)
  local cell_w = tonumber(pos.cell_w or pos.cellWidth or pos.cell or 2) or 2
  local cell_h = tonumber(pos.cell_h or pos.cellHeight or pos.cell or 3) or 3
  local gap = tonumber(pos.gap or 1) or 1
  local max_n = tonumber(pos.count or 8) or 8

  local lvl = power_level(mw_num)
  if lvl > max_n then
    lvl = max_n
  end

  local total = max_n * cell_w + (max_n - 1) * gap
  local x0 = cx - math.floor(total / 2)
  local y_line = cy + cell_h - 1

  for i = 1, max_n do
    local x = x0 + (i - 1) * (cell_w + gap)
    if i <= lvl then
      lcd.drawFilledRectangle(x, cy, cell_w, cell_h, 0)
    else
      lcd.drawFilledRectangle(x, y_line, cell_w, 1, 0)
    end
  end
end

local function _rfmd_value_to_rate(v)
  local k = tonumber(v or 0)
  if not k then
    return nil
  end
  return _RFMD_RATE[k]
end

local function _shape_for_rfmd_center(v)
  local k = tonumber(v or 0)
  if not k then
    return nil
  end
  if _rfmd_wave_cache.k == k and _rfmd_wave_cache.segs then
    return _rfmd_wave_cache.segs, _rfmd_wave_cache.segw, _rfmd_wave_cache.gap, _rfmd_wave_cache.total
  end

  _rfmd_wave_cache.k = k
  _rfmd_wave_cache.segs, _rfmd_wave_cache.segw, _rfmd_wave_cache.gap, _rfmd_wave_cache.total = nil, nil, nil, nil

  local rate = _rfmd_value_to_rate(k)
  if not rate then
    return nil
  end

  local sh = _RFMD_RATE_SHAPES[rate]
  if not sh then
    return nil
  end

  local segs, segw, gap = sh[1], sh[2], sh[3]
  if rate == 50 then
    segw = segw + 4
  end

  _rfmd_wave_cache.segs = segs
  _rfmd_wave_cache.segw = segw
  _rfmd_wave_cache.gap = gap
  _rfmd_wave_cache.total = segs * segw + (segs - 1) * gap

  return segs, segw, gap, _rfmd_wave_cache.total
end

local function draw_rate_wave(pos, rfmd_value)
  if not pos then
    return
  end
  if not (UI and UI.pos_xy) then
    return
  end

  local segs, segw, gap, total = _shape_for_rfmd_center(rfmd_value)
  if not segs then
    return
  end

  local h = 3
  local cx, cy = UI.pos_xy(pos)
  local x0 = cx - math.floor(total / 2)

  for i = 1, segs do
    local x = x0 + (i - 1) * (segw + gap)
    lcd.drawFilledRectangle(x, cy, segw, h, 0)
  end
end


local _SOLID = rawget(_G, "SOLID") or 0
local _ERASE = rawget(_G, "ERASE") or 0

local function _rounded_border(x, y, w, h, border_flag, corner_flag)
  if UI and UI.rounded_border then
    return UI.rounded_border(x, y, w, h, border_flag, corner_flag)
  end
  if not (lcd and lcd.drawRectangle) then
    return
  end
  local bf = border_flag
  if bf == nil then bf = _SOLID end
  lcd.drawRectangle(x, y, w, h, bf)
  local cf = corner_flag
  if cf == nil then
    if bf == _ERASE then
      cf = _SOLID
    else
      cf = _ERASE
    end
  end
  if lcd.drawPoint then
    lcd.drawPoint(x, y, cf)
    lcd.drawPoint(x + w - 1, y, cf)
    lcd.drawPoint(x, y + h - 1, cf)
    lcd.drawPoint(x + w - 1, y + h - 1, cf)
  else
    lcd.drawFilledRectangle(x, y, 1, 1, cf)
    lcd.drawFilledRectangle(x + w - 1, y, 1, 1, cf)
    lcd.drawFilledRectangle(x, y + h - 1, 1, 1, cf)
    lcd.drawFilledRectangle(x + w - 1, y + h - 1, 1, 1, cf)
  end
end


local function _rounded_fill_black(x, y, w, h)
  if UI and UI.rounded_fill then
    return UI.rounded_fill(x, y, w, h, 0)
  end
  if lcd and lcd.drawFilledRectangle then
    lcd.drawFilledRectangle(x, y, w, h, 0)
  end
end


local function draw_tag_badge_text(x, y, w, h, text, bg_invert, _text_invert_unused, flags)
  if not (lcd and lcd.drawText) then
    return
  end

  flags = flags or 0

  local base_flags = flags + (SMLSIZE or 0)
  if INVERS and bit32 and bit32.band and bit32.bnot then
    base_flags = bit32.band(base_flags, bit32.bnot(INVERS))
  end

  local inv = false
  if SET and (SET.UI_INVERT ~= nil) then
    inv = (SET.UI_INVERT == true)
  elseif UI and (UI._invert ~= nil) then
    inv = (UI._invert == true)
  end

  local SOL = _SOLID
  local ERA = _ERASE

  local bf = inv and ERA or SOL
  local cf = inv and SOL or ERA

  if bg_invert and lcd and lcd.drawFilledRectangle then
    local fill = inv and ERA or SOL

    if w > 4 and h > 4 then
      lcd.drawFilledRectangle(x + 1, y + 1, w - 2, h - 2, fill)
    elseif w > 2 and h > 2 then

      lcd.drawFilledRectangle(x + 1, y + 1, w - 2, h - 2, fill)
    end
  end

  _rounded_border(x, y, w, h, bf, cf)

  local need_invers = (bg_invert and (not inv)) or ((not bg_invert) and inv)

  local tf = base_flags + (CENTER or 0) + (need_invers and (INVERS or 0) or 0)

  lcd.drawText(
  x + math.floor(w / 2),
  y + math.max(0, math.floor((h - 6) / 2)),
  tostring(text),
  tf
  )
end


local function short_power_mw(v)
  v = tonumber(v)
  if not v or v <= 0 then
    return "PIT"
  end
  if v >= 1000 then
    if v == 1000 then
      return "1W"
    end
    if v == 2000 then
      return "2W"
    end
    return tostring(math.floor((v / 1000) * 10 + 0.5) / 10) .. "W"
  end
  return tostring(math.floor(v + 0.5)) .. "mW"
end

-- Bars are loaded lazily because they are shared by multiple screens and can be
-- unloaded during screen transitions on tighter targets.
local function ensure_bars()
  local b = rawget(_G, "VB_BAR") or rawget(_G, "BAR")
  if type(b) == "table" then
    return b
  end

  local loader = VB_DOFILE
  local ok, mod = pcall(loader, BARS_MODULE_PATH, true)
  if ok and type(mod) == "table" then
    b = mod
  else
    b = rawget(_G, "VB_BAR") or rawget(_G, "BAR")
  end

  if type(b) == "table" then
    _G.VB_BAR = b
    _G.BAR = b
    return b
  end
end

local function _thick_line(x1, y1, x2, y2, w, flags)
  flags = flags or 0
  w = tonumber(w or 1) or 1
  if w <= 1 then
    drawLine(x1, y1, x2, y2, SOLID or 0, flags)
    return
  end

  local dx = math.abs((x2 or 0) - (x1 or 0))
  local dy = math.abs((y2 or 0) - (y1 or 0))
  local o0 = -math.floor((w - 1) / 2)
  local o1 = o0 + w - 1

  if dx >= dy then
    for o = o0, o1 do
      drawLine(x1, y1 + o, x2, y2 + o, SOLID or 0, flags)
    end
  else
    for o = o0, o1 do
      drawLine(x1 + o, y1, x2 + o, y2, SOLID or 0, flags)
    end
  end
end

local function _draw_lines(lines, flags)
  if type(lines) ~= "table" then return end
  if type(lines[1]) == "number" then
    for i = 1, #lines, 5 do
      _thick_line(lines[i] or 0, lines[i + 1] or 0, lines[i + 2] or 0, lines[i + 3] or 0, lines[i + 4] or 1, flags)
    end
    return
  end
  for i = 1, #lines do
    local ln = lines[i]
    if type(ln) == "table" then
      local x1 = ln[1] or ln.x1 or 0
      local y1 = ln[2] or ln.y1 or 0
      local x2 = ln[3] or ln.x2 or 0
      local y2 = ln[4] or ln.y2 or 0
      local w  = ln[5] or ln.w or 1
      _thick_line(x1, y1, x2, y2, w, flags)
    end
  end
end


local function has_telemetry()
  if CORE and type(CORE.has_telemetry) == "function" then
    return CORE.has_telemetry()
  end
  return has_telemetry_fallback()
end

-- Safe getValue wrapper (older builds used a global gv()).
-- Must be declared BEFORE read_* helpers below.

local function gv(name)
  if CORE and type(CORE.gv) == "function" then
    return CORE.gv(name)
  end
  local ok, v = pcall(getValue, name)
  if ok then
    return v
  end
  return nil
end


local function read_sensor(name, default)
  local v = gv(name)
  if v == nil then
    return default
  end
  return v
end


local function read_rrss(default)
  local v = gv("1RSS")
  if v == nil then
    v = gv("2RSS")
  end
  if v == nil then
    return default
  end
  return v
end

local function is_valid_fm(v)
  if v == nil then
    return false
  end
  local t = type(v)
  if t == "string" then
    return v ~= "" and v ~= "0"
  end
  local n = tonumber(v)
  return n ~= nil and n ~= 0
end


local function is_valid_rxbt(v)
  local n = tonumber(v)
  return n ~= nil and n > 0.1
end


local function rssi_pct(db)
  if db == nil then return nil end
  local v = tonumber(db) or 0
  if v <= -115 then return 0 end
  if v >= -60  then return 100 end
  return math.floor((v + 115) * 100 / 55 + 0.5)
end

-- Antenna bars renderer for MAIN screen (kept local to avoid global nil calls).
-- Mirrors the same antenna logic for consistent look and low allocations.

local function _antennas_main()
  local ANT_ROWS   = 7
  local LQ_W, LQ_H = 1, 3
  local GAP_V      = 1
  local DB_H       = 3
  local DB_W_MAIN  = {3, 4, 5, 7, 9, 12, 16}
  local DB_MAX_MAIN = DB_W_MAIN[#DB_W_MAIN]

  local function lq_active_from_pct(pct)
    local p = tonumber(pct) or 0
    if p < 5  then return 0 end
    if p < 20 then return 1 end
    if p < 35 then return 2 end
    if p < 50 then return 3 end
    if p < 65 then return 4 end
    if p < 80 then return 5 end
    if p < 92 then return 6 end
    return 7
  end

  local function db_active_from_pct(pct)
    local p = tonumber(pct) or 0
    if p <= 0 then return 0 end
    if p >= 100 then return ANT_ROWS end
    return math.floor(p * ANT_ROWS / 100 + 0.5)
  end

  local function layout_positions(x, mirror, opts)
    local gap_lq_val = 0
    local gap_val_db = 1
    if opts then
      gap_lq_val = tonumber(opts.gap_lq_val) or 0
      gap_val_db = tonumber(opts.gap_val_db) or 1
    end
    local lq_x = x
    local db_x
    if not mirror then
      db_x = lq_x + LQ_W + gap_lq_val + gap_val_db
    else
      db_x = lq_x - gap_val_db - DB_MAX_MAIN
    end
    return lq_x, db_x
  end

  local function snr_state(snr_db)
    local s = tonumber(snr_db)
    if not s then return 0 end
    if s >= -3 then return 0 end
    if s >= -6 then return 1 end
    if s >= -10 then return 2 end
    return 3
  end

  local function shade_count(active, state)
    local a = tonumber(active) or 0
    if a <= 0 then return 0 end
    if state <= 0 then return 0 end
    if state == 1 then return math.max(1, math.ceil(a / 3)) end
    if state == 2 then return math.max(1, math.ceil(a / 2)) end
    return a
  end

  local function dither_rect(x, y, w, h, anchor_right)
    if w <= 0 or h <= 0 then return end
    for yy = 0, h - 1 do
      local start = ((yy + 1) % 2)
      if anchor_right then
        start = (start + ((w - 1) % 2)) % 2
      end
      local inv = (UI and UI._invert) and true or false
      local f = inv and (INVERS or 0) or (_ERASE or 0)
      for xx = start, w - 1, 2 do
        lcd.drawFilledRectangle(x + xx, y + yy, 1, 1, f)
      end
    end
  end
  return function(x, y, mirror, lq_pct, rssi_pct, opts, snr_db)
    local lq_active = lq_active_from_pct(lq_pct)
    local db_active = db_active_from_pct(rssi_pct)
    local s_state = snr_state(snr_db)
    local shaded  = shade_count(db_active, s_state)
    local total_h = ANT_ROWS * LQ_H + (ANT_ROWS - 1) * GAP_V
    local bottom  = y + total_h - LQ_H
    local lq_x, base_db_x = layout_positions(x, mirror, opts)
    for i = 0, ANT_ROWS - 1 do
      local ty = bottom - i * (LQ_H + GAP_V)
      if i < lq_active then
        lcd.drawFilledRectangle(lq_x, ty, LQ_W, LQ_H, 0)
      end
      local w = DB_W_MAIN[i + 1] or DB_W_MAIN[#DB_W_MAIN]
      local dx = mirror and (base_db_x + (DB_MAX_MAIN - w)) or base_db_x
      if i < db_active then
        lcd.drawFilledRectangle(dx, ty, w, DB_H, 0)
        if i < shaded then
          dither_rect(dx, ty, w, DB_H, not mirror)
        end
      end
    end
  end
end
local draw_antennas_main = _antennas_main()
local _fmt_cache = {
db_raw = nil, db_txt = nil,
lq_raw = nil, lq_txt = nil,
rxbt_raw = nil, rxbt_txt = nil,
snr_raw = nil, snr_txt = nil,
}

local function fmt_db(db)
  if db == nil then return "--" end
  local n = tonumber(db)
  if n == nil then return "--" end
  local r
  if n >= 0 then
    r = math.floor(n + 0.5)
  else
    r = math.ceil(n - 0.5)
  end
  if _fmt_cache.db_raw == r then
    return _fmt_cache.db_txt
  end
  local s = tostring(r) .. "dBm"
  _fmt_cache.db_raw = r
  _fmt_cache.db_txt = s
  return s
end
local function fmt_lq(p)
  if p == nil then return "--" end
  local n = math.floor(tonumber(p) or 0)
  if _fmt_cache.lq_raw == n then
    return _fmt_cache.lq_txt
  end
  local s = "LQ " .. tostring(n) .. "%"
  _fmt_cache.lq_raw = n
  _fmt_cache.lq_txt = s
  return s
end


local function fmt_rxbt(v)
  if not v then
    return "--"
  end
  local raw = math.floor((tonumber(v) or 0) * 10 + 0.5)
  if _fmt_cache.rxbt_raw == raw then
    return _fmt_cache.rxbt_txt
  end
  local s = string.format("%.1fV", v)
  _fmt_cache.rxbt_raw = raw
  _fmt_cache.rxbt_txt = s
  return s
end


local function fmt_snr(v)
  if v == nil then return "--" end
  local n = tonumber(v)
  if n == nil then return "--" end
  local raw = math.floor(n * 10 + 0.5)
  if _fmt_cache.snr_raw == raw then
    return _fmt_cache.snr_txt
  end
  local r
  if n >= 0 then
    r = math.floor(n + 0.5)
  else
    r = math.ceil(n - 0.5)
  end
  if r > 0 then
    _fmt_cache.snr_raw = raw
    _fmt_cache.snr_txt = "+" .. tostring(r) .. "dB"
    return _fmt_cache.snr_txt
  elseif r == 0 then
    _fmt_cache.snr_raw = raw
    _fmt_cache.snr_txt = "0dB"
    return _fmt_cache.snr_txt
  end
  _fmt_cache.snr_raw = raw
  _fmt_cache.snr_txt = tostring(r) .. "dB"
  return _fmt_cache.snr_txt
end


local function compute_state_badge()
  local txt, invert = "DISARMED", false
  local turtle = src_active(SET and SET.TURTLE_SRC or "sb")
  if src_active(SET and SET.BEEP_SRC or "se") then
    txt, invert = "BEEP", false
  elseif turtle then
    if src_active(SET and SET.ARM_SRC or "sa") then
      txt, invert = "TURTLE!", true
    else
      txt, invert = "TURTLE", false
    end
  elseif src_active(SET and SET.ARM_SRC or "sa") then
    txt, invert = "ARMED!", true
  end
  return txt, invert, false
end


local function draw_state_badge(pos)
  if not (pos and UI and UI.pos_xy and draw_tag_badge_text) then
    return
  end
  local x, y = UI.pos_xy(pos)
  local w = pos.w or 50
  local h = pos.h or 12
  local txt, invert, text_inv = compute_state_badge()
  draw_tag_badge_text(x, y, w, h, txt, invert, text_inv, 0)
end


local function draw_tx_rx_labels_always(P)
  if not (P and UI and UI.pos_xy and lcd and lcd.drawText) then
    return
  end
  do
    local lbl_pos = (P.tx and P.tx.label) or nil
    if lbl_pos then
      UI.text(lbl_pos, "TX", 0)
    else
      local snr_pos = (P.tx and P.tx.snr) or (P.tags and P.tags.tx)
      if snr_pos then
        local x, y = UI.pos_xy(snr_pos)
        local f = (UI.flags and UI.flags(snr_pos)) or (SMLSIZE or 0)
        lcd.drawText(x, y - 7, "TX", (f + (CENTER or 0)))
      end
    end
  end
  do
    local lbl_pos = (P.rx and P.rx.label) or nil
    if lbl_pos then
      UI.text(lbl_pos, "RX", 0)
    else
      local snr_pos = (P.rx and P.rx.snr) or (P.tags and P.tags.rx)
      if snr_pos then
        local x, y = UI.pos_xy(snr_pos)
        local f = (UI.flags and UI.flags(snr_pos)) or (SMLSIZE or 0)
        lcd.drawText(x, y - 7, "RX", (f + (CENTER or 0)))
      end
    end
  end
end

local last_main = rawget(_G, "VB_LAST_MAIN")
if type(last_main) ~= "table" then
  last_main = { fm = nil, rxbt = nil }
  rawset(_G, "VB_LAST_MAIN", last_main)
end

local function last_tlm()
  local T = rawget(_G, "VB_LAST_TLM")
  if not T then
    T = {}
    _G.VB_LAST_TLM = T
  end
  return T
end
-- NOTE: Do NOT use UTIL.blink_on() here.
-- Some builds use a much faster blink, which makes TX/RX flicker too quickly.
-- We keep a stable, slow blink based solely on getTime().

local function __blink_on()
  return (math.floor(getTime() / 64) % 2) == 0
end

local BAR = nil
local _bar_ref = nil
local _bar_setup_done = false
local _bars_defer_until = 0
local _bars_first_try_done = false
local _bars_retry_until = 0

local function _now()
  return getTime()
end


local function _ensure_bars_setup()
  local now = _now()
  if now < (_bars_defer_until or 0) then
    return BAR
  end
  if now < (_bars_retry_until or 0) then
    return BAR
  end

  if (not _bars_first_try_done) and UTIL and UTIL.gc_light then
    UTIL.gc_light()
    _bars_first_try_done = true
  end

  local b = ensure_bars()
  BAR = b
  if b ~= _bar_ref then
    _bar_ref = b
    _bar_setup_done = false
  end

  if type(b) ~= "table" then
    _bars_retry_until = now + 8
    return BAR
  end

  -- Setup can fail on tight radios (path or memory). Do not "lock in" a failed setup.
  if b.setup and (not _bar_setup_done or b.SET ~= SET) then
    local ok = pcall(b.setup, SET)
    _bar_setup_done = (ok == true) and (b._ready == true)
    if not _bar_setup_done then
      _bars_retry_until = now + 8
    end
  end

  return b
end
local app = {}

function app.on_unload(_next_name)
  -- Help Lua GC: drop large upvalue tables so a base-screen switch doesn't
  -- accumulate memory fragments on tight radios.
  POS = nil
  ANT_OPTS = nil
  _bar_ref = nil
  _bar_setup_done = false

  _bars_defer_until = 0
  _bars_first_try_done = false
  _bars_retry_until = 0

  if UTIL and type(UTIL.gc_full) == "function" then
    pcall(UTIL.gc_full)
  elseif type(collectgarbage) == "function" then
    pcall(collectgarbage, "collect")
  end
end
local _ignore_until = 0
local _await_release = true
local _last_enter_t = -100000
local _last_exit_t = -100000

local function _is_enter(e)
  return util_is_enter and util_is_enter(e)
end

local function _is_exit(e)
  return util_is_exit and util_is_exit(e)
end


local function _enter_ok()
  local t = _now()
  if (t - _last_enter_t) < 18 then return false end
  _last_enter_t = t
  return true
end


local function _exit_ok()
  local t = _now()
  if (t - _last_exit_t) < 12 then return false end
  _last_exit_t = t
  return true
end


function app.init(args)
  BAR = nil
  _bar_ref = nil
  _bar_setup_done = false

  local delay = 0
  if args and args.from_overlay then
    delay = 6
  elseif args and args.defer_heavy then
    delay = 4
  elseif args and args.cold_start then
    delay = 2
  end

  _bars_defer_until = _now() + delay
  _bars_retry_until = 0
  _bars_first_try_done = false

  if util_gc_light then
    util_gc_light()
  elseif collectgarbage then
    collectgarbage("step", 200)
  end

  _ignore_until = _now() + 2
  _await_release = true
end


function app.background()
  if CORE and type(CORE.background_tick) == "function" then
    CORE.background_tick()
  elseif CORE and type(CORE.update_tlm) == "function" then
    CORE.update_tlm()
  end
end


function app.run(event)

  -- Refresh settings so UI changes, especially inversion, apply immediately.
  SET = rawget(_G, "SET") or SET
  local e = event or 0
  if _now() <= _ignore_until then
    e = 0
  end
  if _await_release then
    if e ~= 0 then
      e = 0
    else
      _await_release = false
    end
  end
  if _is_exit(e) and _exit_ok() then
    if util_gc_light then
      util_gc_light()
    end
    _await_release = true
    return 0
  end
  if _is_enter(e) and _enter_ok() then
    _await_release = true
    return { next_screen = "MENU", args = { from = "MAIN" } }
  end
  refresh_tlm()
  UI.frame_begin(SET and SET.UI_INVERT)
  UI.small()
  local _b = _ensure_bars_setup()
  if _b and _b.draw_top then _b.draw_top() end
  local __noTel
  do
    __noTel = not has_telemetry()
  end
  if __noTel then
    if POS and POS.main and POS.main.lines then _draw_lines(POS.main.lines) end

    -- TX/RX labels must blink together with the rest in NO TELEMETRY
    if __blink_on() then
      draw_tx_rx_labels_always(POS and POS.main)
    end

    draw_state_badge(POS and POS.main and POS.main.tags and POS.main.tags.state or nil)

    if POS and POS.main and POS.main.notel and UI and UI.text then
      UI.text(POS.main.notel, "NO TELEMETRY")
    else
      lcd.drawText(64, 24, "NO TELEMETRY", (CENTER or 0) + (SMLSIZE or 0))
    end

    do
      local P = POS and POS.main or nil
      local I = (P and P.info) or EMPTY
      local T = last_tlm()
      local ever = (T.ever == true) or (rawget(_G, "VB_TLM_EVER") == true)

      if __blink_on() and P then
        -- Middle info (FM / RxBt)
        if ever then
          local fm = T.fm_good or T.fm or last_main.fm
          local rxbt = T.rxbt_good or T.rxbt or last_main.rxbt

          -- If MAIN was not opened while telemetry was alive, the per-screen cache may be empty.
          -- Pull last-known values from the shared telemetry cache maintained by CORE/background.
          if fm == nil and CORE and type(CORE.gv) == "function" then
            fm = CORE.gv("FM")
            if is_valid_fm(fm) then
              last_main.fm = fm
            else
              fm = nil
            end
          end
          if rxbt == nil and CORE and type(CORE.gv) == "function" then
            rxbt = CORE.gv("RxBt")
            if is_valid_rxbt(rxbt) then
              last_main.rxbt = rxbt
            else
              rxbt = nil
            end
          end
          if fm ~= nil and not is_valid_fm(fm) then fm = nil end
          if rxbt ~= nil and not is_valid_rxbt(rxbt) then rxbt = nil end
          if fm and I.fm then UI.text(I.fm, fm) end
          if rxbt and I.rxbt then UI.text(I.rxbt, fmt_rxbt(rxbt)) end
        else
          if I.fm then UI.text(I.fm, "FM") end
          if I.rxbt then UI.text(I.rxbt, "RxBt") end
        end

        if ever then
          -- Telemetry was seen before, but currently lost: draw cached values only.
          do
            local lq  = T.tx_lq
            local db  = T.tx_db or T.tx_rssi
            local snr = T.tx_snr
            if P.tx and P.tx.ant and (lq ~= nil or db ~= nil or snr ~= nil) then
              local x, y = UI.pos_xy(P.tx.ant)
              local o = P.tx.opts
              draw_antennas_main(x, y, false, tonumber(lq or 0) or 0, rssi_pct(db), o, snr)
              if P.tx.db  and db  ~= nil then UI.text(P.tx.db,  fmt_db(db)) end
              if P.tx.lq  and lq  ~= nil then UI.text(P.tx.lq,  fmt_lq(lq)) end
              if P.tx.snr and snr ~= nil then UI.text(P.tx.snr, fmt_snr(snr)) end
            end
          end

          do
            local lq  = T.rx_lq
            local db  = T.rx_db or T.rx_rssi
            local snr = T.rx_snr
            if P.rx and P.rx.ant and (lq ~= nil or db ~= nil or snr ~= nil) then
              local x, y = UI.pos_xy(P.rx.ant)
              local o = P.rx.opts
              draw_antennas_main(x, y, true, tonumber(lq or 0) or 0, rssi_pct(db), o, snr)
              if P.rx.db  and db  ~= nil then UI.text(P.rx.db,  fmt_db(db)) end
              if P.rx.lq  and lq  ~= nil then UI.text(P.rx.lq,  fmt_lq(lq)) end
              if P.rx.snr and snr ~= nil then UI.text(P.rx.snr, fmt_snr(snr)) end
            end
          end

          -- Bars must blink too (use cached values)
          if I.tpwr_cells then
            draw_power_cells(I.tpwr_cells, T.tpwr)
          end
          if I.rfmd_wave then
            draw_rate_wave(I.rfmd_wave, T.rfmd)
          end

        else
          -- Telemetry has NEVER been seen: blink sensor names.
          do
            local x, y = UI.pos_xy(P.tx.ant)
            draw_antennas_main(x, y, false, 0, 100, P.tx.opts, -20)
            if P.tx.db  then UI.text(P.tx.db,  "TRSS") end
            if P.tx.lq  then UI.text(P.tx.lq,  "TQly") end
            if P.tx.snr then UI.text(P.tx.snr, "TSNR") end
          end

          do
            local x, y = UI.pos_xy(P.rx.ant)
            draw_antennas_main(x, y, true, 0, 100, P.rx.opts, -20)
            if P.rx.db  then UI.text(P.rx.db,  "1RSS") end
            if P.rx.lq  then UI.text(P.rx.lq,  "RQly") end
            if P.rx.snr then
              local sx, sy = UI.pos_xy(P.rx.snr)
              -- Align RSNR label with the rest of the right column (only in this mode)
              drawText(sx + 2, sy, "RSNR", (SMLSIZE or 0) + (CENTER or 0))
            end
          end
        end
      end
    end

    if BAR and BAR.draw_bottom then BAR.draw_bottom() end
    UI.frame_end()
    return 0
  end
  _draw_lines(POS.main.lines)
  do
    local p = POS.main.tx
    local x,y = UI.pos_xy(p.ant)
    local o = p.opts
    local lq = read_sensor("TQly")
    local dB = read_sensor("TRSS")
    local T = last_tlm()
    T.ever = true
    _G.VB_TLM_EVER = true
    T.tx_lq = lq
    T.tx_db = dB
    local snr = read_sensor("TSNR")
    if snr ~= nil then T.tx_snr = snr end
    draw_antennas_main(x, y, false, lq, rssi_pct(dB), o, snr)
    if p.db then UI.text(p.db, fmt_db(dB)) end
    if p.lq then UI.text(p.lq, fmt_lq(lq)) end
  end
  do
    local p = POS.main.rx
    local x,y = UI.pos_xy(p.ant)
    local o = p.opts
    local lq = read_sensor("RQly")
    local dB = read_rrss()
    local T = last_tlm()
    T.ever = true
    _G.VB_TLM_EVER = true
    T.rx_lq = lq
    T.rx_db = dB
    local snr = read_sensor("RSNR")
    if snr ~= nil then T.rx_snr = snr end
    draw_antennas_main(x, y, true, lq, rssi_pct(dB), o, snr)
    if p.db then UI.text(p.db, fmt_db(dB)) end
    if p.lq then UI.text(p.lq, fmt_lq(lq)) end
  end
  do
    local P = POS.main or EMPTY
    local snr_pos = (P.tx and P.tx.snr) or (P.tags and P.tags.tx)
    if snr_pos then
      UI.text(snr_pos, fmt_snr(read_sensor("TSNR")), 0)
    end
    snr_pos = (P.rx and P.rx.snr) or (P.tags and P.tags.rx)
    if snr_pos then
      UI.text(snr_pos, fmt_snr(read_sensor("RSNR")), 0)
    end
    draw_tx_rx_labels_always(P)
  end
  draw_state_badge(POS.main.tags and POS.main.tags.state or nil)
  do
    local I = POS.main.info
    if not I then
      if BAR and BAR.draw_bottom then
        BAR.draw_bottom()
      end
      UI.frame_end()
      return 0
    end
    local tpwr_v = nil
    if I.tpwr then
      tpwr_v = read_sensor("TPWR")
      UI.text(I.tpwr, short_power_mw(tpwr_v))
    end
    do
      local T = last_tlm()
      if tpwr_v ~= nil then
        T.tpwr = tpwr_v
      end
    end
    if I.tpwr_cells then
      draw_power_cells(I.tpwr_cells, tpwr_v)
    end
    local rfmd_v = nil
    if I.rfmd then
      rfmd_v = read_sensor("RFMD")
      UI.text(I.rfmd, rfmd_v and _rfmd_label(rfmd_v) or "--")
    end
    do
      local T = last_tlm()
      if rfmd_v ~= nil then
        T.rfmd = rfmd_v
      end
    end
    if I.rfmd_wave then
      draw_rate_wave(I.rfmd_wave, rfmd_v)
    end
    if I.fm then
      local v = read_sensor("FM")
      local T = last_tlm()
      if is_valid_fm(v) then
        last_main.fm = v
        T.fm = v
        T.fm_good = v
      end
      local show = v
      if not is_valid_fm(show) then
        show = last_main.fm or T.fm_good or T.fm
      end
      UI.text(I.fm, show or "--")
    end
    if I.rxbt then
      local v = read_sensor("RxBt")
      local T = last_tlm()
      if is_valid_rxbt(v) then
        last_main.rxbt = v
        T.rxbt = v
        T.rxbt_good = v
      end
      local show = v
      if not is_valid_rxbt(show) then
        show = last_main.rxbt or T.rxbt_good or T.rxbt
      end
      UI.text(I.rxbt, fmt_rxbt(show))
    end
  end
  if BAR and BAR.draw_bottom then BAR.draw_bottom() end
  UI.frame_end()
  return 0
end
return app
