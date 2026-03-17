-- VB Telemetry Lite
-- Boot loader and screen dispatcher for the memory-optimized monochrome build.
-- Source files in this repository target compiled `.luac` modules at runtime.

local APP_NAME = "VB Telemetry Lite"
local APP_VERSION = "v26.03.17-beta_lite"

local app = {}


local function ensure_table_compat()
  if table == nil then
    table = {}
  end

  if table.insert == nil then
    function table.insert(t, v)
      t[#t + 1] = v
    end
  end

  if table.remove == nil then
    function table.remove(t, i)
      local n = #t
      if n == 0 then
        return nil
      end

      i = i or n
      local value = t[i]
      for idx = i, n - 1 do
        t[idx] = t[idx + 1]
      end
      t[n] = nil
      return value
    end
  end

  if table.concat == nil then
    function table.concat(t, sep, i, j)
      sep = sep or ""
      i = i or 1
      j = j or #t

      local out = ""
      for idx = i, j do
        if idx > i then
          out = out .. sep
        end
        out = out .. tostring(t[idx])
      end
      return out
    end
  end
end


local function ensure_font_flags()
  RIGHT = RIGHT or 0x0400
  CENTER = CENTER or 0x0200
  SMLSIZE = SMLSIZE or 0x0200
  INVERS = INVERS or 0x0100
  BLINK = BLINK or 0x0800
end


ensure_table_compat()
ensure_font_flags()


local function gc_step(amount)
  if type(collectgarbage) == "function" then
    pcall(collectgarbage, "step", amount or 200)
  end
end


local SCRIPT_DIR = "/SCRIPTS/TELEMETRY"
local LIB_DIR = SCRIPT_DIR .. "/VBlib"

rawset(_G, "VB_SCRIPT_DIR", SCRIPT_DIR)
rawset(_G, "VB_LIB_DIR", LIB_DIR)
rawset(_G, "VB_APP_NAME", APP_NAME)
rawset(_G, "VB_APP_VERSION", APP_VERSION)

local NIL_SENTINEL = rawget(_G, "VB_NIL_SENTINEL")
if NIL_SENTINEL == nil then
  NIL_SENTINEL = {}
  rawset(_G, "VB_NIL_SENTINEL", NIL_SENTINEL)
end

local MODULE_CACHE = rawget(_G, "VB_MOD_CACHE")
if type(MODULE_CACHE) ~= "table" then
  MODULE_CACHE = {}
  rawset(_G, "VB_MOD_CACHE", MODULE_CACHE)
end

do
  local meta = getmetatable(MODULE_CACHE)
  if type(meta) ~= "table" then
    meta = {}
  end
  if meta.__mode ~= "v" then
    meta.__mode = "v"
    setmetatable(MODULE_CACHE, meta)
  end
end


local function purge_module(path)
  if type(path) ~= "string" or path == "" then
    return false
  end

  if MODULE_CACHE[path] ~= nil then
    MODULE_CACHE[path] = nil
    return true
  end

  return false
end


local function load_module(path, no_cache)
  if type(path) ~= "string" or path == "" then
    error("VB: invalid module path", 0)
  end

  if not no_cache then
    local cached = MODULE_CACHE[path]
    if cached ~= nil then
      return (cached == NIL_SENTINEL) and nil or cached
    end
  end

  local ok, result = pcall(dofile, path)
  if not ok then
    error("VB: load failed: " .. tostring(path) .. " | " .. tostring(result), 0)
  end

  if not no_cache then
    MODULE_CACHE[path] = (result == nil) and NIL_SENTINEL or result
  end

  return result
end


rawset(_G, "VB_PURGE", purge_module)
rawset(_G, "VB_DOFILE", load_module)

local CORE_PATH = LIB_DIR .. "/core.luac"
local CORE = rawget(_G, "VB_CORE")
if type(CORE) ~= "table" then
  CORE = load_module(CORE_PATH)
  rawset(_G, "VB_CORE", CORE)
end

local UI = (CORE and CORE.UI) or {}
local UTIL = (CORE and CORE.UTIL) or {}

rawset(_G, "UI", UI)
rawset(_G, "UTIL", UTIL)
rawset(_G, "VB_UTIL", UTIL)

if CORE and type(CORE.ensure_settings) == "function" then
  pcall(CORE.ensure_settings)
end

local SCREEN_PATHS = {
  MAIN = LIB_DIR .. "/main.luac",
  MENU = LIB_DIR .. "/menu.luac",
  SETTINGS = LIB_DIR .. "/settings.luac",
}

local current_screen = {
  name = nil,
  path = nil,
  mod = nil,
}

local queued_screen = nil


local function settings_exist()
  if not (CORE and type(CORE.settings_raw) == "function") then
    return false
  end

  local ok, raw = pcall(CORE.settings_raw)
  return ok and type(raw) == "table" and next(raw) ~= nil
end


local function call_screen_unload(mod, next_name)
  if type(mod) ~= "table" then
    return
  end

  local hook = mod.unload
  if type(hook) ~= "function" then
    hook = mod.on_unload or mod.onUnload
  end

  if type(hook) == "function" then
    pcall(hook, next_name)
  end
end


local function unload_current_screen(next_name)
  if current_screen.name == nil then
    return
  end

  local old_mod = current_screen.mod
  local old_path = current_screen.path

  current_screen.name = nil
  current_screen.path = nil
  current_screen.mod = nil

  call_screen_unload(old_mod, next_name)

  if type(old_path) == "string" then
    purge_module(old_path)
  end

  gc_step(128)
end


local function load_screen(name, args)
  local path = SCREEN_PATHS[name]
  if type(path) ~= "string" then
    error("VB: unknown screen: " .. tostring(name), 0)
  end

  unload_current_screen(name)

  local ok, screen_mod = pcall(load_module, path, true)
  if not ok then
    error(screen_mod, 0)
  end

  current_screen.name = name
  current_screen.path = path
  current_screen.mod = screen_mod
  rawset(_G, "VB_SCREEN", name)

  if type(screen_mod) == "table" and type(screen_mod.init) == "function" then
    pcall(screen_mod.init, args)
  end

  gc_step(128)
  return true
end


function app.init()
  if not settings_exist() then
    load_screen("SETTINGS", {
      first_run = true,
      from = "MAIN",
      menu_focus = 1,
    })
    return
  end

  load_screen("MAIN", {
    from = "BOOT",
    cold_start = true,
  })
end


function app.background()
  if CORE and type(CORE.background_tick) == "function" then
    pcall(CORE.background_tick)
  elseif CORE and type(CORE.update_tlm) == "function" then
    pcall(CORE.update_tlm)
  end

  if current_screen.mod and type(current_screen.mod.background) == "function" then
    pcall(current_screen.mod.background)
  end
end


function app.run(event)
  if queued_screen then
    local next_screen = queued_screen
    queued_screen = nil
    load_screen(next_screen.name, next_screen.args)
    return 0
  end

  if not (current_screen.mod and type(current_screen.mod.run) == "function") then
    return 0
  end

  local ok, result = pcall(current_screen.mod.run, event)
  if not ok then
    error(result, 0)
  end

  if type(result) == "table" and result.next_screen then
    queued_screen = {
      name = result.next_screen,
      args = result.args,
    }
  end

  return 0
end


return app
