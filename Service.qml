import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import "Model.js" as Model

Item {
  id: root
  property var shell: null
  property var manifest: null
  property bool resetPending: false
  readonly property int conserveEnd: Model.conserveEndFromSettings(
    Model.settingsFromConfig(shell ? shell.shellConfig : null, "io.github.k7cfo.charge-100-percent"))
  readonly property string ctl: Model.pluginFilePath(Qt.resolvedUrl("scripts/charge-ctl"))
  readonly property string runner: Model.pluginFilePath(Qt.resolvedUrl("scripts/bounded-run"))

  function applyPolicy(reset) {
    resetPending = resetPending || reset
    if (policy.running) return
    policy.command = [runner, ctl, resetPending ? "conserve" : "tick"]
    resetPending = false
    policy.running = true
  }

  Process {
    id: policy
    environment: ({ CHARGE_CONSERVE_END: String(root.conserveEnd) })
    stderr: StdioCollector {
      onStreamFinished: if (text.trim()) console.warn("Charge Limit:", text.trim())
    }
    onExited: {
      if (root.resetPending) Qt.callLater(function() { root.applyPolicy(true) })
    }
  }

  Connections {
    target: UPower
    function onOnBatteryChanged() { root.applyPolicy(UPower.onBattery) }
  }

  Timer {
    interval: 15000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.applyPolicy(false)
  }
}
