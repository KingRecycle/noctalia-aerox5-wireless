# Aerox 5 Wireless — Noctalia Plugin

A [Noctalia](https://noctalia.dev) bar widget plugin for the **SteelSeries Aerox 5 Wireless** mouse. Displays battery level in the bar and provides a settings UI for configuring mouse hardware settings — all powered by [rivalcfg](https://github.com/flozz/rivalcfg).

## Features

**Bar Widget**
- Battery percentage with color-coded indicator (green/yellow/red)
- Charging status detection
- Mouse icon with hover tooltip
- Configurable poll interval

**Mouse Settings** (via plugin settings panel)
- **Performance** — DPI presets, fixed DPI lock, polling rate (125–1000 Hz)
- **Power** — Sleep timer (0–20 min), LED dim timer (0–1200s)
- **Lighting** — Per-zone LED colors, reactive color, default lighting mode, rainbow effect

Settings are applied directly to the mouse when saved.

## Prerequisites

- [Noctalia](https://noctalia.dev) shell (v3.6.0+)
- [rivalcfg](https://github.com/flozz/rivalcfg) — CLI tool for SteelSeries mice
  - Download the latest release from the [releases page](https://github.com/flozz/rivalcfg/releases)
  - The plugin expects `rivalcfg` to be available on your PATH by default
  - If rivalcfg is installed elsewhere, set the full path in the plugin settings

## Installation

1. Clone this repo into your Noctalia plugins directory:

```sh
git clone https://github.com/KingRecycle/noctalia-aerox5-wireless.git ~/.config/noctalia/plugins/aerox5-wireless
```

2. Register the plugin in `~/.config/noctalia/plugins.json` — add to the `"states"` object:

```json
"aerox5-wireless": {
    "enabled": true,
    "sourceUrl": "local"
}
```

3. Restart Noctalia:

```sh
killall qs; nohup qs -c noctalia-shell > /dev/null 2>&1 &
```

4. Add the **Aerox 5 Wireless** widget to your bar through Noctalia bar settings.

## Configuration

Right-click the widget and select **Settings**, or open it through the Noctalia settings panel.

| Setting | Description | Default |
|---------|-------------|---------|
| Poll interval | How often to check battery (seconds) | 120 |
| rivalcfg path | Path to the rivalcfg binary | `rivalcfg` (uses PATH) |
| DPI Preset | Sensitivity presets the DPI button cycles through | 800 |
| Fixed DPI | Lock to a single DPI (disables DPI button) | Disabled |
| Polling rate | USB polling rate | 1000 Hz |
| Sleep timer | Idle time before mouse sleeps (0 = off) | 5 min |
| Dim timer | Idle time before LEDs dim (0 = off) | 30s |
| LED colors | Top, middle, bottom zone colors (hex or name) | — |
| Reactive color | LED color on button click | off |
| Default lighting | LED mode at startup | rainbow |
| Rainbow effect | Enable rainbow LED cycling | off |

## Compatibility

Built for the SteelSeries Aerox 5 Wireless in 2.4 GHz wireless mode. May work with other SteelSeries mice supported by rivalcfg — check [rivalcfg's device list](https://github.com/flozz/rivalcfg#supported-devices) for compatibility.

## AI Disclosure

This plugin was 100% generated using [Claude Code](https://claude.ai/code). I personally had no desire to learn a plugin system for a one-off plugin, so I let AI do it for me. I respect the opinion of those who would rather not use AI-generated code, so I'm disclosing this upfront so you can make your own informed choice to use the plugin or not.

## License

MIT
