import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // Widget settings
  property int pollInterval: cfg.pollInterval ?? defaults.pollInterval ?? 120
  property string rivalcfgPath: cfg.rivalcfgPath ?? defaults.rivalcfgPath ?? "rivalcfg"

  // Mouse settings
  property string sensitivity: cfg.sensitivity ?? defaults.sensitivity ?? "800"
  property string pollingRate: cfg.pollingRate ?? defaults.pollingRate ?? "1000"
  property int sleepTimer: cfg.sleepTimer ?? defaults.sleepTimer ?? 5
  property int dimTimer: cfg.dimTimer ?? defaults.dimTimer ?? 30
  property string topColor: cfg.topColor ?? defaults.topColor ?? ""
  property string middleColor: cfg.middleColor ?? defaults.middleColor ?? ""
  property string bottomColor: cfg.bottomColor ?? defaults.bottomColor ?? ""
  property string reactiveColor: cfg.reactiveColor ?? defaults.reactiveColor ?? "off"
  property string fixedDpi: cfg.fixedDpi ?? defaults.fixedDpi ?? ""
  property string defaultLighting: cfg.defaultLighting ?? defaults.defaultLighting ?? "rainbow"
  property bool rainbowEffect: cfg.rainbowEffect ?? defaults.rainbowEffect ?? false

  spacing: Style.marginL

  // ─── Widget Settings ───
  ColumnLayout {
    spacing: Style.marginM
    Layout.fillWidth: true

    NText {
      text: "Widget"
      pointSize: Style.fontSizeL
      font.weight: Font.Medium
      color: Color.mOnSurface
    }

    NValueSlider {
      Layout.fillWidth: true
      label: "Poll interval (seconds)"
      description: "How often to check battery level"
      text: root.pollInterval + "s"
      from: 30
      to: 300
      stepSize: 10
      value: root.pollInterval
      onMoved: root.pollInterval = value
    }

    NTextInput {
      Layout.fillWidth: true
      label: "rivalcfg path"
      description: "Path to the rivalcfg binary"
      text: root.rivalcfgPath
      onTextChanged: root.rivalcfgPath = text
    }
  }

  // ─── Performance Settings ───
  ColumnLayout {
    spacing: Style.marginM
    Layout.fillWidth: true

    NText {
      text: "Performance"
      pointSize: Style.fontSizeL
      font.weight: Font.Medium
      color: Color.mOnSurface
    }

    NComboBox {
      label: "DPI Preset"
      description: "Sensitivity presets the DPI button cycles through"

      model: [
        { "key": "400, 800, 1200, 2400, 3200", "name": "Default (400/800/1200/2400/3200)" },
        { "key": "400, 800, 1600", "name": "Low (400/800/1600)" },
        { "key": "800, 1600, 3200", "name": "Medium (800/1600/3200)" },
        { "key": "1600, 3200, 6400", "name": "High (1600/3200/6400)" },
        { "key": "800, 1200, 1600, 2400, 3200", "name": "Fine (800/1200/1600/2400/3200)" }
      ]

      currentKey: root.sensitivity
      onSelected: key => root.sensitivity = key
    }

    NComboBox {
      label: "Fixed DPI"
      description: "Lock to a single DPI (DPI button does nothing)"

      model: [
        { "key": "", "name": "Disabled (use preset above)" },
        { "key": "400", "name": "400 DPI" },
        { "key": "800", "name": "800 DPI" },
        { "key": "1200", "name": "1200 DPI" },
        { "key": "1600", "name": "1600 DPI" },
        { "key": "2400", "name": "2400 DPI" },
        { "key": "3200", "name": "3200 DPI" },
        { "key": "6400", "name": "6400 DPI" }
      ]

      currentKey: root.fixedDpi
      onSelected: key => root.fixedDpi = key
    }

    NComboBox {
      label: "Polling rate"
      description: "USB polling rate in Hz"

      model: [
        { "key": "125", "name": "125 Hz" },
        { "key": "250", "name": "250 Hz" },
        { "key": "500", "name": "500 Hz" },
        { "key": "1000", "name": "1000 Hz" }
      ]

      currentKey: root.pollingRate
      onSelected: key => root.pollingRate = key
    }
  }

  // ─── Power Settings ───
  ColumnLayout {
    spacing: Style.marginM
    Layout.fillWidth: true

    NText {
      text: "Power"
      pointSize: Style.fontSizeL
      font.weight: Font.Medium
      color: Color.mOnSurface
    }

    NValueSlider {
      Layout.fillWidth: true
      label: "Sleep timer (minutes)"
      description: "Idle time before mouse sleeps (0 = disable)"
      text: root.sleepTimer === 0 ? "Off" : root.sleepTimer + "m"
      from: 0
      to: 20
      stepSize: 1
      value: root.sleepTimer
      onMoved: root.sleepTimer = value
    }

    NValueSlider {
      Layout.fillWidth: true
      label: "Dim timer (seconds)"
      description: "Idle time before LEDs dim (0 = disable)"
      text: root.dimTimer === 0 ? "Off" : root.dimTimer + "s"
      from: 0
      to: 1200
      stepSize: 10
      value: root.dimTimer
      onMoved: root.dimTimer = value
    }
  }

  // ─── Lighting Settings ───
  ColumnLayout {
    spacing: Style.marginM
    Layout.fillWidth: true

    NText {
      text: "Lighting"
      pointSize: Style.fontSizeL
      font.weight: Font.Medium
      color: Color.mOnSurface
    }

    NTextInput {
      Layout.fillWidth: true
      label: "Top LED color"
      description: "Color name or hex (e.g. red, #ff0000). Leave empty to skip."
      placeholderText: "red"
      text: root.topColor
      onTextChanged: root.topColor = text
    }

    NTextInput {
      Layout.fillWidth: true
      label: "Middle LED color"
      description: "Color name or hex (e.g. lime, #00ff00). Leave empty to skip."
      placeholderText: "lime"
      text: root.middleColor
      onTextChanged: root.middleColor = text
    }

    NTextInput {
      Layout.fillWidth: true
      label: "Bottom LED color"
      description: "Color name or hex (e.g. blue, #0000ff). Leave empty to skip."
      placeholderText: "blue"
      text: root.bottomColor
      onTextChanged: root.bottomColor = text
    }

    NTextInput {
      Layout.fillWidth: true
      label: "Reactive color"
      description: "LED color on button click (color name/hex, or 'off' to disable)"
      placeholderText: "off"
      text: root.reactiveColor
      onTextChanged: root.reactiveColor = text
    }

    NComboBox {
      label: "Default lighting"
      description: "LED mode at mouse startup"

      model: [
        { "key": "off", "name": "Off" },
        { "key": "reactive", "name": "Reactive" },
        { "key": "rainbow", "name": "Rainbow" },
        { "key": "reactive-rainbow", "name": "Reactive Rainbow" }
      ]

      currentKey: root.defaultLighting
      onSelected: key => root.defaultLighting = key
    }

    NToggle {
      label: "Rainbow effect"
      description: "Enable rainbow LED effect (overrides individual colors)"
      checked: root.rainbowEffect
      onToggled: checked => root.rainbowEffect = checked
    }
  }

  function saveSettings() {
    if (!pluginApi) return;

    pluginApi.pluginSettings.pollInterval = root.pollInterval;
    pluginApi.pluginSettings.rivalcfgPath = root.rivalcfgPath;
    pluginApi.pluginSettings.fixedDpi = root.fixedDpi;
    pluginApi.pluginSettings.sensitivity = root.sensitivity;
    pluginApi.pluginSettings.pollingRate = root.pollingRate;
    pluginApi.pluginSettings.sleepTimer = root.sleepTimer;
    pluginApi.pluginSettings.dimTimer = root.dimTimer;
    pluginApi.pluginSettings.topColor = root.topColor;
    pluginApi.pluginSettings.middleColor = root.middleColor;
    pluginApi.pluginSettings.bottomColor = root.bottomColor;
    pluginApi.pluginSettings.reactiveColor = root.reactiveColor;
    pluginApi.pluginSettings.defaultLighting = root.defaultLighting;
    pluginApi.pluginSettings.rainbowEffect = root.rainbowEffect;

    pluginApi.saveSettings();

    if (pluginApi.mainInstance) {
      pluginApi.mainInstance.applyMouseSettings();
    }
  }
}
