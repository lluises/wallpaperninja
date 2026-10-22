/**
   MiniGalleryPreview

   Preview some relevant images for the given galleryId

   Usage:

     MiniGalleryPreview {
       galleryId: "main"
       backend: python
       maxImages: 5
       imageSize: units.gu(5)
       onClicked: console.log("clicked")
     }

**/

import QtQuick 2.12
import Lomiri.Components 1.3
import Lomiri.Content 1.3

Item {
  id: root
  height: imageSize
  width: row.width

  // Public interface
  property string galleryId: ""
  property var backend: null // the shared Python object from Main.qml
  property int maxImages: 95
  property int minImages: 3
  property real imageSize: units.gu(5)

  signal clicked()

  function refresh() {
    if (!backend || galleryId === "")
      return

    recalculate(true);
  }

  function recalculate(force) {
    if (!backend || galleryId === "")
      return

    const available_width = (parent.width - countLabel.font.pixelSize*3 - row.spacing);
    const num_images = optimal_size(
      minImages,
      maxImages,
      available_width,
      imageSize,
      imgRow.spacing
    );

    if (force !== true && num_images == root.numImages)
      return;

    backend.call("gallery.list_some_pictures", [galleryId, num_images], function(result) {
      numImages = num_images
      root.pictures = result || []
    });

    backend.call("gallery.count_how_many_wallpapers", [galleryId], function(result) {
      root.picturesCount = result || 0;
    });
  }

  // Internal state
  property var pictures: []
  property int picturesCount: 0
  property int numImages: 0

  function path_to_url(path) {
    let p = String(path)
    return p.indexOf("://") === -1 ? "file://" + p : p
  }

  function optimal_size(min, max, width, size, spacing) {
    /**
     * min: Minimum number of images
     * max: Maximum number of images
     * width: Total available width
     * size: Image size (width)
     * spacing: Spacing between images (width)
     **/
    const optimal = (width + spacing) / (size + spacing)
    return Math.max(min, Math.min(max, Math.floor(optimal)));
  }

  onGalleryIdChanged: refresh()
  onBackendChanged: recalculate()
  onWidthChanged: recalculate()
  Component.onCompleted: refresh()

  // React to the parent's width changing
  Connections {
    target: root.parent
    onWidthChanged: refresh()
  }

  // Main content
  Row {
    id: row
    spacing: units.gu(2)
    height: imageSize

    Row {
      id: imgRow
      spacing: units.gu(1)

      Repeater {
        model: root.pictures

        Image {
          width: root.imageSize
          height: root.imageSize
          source: root.path_to_url(modelData)
          fillMode: Image.PreserveAspectCrop
          asynchronous: true

          Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: "grey"
            border.width: Math.min(2, units.gu(0.1))
          }
        }
      }

      Repeater {
        model: Math.max(0, numImages - root.pictures.length)

        Rectangle {
          width: imageSize
          height: imageSize
          color: "transparent"
          border.color: "grey"
          border.width: Math.min(2, units.gu(0.1))
        }

        /* Icon { */
        /*   width: root.imageSize */
        /*   height: root.imageSize */
        /*   name: "stock_image" */
        /* } */
      }
    }

    Label {
      id: countLabel
      anchors.verticalCenter: parent.verticalCenter
      text: root.picturesCount
      font.pixelSize: Math.min(imageSize, units.gu(3))
    }
  }

  MouseArea {
    anchors.fill: parent
    onClicked: root.clicked()
  }
}
