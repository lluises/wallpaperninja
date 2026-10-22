import QtQuick 2.12
import QtQuick.Layouts 1.3
import Lomiri.Components 1.3

Item {
  id: root

  // Public interface
  property string icon: "folder-symbolic"
  property string title: ""
  property bool showSwitch: false
  property alias checked: entrySwitch.checked

  // Emitted only when the user toggles the switch (not when set from code)
  signal toggled(bool checked)

  implicitWidth: parent ? parent.width : units.gu(20)
  implicitHeight: Math.max(units.gu(3), titleLabel.implicitHeight,
                           entrySwitch.visible ? entrySwitch.implicitHeight : 0)

  MouseArea {
    anchors.fill: parent
    enabled: root.showSwitch && entrySwitch.enabled
    onClicked: {
      entrySwitch.checked = !entrySwitch.checked
      root.toggled(entrySwitch.checked)
    }
  }

  RowLayout {
    anchors.fill: parent
    spacing: units.gu(1)

    Icon {
      Layout.preferredWidth: units.gu(3)
      Layout.preferredHeight: units.gu(3)
      Layout.alignment: Qt.AlignVCenter
      name: root.icon
    }

    Label {
      id: titleLabel
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      text: root.title
      wrapMode: Text.WordWrap
      font.bold: true
    }

    Switch {
      id: entrySwitch
      Layout.alignment: Qt.AlignVCenter
      visible: root.showSwitch
      onClicked: root.toggled(checked)
    }
  }
}
