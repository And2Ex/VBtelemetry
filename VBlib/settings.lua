-- Settings screen for the lite build.
-- Only options that affect the remaining features are kept here.

local VB_DOFILE = rawget(_G, "VB_DOFILE")


local function vb_lib_dir()
  local value = rawget(_G, "VB_LIB_DIR")
  if type(value) ~= "string" or value == "" then
    return "VBlib"
  end
  return value
end


local function vb_load(relative_path)
  local path = vb_lib_dir() .. "/" .. relative_path
  if type(VB_DOFILE) == "function" then
    return VB_DOFILE(path)
  end
  return dofile(path)
end


local CORE = rawget(_G, "VB_CORE")
if type(CORE) ~= "table" then
  CORE = vb_load("core.luac")
end
rawset(_G, "VB_CORE", CORE)

local UI = CORE.UI or {}
local UTIL = CORE.UTIL or {}
CORE.ensure_settings()

local M = {
  _focus = 1,
  _scroll = 0,
  _edit = false,
  _ignore_until = 0,
  _await_release = false,
  _menu_focus = 1,
  _last_enter_t = -100000,
  _last_exit_t = -100000,
  _dirty = false,
  _first_run = false,
  _pending = {},
}

local VISIBLE_ROWS = 4
local LIST_Y_START = 12
local LIST_Y_STEP = 11
local VALUE_COL_X = 82
local VALUE_COL_W = 46

local ITEMS = {
  { id = "ARM", label = "Arm switch", kind = "switch" },
  { id = "TURTLE", label = "Turtle switch", kind = "switch" },
  { id = "BEEPER", label = "Beeper switch", kind = "switch" },
  { id = "INVERT", label = "Inversion", kind = "toggle" },
}

local SWITCH_OPTIONS = {
  "SA", "!SA", "SB", "!SB", "SC", "!SC", "SD", "!SD", "SE", "!SE", "SF", "!SF", "SG", "!SG", "SH", "!SH",
  "L01", "!L01", "L02", "!L02", "L03", "!L03", "L04", "!L04", "L05", "!L05", "L06", "!L06", "L07", "!L07", "L08", "!L08", "L09", "!L09",
}

local SWITCH_KEY_BY_ID = {
  ARM = "ARM_SRC",
  TURTLE = "TURTLE_SRC",
  BEEPER = "BEEP_SRC",
}

local SWITCH_DEFAULT_BY_ID = {
  ARM = "SA",
  TURTLE = "SD",
  BEEPER = "SE",
}


local function now()
  return UTIL.now and UTIL.now() or 0
end


local function ui_inverted()
  if UTIL and type(UTIL.ui_inverted) == "function" then
    return UTIL.ui_inverted()
  end
  local settings = rawget(_G, "SET")
  return type(settings) == "table" and settings.UI_INVERT == true
end


local function enter_ok()
  local timestamp = now()
  if (timestamp - M._last_enter_t) < 18 then
    return false
  end
  M._last_enter_t = timestamp
  return true
end


local function exit_ok()
  local timestamp = now()
  if (timestamp - M._last_exit_t) < 12 then
    return false
  end
  M._last_exit_t = timestamp
  return true
end


local function current_settings()
  local settings = rawget(_G, "SET")
  if type(settings) ~= "table" then
    settings = CORE.ensure_settings()
    rawset(_G, "SET", settings)
  end
  return settings
end


local function save_settings()
  local settings = current_settings()

  return CORE.update_settings({
    ARM_SWITCH = settings.ARM_SRC,
    TURTLE_SWITCH = settings.TURTLE_SRC,
    BEEP_SWITCH = settings.BEEP_SRC,
    UI_INVERT_DEFAULT = not not settings.UI_INVERT,
  })
end


local function switch_index(value)
  for index = 1, #SWITCH_OPTIONS do
    if SWITCH_OPTIONS[index] == value then
      return index
    end
  end
  return 1
end


local function next_switch_value(value, direction)
  local index = switch_index(value) + direction
  if index < 1 then
    index = #SWITCH_OPTIONS
  end
  if index > #SWITCH_OPTIONS then
    index = 1
  end
  return SWITCH_OPTIONS[index]
end


local function get_switch_value(id)
  local settings = current_settings()
  local key = SWITCH_KEY_BY_ID[id]
  local value = key and settings[key] or nil
  if type(value) ~= "string" or value == "" then
    return SWITCH_DEFAULT_BY_ID[id] or "SA"
  end
  return value
end


local function set_switch_value(id, value)
  local settings = current_settings()
  local key = SWITCH_KEY_BY_ID[id]
  if key then
    settings[key] = value
    M._dirty = true
  end
end


local function get_pending_switch(id)
  local value = M._pending and M._pending[id] or nil
  if type(value) == "string" and value ~= "" then
    return value
  end
  return nil
end


local function set_pending_switch(id, value)
  if type(M._pending) ~= "table" then
    M._pending = {}
  end
  M._pending[id] = value
end


local function clear_pending_switch(id)
  if type(M._pending) == "table" then
    M._pending[id] = nil
  end
end


local function commit_pending_switch(id)
  local value = get_pending_switch(id)
  if value then
    set_switch_value(id, value)
  end
  clear_pending_switch(id)
end


local function toggle_item(id)
  local settings = current_settings()
  if id == "INVERT" then
    settings.UI_INVERT = not settings.UI_INVERT
    M._dirty = true
  end
end


local function value_text(item)
  local settings = current_settings()
  if item.kind == "switch" then
    if M._edit and ITEMS[M._focus] == item then
      return get_pending_switch(item.id) or get_switch_value(item.id)
    end
    return get_switch_value(item.id)
  end

  if item.id == "INVERT" then
    return settings.UI_INVERT and "ON" or "OFF"
  end

  return ""
end


local function text_width(text)
  if UTIL and type(UTIL.text_width_small) == "function" then
    return UTIL.text_width_small(text)
  end
  return #tostring(text or "") * 6
end


local function row_height()
  return 9
end


local function draw_row(y, is_focused, highlight_value, label, value)
  local label_flags = (SMLSIZE or 0)
  local value_flags = (SMLSIZE or 0)
  local inverted = ui_inverted()

  if inverted then
    lcd.drawFilledRectangle(0, y - 1, 128, row_height(), INVERS or 0)
    label_flags = label_flags + (INVERS or 0)
    value_flags = value_flags + (INVERS or 0)
  end

  if is_focused then
    lcd.drawText(2, y, ">", label_flags)
  end

  if highlight_value then
    lcd.drawFilledRectangle(VALUE_COL_X, y - 1, VALUE_COL_W, row_height(), 0)
    if not inverted then
      value_flags = value_flags + (INVERS or 0)
    else
      value_flags = (SMLSIZE or 0)
    end
  end

  lcd.drawText(12, y, label, label_flags)

  local text = value or ""
  local width = text_width(text)
  local x = VALUE_COL_X + math.floor((VALUE_COL_W - width) / 2)
  if x < VALUE_COL_X then
    x = VALUE_COL_X
  end
  lcd.drawText(x, y, text, value_flags)
end


function M.init(args)
  args = args or {}

  M._focus = 1
  M._scroll = 0
  M._edit = false
  M._ignore_until = now() + 2
  M._menu_focus = tonumber(args.menu_focus or 1) or 1
  M._caller = args.from or "MAIN"
  M._await_release = true
  M._dirty = false
  M._first_run = args.first_run and true or false
  M._pending = {}
end


function M.on_unload()
  M._edit = false
  M._pending = {}
  M._await_release = false

  if UTIL and type(UTIL.gc_full) == "function" then
    UTIL.gc_full()
  elseif type(collectgarbage) == "function" then
    collectgarbage("collect")
  end
end


function M.run(event)
  local e = event or 0

  if now() <= (M._ignore_until or 0) then
    e = 0
  end

  if M._await_release then
    if e ~= 0 then
      e = 0
    else
      M._await_release = false
    end
  end

  if UTIL.is_exit(e) and exit_ok() then
    if M._edit then
      local current_item = ITEMS[M._focus]
      if current_item and current_item.kind == "switch" then
        commit_pending_switch(current_item.id)
      end
    end

    M._edit = false
    if M._dirty or M._first_run then
      save_settings()
    end

    if M._first_run then
      return { next_screen = "MAIN", args = { swallow = true, defer_heavy = true } }
    end

    return { next_screen = "MENU", args = { from = M._caller, swallow = true, focus = M._menu_focus } }
  end

  if UTIL.is_next(e) then
    if M._edit and ITEMS[M._focus] and ITEMS[M._focus].kind == "switch" then
      local item = ITEMS[M._focus]
      local current_value = get_pending_switch(item.id) or get_switch_value(item.id)
      set_pending_switch(item.id, next_switch_value(current_value, 1))
    else
      M._focus = UTIL.clamp(M._focus + 1, 1, #ITEMS)
    end
  elseif UTIL.is_prev(e) then
    if M._edit and ITEMS[M._focus] and ITEMS[M._focus].kind == "switch" then
      local item = ITEMS[M._focus]
      local current_value = get_pending_switch(item.id) or get_switch_value(item.id)
      set_pending_switch(item.id, next_switch_value(current_value, -1))
    else
      M._focus = UTIL.clamp(M._focus - 1, 1, #ITEMS)
    end
  end

  M._scroll = UTIL.scroll_to_focus(M._focus, M._scroll, #ITEMS, VISIBLE_ROWS)

  local item = ITEMS[M._focus]
  if UTIL.is_enter(e) and enter_ok() and item then
    if item.kind == "toggle" then
      toggle_item(item.id)
      M._await_release = true
    elseif item.kind == "switch" then
      if not M._edit then
        set_pending_switch(item.id, get_switch_value(item.id))
        M._edit = true
      else
        commit_pending_switch(item.id)
        M._edit = false
      end
      M._await_release = true
    end
  end

  local inverted = ui_inverted()
  UI.frame_begin(inverted)
  UI.small()
  UTIL.draw_header("SETTINGS", inverted)

  local y = LIST_Y_START
  for row = 1, VISIBLE_ROWS do
    local index = M._scroll + row
    if index > #ITEMS then
      break
    end

    local row_item = ITEMS[index]
    local is_focused = index == M._focus
    local highlight_value = is_focused and M._edit and row_item.kind == "switch"
    draw_row(y, is_focused, highlight_value, row_item.label, value_text(row_item))
    y = y + LIST_Y_STEP
  end

  UI.frame_end()
  return 0
end


return M
