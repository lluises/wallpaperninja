import QtQuick 2.7
import Lomiri.Components.ListItems 1.3
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0
import io.thp.pyotherside 1.4
import QtQuick.Controls 2.2
import Lomiri.Components 1.3
import QtQuick.Dialogs 1.2
import Lomiri.Components.Popups 1.3
import Lomiri.Content 1.3

MainView {
  id: root
  objectName: 'mainView'
  applicationName: 'wallpaperninja.kitsune.cat'

  width: units.gu(45)
  height: units.gu(75)

  property string folderPath1: ""
  property string folderPath2: ""
  property int pickerTarget: 0
  property var activeTransfer: null
  property var busyPopup: null   // the currently open popup, if any

  function show_loading() {
    if (busyPopup)
      return // never open two
    busyPopup = PopupUtils.open(busyDialog);
  }

  function hide_loading() {
    if (! busyPopup)
      return;
    PopupUtils.close(busyPopup);
    busyPopup = null;
  }

  function startPicking(target) {
    pickerTarget = target
    folderPicker.openAt(target === 1 ? folderPath1 : folderPath2)
    pageStack.push(folderPicker)
  }

  function folderFromUrl(url) {
    var path = url.toString().replace(/^file:\/\//, "")
    return path.substring(0, path.lastIndexOf("/"))
  }

  function folder1_changed(update_label) {
    if (update_label === undefined || update_label)
      editablePath.text = root.folderPath1
    imageCountLabel.calculate_count()
  }

  function folder2_changed(update_label) {
    if (update_label === undefined || update_label)
      editablePath2.text = root.folderPath2
    imageCount2Label.calculate_count()
  }

  function do_popup(title, text) {
    let popup = PopupUtils.open(invalidDialog);
    popup.title = title;
    popup.text = text;
    return
  }

  function check_background_status() {
    python.call("manager.is_background_module_enabled", [], function(status) {
      bannerEnabled.visible = status;
      bannerDisabled.visible = !status;
    });
  }

  function pull_settings_from_cfg(cfg) {
    root.folderPath1               = cfg.folder || "";
    root.folderPath2               = cfg.folder2 || "";
    recursiveCheckbox.checked      = !!cfg.recursive;
    recursive2Checkbox.checked     = !!cfg.recursive2;
    orderSelector.selectedIndex    = cfg.order || 0;
    intervalSelector.selectedIndex = cfg.interval || 0;
    timeValueField.text            = '' + (0+cfg.interval_value || 1);
    slot1Hours.text                = (cfg.day_hour || '').split(':')[0] || '07'
    slot1Minutes.text              = (cfg.day_hour || '').split(':')[1] || '00'
    slot2Hours.text                = (cfg.night_hour || '').split(':')[0] || '20'
    slot2Minutes.text              = (cfg.night_hour || '').split(':')[1] || '00'
    intervalCheckbox.checked       = !!cfg.enable_interval;
    slotSwitchCheckbox.checked     = !!cfg.enable_daynight;
    deletePreviousCheckbox.checked = !!cfg.remove_previous_wallpapers
    folder1_changed()
    folder2_changed()
  }

  PageStack {
    id: pageStack
    Component.onCompleted: push(mainPage)

    Page {
      id: mainPage
      visible: false
      anchors.fill: parent

      header: PageHeader {
        id: header
        title: i18n.tr('Wallpaper Ninja')
      }

      Column {
        anchors.fill: parent
        spacing: units.gu(3)
        topPadding: units.gu(0)
        leftPadding: units.gu(2)
        rightPadding: units.gu(2)
        bottomPadding: units.gu(0)

        Flickable {
          id: pageFlickable

          width: parent.width - parent.rightPadding - parent.leftPadding
          height: parent.height - applyButton.height - parent.spacing

          contentWidth: width
          contentHeight: contColumn.height
          flickableDirection: Flickable.VerticalFlick
          clip: true

          Column {
            id: contColumn
            spacing: units.gu(4)
            anchors.left: parent.left
            anchors.right: parent.right
            leftPadding: units.gu(2)
            rightPadding: units.gu(2)
            topPadding: units.gu(8)
            bottomPadding: units.gu(8)

            Row {
              anchors.left: parent.left
              anchors.right: parent.right
              spacing: units.gu(1)

              Image {
                id: imgFox
                source: "../assets/foxninja.png"
                width: units.gu(24)
                height: units.gu(24)
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: false
                antialiasing: true
              }

              Label {
                anchors.verticalCenter: parent.verticalCenter
                text: i18n.tr('The ninja will take care of your Ubuntu Touch wallpaper')
                font.pixelSize: units.gu(2.5)
                width: Math.max(0, parent.width - imgFox.width - parent.spacing)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
              }
            }

            Column {
              spacing: units.gu(2)
              anchors.left: parent.left
              anchors.right: parent.right

              Row {
                id: bannerEnabled
                spacing: units.gu(1)
                visible: false
                anchors.horizontalCenter: parent.horizontalCenter

                Icon {
                  width: units.gu(3)
                  height: units.gu(3)
                  name: "ok"
                  anchors.verticalCenter: parent.verticalCenter
                }
                Label {
                  text: i18n.tr('Wallpaper Ninja is operational')
                  wrapMode: Text.WordWrap
                  anchors.verticalCenter: parent.verticalCenter
                  color: LomiriColors.green
                  font.bold: true
                }
              }

              Row {
                spacing: units.gu(1)
                id: bannerDisabled
                visible: false
                anchors.horizontalCenter: parent.horizontalCenter

                Icon {
                  width: units.gu(3)
                  height: units.gu(3)
                  name: "security-alert"
                  anchors.verticalCenter: parent.verticalCenter
                }
                Label {
                  text: i18n.tr('Wallpaper Ninja is disabled')
                  wrapMode: Text.WordWrap
                  anchors.verticalCenter: parent.verticalCenter
                  color: LomiriColors.red
                  font.bold: true
                }
              }
            }

            Column {
              anchors.left: parent.left
              anchors.right: parent.right
              spacing: units.gu(1)

              Row {
                anchors.horizontalCenter: parent.horizontalCenter
                Button {
                  id: changenowButton
                  text: i18n.tr("Next wallpaper")
                  color: LomiriColors.purple
                  width: units.gu(30)
                  enabled: (bannerEnabled.visible);
                  onClicked: {
                    python.call("manager.trigger_next_wallpaper", [], function(ok) {
                      if (ok) {
                        console.log("Wallpaper changed");
                      } else {
                        console.log("Failed to change the wallpaper");
                        root.do_popup(
                          i18n.tr("Next wallpaper"),
                          i18n.tr("Failed to change the wallpaper. Make sure to configure and click apply before triggering the wallpaper change"),
                        )
                      }
                    });
                  }
                }
              }
            }

            
            ThinDivider {
              width: parent.width
            }

            Column {
              spacing: units.gu(1)
              anchors.left: parent.left
              anchors.right: parent.right

              Row {
                spacing: units.gu(1)
                Icon {
                  width: units.gu(3)
                  height: units.gu(3)
                  name: "folder-symbolic"
                  anchors.verticalCenter: parent.verticalCenter
                }
                Label {
                  text: i18n.tr('Main wallpapers folder ')
                  wrapMode: Text.WordWrap
                  anchors.verticalCenter: parent.verticalCenter
                  font.bold: true
                }
              }

              Column {
                spacing: units.gu(2)
                anchors.left: parent.left
                anchors.right: parent.right

                Row {
                  spacing: units.gu(1)
                  anchors.left: parent.left
                  anchors.right: parent.right

                  Button {
                    id: chooseFolderButton
                    text: i18n.tr("Choose folder")
                    onClicked: root.startPicking(1)
                  }

                  TextField {
                    id: editablePath
                    text: "1"
                    placeholderText: i18n.tr("/path/to/folder")
                    width: Math.max(0, parent.width - chooseFolderButton.width - parent.spacing)
                    anchors.verticalCenter: parent.verticalCenter
                    onTextChanged: {
                      folderPath1 = text;
                      folder1_changed(false);
                    }
                  }
                }

                Row {
                  spacing: units.gu(2)

                  CheckBox {
                    id: recursiveCheckbox
                    checked: true
                    onCheckedChanged: {
                      console.log("Checked:", checked)
                      imageCountLabel.calculate_count()
                    }
                  }

                  Label {
                    text: i18n.tr("Recursive")
                    anchors.verticalCenter: recursiveCheckbox.verticalCenter
                    MouseArea {
                      anchors.fill: parent
                      onClicked: recursiveCheckbox.checked = !recursiveCheckbox.checked
                    }
                  }
                }

                Row {
                  spacing: units.gu(1)

                  Label {
                    text: i18n.tr('Detected images:')
                    wrapMode: Text.WordWrap
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Label {
                    id: imageCountLabel
                    text: "0"
                    anchors.verticalCenter: parent.verticalCenter

                    function calculate_count() {
                      let recursive = !!recursiveCheckbox.checked
                      let folder = folderPath1
                      if (!folder || folder == null || folder == "") {
                        imageCountLabel.text = "0"
                      } else {
                        imageCountLabel.text = "[···]";
                        python.call("manager.count_how_many_wallpapers", [folder, recursive], function(count) {
                          console.log("folder:", folder, " | recursive: ", recursive, " | count: ", count);
                          if (count < 0) {
                            imageCountLabel.text = "error";
                          } else {
                            imageCountLabel.text = ''+count;
                          }
                        });

                      }
                    }
                  }

                  Icon {
                    width: units.gu(3)
                    height: units.gu(3)
                    name: "stock_image"
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
              }
            }


            ThinDivider {
              width: parent.width
            }


            Column {
              spacing: units.gu(1)
              anchors.left: parent.left
              anchors.right: parent.right

              Row {
                spacing: units.gu(1)
                Icon {
                  width: units.gu(3)
                  height: units.gu(3)
                  name: "folder-symbolic"
                  anchors.verticalCenter: parent.verticalCenter
                }
                Label {
                  text: i18n.tr('Alternative wallpapers folder ')
                  wrapMode: Text.WordWrap
                  anchors.verticalCenter: parent.verticalCenter
                  font.bold: true
                }
              }

              Column {
                spacing: units.gu(2)
                anchors.left: parent.left
                anchors.right: parent.right

                Label {
                  text: i18n.tr('Optional. Used for the day/night switch')
                  wrapMode: Text.WordWrap
                }

                Row {
                  spacing: units.gu(1)
                  anchors.left: parent.left
                  anchors.right: parent.right

                  Button {
                    id: chooseFolder2Button
                    text: i18n.tr("Choose folder")
                    onClicked: root.startPicking(2)
                  }

                  TextField {
                    id: editablePath2
                    text: ""
                    placeholderText: i18n.tr("Unselected")
                    width: Math.max(0, parent.width - chooseFolderButton.width - parent.spacing)
                    anchors.verticalCenter: parent.verticalCenter
                    onTextChanged: {
                      folderPath2 = text;
                      folder2_changed(false);
                    }
                  }
                }

                Row {
                  spacing: units.gu(2)

                  CheckBox {
                    id: recursive2Checkbox
                    checked: true
                    onCheckedChanged: {
                      imageCount2Label.calculate_count()
                    }
                  }

                  Label {
                    text: i18n.tr("Recursive")
                    anchors.verticalCenter: recursive2Checkbox.verticalCenter
                    MouseArea {
                      anchors.fill: parent
                      onClicked: recursive2Checkbox.checked = !recursive2Checkbox.checked
                    }
                  }
                }

                Row {
                  spacing: units.gu(1)

                  Label {
                    text: i18n.tr('Detected images:')
                    wrapMode: Text.WordWrap
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Label {
                    id: imageCount2Label
                    text: "0"
                    anchors.verticalCenter: parent.verticalCenter

                    function calculate_count() {
                      let recursive = !!recursive2Checkbox.checked
                      let folder = folderPath2
                      if (!folder || folder == null || folder == "") {
                        imageCount2Label.text = "0"
                      } else {
                        imageCount2Label.text = "[···]";
                        python.call("manager.count_how_many_wallpapers", [folder, recursive], function(count) {
                          console.log("folder:", folder, " | recursive: ", recursive, " | count: ", count);
                          if (count < 0) {
                            imageCount2Label.text = "error";
                          } else {
                            imageCount2Label.text = ''+count;
                          }
                        });

                      }
                    }
                  }

                  Icon {
                    width: units.gu(3)
                    height: units.gu(3)
                    name: "stock_image"
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
              }
            }


            ThinDivider {
              width: parent.width
            }


            Column {
              spacing: units.gu(2)
              anchors.left: parent.left
              anchors.right: parent.right

              Row {
                spacing: units.gu(1)
                Icon {
                  width: units.gu(3)
                  height: units.gu(3)
                  name: "media-playlist-shuffle"
                  anchors.verticalCenter: parent.verticalCenter
                }
                Label {
                  text: i18n.tr('Order')
                  wrapMode: Text.WordWrap
                  anchors.verticalCenter: parent.verticalCenter
                  font.bold: true
                }
              }

              OptionSelector {
                id: orderSelector
                expanded: true

                model: [
                  i18n.tr("Alphabetical"),
                  i18n.tr("Reverse alphabetical"),
                  i18n.tr("Random"),
                  i18n.tr("Random without repeating"),
                ]
              }
            }


            ThinDivider {
              width: parent.width
            }

            
            Column {
              spacing: units.gu(2)
              anchors.left: parent.left
              anchors.right: parent.right

              Row {
                spacing: units.gu(1)
                Icon {
                  width: units.gu(3)
                  height: units.gu(3)
                  name: "timer"
                  anchors.verticalCenter: parent.verticalCenter
                }
                Label {
                  text: i18n.tr('Change at an interval')
                  wrapMode: Text.WordWrap
                  anchors.verticalCenter: parent.verticalCenter
                  font.bold: true
                }
              }

              Row {
                spacing: units.gu(0.5)

                Switch {
                  id: intervalCheckbox
                  checked: true
                }

                Label {
                  text: i18n.tr('Enable wallpaper change at an interval')
                  wrapMode: Text.WordWrap
                  anchors.verticalCenter: parent.verticalCenter
                  MouseArea {
                    anchors.fill: parent
                    onClicked: intervalCheckbox.checked = !intervalCheckbox.checked
                  }
                }
              }

              OptionSelector {
                id: intervalSelector
                expanded: false
                enabled: (intervalCheckbox.checked)

                model: [
                  i18n.tr("On boot"),
                  i18n.tr("Seconds"),
                  i18n.tr("Minutes"),
                  i18n.tr("Hours"),
                  i18n.tr("Days"),
                  i18n.tr("Weeks"),
                  i18n.tr("Months")
                ]
              }

              Row {
                spacing: units.gu(3)
                enabled: (intervalCheckbox.checked && intervalSelector.selectedIndex >= 1)

                Label {
                  text: i18n.tr("Repeat every")
                  width: units.gu(18)
                  anchors.verticalCenter: parent.verticalCenter
                }

                TextField {
                  id: timeValueField
                  text: ""
                  width: units.gu(12)
                  placeholderText: i18n.tr("Time value")
                  inputMethodHints: Qt.ImhFormattedNumbersOnly
                  validator: IntValidator {
                    bottom: 1
                    top: 500
                  }
                }
              }
            }


            ThinDivider {
              width: parent.width
            }


            Column {
              spacing: units.gu(2)
              anchors.left: parent.left
              anchors.right: parent.right

              Row {
                spacing: units.gu(1)
                Icon {
                  width: units.gu(3)
                  height: units.gu(3)
                  name: "night-mode"
                  anchors.verticalCenter: parent.verticalCenter
                }
                Label {
                  text: i18n.tr('Day/night wallpaper folder switching')
                  wrapMode: Text.WordWrap
                  anchors.verticalCenter: parent.verticalCenter
                  font.bold: true
                }
              }
              
              Row {
                spacing: units.gu(0.5)

                Switch {
                  id: slotSwitchCheckbox
                  checked: true
                }

                Label {
                  text: i18n.tr('Enable the day/night switch')
                  wrapMode: Text.WordWrap
                  anchors.verticalCenter: parent.verticalCenter
                  MouseArea {
                    anchors.fill: parent
                    onClicked: slotSwitchCheckbox.checked = !slotSwitchCheckbox.checked
                  }
                }
              }
              
              Row {
                spacing: units.gu(0.5)
                enabled: (slotSwitchCheckbox.checked)

                Label {
                  text: i18n.tr('Main folder')
                  width: units.gu(19)
                  wrapMode: Text.WordWrap
                  anchors.verticalCenter: parent.verticalCenter
                }

                TextField {
                  id: slot1Hours
                  text: "07"
                  placeholderText: "hh"
                  inputMethodHints: Qt.ImhFormattedNumbersOnly
                  width: units.gu(8)
                  validator: IntValidator {
                    bottom: 0
                    top: 23
                  }
                }

                Label {
                  text: i18n.tr(':')
                  wrapMode: Text.WordWrap
                  anchors.verticalCenter: parent.verticalCenter
                }

                TextField {
                  id: slot1Minutes
                  text: "00"
                  placeholderText: "mm"
                  inputMethodHints: Qt.ImhFormattedNumbersOnly
                  width: units.gu(8)
                  validator: IntValidator {
                    bottom: 0
                    top: 59
                  }
                }

                Icon {
                  width: units.gu(3)
                  height: units.gu(3)
                  name: "clock"
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              Row {
                spacing: units.gu(0.5)
                enabled: (slotSwitchCheckbox.checked)

                Label {
                  text: i18n.tr('Alternative folder')
                  width: units.gu(19)
                  wrapMode: Text.WordWrap
                  anchors.verticalCenter: parent.verticalCenter
                }

                TextField {
                  id: slot2Hours
                  text: "20"
                  placeholderText: "hh"
                  inputMethodHints: Qt.ImhFormattedNumbersOnly
                  width: units.gu(8)
                  validator: IntValidator {
                    bottom: 0
                    top: 23
                  }
                }

                Label {
                  text: i18n.tr(':')
                  wrapMode: Text.WordWrap
                  anchors.verticalCenter: parent.verticalCenter
                }

                TextField {
                  id: slot2Minutes
                  text: "00"
                  placeholderText: "mm"
                  inputMethodHints: Qt.ImhFormattedNumbersOnly
                  width: units.gu(8)
                  validator: IntValidator {
                    bottom: 0
                    top: 59
                  }
                }

                Icon {
                  width: units.gu(3)
                  height: units.gu(3)
                  name: "clock"
                  anchors.verticalCenter: parent.verticalCenter
                }
              }
            }

            ThinDivider {
              width: parent.width
            }

            Column {
              spacing: units.gu(2)
              anchors.left: parent.left
              anchors.right: parent.right

              Row {
                spacing: units.gu(1)
                Icon {
                  width: units.gu(3)
                  height: units.gu(3)
                  name: "settings"
                  anchors.verticalCenter: parent.verticalCenter
                }
                Label {
                  text: i18n.tr('Miscellaneous')
                  wrapMode: Text.WordWrap
                  anchors.verticalCenter: parent.verticalCenter
                  font.bold: true
                }
              }

              Column {
                spacing: units.gu(2)
                anchors.left: parent.left
                anchors.right: parent.right

                Row {
                  spacing: units.gu(0.5)

                  Switch {
                    id: deletePreviousCheckbox
                    checked: false
                  }

                  Label {
                    text: i18n.tr('Do not keep wallpapers in the settings list')
                    wrapMode: Text.WordWrap
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea {
                      anchors.fill: parent
                      onClicked: (deletePreviousCheckbox.checked = !deletePreviousCheckbox.checked)
                    }
                  }
                }

                Label {
                  text: i18n.tr("Every wallpaper must be added to the Ubuntu Touch settings wallpaper list. This app can delete its own previous wallpapers to keep the list clean")
                  wrapMode: Text.WordWrap
                  width: parent.width
                }

                Button {
                  text: i18n.tr("Reset all settings (without appliying)")
                  onClicked: {
                    pull_settings_from_cfg({});
                  }
                }
              }
            }

            ThinDivider {
              width: parent.width
            }

            Column {
              anchors.left: parent.left
              anchors.right: parent.right
              spacing: units.gu(2)

              Row {
                spacing: units.gu(1)
                Icon {
                  width: units.gu(3)
                  height: units.gu(3)
                  name: "stop"
                  anchors.verticalCenter: parent.verticalCenter
                }
                Label {
                  text: i18n.tr('Disable')
                  wrapMode: Text.WordWrap
                  anchors.verticalCenter: parent.verticalCenter
                  font.bold: true
                }
              }

              Button {
                id: uninstallButton
                text: i18n.tr("Disable")
                color: LomiriColors.red
                width: units.gu(20)
                onClicked: {
                  show_loading();

                  python.call("manager.remove_background_module", [], function(ok) {
                    hide_loading();

                    if (ok) {
                      console.log("Systemd service uninstalled");
                    } else {
                      console.log("Failed to uninstall the Systemd service");
                    }

                    root.do_popup(
                      i18n.tr("Disable background module"),
                      (ok ?
                       i18n.tr("The module has been disabled")
                       : i18n.tr("Failed to deactivate"))
                    )

                    check_background_status();
                  });
                }
              }

              Label {
                text: i18n.tr("This button removes the background module that manages the wallpaper timer. Click it before uninstalling this app")
                wrapMode: Text.WordWrap
                width: Math.max(0, parent.width)
              }
            }

            ThinDivider {
              width: parent.width
            }

            Column {
              spacing: units.gu(2)
              anchors.left: parent.left
              anchors.right: parent.right

              Row {
                spacing: units.gu(1)
                Icon {
                  width: units.gu(3)
                  height: units.gu(3)
                  name: "info"
                  anchors.verticalCenter: parent.verticalCenter
                }
                Label {
                  text: i18n.tr('Notes and limitations')
                  wrapMode: Text.WordWrap
                  anchors.verticalCenter: parent.verticalCenter
                  font.bold: true
                }
              }

              Column {
                spacing: units.gu(1)
                anchors.left: parent.left
                anchors.right: parent.right

                Repeater {
                  model: [
                    i18n.tr("Only JPG and PNG images are supported"),
                    i18n.tr("Invalid images might fallback to the default Ubuntu wallpaper"),
                    i18n.tr("When enabled, the interval timer always changes the wallpaper on boot"),
                    i18n.tr("The interval timer and daynight times are not exact and they may vary up to 1 minute to improve battery life."),
                    i18n.tr("When using both, the time interval and the day/night switch, the day/night switch will reset the time interval counter when switching folders. If you set an interval once a day it will never fire because the day/night will always be faster."),
                  ]

                  Row {
                    spacing: units.gu(1)
                    width: parent.width

                    Label { text: "•" }

                    Label {
                      text: modelData
                      width: parent.width - units.gu(2)
                      wrapMode: Text.WordWrap
                    }
                  }
                }
              }
            }

            ThinDivider {
              width: parent.width
            }

            Row {
              spacing: 0
              anchors.horizontalCenter: parent.horizontalCenter

              Label {
                anchors.verticalCenter: parent.verticalCenter
                wrapMode: Text.WordWrap
                text: i18n.tr("Made with love by LluísE - ")
              }

              Image {
                source: "../assets/kitsunecat.png"
                width: units.gu(3)
                height: units.gu(3)
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: false
                antialiasing: true
              }
              Label {
                anchors.verticalCenter: parent.verticalCenter
                wrapMode: Text.WordWrap
                text: 'kitsune.cat'
                textFormat: Text.RichText
                horizontalAlignment: Text.AlignHCenter
                font.underline: true
                MouseArea {
                  anchors.fill: parent
                  onClicked: Qt.openUrlExternally("https://kitsune.cat")
                }
              }
            }
          }
        }
      }
      
      Button {
        id: applyButton
        text: i18n.tr("Apply")
        width: parent.width
        anchors {
          left: parent.left
          right: parent.right
          bottom: parent.bottom
          margins: units.gu(2)
        }
        color: LomiriColors.green

        onClicked: {
          // TODO: Apply your settings here
          let folder_url = folderPath1
          console.log('folder_url = ', folder_url)
          if (folder_url == null || folder_url == "" || folder_url.length < 2) {
            do_popup(
              i18n.tr("Invalid configuration"),
              i18n.tr("Please select a valid folder")
            );
            return
          }

          let recursive = !!recursiveCheckbox.checked;

          let folder2_url = folderPath2
          console.log('folder2_url = ', folder2_url)
          if (folder2_url == null || folder2_url == "" || folder_url.length < 2) {
            folder2_url = null
          }
          let recursive2 = !!recursive2Checkbox.checked;

          let order = orderSelector.selectedIndex
          if (order < 0) {
            do_popup(
              i18n.tr("Invalid configuration"),
              i18n.tr("Please select an order")
            );
            return
          }

          let interval = intervalSelector.selectedIndex
          if (interval < 0) {
            do_popup(
              i18n.tr("Invalid configuration"),
              i18n.tr("Please select an interval")
            );
            return
          }

          let time = parseInt(timeValueField.text)
          if (time <= 0 || time > 500) {
            do_popup(
              i18n.tr("Invalid configuration"),
              i18n.tr("Please input a valid time number")
            );
            return
          }

          let hh1 = parseInt(slot1Hours.text)
          let mm1 = parseInt(slot1Minutes.text)
          if (hh1 < 0 || hh1 > 23 || mm1 < 0 || mm1 > 59) {
            do_popup(
              i18n.tr("Invalid configuration"),
              i18n.tr("Please input valid hours and minutes for the day/night main folder")
            );
            return
          }
          let day_hour = `${String(hh1).padStart(2, '0')}:${String(mm1).padStart(2, '0')}`

          let hh2 = parseInt(slot2Hours.text)
          let mm2 = parseInt(slot2Minutes.text)
          if (hh1 < 0 || hh1 > 23 || mm1 < 0 || mm1 > 59) {
            do_popup(
              i18n.tr("Invalid configuration"),
              i18n.tr("Please input valid hours and minutes for the day/night alternative folder")
            );
            return
          }
          let night_hour = `${String(hh2).padStart(2, '0')}:${String(mm2).padStart(2, '0')}`

          let enable_interval = !!intervalCheckbox.checked;
          let enable_daynight = !!slotSwitchCheckbox.checked;

          if (!enable_interval && !enable_daynight) {
            do_popup(
              i18n.tr("Invalid configuration"),
              i18n.tr("Enable at least one: Interval timer or Day/night switch")
            );
            return
          }

          if (enable_daynight && folder2_url === null) {
            do_popup(
              i18n.tr("Invalid configuration"),
              i18n.tr("In order to use the day/night switch you must select an alternative folder")
            );
            return
          }

          let remove_previous_wallpapers = !!deletePreviousCheckbox.checked;

          let cfg = {
            folder: folder_url,
            folder2: folder2_url,
            recursive: recursive,
            recursive2: recursive2,
            order: order,
            interval: interval,
            interval_value: time,
            day_hour: day_hour,
            night_hour: night_hour,
            enable_daynight: enable_daynight,
            enable_interval: enable_interval,
            remove_previous_wallpapers: remove_previous_wallpapers
          }

          show_loading();

          python.call("manager.save_config", [cfg], function(ok) {
            if (ok) {
              console.log("Configuration saved");

              python.call("manager.install_background_module", [], function (ok) {
                hide_loading();

                if (ok) {
                  console.log("Systemd unit installed");
                  do_popup(
                    i18n.tr("Configuration applied"),
                    i18n.tr("Everything okey")
                  );
                } else {
                  console.log("Failed to install the systemd unit");
                  do_popup(
                    i18n.tr("Error"),
                    i18n.tr("Failed to set up the background service")
                  );
                }

                check_background_status();
              })
            } else {
              hide_loading();
              do_popup(
                i18n.tr("Error"),
                i18n.tr("Failed to save the configuration")
              );
            }
          });
        }
      }
    }

    FolderPicker {
      id: folderPicker
      visible: false
      title: i18n.tr("Select a folder")

      onFolderSelected: {
        if (root.pickerTarget === 1) {
          root.folderPath1 = path;
          folder1_changed()
        } else if (root.pickerTarget === 2) {
          root.folderPath2 = path;
          folder2_changed()
        }
        root.pickerTarget = 0;
        pageStack.pop();
      }

      onCanceled: {
        root.pickerTarget = 0;
        pageStack.pop()
      }
    }
  }
 
  Component {
    id: invalidDialog

    Dialog {
      id: dlg
      title: i18n.tr("Invalid configuration")
      text: i18n.tr("Please make sure to input a valid configuration")

      Button {
        text: i18n.tr("OK")
        onClicked: PopupUtils.close(dlg)
      }
    }
  }

  Component {
    id: busyDialog

    Dialog {
      id: dlg
      title: i18n.tr("Working")
      text: i18n.tr("Please wait")

      ActivityIndicator {
        anchors.horizontalCenter: parent.horizontalCenter
        running: true
      }
    }
  }


  Python {
    id: python

    Component.onCompleted: {
      addImportPath(Qt.resolvedUrl('../src/'));

      importModule('manager', function() {
        function path_to_url(path) {
          return Qt.resolvedUrl("file://" + path)
        }

        console.log('module imported');
        python.call('manager.pull_config', [], function(cfg) {
          console.log('manager.pull_config returned ' + JSON.stringify(cfg));

          pull_settings_from_cfg(cfg);
        })

        root.check_background_status();
      });
    }

    onError: {
      console.log('python error: ' + traceback);
    }
  }
}
