import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import qs.Commons as Commons
import qs.Ui as Ui
import "Model.js" as Model

Ui.BarWidget {
  id: root
  moduleName: "io.github.k7cfo.charge-100-percent"
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  property var status: Model.parseStatus("")
  property bool known: false
  property string error: ""
  property bool refreshPending: false
  readonly property int conserveEnd: Model.conserveEndFromSettings(settings)
  readonly property bool full: known && status.end === 100
  readonly property bool fullActive: known && !UPower.onBattery && Model.fullActive(status)
  readonly property bool conserved: known && status.end === conserveEnd
  readonly property bool opened: panel.open
  readonly property bool popoutSwitchClosing: panel.popoutSwitchClosing
  readonly property string ctl: Model.pluginFilePath(Qt.resolvedUrl("scripts/charge-ctl"))
  readonly property string runner: Model.pluginFilePath(Qt.resolvedUrl("scripts/bounded-run"))
  readonly property int capacity: Model.packPercent(
    UPower.displayDevice && UPower.displayDevice.isPresent ? UPower.displayDevice.percentage : undefined,
    status.capacity)
  readonly property string message: !known ? strings.t("unavailable")
    : !status.supported ? strings.t("unsupported")
    : !status.ac && full ? strings.t("resetFailed")
    : UPower.onBattery || !status.ac ? strings.t("plugIn")
    : fullActive ? (status.chargeState === "Charging" ? strings.t("chargingStatus") : strings.t("fullStatus"))
    : full ? strings.t("notCharging")
    : strings.t("capStatus").arg(Commons.I18n.formatNumber(status.end))

  Commons.Translations { id: strings; directory: Qt.resolvedUrl("i18n") }

  function refresh() {
    if (action.running) return
    if (statusProc.running) { refreshPending = true; return }
    refreshPending = false
    statusProc.running = true
  }
  function open() { panel.open = true; refresh() }
  function close() { panel.open = false }
  function toggle() { if (panel.open) close(); else open() }
  function closeForPopoutSwitch() {
    panel.popoutSwitchClosing = true
    close()
  }
  function choose(mode) {
    if (action.running || !known || !status.supported) return
    if (mode === "full" && (!status.ac || UPower.onBattery)) return
    error = ""
    action.command = [runner, ctl, mode]
    action.running = true
  }

  Process {
    id: statusProc
    command: [root.runner, root.ctl, "status", "--json"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.status = Model.parseStatus(text)
        root.known = root.status.error !== "invalid-json" && text.trim() !== ""
      }
    }
    onExited: function(code) {
      if (code !== 0) root.known = false
      if (root.refreshPending) Qt.callLater(root.refresh)
    }
  }
  Process {
    id: action
    environment: ({ CHARGE_CONSERVE_END: String(root.conserveEnd) })
    onExited: function(code) {
      root.error = code === 0 ? "" : strings.t("changeFailed")
      root.known = false
      Qt.callLater(function() { root.broadcast("refresh") })
    }
  }
  Timer {
    interval: panel.open ? 1000 : 15000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
  Connections {
    target: UPower
    function onOnBatteryChanged() { root.refresh() }
  }
  Connections {
    target: UPower.displayDevice
    function onStateChanged() { root.refresh() }
  }

  Ui.WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    fixedWidth: bar && bar.vertical ? bar.barSize : Commons.Style.space(46)
    tooltipText: Model.plain(strings.t("tooltip").arg(root.capacity).arg(root.message), 240)
    onPressed: function(mouseButton) { if (mouseButton === Qt.LeftButton) root.toggle() }

    Row {
      anchors.centerIn: parent
      spacing: Commons.Style.space(4)
      scale: button.pressScale
      Item {
        width: Commons.Style.space(21)
        height: Commons.Style.space(13)
        Rectangle {
          width: Commons.Style.space(18)
          height: parent.height
          radius: Commons.Style.space(2)
          color: "transparent"
          border.width: Commons.Style.space(1)
          border.color: button.foreground
          Rectangle {
            x: Commons.Style.space(3)
            y: Commons.Style.space(3)
            width: Math.round(Commons.Style.space(12) * root.capacity / 100)
            height: parent.height - Commons.Style.space(6)
            color: button.foreground
          }
        }
        Rectangle {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          width: Commons.Style.space(2)
          height: Commons.Style.space(5)
          color: button.foreground
        }
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: root.fullActive ? "↑" : root.conserved ? "↓" : "?"
        color: button.foreground
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.body
        font.bold: true
      }
    }
  }

  Ui.KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    focusTarget: choices
    contentWidth: fittedContentWidth(Commons.Style.space(330))
    contentHeight: fittedContentHeight(choices.implicitHeight)

    Column {
      id: choices
      width: parent.width
      spacing: Commons.Style.space(10)
      Keys.onEscapePressed: root.close()
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_1) { root.choose("full"); event.accepted = true }
        if (event.key === Qt.Key_2) { root.choose("conserve"); event.accepted = true }
      }
      Text {
        textFormat: Text.PlainText
        text: strings.t("title")
        color: Commons.Color.popups.text
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.title
        font.bold: true
      }
      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: strings.t("battery").arg(Commons.I18n.formatNumber(root.capacity))
        color: Commons.Color.popups.text
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.body
      }
      Ui.Button {
        width: parent.width
        text: Model.plain(strings.t("full"))
        bordered: true
        focusable: true
        enabled: root.known && root.status.supported && root.status.ac && !UPower.onBattery && !action.running
        opacity: enabled ? 1 : 0.45
        onClicked: root.choose("full")
        Rectangle {
          anchors.fill: parent
          visible: root.full
          color: "transparent"
          radius: parent.radius
          border.width: Commons.Style.space(2)
          border.color: Commons.Color.accent
        }
      }
      Ui.Button {
        width: parent.width
        text: Model.plain(strings.t("conserve").arg(Commons.I18n.formatNumber(root.conserveEnd)))
        bordered: true
        focusable: true
        enabled: root.known && root.status.supported && !action.running
        onClicked: root.choose("conserve")
        Rectangle {
          anchors.fill: parent
          visible: root.conserved
          color: "transparent"
          radius: parent.radius
          border.width: Commons.Style.space(2)
          border.color: Commons.Color.accent
        }
      }
      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: action.running ? strings.t("changing") : root.error || root.message
        color: root.error || (!root.status.ac && root.full) ? Commons.Color.urgent : Commons.Color.popups.text
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.body
        wrapMode: Text.Wrap
      }
      Text {
        width: parent.width
        textFormat: Text.PlainText
        text: strings.t("explanation").arg(Commons.I18n.formatNumber(root.conserveEnd))
        color: Commons.Color.popups.text
        opacity: 0.7
        font.family: Commons.Style.font.family
        font.pixelSize: Commons.Style.font.caption
        wrapMode: Text.Wrap
      }
    }
  }
}
