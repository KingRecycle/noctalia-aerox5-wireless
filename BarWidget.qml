import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""

  readonly property string screenName: screen ? screen.name : ""
  readonly property string barPosition: Settings.getBarPositionForScreen(screenName)
  readonly property bool isVertical: barPosition === "left" || barPosition === "right"
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)

  readonly property var mainInstance: pluginApi?.mainInstance
  readonly property int batteryLevel: mainInstance ? mainInstance.batteryLevel : -1
  readonly property string chargeStatus: mainInstance ? mainInstance.chargeStatus : ""
  readonly property bool hasError: mainInstance ? mainInstance.hasError : true

  readonly property bool isCharging: chargeStatus === "Charging"

  readonly property color levelColor: {
    if (hasError || batteryLevel < 0) return Color.mOnSurfaceVariant;
    if (isCharging) return Color.mPrimary;
    if (batteryLevel <= 20) return Color.mError;
    if (batteryLevel <= 50) return Color.mWarning;
    return Color.mSuccess;
  }

  readonly property string widgetIcon: "mouse"

  readonly property string displayText: {
    if (hasError || batteryLevel < 0) return "?";
    return batteryLevel + "%";
  }

  readonly property real contentWidth: isVertical ? capsuleHeight : Math.round(layout.implicitWidth + Style.marginM * 2)
  readonly property real contentHeight: isVertical ? Math.round(layout.implicitHeight + Style.marginM * 2) : capsuleHeight

  implicitWidth: contentWidth
  implicitHeight: contentHeight

  Rectangle {
    id: visualCapsule
    x: Style.pixelAlignCenter(parent.width, width)
    y: Style.pixelAlignCenter(parent.height, height)
    width: root.contentWidth
    height: root.contentHeight
    radius: Style.radiusM
    color: mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    RowLayout {
      id: layout
      anchors.centerIn: parent
      spacing: Style.marginXS

      NIcon {
        icon: root.widgetIcon
        color: root.levelColor
      }

      NText {
        text: root.displayText
        color: root.levelColor
        pointSize: root.barFontSize
      }
    }
  }

  NPopupContextMenu {
    id: contextMenu

    model: [
      {
        "label": "Settings",
        "action": "settings",
        "icon": "settings"
      }
    ]

    onTriggered: function (action) {
      contextMenu.close();
      PanelService.closeContextMenu(screen);
      if (action === "settings") {
        BarService.openPluginSettings(root.screen, pluginApi.manifest);
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    acceptedButtons: Qt.RightButton | Qt.LeftButton
    hoverEnabled: true

    onClicked: function (mouse) {
      if (mouse.button === Qt.RightButton) {
        PanelService.showContextMenu(contextMenu, root, screen);
      }
    }

    onEntered: {
      var tooltip = "Aerox 5 Wireless";
      if (!root.hasError && root.batteryLevel >= 0) {
        tooltip += " — " + root.chargeStatus + " " + root.batteryLevel + "%";
      } else {
        tooltip += " — Battery unknown";
      }
      TooltipService.show(root, tooltip, BarService.getTooltipDirection());
    }
    onExited: TooltipService.hide()
  }
}
