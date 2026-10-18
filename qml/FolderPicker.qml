import QtQuick 2.12
import Qt.labs.folderlistmodel 2.12
import Lomiri.Components 1.3

Page {
  id: picker

  // Where browsing starts (only used the first time; it then remembers the last location)
  property url startFolder: "file:///home/phablet"
  property string title: i18n.tr("Select folder")

  // Emitted with a plain path, e.g. "/home/phablet/Documents"
  signal folderSelected(string path)
  signal canceled()

  // Jump to a given folder path; falls back to startFolder if empty
  function openAt(path) {
    if (path && path !== "")
      folderModel.folder = "file://" + encodeURI(path)
    else
      folderModel.folder = startFolder
  }

  function urlToPath(url) {
    return decodeURIComponent(url.toString().replace(/^file:\/\//, ""))
  }

  header: PageHeader {
    id: pickerHeader
    title: picker.title
    leadingActionBar.actions: Action {
      iconName: "close"
      text: i18n.tr("Cancel")
      onTriggered: picker.canceled()
    }
  }

  FolderListModel {
    id: folderModel
    folder: picker.startFolder
    showFiles: false
    showDirs: true
    showDotAndDotDot: false
    sortField: FolderListModel.Name
  }

  Row {
    id: pathBar
    anchors {
      top: pickerHeader.bottom
      left: parent.left
      right: parent.right
      margins: units.gu(1)
    }
    spacing: units.gu(1)

    Button {
      id: upButton
      width: units.gu(6)
      iconName: "go-up"
      onClicked: {
        if (folderModel.parentFolder.toString() !== "")
          folderModel.folder = folderModel.parentFolder
      }
    }
    Label {
      width: parent.width - upButton.width - parent.spacing
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideLeft
      text: picker.urlToPath(folderModel.folder)
    }
  }

  ListView {
    id: listView
    anchors {
      top: pathBar.bottom
      left: parent.left
      right: parent.right
      bottom: selectButton.top
      topMargin: units.gu(1)
      bottomMargin: units.gu(1)
    }
    clip: true
    model: folderModel

    delegate: ListItem {
      id: item

      // Role values as typed properties; fall back to "" so nothing is ever undefined
      readonly property string name: model.fileName !== undefined ? model.fileName : ""
      readonly property string path: model.filePath !== undefined ? model.filePath : ""

      height: layout.height + (divider.visible ? divider.height : 0)
      onClicked: folderModel.folder = "file://" + item.path

      ListItemLayout {
        id: layout
        title.text: item.name

        Icon {
          name: "folder"
          width: units.gu(3)
          height: width
          SlotsLayout.position: SlotsLayout.Leading
        }

        Icon {
          name: "go-next"
          width: units.gu(2)
          height: width
          SlotsLayout.position: SlotsLayout.Trailing
        }
      }
    }
  }

  // Sibling of the ListView, not a child (children of a Flickable get reparented)
  Label {
    anchors.centerIn: listView
    visible: listView.count === 0
    text: i18n.tr("No subfolders")
  }

  Button {
    id: selectButton
    anchors {
      left: parent.left
      right: parent.right
      bottom: parent.bottom
      margins: units.gu(2)
    }
    color: theme.palette.normal.positive
    text: i18n.tr("Select this folder")
    onClicked: picker.folderSelected(picker.urlToPath(folderModel.folder))
  }
}
