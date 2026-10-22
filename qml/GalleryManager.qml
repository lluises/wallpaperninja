/**
   GalleryManager

   Manage a galleryId photo collection: view, add and delete imagese.
   Generates thumbnails for all photos after the first use.

   Usage:

     Component {
       id: galleryComponent

       GalleryManager {
         galleryId: "main"
         backend: python
         title: i18n.tr("Main wallpapers")
         onClose: on_gallery_close()
       }
     }

**/

import QtQuick 2.12
import Lomiri.Components 1.3
import Lomiri.Content 1.3
import io.thp.pyotherside 1.5
import "components"

Page {
  id: root

  // Public interface
  property string galleryId: ""
  property string thumbnailExtension: ".jpg"
  property string thumbnailFolder: "" // /path/to/folder
  property var alreadyThumbnailed: null // {"file:///path/to/folder": true}
  property var backend: null // the shared Python object from Main.qml
  property bool autoPop: true
  property var selected_images: []

  signal close()

  // Internal state
  property var pictures: []
  property var activeTransfer: null
  property bool picking: false

  function is_selected(path) {
    return (selected_images.indexOf(path) >= 0)
  }

  function path_to_url(path) {
    let p = String(path)
    return p.indexOf("://") === -1 ? "file://" + p : p
  }

  function refresh() {
    root.alreadyThumbnailed = {};

    if (!backend || galleryId === "")
      return

    backend.call("gallery.get_thumbnail_folder", [], function(path) {
      root.thumbnailFolder = path;
      backend.call("gallery.init_imgorder", [galleryId], function(result) {
        backend.call("gallery.list_thumbs_or_pictures", [galleryId], function(result) {
          root.pictures = result || []
        });
      });
    });
  }

  function remove_selected_pictures() {
    if (selected_images.length <= 0 || !backend || galleryId === "")
      return

    const names = selected_images.map((path) => {
      let parts = path.toString().split('/');
      return parts[parts.length-1];
    });

    backend.call("gallery.remove_pictures", [galleryId, names], function(ok) {
      galleryGrid.reset_selection();
      refresh();
    });
  }

  function swap_images(img1, img2) {
    // Never swaps anything: it only logs.
    const name1 = img1.split('/').pop();
    const name2 = img2.split('/').pop();
    backend.call("gallery.swap_order", [galleryId, name1, name2], function(err) {
      if (err && err != "")
        console.log("[PY.ERR] " + err)
      galleryGrid.reset_selection();
      refresh();
    });
  }

  function check_if_thumbnail_needed(image) {
    // image is an Image component
    let source = image.source.toString()

    if (alreadyThumbnailed[source]) {
      return

    } else if (source.indexOf(thumbnailFolder) >= 0) {
      alreadyThumbnailed[source] = true

    } else  {
      alreadyThumbnailed[source] = true;
      capture_thumbnail(image);
    }
  }

  function capture_thumbnail(image) {
    // image is an Image component
    var w = image.sourceSize.width
    var h = image.sourceSize.height

    if (w <= 0 || h <= 0)
      return

    let filename = image.source.toString().split("/").pop().replace(/\.[^.]*$/, "");
    let target = thumbnailFolder + "/" + filename + thumbnailExtension

    image.grabToImage(
      function(result) {
        if (result.saveToFile(target))
          console.log("Generated thumbnail for " + target)
        else
          console.log("Failed to save thumbnail " + target)
      },
      Qt.size(image.width, image.height)
    );
  }

  onGalleryIdChanged: refresh()
  onBackendChanged: refresh()
  Component.onCompleted: refresh()

  header: PageHeader {
    id: pageHeader
    title: root.title
    leadingActionBar.actions: [
      Action {
        iconName: "back"
        text: i18n.tr("Back")
        onTriggered: {
          root.close()
          if (root.autoPop && root.pageStack)
            root.pageStack.pop()
        }
      }
    ]
  }

  // Receives the pictures chosen in Content Hub
  Connections {
    target: root.activeTransfer

    onStateChanged: {
      let transfer = root.activeTransfer
      if (transfer && transfer.state === ContentTransfer.Charged) {
        let urls = []

        for (let i = 0; i < transfer.items.length; i++)
          urls.push(String(transfer.items[i].url))

        backend.call("gallery.append_pictures", [root.galleryId, urls], function(ok) {
          transfer.finalize()
          root.activeTransfer = null
          root.refresh();
        });

      } else if (transfer
                 && (transfer.state === ContentTransfer.Aborted
                  || transfer.state === ContentTransfer.Finalized)) {
        root.activeTransfer = null
      }
    }
  }

  // Main content
  Item {
    anchors {
      top: pageHeader.bottom
      left: parent.left
      right: parent.right
      bottom: parent.bottom
    }

    Button {
      id: addButton
      anchors {
        top: parent.top
        left: parent.left
        right: parent.right
        margins: units.gu(2)
      }
      text: i18n.tr("Add images")
      iconName: "add"
      color: theme.palette.normal.positive
      onClicked: root.picking = true
    }

    DragDropGalleryGird {
      id: galleryGrid
      anchors {
        top: addButton.bottom
        topMargin: units.gu(2)
        left: parent.left
        right: parent.right
        bottom: parent.bottom
      }

      pictures: root.pictures
      columns: Math.max(3, Math.floor(width / units.gu(14)))

      onSwap: root.swap_images(swap1, swap2)
      onSelect: root.selected_images = selection
      onImageReady: root.check_if_thumbnail_needed(image)
    }

    Label {
      anchors.centerIn: galleryGrid
      width: galleryGrid.width - units.gu(4)
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      visible: root.pictures.length === 0
      text: i18n.tr("No pictures yet")
      color: theme.palette.normal.backgroundSecondaryText
    }

    Button {
      anchors {
        bottom: parent.bottom
        left: parent.left
        right: parent.right
        margins: units.gu(2)
      }
      visible: root.selected_images.length >= 1
      text: i18n.tr("Delete images")
      color: LomiriColors.red

      onClicked: {
        remove_selected_pictures()
      }
    }
  }

  // Content Hub picker, shown over the page
  Rectangle {
    anchors.fill: parent
    visible: root.picking
    color: theme.palette.normal.background

    ContentPeerPicker {
      anchors.fill: parent
      visible: parent.visible
      contentType: ContentType.Pictures
      handler: ContentHandler.Source

      onPeerSelected: {
        if (! backend) {
          return
        }
        peer.selectionType = ContentTransfer.Multiple
        root.activeTransfer = peer.request()
        root.picking = false
      }
      onCancelPressed: root.picking = false
    }
  }

  ContentTransferHint {
    anchors.fill: parent
    activeTransfer: root.activeTransfer
  }
}
