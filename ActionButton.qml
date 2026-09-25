import QtQuick
import qs.Commons

Rectangle {
  id: root

  property string label: ""
  property string detail: ""
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family
  signal clicked()

  implicitHeight: buttonContent.implicitHeight + Style.space(20)
  height: implicitHeight
  radius: Style.cornerRadius
  color: pointer.containsMouse
    ? Style.hoverFillFor(root.foreground, Color.accent)
    : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)

  Column {
    id: buttonContent
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    anchors.leftMargin: Style.space(12)
    anchors.rightMargin: Style.space(12)
    spacing: Style.space(2)

    Text {
      width: parent.width
      text: root.label
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      font.bold: true
    }

    Text {
      width: parent.width
      text: root.detail
      color: Qt.darker(root.foreground, 1.25)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      wrapMode: Text.WordWrap
    }
  }

  MouseArea {
    id: pointer
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
