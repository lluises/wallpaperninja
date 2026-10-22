/**
   DragDropGalleryGird

   Grid of pictures with tap-to-select and long-press-to-drag re-arrangement.
   The grid never re-orders anything by itself: it only reports what the user
   did, through signals.

   Usage:

     DragDropGalleryGird {
       anchors.fill: parent
       pictures: root.pictures
       columns: Math.max(3, Math.floor(width / units.gu(14)))
       onSwap: console.log(swap1, swap2)       // paths of the two pictures
       onSelect: console.log(selection)        // paths of the selected pictures
       onImageReady: check_if_thumbnail_needed(image)
     }

     // Methods
     reset_selection()
**/

import QtQuick 2.12
import Lomiri.Components 1.3

Item {
  id: root

  // Public interface
  property var pictures: [] // list of paths (or urls)
  property int columns: 3

  signal swap(var swap1, var swap2) // dragged picture, picture it was dropped on
  signal select(var selection) // emitted every time the selection changes
  signal imageReady(var image) // an Image finished loading (Image.Ready)

  function reset_selection() {
    _set_selection([]);
  }

  // Internal state
  property var _selected: []
  property int _dragIndex: -1   // index of the picture being dragged (-1 = none)
  property int _dropIndex: -1   // index of the cell currently under the finger
  readonly property bool _dragging: _dragIndex >= 0

  function _set_selection(list) {
    _selected = list
    select(list)
  }

  function _is_selected(path) {
    return _selected.indexOf(path) >= 0
  }

  function _toggle_selected(path) {
    let list = _selected.slice()
    let idx = list.indexOf(path)
    if (idx < 0)
      list.push(path)
    else
      list.splice(idx, 1)
    _set_selection(list)
  }

  function _path_to_url(path) {
    let p = String(path)
    return p.indexOf("://") === -1 ? "file://" + p : p
  }

  function _begin_drag(area, index, path, mx, my) {
    _dragIndex = index
    _dropIndex = index
    ghost.source = _path_to_url(path)
    _update_drag(area, mx, my)
  }

  function _update_drag(area, mx, my) {
    if (!_dragging)
      return
    // Ghost follows the finger (coordinates relative to dragLayer)
    let p = area.mapToItem(dragLayer, mx, my)
    ghost.x = p.x - ghost.width / 2
    ghost.y = p.y - ghost.height / 2
    // Cell under the finger (coordinates relative to the grid content)
    let c = area.mapToItem(grid.contentItem, mx, my)
    _dropIndex = grid.indexAt(c.x, c.y)
  }

  function _end_drag(area, mx, my) {
    if (!_dragging)
      return
    _update_drag(area, mx, my)
    let from = _dragIndex
    let to = _dropIndex
    _cancel_drag()
    if (to >= 0 && to !== from)
      swap(pictures[from], pictures[to])
  }

  function _cancel_drag() {
    _dragIndex = -1
    _dropIndex = -1
    ghost.source = ""
  }

  GridView {
    id: grid
    anchors.fill: parent
    clip: true
    interactive: !root._dragging

    cellWidth: width / root.columns
    cellHeight: cellWidth

    model: root.pictures

    delegate: Item {
      width: grid.cellWidth
      height: grid.cellHeight

      readonly property bool selected: root._is_selected(modelData)

      Image {
        id: img
        anchors { fill: parent; margins: units.dp(1) }
        opacity: root._dragIndex === index ? 0.3 : 1
        source: root._path_to_url(modelData)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        sourceSize { width: grid.cellWidth * 2; height: grid.cellHeight * 2 }
        onStatusChanged: {
          if (status === Image.Ready)
            root.imageReady(img)
          else if (status === Image.Error)
            console.log("Image failed:", source)
        }
      }

      // Dim the image when selected
      Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: parent.selected ? 0.40 : 0
        Behavior on opacity { NumberAnimation { duration: 100 } }
      }

      CheckBox {
        anchors {
          top: parent.top
          right: parent.right
          margins: units.gu(0.5)
        }
        visible: parent.selected
        checked: parent.selected
        onClicked: root._toggle_selected(modelData)
      }

      // Highlight the cell where the dragged picture would land
      Rectangle {
        anchors.fill: parent
        color: "transparent"
        border {
          width: units.dp(3)
          color: theme.palette.normal.focus
        }
        visible: root._dragging && root._dropIndex === index && root._dragIndex !== index
      }

      MouseArea {
        anchors.fill: parent
        preventStealing: root._dragging
        onClicked: root._toggle_selected(modelData)
        onPressAndHold: root._begin_drag(this, index, modelData, mouse.x, mouse.y)
        onPositionChanged: {
          if (root._dragIndex === index)
            root._update_drag(this, mouse.x, mouse.y)
        }
        onReleased: {
          if (root._dragIndex === index)
            root._end_drag(this, mouse.x, mouse.y)
        }
        onCanceled: {
          if (root._dragIndex === index)
            root._cancel_drag()
        }
      }
    }
  }

  // Overlay holding the picture that follows the finger while dragging
  Item {
    id: dragLayer
    anchors.fill: parent
    z: 100

    Image {
      id: ghost
      width: grid.cellWidth
      height: grid.cellHeight
      visible: root._dragging
      opacity: 0.85
      scale: 1.1
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: false
      sourceSize { width: grid.cellWidth * 2; height: grid.cellHeight * 2 }
    }
  }
}
