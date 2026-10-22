/**
   LabelAndSwitch

   A word-wrapping label paired with a switch

   Usage:

     LabelAndSwitch {
       id: deletePreviousCheckbox
       text: i18n.tr("My text")
       checked: false
       onToggled: console.log("checked:", checked)
     }

**/

import QtQuick 2.12
import Lomiri.Components 1.3

Item {
    id: root

    // Public API
    property alias text: label.text
    property alias checked: toggle.checked
    property alias switchEnabled: toggle.enabled
    signal toggled(bool checked)

    implicitWidth: parent ? parent.width : units.gu(40)
    implicitHeight: Math.max(label.implicitHeight, toggle.implicitHeight)

    Label {
        id: label
        anchors {
            left: parent.left
            right: toggle.left
            rightMargin: units.gu(1.5)
            verticalCenter: parent.verticalCenter
        }
        wrapMode: Text.WordWrap

        MouseArea {
            anchors.fill: parent
            enabled: toggle.enabled
            onClicked: toggle.checked = !toggle.checked
        }
    }

    Switch {
        id: toggle
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }
        onCheckedChanged: root.toggled(checked)
    }
}
