--!nonstrict
-- Aerox 5 Wireless service. Owns the battery state and the mouse settings.
--
-- Battery: runs bin/aerox5-battery (hidraw) every poll_interval seconds, or
-- every 10 s while the mouse is asleep. Never polls with rivalcfg, whose
-- libusb backend rebinds the dongle and makes games stutter.
-- Settings: pluginDataDir()/mouse.json holds the last values applied. The
-- first run imports the QML plugin's settings.json, applying nothing.
-- State: aerox5.battery = Battery + checked_at (ms), aerox5.settings =
-- Settings, aerox5.busy = true while rivalcfg runs, aerox5.applied =
-- { key, value, ok, n } after each change finishes or is refused.
-- Commands: aerox5.cmd = { op = "set", key, value, delay_ms } | { op = "refresh" },
-- cleared after handling.

local battery = require("./lib/battery.luau")
local mouse = require("./lib/mouse.luau")
local queue = require("./lib/queue.luau")

local PLUGIN_ID = "kingrecycle/aerox5-wireless"
local LEGACY_SETTINGS = "~/.config/noctalia/plugins/aerox5-wireless/settings.json"
local POLL_TIMEOUT_MS = 5000
local RIVALCFG_TIMEOUT_MS = 10000

noctalia.setUpdateInterval(250)

local current = nil -- last battery reading
local settings = mouse.defaults()
local pending = queue.new()
local polling = false
local nextPollAt = 0

local function title()
  return noctalia.tr("title")
end

local function pollIntervalS()
  local v = tonumber(noctalia.getConfig("poll_interval")) or 120
  return math.clamp(math.floor(v), 30, 300)
end

local function rivalcfgPath()
  local p = noctalia.getConfig("rivalcfg_path")
  if type(p) ~= "string" or noctalia.string.trim(p) == "" then
    p = "rivalcfg"
  end
  return noctalia.expandPath(noctalia.string.trim(p))
end

local function dataPath()
  local dir = noctalia.pluginDataDir()
  return dir and (dir .. "/mouse.json") or nil
end

local function publishSettings()
  noctalia.state.set("aerox5.settings", table.clone(settings))
end

local function saveSettings()
  local path = dataPath()
  local encoded = noctalia.json.encode(settings)
  if path and encoded then
    noctalia.writeFile(path, encoded)
  end
end

local function tomlString(s)
  return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

-- Copies the QML plugin's poll interval and rivalcfg path to this plugin's settings page.
local function importPluginSettings(extras)
  local values = {}
  if extras.poll_interval then
    values.poll_interval = tostring(extras.poll_interval)
  end
  if extras.rivalcfg_path then
    values.rivalcfg_path = tomlString(extras.rivalcfg_path)
  end
  for key, value in values do
    noctalia.runAsync({
      "noctalia", "msg", "config-set",
      `plugin_settings."{PLUGIN_ID}".{key}`, value,
    }, function(result)
      if result.exitCode ~= 0 then
        noctalia.log(`config-set {key} failed: {result.stderr or result.stdout or ""}`)
      end
    end)
  end
end

local function loadSettings()
  local path = dataPath()
  local raw = path and noctalia.readFile(path)
  if raw then
    -- mouse.json exists, so the legacy import already ran once.
    local decoded = noctalia.json.decode(raw)
    settings = if type(decoded) == "table" then mouse.fromStored(decoded) else mouse.defaults()
    return
  end

  local legacyRaw = noctalia.readFile(noctalia.expandPath(LEGACY_SETTINGS))
  local legacy = legacyRaw and noctalia.json.decode(legacyRaw)
  if type(legacy) == "table" then
    local s, extras = mouse.fromLegacy(legacy)
    settings = s
    importPluginSettings(extras)
  else
    settings = mouse.defaults()
  end
  saveSettings()
end

local function publishBattery(b)
  current = b
  local published = table.clone(b)
  published.checked_at = noctalia.nowMs()
  noctalia.state.set("aerox5.battery", published)
end

local function poll()
  if polling then
    return
  end
  polling = true
  local launched = noctalia.runAsync({ "python3", noctalia.pluginDir() .. "/bin/aerox5-battery" }, function(result)
    polling = false
    local code = result.exitCode
    if result.timedOut then
      code = 1
    end
    local b = battery.parse(code or 3, result.stdout or "", current, result.stderr)
    publishBattery(b)
    nextPollAt = noctalia.nowMs() + battery.nextPollMs(b, pollIntervalS())
  end, POLL_TIMEOUT_MS)
  if not launched then
    polling = false
    publishBattery(battery.parse(3, "", current))
    nextPollAt = noctalia.nowMs() + battery.nextPollMs(current, pollIntervalS())
  end
end

local function failMessage(result)
  local text = noctalia.string.trim(result.stderr or "")
  if text == "" then
    text = noctalia.string.trim(result.stdout or "")
  end
  if text == "" then
    return noctalia.tr("error.rivalcfg_unknown", { code = tostring(result.exitCode) })
  end
  -- rivalcfg's last line holds the error after any warnings.
  local last = text:match("([^\n]+)$") or text
  return noctalia.tr("error.rivalcfg_failed", { message = last })
end

-- Tells the panel a change finished, so it can drop or revert that field's draft.
local appliedCount = 0
local function publishApplied(key, value, ok)
  appliedCount += 1
  noctalia.state.set("aerox5.applied", { key = key, value = value, ok = ok, n = appliedCount })
end

-- The dongle can be briefly gone while it rebinds after a rivalcfg call.
local POLL_AFTER_APPLY_MS = 2000

local function finishApply()
  pending:done()
  noctalia.state.set("aerox5.busy", false)
  nextPollAt = math.max(nextPollAt, noctalia.nowMs() + POLL_AFTER_APPLY_MS)
end

local function applyNext()
  local entry = pending:take(noctalia.nowMs())
  if entry == nil then
    return
  end
  local new, args = mouse.change(settings, entry.key, entry.value)
  if new == nil then
    finishApply()
    publishSettings()
    publishApplied(entry.key, entry.value, false)
    noctalia.notifyError(title(), noctalia.tr("error." .. args, { value = tostring(entry.value) }))
    return
  end

  noctalia.state.set("aerox5.busy", true)
  local path = rivalcfgPath()
  local launched = noctalia.runAsync({ path, table.unpack(args) }, function(result)
    local ok = result.exitCode == 0 and not result.timedOut
    if ok then
      settings = new
      saveSettings()
    elseif result.exitCode == 127 and noctalia.string.trim(result.stderr or "") == "" then
      -- The shell's "command not found": the rivalcfg path is wrong.
      noctalia.notifyError(title(), noctalia.tr("error.rivalcfg_not_started", { path = path }))
    else
      noctalia.notifyError(title(), failMessage(result))
    end
    publishSettings()
    publishApplied(entry.key, entry.value, ok)
    finishApply()
  end, RIVALCFG_TIMEOUT_MS)
  if not launched then
    publishSettings()
    publishApplied(entry.key, entry.value, false)
    finishApply()
    noctalia.notifyError(title(), noctalia.tr("error.rivalcfg_not_started", { path = path }))
  end
end

local function handleSet(cmd)
  if current == nil or current.state ~= "ok" then
    publishSettings()
    publishApplied(cmd.key, cmd.value, false)
    noctalia.notifyError(title(), noctalia.tr("error.not_ready"))
    return
  end
  if type(cmd.key) ~= "string" then
    return
  end
  local delay = tonumber(cmd.delay_ms) or 0
  -- Values are checked when they're taken, after the delay, so a color
  -- that is still being typed doesn't raise an error per keystroke.
  pending:push(cmd.key, cmd.value, noctalia.nowMs(), delay)
end

noctalia.state.watch("aerox5.cmd", function(cmd)
  if type(cmd) ~= "table" then
    return
  end
  if cmd.op == "set" then
    handleSet(cmd)
  elseif cmd.op == "refresh" then
    nextPollAt = 0
  end
  noctalia.state.set("aerox5.cmd", nil)
end)

function update()
  local now = noctalia.nowMs()
  -- The battery read and rivalcfg both open the dongle, so they take turns.
  if not polling and not pending:busy() and now >= nextPollAt then
    poll()
  end
  if not polling then
    applyNext()
  end
end

loadSettings()
publishSettings()
noctalia.state.set("aerox5.busy", false)
poll()
