import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root

  moduleName: "hajimetchi.files.stl"
  ipcTarget: "hajimetchi.files.stl"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property bool installationChecked: false
  property bool installationComplete: false
  property bool installationCheckPending: false
  property string installationDate: ""
  property string thumbnailCount: "0"
  readonly property var inputSizeOptions: [8, 16, 32, 64, 128]
  readonly property int maxInputSizeIndex: {
    var saved = Number(root.setting("maxInputMiB", 16))
    var index = root.inputSizeOptions.indexOf(saved)
    return index < 0 ? 1 : index
  }
  property int headerStatusIndex: 0
  readonly property var headerStatuses: [
    "Searching for models",
    "Parsing 3D models",
    "Projecting polygon meshes",
    "Counting generated previews"
  ]
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

  function checkInstallation() {
    if (installationStatus.running) return
    root.installationCheckPending = true
    installationStatus.running = true
    installationCheckTimeout.restart()
  }

  function setInstallationStatus(installed) {
    installationComplete = installed
    installationChecked = true
    installationCheckPending = false
    installationCheckTimeout.stop()
  }

  function checkThumbnailCount() {
    if (!thumbnailCounter.running) thumbnailCounter.running = true
  }

  function formatThumbnailCount(value) {
    return String(Math.floor(value)).replace(/\B(?=(\d{3})+(?!\d))/g, ",")
  }

  function setMaxInputSizeIndex(index) {
    var bounded = Math.max(0, Math.min(root.inputSizeOptions.length - 1, Math.round(index)))
    var mib = root.inputSizeOptions[bounded]
    if (root.barIdentity && typeof root.barIdentity.updatePluginSetting === "function")
      root.barIdentity.updatePluginSetting("maxInputMiB", mib)
    if (!root.installationComplete) return
    fileCapProcess.command = ["python3", root.localScriptPath("set-file-cap.py"), String(mib)]
    fileCapUpdateTimer.restart()
  }

  function openLinkedFile(url) {
    if (url.toString().startsWith("file://")) Qt.openUrlExternally(url)
  }

  function htmlColor(color) {
    function hexByte(value) {
      var hex = Math.round(value * 255).toString(16)
      return hex.length === 1 ? "0" + hex : hex
    }
    return "#" + hexByte(color.r) + hexByte(color.g) + hexByte(color.b)
  }

  function localScriptPath(scriptName) {
    var scriptUrl = Qt.resolvedUrl(scriptName).toString()
    if (!scriptUrl.startsWith("file://")) return ""
    return decodeURIComponent(scriptUrl.replace(/^file:\/\//, ""))
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

  Component.onCompleted: {
    checkInstallation()
    checkThumbnailCount()
  }

  Process {
    id: installationStatus
    command: ["bash", root.localScriptPath("status.sh")]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var result = text.trim().split("|")
        root.installationDate = result.length > 1 ? result[1] : ""
        root.setInstallationStatus(result[0] === "installed")
      }
    }
    onExited: function(exitCode) {
      if (root.installationCheckPending)
        root.setInstallationStatus(exitCode === 0)
    }
  }

  Timer {
    id: headerPhraseTimer
    interval: 2800
    running: root.opened
    repeat: true
    triggeredOnStart: false
    onTriggered: headerPhraseSwap.restart()
  }

  SequentialAnimation {
    id: headerPhraseSwap
    PropertyAnimation {
      target: headerStatusText
      property: "opacity"
      to: 0.0
      duration: 180
      easing.type: Easing.OutQuad
    }
    ScriptAction {
      script: root.headerStatusIndex = (root.headerStatusIndex + 1) % root.headerStatuses.length
    }
    PropertyAnimation {
      target: headerStatusText
      property: "opacity"
      to: 1.0
      duration: 260
      easing.type: Easing.InQuad
    }
  }

  onOpenedChanged: {
    if (!opened) {
      headerPhraseSwap.stop()
      headerStatusText.opacity = 1.0
    }
  }

  Timer {
    id: installationCheckTimeout
    interval: 5000
    onTriggered: {
      if (!root.installationCheckPending) return
      root.setInstallationStatus(false)
      installationStatus.running = false
    }
  }

  Process {
    id: thumbnailCounter
    command: ["python3", root.localScriptPath("thumbnail-counter.py"), "--read"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var value = Number(text.trim())
        if (!isNaN(value) && value >= 0)
          root.thumbnailCount = root.formatThumbnailCount(value)
      }
    }
  }

  Process {
    command: ["python3", root.localScriptPath("thumbnail-counter.py"), "--watch"]
    running: root.installationComplete
  }

  Timer {
    interval: 2000
    repeat: true
    running: root.opened
    onRunningChanged: if (running) {
      root.checkInstallation()
      root.checkThumbnailCount()
    }
    onTriggered: {
      root.checkInstallation()
      root.checkThumbnailCount()
    }
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
        spacing: Style.space(14)

        Item {
          id: menuHeader
          width: parent.width
          implicitHeight: Math.max(menuIcon.height, headerLabels.implicitHeight, countLabel.implicitHeight)

          Image {
            id: menuIcon
            width: Style.font.display
            height: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            source: Qt.resolvedUrl("icons/preview-grid.svg")
            sourceSize: Qt.size(64, 64)
            layer.enabled: true
            layer.effect: MultiEffect {
              colorization: 1
              colorizationColor: root.contentForeground
            }
          }

          Column {
            id: headerLabels
            anchors.left: menuIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: countLabel.left
            anchors.rightMargin: Style.space(10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              width: parent.width
              text: "Thumbnails generated:"
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              id: headerStatusText
              width: parent.width
              textFormat: Text.PlainText
              text: root.headerStatuses[root.headerStatusIndex].toUpperCase()
              color: Qt.darker(root.contentForeground, 1.4)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
            }
          }

          Text {
            id: countLabel
            text: root.thumbnailCount
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.displayLarge
            font.bold: true
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        PanelSeparator {
          width: parent.width
          foreground: root.contentForeground
        }

        PanelSectionHeader {
          text: "PREVIEW FOR .STL FILES"
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
        }

        Text {
          width: parent.width
          text: "Add transparent .stl model thumbnails to GNOME Files. The renderer uses Python's standard library; no pip packages or network access are needed."
          color: root.contentForeground
          opacity: 0.6
          font.family: root.contentFontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        ActionButton {
          width: parent.width
          label: "INSTALL .STL PREVIEWS"
          detail: (root.installationComplete
            ? "Installed on " + (root.installationDate || "an earlier date") + ". "
            : !root.installationChecked
              ? "Checking installation status… "
              : "Opens a terminal; sudo will ask for your password. ")
            + "Review <a href=\"" + Qt.resolvedUrl("install.sh") + "\" style=\"color:"
            + root.htmlColor(Qt.darker(root.contentForeground, 1.25))
            + "; text-decoration: underline;\">install.sh</a>."
          actionEnabled: root.installationChecked && !root.installationComplete
          completed: root.installationComplete
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onClicked: root.launchScript("install.sh")
          onLinkActivated: function(link) { root.openLinkedFile(link) }
        }

        ActionButton {
          width: parent.width
          label: "REMOVE .STL PREVIEWS"
          detail: "Removes this integration and asks whether to delete its thumbnail statistics. Review <a href=\""
            + Qt.resolvedUrl("uninstall.sh") + "\" style=\"color:"
            + root.htmlColor(Qt.darker(root.contentForeground, 1.25))
            + "; text-decoration: underline;\">uninstall.sh</a>."
          foreground: root.contentForeground
          fontFamily: root.contentFontFamily
          onClicked: root.launchScript("uninstall.sh")
          onLinkActivated: function(link) { root.openLinkedFile(link) }
        }

        PanelSeparator {
          width: parent.width
          foreground: root.contentForeground
        }

        Column {
          width: parent.width
          spacing: Style.space(6)

          Item {
            width: parent.width
            implicitHeight: Math.max(fileCapHeader.implicitHeight, fileCapValue.implicitHeight)

            PanelSectionHeader {
              id: fileCapHeader
              text: "MAXIMUM .STL FILE SIZE"
              foreground: root.contentForeground
              fontFamily: root.contentFontFamily
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: fileCapValue
              text: root.inputSizeOptions[root.maxInputSizeIndex] + " MiB"
              color: Qt.darker(root.contentForeground, 1.4)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              anchors.right: parent.right
              anchors.rightMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Text {
            width: parent.width
            text: "Skip larger files to limit memory use. Restart Files to apply changes."
            color: root.contentForeground
            opacity: 0.6
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          CursorSurface {
            width: parent.width
            height: fileCapSlider.implicitHeight + Style.spacing.controlGap
            foreground: root.contentForeground
            outline: true

            PanelSlider {
              id: fileCapSlider
              bar: root.bar
              anchors.fill: parent
              anchors.leftMargin: Style.space(6)
              anchors.rightMargin: Style.space(6)
              minimum: 0
              maximum: root.inputSizeOptions.length - 1
              step: 1
              integer: true
              tickCount: root.inputSizeOptions.length
              value: root.maxInputSizeIndex
              onReleased: function(v) { root.setMaxInputSizeIndex(v) }
            }
          }
        }
      }
    }
  }

  Process {
    id: fileCapProcess
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (text.trim().length) console.error("STL Preview size limit:", text.trim())
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) console.error("Could not update the STL preview size limit")
      else if (fileCapUpdateTimer.running) fileCapUpdateTimer.restart()
    }
  }

  Timer {
    id: fileCapUpdateTimer
    interval: 200
    onTriggered: {
      if (fileCapProcess.running) restart()
      else fileCapProcess.running = true
    }
  }
}
