import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root

  moduleName: "io.github.hajimetchi.stl-preview"
  ipcTarget: "io.github.hajimetchi.stl-preview"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property color contentForeground: root.barForeground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function closeForPopoutSwitch() {
    root.close()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function launchScript(scriptName) {
    var scriptUrl = Qt.resolvedUrl(scriptName).toString()
    if (!scriptUrl.startsWith("file://")) {
      console.error("STL Preview script is not a local file:", scriptUrl)
      return
    }
    var scriptPath = decodeURIComponent(scriptUrl.replace(/^file:\/\//, ""))
    var command = "script_dir=$(dirname -- \"$1\")\n"
      + "cd -- \"$script_dir\" || exit 1\n"
      + "./\"$(basename -- \"$1\")\"\n"
      + "result=$?\n"
      + "echo\n"
      + "if [ $result -eq 0 ]; then echo 'Finished successfully.'; else echo 'The command failed.'; fi\n"
      + "read -r -p 'Press Enter to close this terminal...'"

    Quickshell.execDetached([
      "omarchy-launch-terminal",
      "bash", "-lc", command,
      "stl-preview", scriptPath
    ])
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        Text {
          text: "STL Preview"
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        Text {
          width: parent.width
          text: "Add transparent STL model thumbnails to GNOME Files. The renderer uses Python's standard library; no pip packages or network access are needed."
          color: root.contentForeground
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.body
          wrapMode: Text.WordWrap
        }

        ActionButton {
          width: parent.width
          label: "Install STL previews"
          detail: "Opens a terminal; sudo will ask for your password."
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onClicked: root.launchScript("install.sh")
        }

        ActionButton {
          width: parent.width
          label: "Remove STL previews"
          detail: "Removes this integration from the system and your account."
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onClicked: root.launchScript("uninstall.sh")
        }

        Text {
          width: parent.width
          text: "The scripts run only when you choose an action. Review install.sh and uninstall.sh in this plugin before running them."
          color: Qt.darker(root.contentForeground, 1.25)
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
