# Aerox 5 Wireless, a Noctalia plugin

A [Noctalia](https://noctalia.dev) plugin for the SteelSeries Aerox 5 Wireless mouse. It shows the battery level in the bar so you know when to charge, and its panel changes the mouse's hardware settings with [rivalcfg](https://github.com/flozz/rivalcfg).

This version is for Noctalia 5.6 and later, whose plugins are written in Luau. For Noctalia v4, use the `v1-qml` tag.

## What it does

The bar widget shows the mouse glyph and the battery percent:

| State | Glyph | Text | Color role |
|---|---|---|---|
| Above 50% | mouse | `85%` | `on_surface` |
| 21% to 50% | mouse | `42%` | `tertiary` |
| 20% or less | mouse | `15%` | `error` |
| Charging | battery-charging | `60%` | `primary` |
| Asleep or switched off | moon | last known level | `on_surface_variant` |
| Dongle not found | mouse-off | `?` | `on_surface_variant` |

Noctalia's theme has no green or yellow role, so the colors come from your palette's roles. A vertical bar shows the glyph only.

Click the widget to open the panel. It shows the battery and every mouse setting:

- Performance has the DPI presets the mouse's DPI button cycles through, a fixed DPI that locks one value, and the polling rate (125 to 1000 Hz).
- Power has the sleep timer (0 to 20 min) and the LED dim timer (0 to 1200 s). 0 turns either one off.
- Lighting has the mode (Off, Reactive only, Custom zones or Rainbow cycle), the top, middle and bottom LED colors, and Reactive, which flashes a color of your choice on each click.

A change reaches the mouse as soon as you pick it. Sliders and color fields wait until about one second after your last change, so dragging a slider sends one rivalcfg call, not dozens. Press Enter in a color field to send it at once.

The lighting mode takes effect right away and sticks after a restart. Off turns the LEDs dark with no click flash. Reactive only keeps them dark and flashes your reactive color on each click. Custom zones shows your three zone colors. Rainbow cycle cycles colors on its own. Reactive is a separate on/off for the click flash, used by Custom zones and Rainbow cycle. Controls the current mode doesn't use gray out, and the plugin keeps their values for when you switch back.

rivalcfg's own lighting setting only applies at the next power-on, and the mouse flashes the reactive color on clicks whatever that setting says. So each mode change sends both the startup setting and what the LEDs should show now.

Each color has a dropdown and a text field. The dropdown holds eight preset colors, four colors from your current Noctalia palette (primary, secondary, tertiary and error), and Custom. A palette pick sends the palette's color as it is right now. The mouse keeps that color when the theme changes later, because each re-send would be a rivalcfg call. The text field takes any name rivalcfg knows, like `red`, or hex like `#ff0000` or `#f00`.

The controls turn off while the mouse is asleep or the dongle is unplugged. A sleeping mouse can miss a write that rivalcfg still reports as a success. Move the mouse and the controls come back within 10 seconds.

The DPI presets are grayed out while fixed DPI is on. Both use rivalcfg's `-s` flag, so sending the presets would cancel the fixed DPI. Turn fixed DPI off and the mouse goes back to the presets.

rivalcfg can't read settings back from the mouse, so the panel shows the values the plugin last applied. rivalcfg saves each change to the mouse's own memory, so settings survive a power cycle.

## Why the battery check doesn't use rivalcfg

rivalcfg talks to the mouse through libusb, which unbinds and rebinds the dongle's kernel HID driver on every call. Proton and Steam Input then rescan every input device, and games freeze for about 200 ms. With a battery check every couple of minutes, that's a stutter every couple of minutes.

The battery check runs `bin/aerox5-battery` instead. It's a small Python script that asks the dongle for the battery level over `/dev/hidraw` and leaves the driver alone. rivalcfg only runs when you change a setting in the panel, so expect one hitch per change if you do that mid-game.

## Requirements

- Noctalia 5.6 or later
- Python 3 (the battery reader uses the standard library only)
- [rivalcfg](https://github.com/flozz/rivalcfg), for the panel's settings. Without it the battery widget still works.
- Read and write access to the dongle's `/dev/hidraw` node for your user. rivalcfg's udev rules give it (run `rivalcfg --update-udev` as root once), and some systems already have a rule that does.

## Install

1. Clone the repo into a folder that holds your local plugins:

   ```sh
   git clone https://github.com/KingRecycle/noctalia-aerox5-wireless.git ~/.config/noctalia/plugins/aerox5-wireless
   ```

2. Register that parent folder as a plugin source. Noctalia looks for plugin folders one level below it, the same way it reads its git sources.

   ```sh
   noctalia msg plugins source add local path ~/.config/noctalia/plugins
   ```

3. Enable the plugin:

   ```sh
   noctalia msg plugins enable kingrecycle/aerox5-wireless
   ```

4. Add the Aerox 5 Wireless widget to your bar in Noctalia's settings.

Noctalia runs the plugin from the cloned folder. After you pull an update or edit a file, reload it:

```sh
noctalia msg plugins disable kingrecycle/aerox5-wireless
noctalia msg plugins enable kingrecycle/aerox5-wireless
```

`noctalia msg plugins update <source>` doesn't reload a running plugin.

## Settings page

Open it from the gear in the panel, or with `noctalia msg settings-open-plugin kingrecycle/aerox5-wireless`.

| Setting | What it does | Default |
|---|---|---|
| Battery check interval | Seconds between battery checks while the mouse is awake, 30 to 300 | 120 |
| rivalcfg path | The rivalcfg command or its full path. Noctalia's `PATH` may not include `~/.local/bin`. | `rivalcfg` |

## Coming from the v4 plugin

On its first run the plugin reads the v4 plugin's `settings.json` from `~/.config/noctalia/plugins/aerox5-wireless/`, if it's there. It copies the mouse settings into the panel and the poll interval and rivalcfg path into the settings page. It sends nothing to the mouse, which already holds those values. The mouse settings then live in Noctalia's plugin data folder as `mouse.json`.

## Development

```sh
luau tests/run.luau                       # unit tests for lib/
luau-analyze lib/*.luau tests/*.luau      # type check
noctalia plugins lint .                   # manifest and settings check
PYTHONDONTWRITEBYTECODE=1 python3 -c "import doctest,importlib.machinery as m,importlib.util as u; l=m.SourceFileLoader('r','bin/aerox5-battery'); s=u.spec_from_loader('r',l); mod=u.module_from_spec(s); l.exec_module(mod); print(doctest.testmod(mod))"
```

`lib/` holds the logic the tests cover: battery parsing, the settings model with its rivalcfg arguments, and the queue that sends one change at a time. `service.luau`, `bar.luau` and `panel.luau` connect it to Noctalia.

## Compatibility

Built and tested with the SteelSeries Aerox 5 Wireless over its 2.4 GHz dongle. The battery reader looks for that dongle's USB ID only. The panel may work with other mice rivalcfg supports, but nothing here was tested with them.

## AI disclosure

This plugin was 100% generated using Claude Code. I personally had no desire to learn a plugin system for a one-off plugin, so I let AI do it for me. I respect the opinion of those who would rather not use AI-generated code, so I'm disclosing this upfront so you can make your own informed choice to use the plugin or not.

## How AI was used

Tools: Claude (Claude Code). From 2026-10-31 on, commits Claude wrote carry a `Co-Authored-By: Claude` line, so `git log` shows which ones.

Roughly how much of the code AI wrote: **all**

**Code**
- [x] Wrote new features
- [x] Wrote tests
- [ ] Found bugs or issues for me to look into
- [x] Fixed bugs
- [x] Refactored existing code
- [ ] Reviewed code before merge
- [ ] Autocomplete only

**Design and planning**
- [x] Chose the architecture or tech stack
- [x] Turned my ideas into written specs and plans
- [x] Made product or UX decisions
- [x] Drew UI mockups

**Writing**
- [x] Drafted the README and docs
- [x] Wrote commit messages and PR descriptions
- [x] Wrote text users see in the app

**Assets**
- [ ] Made images, icons, or art
- [ ] Made audio or voice

**In the app itself**
- [ ] The app sends your data to an AI model while it runs

**My part**
- [ ] I made the product and design decisions
- [ ] I tested the app myself
- [ ] I reviewed every AI change before it merged

## License

MIT
