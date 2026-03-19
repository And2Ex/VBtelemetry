-- Unified menu module for VB Telemetry Lite.
--
-- This file handles the main menu, the Donate submenu and all QR overlays.
-- Keeping these small overlays in a single module reduces screen transitions,
-- avoids extra module loads and makes input latching more predictable on radios
-- with very limited memory.

local CORE = rawget(_G, "VB_CORE") or {}
local UI = CORE.UI or {}
local UTIL = CORE.UTIL or {}

local MENU_STATE = "menu"
local DONATE_STATE = "donate"
local QR_STATE = "qr"

local VERSION_SHORT = rawget(_G, "VB_APP_VERSION") or "v26.03.20-beta_lite"
local VISIBLE_ROWS = 4
local LIST_Y_START = 12
local LIST_Y_STEP = 11

local MENU_ITEMS = {
  { id = "SETTINGS", label = "Settings", kind = "screen" },
  { id = "UPDATE", label = "Update", kind = "qr", qr = "github" },
  { id = "DONATE", label = "Donate", kind = "submenu" },
  { id = "GETPRO", label = "Get Pro", kind = "qr", qr = "patreon" },
}

-- Compact 29x29 QR payloads are stored as bitmaps to avoid runtime generation.

local DONATE_ITEMS = {
  { id = "patreon", label = "Patreon (Global)" },
  { id = "mono", label = "Monobank (UA)" },
  { id = "email", label = "Email" },
  { id = "telegram", label = "Telegram" },
}

local QR_DATA = {
  github = {
    text = { "github.com/", "And2Ex/", "VBtelemetry" },
    bitmap = {
      w = 29,
      h = 29,
      hex = "7f83d13f08cc0b76114dddae4ba3dbf55d74831eb0e05f55f50788f500d127f3d3347cfcab434a431b64e15d24e6832c329fbf1c3fbd6511f5c1f5b09068563e7a335552509865d93cd6073f01123be2df7bd60d32d5885dadfaab4b3c047659faf82079b9fdb720bf00",
    },
  },
  telegram = {
    text = { "t.me/", "VBtelemetry" },
    bitmap = {
      w = 29,
      h = 29,
      hex = "7f34c93f68380976b915dd2e79aedbb5a474835cb4e05f55f507e0fb0055c61489861b5e7a8d88f68b4b2c342491a72b752724dd76f9de15fb5bc3d374da409ac6d6c34861dd47bc9565911f007a37fa1f72d70e42bb585dcff4a10b98b074e5e8cd205d4cf45795bd01",
    },
  },
  email = {
    text = { "and3ex+vbtlm", "(a)gmail.com" },
    bitmap = {
      w = 29,
      h = 29,
      hex = "7f9cdd3f88820a761d45ddae8da5db15ef7583ceabe05f55f507a8c5007ddcc20726f2fbf7258087dfa0d291fc70e219c1ed37d2f93cd008a51a79cd8aecb2b0ebd727189c86aff8506fb07f01ca2dfa1ffc56099ac5185ddff2b56bf4007435a0af20bb1cf597c54e00",
    },
  },
  mono = {
    text = { "5375 4112", "2351 6571" },
    bitmap = {
      w = 29,
      h = 29,
      hex = "7f0cc83f88d208764968dd2e3ea2db255d75839e91e05f55f507807c0069e7ac60a5025efe13e93d9237721627b5a765547000511bad172d5458c3b63b88d30d5c661dd566d62f075c6f115f00b23ffa9f86550aea8ab85d0af6b9ab17fb750960dc208daff4b7719500",
    },
  },
  patreon = {
    text = { "patreon.com/", "VBtelemetry" },
    bitmap = {
      w = 29,
      h = 29,
      hex = "7f4ac83f88e10876193bdd2e9ba6db05c174831ebbe05f55f507c0fd00695bb1a001354f7ab3a3b8139700d6adadaf59f257c05e9aec5f65f452e42db2c8b67c5c365f8766ce295f9cef995f00ba35fa9f40540a5aa6b85d98f2a9abc4ff76510cdc20346df457329500",
    },
  },
}

local M = {
  _state = MENU_STATE,
  _focus_menu = 1,
  _focus_donate = 1,
  _scroll_menu = 0,
  _scroll_donate = 0,
  _qr_id = nil,
  _qr_return_state = MENU_STATE,
  _input = (UTIL and type(UTIL.new_input_latch) == "function") and UTIL.new_input_latch() or {
    ignore_until = 0,
    await_release = false,
    last_enter_t = -100000,
    last_exit_t = -100000,
  },
}


local function now()
  if UTIL and type(UTIL.now) == "function" then
    return UTIL.now()
  end
  if type(getTime) == "function" then
    return getTime() or 0
  end
  return 0
end


local function ui_inverted()
  if UTIL and type(UTIL.ui_inverted) == "function" then
    return UTIL.ui_inverted()
  end

  local settings = rawget(_G, "SET")
  return type(settings) == "table" and settings.UI_INVERT == true
end


local function arm_release_latch(delay)
  if UTIL and type(UTIL.latch_arm_release) == "function" then
    UTIL.latch_arm_release(M._input, delay or 2)
    return
  end

  M._input.ignore_until = now() + (delay or 2)
  M._input.await_release = true
end


local function enter_ok()
  if UTIL and type(UTIL.latch_enter_ok) == "function" then
    return UTIL.latch_enter_ok(M._input, 18)
  end
  return true
end


local function exit_ok()
  if UTIL and type(UTIL.latch_exit_ok) == "function" then
    return UTIL.latch_exit_ok(M._input, 12)
  end
  return true
end


local function apply_input_latch(event)
  if UTIL and type(UTIL.latch_apply) == "function" then
    return UTIL.latch_apply(M._input, event)
  end
  return event or 0
end


local function draw_footer_version(inverted)
  lcd.drawFilledRectangle(0, 56, 128, 8, 0)

  local flags = (SMLSIZE or 0) + (CENTER or 0)
  if not inverted then
    flags = flags + (INVERS or 0)
  end

  lcd.drawText(64, 57, VERSION_SHORT, flags)
end


local function current_list()
  if M._state == DONATE_STATE then
    return DONATE_ITEMS, M._focus_donate, M._scroll_donate, "DONATE"
  end
  return MENU_ITEMS, M._focus_menu, M._scroll_menu, "MENU"
end


local function set_scroll(value)
  if M._state == DONATE_STATE then
    M._scroll_donate = value
  else
    M._scroll_menu = value
  end
end


local function set_focus(value)
  if M._state == DONATE_STATE then
    M._focus_donate = value
  else
    M._focus_menu = value
  end
end


local function move_focus(delta)
  local focus
  local min_value
  local max_value

  if M._state == DONATE_STATE then
    focus = M._focus_donate
    min_value = 1
    max_value = #DONATE_ITEMS
  else
    focus = M._focus_menu
    min_value = 1
    max_value = #MENU_ITEMS
  end

  focus = focus + delta
  if focus < min_value then
    focus = min_value
  elseif focus > max_value then
    focus = max_value
  end

  set_focus(focus)
end


local function normalize_focus()
  if M._focus_menu < 1 then
    M._focus_menu = 1
  elseif M._focus_menu > #MENU_ITEMS then
    M._focus_menu = #MENU_ITEMS
  end

  if M._focus_donate < 1 then
    M._focus_donate = 1
  elseif M._focus_donate > #DONATE_ITEMS then
    M._focus_donate = #DONATE_ITEMS
  end
end


local function draw_list_screen()
  local items, focus, scroll, title = current_list()
  local inverted = ui_inverted()

  UI.frame_begin(inverted)
  UI.small()
  UTIL.draw_header(title, inverted)

  local flags = SMLSIZE or 0
  if inverted then
    flags = flags + (INVERS or 0)
  end

  scroll = UTIL.scroll_to_focus(focus, scroll, #items, VISIBLE_ROWS)
  set_scroll(scroll)

  local y = LIST_Y_START
  for row = 1, VISIBLE_ROWS do
    local index = scroll + row
    if index > #items then
      break
    end

    if index == focus then
      lcd.drawText(2, y, ">", flags)
    end

    lcd.drawText(12, y, items[index].label, flags)
    y = y + LIST_Y_STEP
  end

  if M._state == MENU_STATE then
    draw_footer_version(inverted)
  end

  UI.frame_end()
end


local function draw_qr_screen()
  local inverted = ui_inverted()
  local qr_data = QR_DATA[M._qr_id]
  local bitmap = qr_data and qr_data.bitmap or nil
  local lines = qr_data and qr_data.text or { "QR error" }

  UI.frame_begin(inverted)
  UI.small()

  local text_flags = (SMLSIZE or 0) + (CENTER or 0)
  if inverted then
    text_flags = text_flags + (INVERS or 0)
  end

  local ok, qr_w, qr_h = UTIL.draw_qr_bitmap(bitmap, 3, 3, 2, inverted)
  local text_x = 3 + qr_w + 6
  local mid_x = text_x + math.floor((128 - text_x) / 2)
  local center_y = 3 + math.floor((qr_h or 0) / 2) - 3

  if ok then
    local line_height = 10
    local total_height = (#lines - 1) * line_height
    local start_y = center_y - math.floor(total_height / 2)

    for i = 1, #lines do
      lcd.drawText(mid_x, start_y + (i - 1) * line_height, lines[i], text_flags)
    end
  else
    lcd.drawText(mid_x, center_y, "QR error", text_flags)
  end

  UI.frame_end()
end


local function enter_donate()
  M._state = DONATE_STATE
  arm_release_latch()
end


local function open_qr(qr_id, return_state)
  M._qr_id = qr_id
  M._qr_return_state = return_state or MENU_STATE
  M._state = QR_STATE
  arm_release_latch()
end


local function close_qr()
  M._qr_id = nil
  M._state = M._qr_return_state or MENU_STATE
  arm_release_latch()

  if UTIL and type(UTIL.gc_full) == "function" then
    UTIL.gc_full()
  elseif type(collectgarbage) == "function" then
    collectgarbage("collect")
  end
end


local function leave_donate()
  M._state = MENU_STATE
  arm_release_latch()
end


function M.init(args)
  args = args or {}

  M._state = MENU_STATE
  M._focus_menu = tonumber(args.focus or args.menu_focus or 1) or 1
  M._focus_donate = 1
  M._scroll_menu = 0
  M._scroll_donate = 0
  M._qr_id = nil
  M._qr_return_state = MENU_STATE
  if UTIL and type(UTIL.latch_reset) == "function" then
    UTIL.latch_reset(M._input, 0, false)
  else
    M._input.ignore_until = 0
    M._input.await_release = false
    M._input.last_enter_t = -100000
    M._input.last_exit_t = -100000
  end

  normalize_focus()
  arm_release_latch(12)
end


function M.on_unload()
  M._state = MENU_STATE
  M._focus_donate = 1
  M._scroll_donate = 0
  M._qr_id = nil
  M._qr_return_state = MENU_STATE
  M._input.await_release = false

  if UTIL and type(UTIL.gc_light) == "function" then
    UTIL.gc_light()
  elseif type(collectgarbage) == "function" then
    collectgarbage("step", 64)
  end
end


function M.run(event)
  local e = apply_input_latch(event)

  if M._state == QR_STATE then
    if (UTIL.is_exit(e) and exit_ok()) or (UTIL.is_enter(e) and enter_ok()) then
      close_qr()
      draw_list_screen()
      return 0
    end

    draw_qr_screen()
    return 0
  end

  if UTIL.is_exit(e) and exit_ok() then
    if M._state == DONATE_STATE then
      leave_donate()
      draw_list_screen()
      return 0
    end

    return { next_screen = "MAIN", args = { from_overlay = true } }
  end

  if UTIL.is_next(e) then
    move_focus(1)
  elseif UTIL.is_prev(e) then
    move_focus(-1)
  end

  if UTIL.is_enter(e) and enter_ok() then
    if M._state == DONATE_STATE then
      local donate_item = DONATE_ITEMS[M._focus_donate]
      if donate_item and donate_item.id then
        open_qr(donate_item.id, DONATE_STATE)
        draw_qr_screen()
        return 0
      end
    else
      local item = MENU_ITEMS[M._focus_menu]
      if item then
        if item.kind == "screen" then
          return { next_screen = "SETTINGS", args = { menu_focus = M._focus_menu, from = "MAIN" } }
        end
        if item.kind == "submenu" then
          enter_donate()
          draw_list_screen()
          return 0
        end
        if item.kind == "qr" and item.qr then
          open_qr(item.qr, MENU_STATE)
          draw_qr_screen()
          return 0
        end
      end
    end
  end

  draw_list_screen()
  return 0
end


return M
