import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root
  property var pluginApi: null

  property int batteryLevel: -1
  property string chargeStatus: ""
  property bool hasError: false

  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  property int pollInterval: cfg.pollInterval ?? defaults.pollInterval ?? 120
  property string rivalcfgPath: cfg.rivalcfgPath ?? defaults.rivalcfgPath ?? "/home/charlie/.local/bin/rivalcfg"

  Timer {
    interval: root.pollInterval * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: pollBattery()
  }

  Process {
    id: batteryProcess
    running: false
    command: [root.rivalcfgPath, "--battery-level"]

    stdout: StdioCollector {
      onStreamFinished: {
        var output = this.text.trim();
        root.parseBatteryOutput(output);
      }
    }

    onExited: (exitCode, exitStatus) => {
      if (exitCode !== 0) {
        root.hasError = true;
      }
    }
  }

  function pollBattery() {
    if (!batteryProcess.running) {
      batteryProcess.running = true;
    }
  }

  function parseBatteryOutput(output) {
    // Output format: "Discharging [========= ] 90 %"
    // or "Charging [========= ] 90 %"
    var match = output.match(/^(\w+)\s+\[.*\]\s+(\d+)\s*%/);
    if (match) {
      root.chargeStatus = match[1];
      root.batteryLevel = parseInt(match[2]);
      root.hasError = false;
    } else {
      root.hasError = true;
    }
  }

  function applyMouseSettings() {
    var cfg = pluginApi?.pluginSettings || ({});
    var defaults = pluginApi?.manifest?.metadata?.defaultSettings || ({});
    var args = [rivalcfgPath];

    var fixedDpi = cfg.fixedDpi ?? "";
    var sensitivity = cfg.sensitivity ?? defaults.sensitivity ?? "";
    if (fixedDpi) {
      args.push("-s");
      args.push(fixedDpi + ", " + fixedDpi + ", " + fixedDpi + ", " + fixedDpi + ", " + fixedDpi);
    } else if (sensitivity) {
      args.push("-s");
      args.push(sensitivity);
    }

    var pollingRate = cfg.pollingRate ?? defaults.pollingRate ?? "";
    if (pollingRate) {
      args.push("-p");
      args.push(pollingRate);
    }

    var sleepTimer = cfg.sleepTimer ?? defaults.sleepTimer;
    if (sleepTimer !== undefined) {
      args.push("-t");
      args.push(sleepTimer.toString());
    }

    var dimTimer = cfg.dimTimer ?? defaults.dimTimer;
    if (dimTimer !== undefined) {
      args.push("-T");
      args.push(dimTimer.toString());
    }

    var topColor = cfg.topColor ?? defaults.topColor ?? "";
    if (topColor) {
      args.push("--top-color");
      args.push(topColor);
    }

    var middleColor = cfg.middleColor ?? defaults.middleColor ?? "";
    if (middleColor) {
      args.push("--middle-color");
      args.push(middleColor);
    }

    var bottomColor = cfg.bottomColor ?? defaults.bottomColor ?? "";
    if (bottomColor) {
      args.push("--bottom-color");
      args.push(bottomColor);
    }

    var reactiveColor = cfg.reactiveColor ?? defaults.reactiveColor ?? "";
    if (reactiveColor) {
      args.push("-a");
      args.push(reactiveColor);
    }

    var defaultLighting = cfg.defaultLighting ?? defaults.defaultLighting ?? "";
    if (defaultLighting) {
      args.push("-d");
      args.push(defaultLighting);
    }

    var rainbowEffect = cfg.rainbowEffect ?? defaults.rainbowEffect ?? false;
    if (rainbowEffect) {
      args.push("-e");
    }

    if (args.length > 1) {
      Quickshell.execDetached(args);
    }
  }
}
