import QtQuick
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  property string label: ""
  property string detail: ""
  property bool actionEnabled: true
  property bool completed: false
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  signal clicked()
  signal linkActivated(string link)

  readonly property var normalBorder: Border.controlSpec("normal", root.foreground, Color.accent)
  readonly property var hoverBorder: Border.controlSpec("hover-cursor", root.foreground, Color.accent)
  readonly property real reservedBorderTop: Math.max(Border.top(normalBorder), Border.top(hoverBorder))
  readonly property real reservedBorderBottom: Math.max(Border.bottom(normalBorder), Border.bottom(hoverBorder))
  readonly property real reservedBorderLeft: Math.max(Border.left(normalBorder), Border.left(hoverBorder))
  readonly property real reservedBorderRight: Math.max(Border.right(normalBorder), Border.right(hoverBorder))
  implicitHeight: buttonContent.implicitHeight + topPadding + bottomPadding + reservedBorderTop + reservedBorderBottom
  height: implicitHeight
  radius: Style.cornerRadius
  leftPadding: Style.spacing.controlPaddingX
  rightPadding: Style.spacing.controlPaddingX
  topPadding: Style.spacing.controlPaddingY + Style.space(2)
  bottomPadding: Style.spacing.controlPaddingY + Style.space(2)
  opacity: root.actionEnabled ? 1 : 0.55
  color: root.actionEnabled && hoverTracker.containsMouse
    ? Style.hoverFillFor(root.foreground, Color.accent)
    : "transparent"
  borderSpec: root.actionEnabled && hoverTracker.containsMouse
    ? Border.controlSpec("hover-cursor", root.foreground, Color.accent)
    : Border.controlSpec("normal", root.foreground, Color.accent)

  MouseArea {
    id: pointer
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.actionEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    enabled: root.actionEnabled
    onClicked: if (root.actionEnabled) root.clicked()
  }

  Column {
    id: buttonContent
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: parent.leftPadding + parent.reservedBorderLeft
    anchors.rightMargin: parent.rightPadding + parent.reservedBorderRight
    spacing: Style.spacing.controlGap

    Text {
      width: parent.width
      text: root.label + (root.completed ? "  ✓" : "")
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      wrapMode: Text.WordWrap
    }

    Text {
      id: detailText
      width: parent.width
      text: root.detail
      textFormat: Text.RichText
      color: root.foreground
      opacity: 0.6
      linkColor: Qt.darker(root.foreground, 1.25)
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      wrapMode: Text.WordWrap
      onLinkActivated: function(link) { root.linkActivated(link) }
    }
  }

  // Track hover above the text so hovering text highlights the whole button.
  // Accept no buttons here, leaving clicks and RichText links to their targets.
  MouseArea {
    id: hoverTracker
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    hoverEnabled: true
    cursorShape: {
      if (root.actionEnabled) return Qt.PointingHandCursor
      var point = hoverTracker.mapToItem(detailText, mouseX, mouseY)
      return detailText.linkAt(point.x, point.y) !== ""
        ? Qt.PointingHandCursor
        : Qt.ArrowCursor
    }
  }

}
