import QtQuick 2.12
import Lomiri.Components 1.3
import Lomiri.Components.ListItems 1.3

Item {
  id: root

  // Public interface (ContentBox)
  property alias showDivider: topDivider.visible

  // Public interface (forwarded to the inner EntryTitle)
  property alias icon: entryTitle.icon
  property alias title: entryTitle.title
  property alias showSwitch: entryTitle.showSwitch
  property alias checked: entryTitle.checked

  default property alias content: contentColumn.data

  signal toggled(bool checked)

  implicitWidth: parent ? parent.width : units.gu(20)
  implicitHeight: outerColumn.height

  data: [
    Column {
      id: outerColumn
      width: parent.width
      anchors.left: parent.left
      anchors.right: parent.right

      ThinDivider {
        visible: true
        id: topDivider
        width: parent.width
      }

      Item {
        width: parent.width
        height: entryTitle.height + units.gu(2)

        EntryTitle {
          id: entryTitle
          anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: units.gu(2)
          }
          onToggled: root.toggled(checked)
        }
      }

      Item {
        id: contentWrapper
        width: parent.width
        height: contentColumn.height + units.gu(3) // top padding

        Column {
          id: contentColumn
          x: units.gu(2) // left padding
          y: units.gu(3) // top padding
          width: parent.width - x*2 // left + right padding
          spacing: units.gu(3)
        }
      }
    }
  ]
}
