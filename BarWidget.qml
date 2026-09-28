import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui

BarWidget {
  id: root

  moduleName: "hajimetchi.files.stl"

  readonly property bool opened: panelLoader.item
    ? panelLoader.item.opened === true
    : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true
    : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.settings = root.settings
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  function updatePluginSetting(name, value) {
    var next = { id: root.moduleName }
    for (var key in root.settings) if (key !== "id") next[key] = root.settings[key]
    next[name] = value
    root.settings = next
    if (panelLoader.item) panelLoader.item.settings = next
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, next)
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: icon.status === Image.Ready ? "" : ".stl"
    labelVisible: icon.status !== Image.Ready
    hasVisualContent: true
    fixedWidth: Style.space(30)
    tooltipText: "Manage .stl previews"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }

    Image {
      id: icon
      anchors.centerIn: parent
      width: Style.space(20)
      height: width
      source: Qt.resolvedUrl("icons/isometric-grid.svg")
      sourceSize: Qt.size(64, 64)
      layer.enabled: true
      layer.effect: MultiEffect {
        colorization: 1
        colorizationColor: button.foreground
      }
    }
  }
}
