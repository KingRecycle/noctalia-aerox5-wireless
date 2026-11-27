# Aerox 5 Wireless plugin: Noctalia v5 (Luau) rewrite

Date: 2026-11-27. Status: draft for Charlie's approval.

## Intent

Charlie uses this plugin to see the SteelSeries Aerox 5 Wireless battery level in the bar, so they know when to charge the mouse. They also want to change the mouse's hardware settings (DPI, polling rate, timers, lighting) from the shell.

The QML plugin in this repo ran on Noctalia v4. Charlie's desktop is now Umbriel with Noctalia 5.6, whose plugins are Luau, so the QML plugin no longer loads. This rewrite brings both features back on v5.

## Goals

- A bar widget that shows the battery level and charge state at a glance.
- A panel, opened by clicking the widget, that shows the battery and holds every mouse control.
- Changes made in the panel reach the mouse right away.
- The plugin keeps the hidraw battery reader, so polling never causes the game stutter described below.

## Non-goals

- Button remapping (`rivalcfg -b`) and factory reset (`rivalcfg -r`). The old plugin didn't offer them.
- Other SteelSeries mice. The README can keep its "may work" note, but nothing is built or tested for them.
- A desktop widget. Bar widget and panel only.
- Low-battery notifications. Not requested.

## Anti-goals

- Any battery polling through `rivalcfg`. Its libusb backend unbinds and rebinds the dongle's kernel HID driver on every call. Proton's winebus and Steam Input re-enumerate every input device on each rebind, which caused a ~200 ms hitch every poll (found and fixed 2026-08-24). rivalcfg runs only when Charlie changes a setting.
- A panel control that fires `rivalcfg` continuously while being dragged.
- Breaking the DMS copy of this widget (`~/.config/DankMaterialShell/plugins/aerox5-wireless/`) or `~/.local/bin/aerox5-battery`, which DMS uses.

## Constraints and verified facts

Checked on Charlie's PC (endfield) on 2026-11-27:

- Noctalia 5.6.0 (`noctalia` package, cachyos repo). Plugins are a folder with `plugin.toml` plus `.luau` entry files, as in the installed official plugins under `~/.local/state/noctalia/plugins/materialized/official/`. `world_clock` (service + bar + panel) is the closest model for this plugin's shape.
- A local folder can be registered as a plugin source: `noctalia msg plugins source add <name> path <location>`. Not yet tried.
- Plugin API calls seen in installed plugins: `noctalia.runAsync(argv, callback)`, `noctalia.setUpdateInterval(ms)`, `noctalia.getConfig`, `noctalia.state.get/set/watch` (shared state between entries), `noctalia.pluginDir()`, `noctalia.pluginDataDir()`, `noctalia.readFile/writeFile`, `noctalia.json.encode/decode`, `noctalia.togglePanel`, `noctalia.notifyError`, `noctalia.commandExists`. Bar widgets define `update()` and `onClick()` (`onRightClick`, `onMiddleClick`, `onScroll` also exist) and draw with `barWidget.render(...)`.
- UI elements seen: `ui.label`, `ui.row`, `ui.column`, `ui.button`, `ui.glyph`, `ui.input`, `ui.select`, `ui.slider`, `ui.progress`, `ui.separator`, `ui.scroll`, `ui.box`. No color picker was found.
- Settings-page field types seen in `plugin.toml`: `bool`, `int`, `select`, `string`.
- The binary contains "calling onConfigChanged", but no installed plugin uses that hook. This design doesn't depend on it.
- `noctalia plugins lint <path>` cross-checks declared settings against plugin code, offline.
- `~/.local/bin/aerox5-battery` (stdlib Python) prints the same line as `rivalcfg --battery-level`, for example `Discharging [========  ] 85 %`. Exit codes: 0 ok, 1 mouse unreachable (asleep or switched off, which can't be told apart), 2 dongle not found. It read 85% on 2026-11-27 with no USB re-probe.
- `rivalcfg` (`~/.local/bin/rivalcfg`) saves settings to the mouse's internal memory by default (`--no-save` turns that off). Settings survive power cycles, so the plugin doesn't need to re-apply them at startup.
- `rivalcfg --help` warns "udev rules are not installed. You may not be able to open the device using a regular user." Whether a write works as Charlie's user is not yet verified. If it doesn't, the fix is a one-time `rivalcfg --update-udev` as root, which Charlie runs.
- rivalcfg can't read settings back from the mouse. The panel can only show what the plugin last applied.
- Aerox 5 rivalcfg ranges: sensitivity up to 5 DPI values, 100 to 18000; polling rate 125, 250, 500 or 1000 Hz; sleep timer 0 to 20 minutes (0 = off); dim timer 0 to 1200 seconds (0 = off); colors as names or hex; reactive color can be `off`; default lighting is off, reactive, rainbow or reactive-rainbow; `-e` turns on the rainbow effect, and setting a color turns it off.
- This repo is public on GitHub (`KingRecycle/noctalia-aerox5-wireless`). Its last QML version is tagged `v1-qml` (commit 0e4a67c, includes the hidraw battery change).

## Approaches considered

1. **Settings page, applied on save.** A service polls the battery, the bar widget shows it, and every mouse setting lives on the plugin's settings page, applied with rivalcfg on save. Least code, and closest to the QML plugin.
2. **Service, bar widget and a panel with every mouse control (chosen).** Same service and bar widget. Clicking the widget opens a panel holding the battery readout and all mouse controls, applied as they change. The settings page keeps only plugin plumbing.
3. Reading the battery from `/dev/hidraw` directly in Luau was dropped. The file API plugins get doesn't appear to support writing a request and reading the reply on one open device, so the Python reader stays.

Charlie picked 2, with the panel layout "C" (every control in the panel) over smaller panels with only quick switches.

## What Charlie decided

- Battery display plus mouse settings, not battery only.
- A panel opened from the bar widget, holding every mouse control.
- Panel changes apply instantly, per control. Sliders apply about one second after the last change, not while dragging.
- While the mouse is asleep or the dongle is missing, the mouse controls are disabled, with a line like "Mouse asleep. Move it to wake it." (rivalcfg may report success for a write the sleeping mouse never received.)
- While fixed DPI is on, the preset list is grayed out, with a note that presets apply when fixed DPI is off. Presets and fixed DPI share rivalcfg's `-s` flag, so sending presets would cancel fixed DPI.
- Turning rainbow off sends the three zone colors, falling back to rivalcfg's defaults (red, lime, blue) for any never set. Setting a zone color while rainbow is on flips the rainbow switch off, matching what the mouse does.

## Design

### Entries

- **Service** (`service.luau`). Owns the battery state and the mouse settings. Polls the battery, runs rivalcfg, and publishes state for the other two entries through `noctalia.state`.
- **Bar widget** (`bar.luau`). Shows the battery and opens the panel on click.
- **Panel** (`panel.luau`), attached to the bar.

### Battery polling

- The service runs the bundled `bin/aerox5-battery` with `noctalia.runAsync` every poll interval (default 120 s). It never polls with rivalcfg.
- Exit 0: parse status and percent. Exit 1: mouse asleep, so keep the last known level, mark it asleep, and re-poll every 10 s until it answers. Exit 2: dongle not found, level unknown. Same behavior as the DMS widget.
- Only one poll runs at a time.

### Bar widget states

| State | Glyph | Text | Color |
|---|---|---|---|
| Level above 50% | mouse | `85%` | success / green |
| 21% to 50% | mouse | `42%` | warning / yellow |
| 20% or less | mouse | `15%` | error / red |
| Charging | charging glyph | `60%` | primary |
| Asleep (exit 1) | moon | last known level | muted |
| Dongle not found (exit 2) or parse error | mouse-off or similar | `?` | muted |

The 20% and 50% thresholds are fixed, as in the QML plugin. Exact glyph names and theme color roles are the builder's call. They should match Noctalia's theme roles so Charlie's Endfield palette applies.

Left click toggles the panel. No hover tooltip (Charlie removed it from the DMS version).

### Panel

Top to bottom:

1. Header: plugin name, a refresh button (forces a battery poll), a settings button (opens the plugin's settings page), and a close button if the shell's settings call for one.
2. Battery: level, a progress bar, and a status line ("Discharging", "Charging", "Asleep, last seen 85%", "Dongle not found") with how long ago it was checked.
3. Performance: DPI presets (the list the mouse's DPI button cycles through), fixed DPI (off, or one value that locks the mouse), and polling rate.
4. Power: sleep timer slider (0 to 20 min, 0 shows "Off") and dim timer slider (0 to 1200 s, 0 shows "Off").
5. Lighting: default lighting mode, rainbow effect on or off, top, middle and bottom LED colors, and the reactive color.

The preset and fixed-DPI choices are the QML plugin's lists. Presets: 400/800/1200/2400/3200 (rivalcfg default), 400/800/1600, 800/1600/3200, 1600/3200/6400, 800/1200/1600/2400/3200. Fixed DPI: off, 400, 800, 1200, 1600, 2400, 3200, 6400.

### Applying changes

- Controls are disabled while the battery state is asleep or dongle-not-found, and re-enable at the next successful poll.
- Selects and buttons apply on change. Sliders and color text inputs apply about one second after the last edit (color inputs also on Enter).
- One rivalcfg call carries only the setting that changed, with the same flag mapping as `Main.qml` `applyMouseSettings()`. Fixed DPI sends `-s` with the value repeated, as the QML did. Choosing fixed DPI "off" re-sends the preset list. The preset select is disabled while fixed DPI is on. Edits to it are impossible in that state, so nothing is stored without being applied.
- While a call runs, further changes queue, and only the latest value per setting is sent. Calls never overlap.
- On success the new value is saved. On failure the panel control reverts to the last good value and the plugin shows an error notification with rivalcfg's message.
- Rainbow on sends `-e`. Rainbow off sends `--top-color`, `--middle-color` and `--bottom-color` with the stored colors, using red, lime and blue for any empty one, and stores those values. A successful zone-color change sets the stored rainbow value to off.
- Invalid color text is rejected before calling rivalcfg (rivalcfg accepts names and `#rgb`/`#rrggbb`/`rrggbb` hex).

### Stored settings

- Mouse settings live in `pluginDataDir()/mouse.json`, written by the service. The panel shows these values.
- On first run, if `mouse.json` doesn't exist, the service imports the QML plugin's settings once from `~/.config/noctalia/plugins/aerox5-wireless/settings.json` (through `noctalia.expandPath`), if that file exists. It can't rely on `pluginDir()`, because a registered source may be copied elsewhere and `settings.json` is gitignored. Without the file, it starts from rivalcfg's defaults. The import never applies anything to the mouse, and no user's values are hardcoded in the plugin.
- The same import carries the old `pollInterval` and `rivalcfgPath` into this plugin's settings page values, for example with `noctalia msg config-set`. The builder confirms the exact config path.
- Empty colors mean "never set by the plugin" and are left out of calls.

### Settings page (plugin.toml)

- `poll_interval` (int, seconds, 30 to 300, default 120).
- `rivalcfg_path` (string, default `rivalcfg`). Noctalia's PATH may not include `~/.local/bin`.

### Repo layout

- Replace the QML files on this branch. The `v1-qml` tag keeps them.
- `plugin.toml`, `service.luau`, `bar.luau`, `panel.luau`, `translations/en.json` (if the plugin API expects translation keys, as the official plugins use), `bin/aerox5-battery` (copied from `~/.local/bin`, with its doctests), `README.md`.
- Plugin ID: `kingrecycle/aerox5-wireless` or whatever author/name format v5 requires.

### README

- Rewrite install steps for v5: register the folder with `noctalia msg plugins source add`, enable with `noctalia msg plugins enable`, add the widget to the bar.
- Keep the AI disclosure paragraph and add the "How AI was used" checklist from `~/.claude/templates/ai-disclosure.md`.
- Explain the hidraw reader and why rivalcfg isn't used for polling.

## Left to the builder

- Glyph names, color roles, spacing and panel size.
- Internal state shape in `noctalia.state`.
- Whether the debounce is 0.8 s or 1.2 s.
- How to show "applying" feedback, if any.
- Tests: Luau has no test runner here, so verification is `noctalia plugins lint`, the bundled script's doctests, and a live check on the real mouse with screenshots of each bar state.

## Risks

- rivalcfg may need udev rules before it can write as Charlie's user (see constraints).
- Each rivalcfg call re-enumerates the dongle's settings interface. If Charlie changes settings during a game, expect one hitch per change.
- If the panel API can't report slider releases, the debounce timer has to run in the service.
