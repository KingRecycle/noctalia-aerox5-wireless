# Aerox 5 Wireless v5 (Luau) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Noctalia v4 QML plugin with a Noctalia 5.6 Luau plugin: a service, a bar widget showing the Aerox 5 battery, and a panel holding every mouse setting, applied with rivalcfg.

**Architecture:** Pure logic lives in three dependency-free modules under `lib/` (battery parsing, mouse settings and rivalcfg arguments, the apply queue), unit-tested with the `luau` CLI. `service.luau` glues them to the Noctalia API: it polls the bundled hidraw reader, owns `mouse.json`, runs rivalcfg, and publishes state. `bar.luau` and `panel.luau` only read state and send commands, following the official `world_clock` plugin's service/bar/panel pattern.

**Tech Stack:** Luau (Noctalia 5.6 plugin API), `luau` 0.748 CLI for unit tests, Python 3 stdlib (`bin/aerox5-battery`), rivalcfg.

**Spec:** `docs/superpowers/specs/2026-11-27-v5-luau-rewrite-design.md`

## Global Constraints

- Never poll the battery with rivalcfg. Battery reads go only through `bin/aerox5-battery`.
- rivalcfg runs only in response to a panel change, one call at a time, never while a slider is being dragged (about 1 s after the last change).
- Plugin ID `kingrecycle/aerox5-wireless`, panel `kingrecycle/aerox5-wireless:panel`, version `2.0.0`.
- Battery color cutoffs fixed: above 50 high, 21 to 50 mid, 20 or less low.
- Asleep re-poll every 10 s; normal poll from the `poll_interval` setting (30 to 300 s, default 120).
- Mouse controls disabled unless battery state is `ok`. Preset list disabled while fixed DPI is set.
- Rainbow off sends the three zone colors, using red, lime, blue for any empty one. A zone-color change sets rainbow to false.
- No user's values hardcoded. The legacy import reads `~/.config/noctalia/plugins/aerox5-wireless/settings.json` once, only when `mouse.json` doesn't exist, and applies nothing to the mouse.
- Don't touch `~/.local/bin/aerox5-battery` or the DMS plugin.
- Writing rules for all copy (UI strings, README, commits): no em dashes, sentence-case headings, plain words. Commits are conventional and end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Prerequisites (Charlie runs these)

- `! pkexec pacman -S --noconfirm luau` (official `extra` repo, 0.748). Needed from Task 1.
- Only if Task 4's rivalcfg write check fails with a permission error: `! pkexec /home/charlie/.local/bin/rivalcfg --update-udev`.

## Review Focus

1. Mouse goes to sleep, then wakes: the widget shows the moon with the last level, controls disable, and within 10 s of waking everything returns. Pinned by `test_asleep_keeps_level` and `test_next_poll_asleep` (Task 1) plus the live check in Task 5.
2. The reader exits 0 with a level outside 0 to 100 or garbage text: the widget shows "?" instead of a wrong percent. Pinned by `test_out_of_range_is_error` and `test_garbage_is_error` (Task 1).
3. Dragging the sleep slider from 0 to 20: exactly one rivalcfg call, with the final value, and never two calls at once. Pinned by `test_coalesces_same_key` and `test_no_take_while_busy` (Task 3).
4. Typing a bad color (`#12345`, `blue!`): no rivalcfg call, the field reverts. Pinned by `test_rejects_bad_colors` (Task 2).
5. rivalcfg missing or failing: the control reverts and an error notification shows rivalcfg's message. Pinned by the live check with `rivalcfg_path = /nonexistent` in Task 5.

---

### Task 1: Test harness, battery module and bundled reader

**Files:**
- Create: `tests/run.luau`, `tests/test_battery.luau`, `lib/battery.luau`
- Create: `bin/aerox5-battery` (copy of `~/.local/bin/aerox5-battery`, mode 755)

**Interfaces:**
- Produces: `tests/run.luau` runs every `tests/test_*.luau` listed in it. Each test module returns `{ [string]: () -> () }`. Harness exposes `eq(actual, expected, msg?)` and `truthy(v, msg?)` through `require("./assert")` (`tests/assert.luau`). Exit code 1 on any failure.
- Produces (`lib/battery.luau`):
  - `type Battery = { state: "ok" | "asleep" | "no_dongle" | "error", level: number?, charging: boolean }`
  - `parse(exitCode: number, stdout: string, previous: Battery?): Battery`
  - `band(b: Battery): "high" | "mid" | "low" | "charging" | "asleep" | "unknown"`
  - `nextPollMs(b: Battery, intervalS: number): number`

- [ ] **Step 1: Check the require form.** Write `tests/assert.luau` and a one-line `tests/run.luau` that requires `./assert` and `../lib/battery` (empty module). Run `luau tests/run.luau`. Expected: exit 0. If the CLI wants another form, use it in tests only. Plugin entry files keep Noctalia's form `require("./lib/battery.luau")`, and `lib/` modules never require each other.

- [ ] **Step 2: Write the failing tests** in `tests/test_battery.luau`:

```lua
test_discharging = parse(0, "Discharging [========  ] 85 %") → { state="ok", level=85, charging=false }
test_charging = parse(0, "Charging [====      ] 40 %") → { state="ok", level=40, charging=true }
test_out_of_range_is_error = parse(0, "Charging [==] 630 %").state == "error", level == nil
test_garbage_is_error = parse(0, "hello").state == "error"
test_asleep_keeps_level = parse(1, "", {state="ok", level=85, charging=false}) → { state="asleep", level=85, charging=false }
test_asleep_without_previous = parse(1, "").level == nil
test_no_dongle = parse(2, "").state == "no_dongle", level == nil
test_unknown_exit = parse(3, "").state == "error"
test_bands = band(level 51)="high", 50="mid", 21="mid", 20="low", 0="low"; charging=true → "charging"; asleep → "asleep"; error/no_dongle → "unknown"
test_next_poll = nextPollMs(ok, 120) == 120000
test_next_poll_asleep = nextPollMs(asleep, 120) == 10000
```

- [ ] **Step 3: Run** `luau tests/run.luau`. Expected: FAIL, functions missing.
- [ ] **Step 4: Implement `lib/battery.luau`.** Status line pattern `^(%a+)%s+%[.-%]%s+(%d+)%s*%%`, matching the QML regex. A level outside 0 to 100 is `error`.
- [ ] **Step 5: Run** `luau tests/run.luau`. Expected: all pass.
- [ ] **Step 6: Copy the reader and run its doctests.** `cp ~/.local/bin/aerox5-battery bin/ && python3 -m doctest -v bin/aerox5-battery`. Expected: all doctests pass (8 at last count). If `doctest` can't import a file without `.py`, run `python3 -c "import doctest,importlib.machinery as m; mod=m.SourceFileLoader('r','bin/aerox5-battery').load_module(); print(doctest.testmod(mod))"` and expect `failed=0`.
- [ ] **Step 7: Commit** `feat: add battery parsing module and bundled hidraw reader`.

### Task 2: Mouse settings model

**Files:**
- Create: `lib/mouse.luau`, `tests/test_mouse.luau`; add the test module to `tests/run.luau`

**Interfaces:**
- Produces:
  - `type Settings = { presets: string, fixed_dpi: string, polling_rate: string, sleep_timer: number, dim_timer: number, top_color: string, middle_color: string, bottom_color: string, reactive_color: string, default_lighting: string, rainbow: boolean }`
  - Constants `PRESETS` (the five lists from the spec, rivalcfg default first), `FIXED_DPI` (`""` then 400, 800, 1200, 1600, 2400, 3200, 6400), `POLLING` (125, 250, 500, 1000), `LIGHTING` (off, reactive, rainbow, reactive-rainbow). Option values are strings.
  - `defaults(): Settings`: presets `"400, 800, 1200, 2400, 3200"`, fixed `""`, polling `"1000"`, sleep 5, dim 30, colors `""`, reactive `"off"`, lighting `"rainbow"`, rainbow false.
  - `fromLegacy(t: { [string]: any }): (Settings, { poll_interval: number?, rivalcfg_path: string? })`
  - `normalizeColor(s: string, allowOff: boolean): string?`
  - `change(s: Settings, key: string, value: any): (Settings?, { string } | string)`: on success the new settings (input not mutated) and the rivalcfg arguments without the binary; on failure `nil` and an error code.

- [ ] **Step 1: Write the failing tests:**

```lua
test_legacy_import: fromLegacy({ sensitivity="800, 1600, 3200", fixedDpi="2400", pollingRate="1000", sleepTimer=15, dimTimer=30, reactiveColor="off", defaultLighting="reactive", rainbowEffect=false, pollInterval=60, rivalcfgPath="/home/x/rivalcfg" })
  → presets "800, 1600, 3200", fixed_dpi "2400", sleep_timer 15, default_lighting "reactive"; extras { poll_interval=60, rivalcfg_path="/home/x/rivalcfg" }
test_legacy_bad_values_fall_back: fromLegacy({ sleepTimer=99, pollingRate="7", defaultLighting="disco" }) → defaults for those three
test_legacy_empty: fromLegacy({}) == defaults(), extras empty
test_fixed_dpi_args: change(s, "fixed_dpi", "2400") → args { "-s", "2400, 2400, 2400, 2400, 2400" }
test_fixed_off_resends_presets: s.presets="800, 1600, 3200"; change(s, "fixed_dpi", "") → { "-s", "800, 1600, 3200" }
test_presets_locked: s.fixed_dpi="2400"; change(s, "presets", PRESETS[2]) → nil, "presets_locked"
test_presets_args: change(defaults(), "presets", "400, 800, 1600") → { "-s", "400, 800, 1600" }
test_polling: "polling_rate" "500" → { "-p", "500" }; "7" → nil, "invalid"
test_timers: sleep_timer 20 → { "-t", "20" }; 21 → nil, "invalid"; dim_timer 1200 → { "-T", "1200" }; -1 → nil, "invalid"
test_lighting: default_lighting "reactive-rainbow" → { "-d", "reactive-rainbow" }; "disco" → nil, "invalid"
test_rejects_bad_colors: top_color "#12345" → nil, "invalid"; "blue!" → nil, "invalid"; "" → nil, "invalid"
test_colors_accepted: normalizeColor("#F00", false) == "#f00"; "ff0000" == "ff0000"; " Red " == "red"; normalizeColor("off", true) == "off"; normalizeColor("off", false) == nil
test_color_clears_rainbow: s.rainbow=true; change(s, "middle_color", "lime") → new.rainbow == false, args { "--middle-color", "lime" }
test_reactive: reactive_color "off" → { "-a", "off" }
test_rainbow_on: change(s, "rainbow", true) → { "-e" }
test_rainbow_off_defaults: colors empty; change(s, "rainbow", false) → args { "--top-color", "red", "--middle-color", "lime", "--bottom-color", "blue" }, new colors stored as red/lime/blue
test_rainbow_off_keeps_colors: top_color "#00ff00" → first pair { "--top-color", "#00ff00" }
test_unknown_key: change(s, "dpi", 1) → nil, "invalid"
test_no_mutation: input table unchanged after any change call
```

- [ ] **Step 2: Run** `luau tests/run.luau`. Expected: FAIL.
- [ ] **Step 3: Implement `lib/mouse.luau`.** Colors: trim and lowercase; accept `#rgb`, `#rrggbb`, `rgb`, `rrggbb` hex, or a name matching `^%a+$` (rivalcfg validates names). `reactive_color` also accepts `off`. Presets accepted are the `PRESETS` entries only.
- [ ] **Step 4: Run** `luau tests/run.luau`. Expected: all pass.
- [ ] **Step 5: Commit** `feat: add mouse settings model and rivalcfg argument builder`.

### Task 3: Apply queue

**Files:**
- Create: `lib/queue.luau`, `tests/test_queue.luau`; add to `tests/run.luau`

**Interfaces:**
- Produces: `new(): Queue` with methods `push(key: string, value: any, nowMs: number, delayMs: number)`, `take(nowMs: number): { key: string, value: any }?`, `done()`, `isEmpty(): boolean`, `busy(): boolean`. `push` replaces any pending entry for the same key and resets its ready time. `take` returns the entry with the earliest ready time that is due, removes it and marks the queue busy. It returns nil while busy. `done` clears busy.

- [ ] **Step 1: Write the failing tests:** `test_take_when_due` (push delay 0, take(now) returns it), `test_not_before_delay` (push at 0 with 1000, take(999) nil, take(1000) returns), `test_coalesces_same_key` (push sleep_timer 3 at 0, 7 at 500, 20 at 900, each delay 1000; take(1899) nil; take(1900) returns value 20; then queue empty after done), `test_no_take_while_busy` (two due keys; first take returns one; second take nil until done), `test_earliest_first` (a due at 100, b due at 50 → b first).
- [ ] **Step 2: Run** and expect FAIL.
- [ ] **Step 3: Implement `lib/queue.luau`.**
- [ ] **Step 4: Run** `luau tests/run.luau`. Expected: all pass.
- [ ] **Step 5: Commit** `feat: add coalescing apply queue`.

### Task 4: Manifest, service and bar widget

**Files:**
- Create: `plugin.toml`, `service.luau`, `bar.luau`, `translations/en.json`

**Interfaces:**
- Consumes: Tasks 1 to 3.
- Produces (shared state, read by `bar.luau` and `panel.luau`):
  - `aerox5.battery` = `Battery` plus `checked_at: number` (ms, `noctalia.nowMs()`)
  - `aerox5.settings` = `Settings` (last applied values)
  - `aerox5.busy` = boolean (a rivalcfg call is running)
  - `aerox5.cmd` = `{ op: "set", key: string, value: any, delay_ms: number } | { op: "refresh" }`, cleared to nil by the service after handling (the `world_clock.cmd` pattern)

- [ ] **Step 1: Write `plugin.toml`** modeled on `~/.local/state/noctalia/plugins/materialized/official/world_clock/plugin.toml`: id, name "Aerox 5 Wireless", version 2.0.0, `plugin_api` equal to world_clock's (43), author "KingRecycle", license MIT, icon a mouse glyph, `[[service]]`, `[[widget]] id="bar"`, `[[panel]] id="panel"` (attached, `height = "content"`, `max_height = 640`, `open_near_click = true`), and plugin-level `[[setting]]` entries `poll_interval` (int 30 to 300, default 120) and `rivalcfg_path` (string, default `rivalcfg`). Labels go through `translations/en.json`.
- [ ] **Step 2: Lint.** `noctalia plugins lint .` Expected: no errors.
- [ ] **Step 3: Implement `service.luau`:**
  - `noctalia.setUpdateInterval(250)`. `update()` starts a battery poll when due (one in flight at most) and takes the next queue entry when due.
  - Battery poll: `noctalia.runAsync({ noctalia.pluginDir() .. "/bin/aerox5-battery" }, cb, 5000)` then `battery.parse(result.exitCode, result.stdout, previous)`. A timeout counts as exit 1.
  - Load `pluginDataDir()/mouse.json`. If missing, run the legacy import from `noctalia.expandPath("~/.config/noctalia/plugins/aerox5-wireless/settings.json")` or fall back to `defaults()`, write `mouse.json`, and for each extra run `noctalia msg config-set 'plugin_settings."kingrecycle/aerox5-wireless".<key>' <toml value>` through `runAsync` (strings TOML-quoted).
  - `set` command: reject when battery state isn't `ok`; validate with `mouse.change` against current settings (reject and republish on error, with `noctalia.notifyError` for `invalid`); otherwise `queue:push(key, value, now, delay_ms)`.
  - Apply: recompute `mouse.change` against the settings current at take time, run `{ rivalcfg_path, table.unpack(args) }` with a 10000 ms timeout, set `aerox5.busy`. On exit 0 save `mouse.json` and publish. On failure publish the unchanged settings (the panel reverts) and `notifyError` with stderr, else stdout, else a generic message. Always `queue:done()`.
  - `refresh` command: poll now.
- [ ] **Step 4: Implement `bar.luau`:** glyph plus `"85%"` text per the spec's state table, colors by `battery.band` (high success, mid warning, low error, charging primary, asleep and unknown on_surface_variant). Vertical bar: glyph only. `onClick()` toggles `kingrecycle/aerox5-wireless:panel`. No tooltip.
- [ ] **Step 5: Register and enable.** `noctalia msg plugins source add aerox5-local path ~/.config/noctalia/plugins` (if the source must point at the plugin folder itself, use that path instead), then `noctalia msg plugins enable kingrecycle/aerox5-wireless`, then add the widget to the bar in Settings. Expected: `noctalia msg plugins list` shows it enabled. Note in the README whether edits need `noctalia msg plugins update aerox5-local`.
- [ ] **Step 6: Live checks with screenshots** (`grim`, crop to the bar): the real level shows in the right band color. Then temporarily point the battery command at a script printing `Charging [==] 40 %` (exit 0), one exiting 1 and one exiting 2, take a screenshot of each, and revert. Expected: bolt with 40%, moon with the last level, "?" respectively. Confirm `journalctl -k --since` the start shows no `hid-generic ... Aerox` re-probe during polling.
- [ ] **Step 7: rivalcfg write check.** Run `~/.local/bin/rivalcfg -p 1000` (Charlie's current value, so nothing changes). Expected: exit 0. On a permission error, stop and ask Charlie to run the udev prerequisite.
- [ ] **Step 8: Commit** `feat: add v5 service and bar widget`.

### Task 5: Panel

**Files:**
- Create: `panel.luau`; extend `translations/en.json`

**Interfaces:**
- Consumes: the `aerox5.*` state keys and `lib/mouse.luau` constants.

- [ ] **Step 1: Implement `panel.luau`** in the spec's order: header (name, refresh button sending `{op="refresh"}`, settings button via `noctalia.openSettings` as the official plugins use it, close button), battery block (level, `ui.progress`, status line with age), then Performance, Power, Lighting. Selects use `ui.select` with `selectedIndex` (0-based) and send `delay_ms = 0`. Sliders use `ui.slider` with `delay_ms = 1000`, labels "Off" at 0. Colors use `ui.input`: `onChange` sends `delay_ms = 1000`, `onSubmit` sends 0. Rainbow is a two-option select (Off, On). Every control has `enabled = battery.state == "ok"`; the preset select also requires `fixed_dpi == ""` and shows "Presets apply when fixed DPI is off." beneath it. When disabled for battery state, show "Mouse asleep. Move it to wake it." or "Dongle not found." Re-render on `noctalia.state.watch` of each key.
- [ ] **Step 2: Lint.** `noctalia plugins lint .` Expected: no errors.
- [ ] **Step 3: Live checks with screenshots of the open panel** (`noctalia msg panel-toggle kingrecycle/aerox5-wireless:panel`, then `grim`):
  - Panel shows Charlie's imported values (fixed 2400, presets 800/1600/3200 grayed with the note, sleep 15 min).
  - Change polling rate to 500 then back to 1000. Expected: two rivalcfg calls, panel stays on the chosen value, no error.
  - Drag sleep from 15 to 14 and back to 15 quickly. Expected: one rivalcfg call (check with a temporary `noctalia.log` line, removed before commit).
  - Set `rivalcfg_path` to `/nonexistent`, change polling rate. Expected: control reverts, error notification. Restore the path.
  - Type `#12345` in the top color and press Enter. Expected: error notification, field reverts, no rivalcfg call.
  - Ask Charlie to switch the mouse off. Expected within one poll: moon in the bar, controls disabled with the asleep line. Switch on: back within 10 s.
- [ ] **Step 4: Commit** `feat: add mouse settings panel`.

### Task 6: Retire the QML plugin and document v5

**Files:**
- Delete: `Main.qml`, `BarWidget.qml`, `Settings.qml`, `manifest.json`
- Modify: `README.md`

- [ ] **Step 1: Delete the QML files.** `git rm Main.qml BarWidget.qml Settings.qml manifest.json`. Leave the untracked `CLAUDE.md` and gitignored `settings.json` alone.
- [ ] **Step 2: Rewrite `README.md`** for v5: what it does, prerequisites (Noctalia 5.6+, Python 3, rivalcfg with udev rules), install (clone, `plugins source add`, `plugins enable`, add widget), the panel and its controls, why battery reads use hidraw and not rivalcfg, the `v1-qml` tag for Noctalia v4 users. Keep the AI disclosure paragraph and add the "How AI was used" checklist from `~/.claude/templates/ai-disclosure.md`, following that file's notes.
- [ ] **Step 3: Full checks.** `luau tests/run.luau` (all pass), `noctalia plugins lint .` (clean), `python3` doctests (Task 1 command, `failed=0`), `noctalia msg plugins update aerox5-local` then a bar screenshot showing the widget.
- [ ] **Step 4: Commit** `docs: rewrite README for Noctalia v5` (including the deletions as `refactor!: remove Noctalia v4 QML plugin` in a separate commit first).
