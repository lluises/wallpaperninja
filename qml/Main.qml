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
import "components"

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
  property var busyPopup: null // the currently open popup, if any
  property bool backendReady: false

  function show_loading() {
    if (busyPopup)
      return;
    busyPopup = PopupUtils.open(busyDialog);
  }

  function hide_loading() {
    if (! busyPopup)
      return;
    PopupUtils.close(busyPopup);
    busyPopup = null;
  }

  function do_popup(title, text) {
    let popup = PopupUtils.open(invalidDialog);
    popup.title = title;
    popup.text = text;
  }

  function check_background_status() {
    // Update the status indicator (okey or disabled)
    python.call("manager.is_background_module_enabled", [], function(status) {
      bannerEnabled.visible = status;
      bannerDisabled.visible = !status;
    });
  }

  function pull_settings_from_cfg(cfg) {
    orderSelector.selectedIndex    = cfg.order || 0;
    intervalSelector.selectedIndex = cfg.interval || 0;
    timeValueField.text            = '' + (0+cfg.interval_value || 1);
    slot1Hours.text                = (cfg.day_hour || '').split(':')[0] || '07'
    slot1Minutes.text              = (cfg.day_hour || '').split(':')[1] || '00'
    slot2Hours.text                = (cfg.night_hour || '').split(':')[0] || '20'
    slot2Minutes.text              = (cfg.night_hour || '').split(':')[1] || '00'
    intervalTimer.checked          = !!cfg.enable_interval;
    daynightSwitching.checked      = !!cfg.enable_daynight;
    deletePreviousCheckbox.checked = !!cfg.remove_previous_wallpapers
    strictTimeCheckbox.checked     = !!cfg.strict_time;
  }

  function pull_settings_from_interface() {
    // Returns settings object {"interval": ...} if all okey
    // Returns error object {"error": true, "message": i18n.tr("Error message")}

    function make_error(msg) {
      return {
        error: true,
        message: i18n.tr(msg),
      };
    }

    const order = orderSelector.selectedIndex
    if (order < 0)
      order = 0

    const interval = intervalSelector.selectedIndex
    if (interval < 0)
      interval = 0

    const time = parseInt(timeValueField.text)
    if (time <= 0 || time > 1000)
      return make_error("Invalid timer value");

    const hh1 = parseInt(slot1Hours.text)
    const mm1 = parseInt(slot1Minutes.text)
    if (hh1 < 0 || hh1 > 23 || mm1 < 0 || mm1 > 59)
      return make_error("Invalid time at the day and night main profile");

    const day_hour = `${String(hh1).padStart(2, '0')}:${String(mm1).padStart(2, '0')}`

    const hh2 = parseInt(slot2Hours.text)
    const mm2 = parseInt(slot2Minutes.text)
    if (hh1 < 0 || hh1 > 23 || mm1 < 0 || mm1 > 59)
      return make_error("Invalid time at the day and night alternative profile");

    const night_hour = `${String(hh2).padStart(2, '0')}:${String(mm2).padStart(2, '0')}`

    const enable_interval = !!intervalTimer.checked;
    const enable_daynight = !!daynightSwitching.checked;

    if (!enable_interval && !enable_daynight)
      return make_error("Please enable at least one: Timer or Day/Night.");

    const remove_previous_wallpapers = !!deletePreviousCheckbox.checked;
    const strict_time = !!strictTimeCheckbox.checked;

    return {
      order: order,
      interval: interval,
      interval_value: time,
      day_hour: day_hour,
      night_hour: night_hour,
      enable_daynight: enable_daynight,
      enable_interval: enable_interval,
      remove_previous_wallpapers: remove_previous_wallpapers,
      strict_time: strict_time,
    }
  }

  function do_apply() {
    // Save the interface settings and install/configure the background module
    const cfg = pull_settings_from_interface();

    if (cfg.error === true) {
      do_popup(i18n.tr("Invalid configuration"), cfg.message);
      return
    }

    show_loading();

    python.call("manager.save_config", [cfg], function(ok) {
      if (! ok) {
        hide_loading();
        do_popup(i18n.tr("Error"), i18n.tr("Failed to save the configuration"));
        return
      }

      console.log("Configuration saved");

      python.call("manager.install_background_module", [], function (ok) {
        hide_loading();
        
        if (ok) {
          console.log("Systemd unit installed");
          do_popup(i18n.tr("Configuration applied"), "");
        } else {
          console.log("Failed to install the background module");
          do_popup(i18n.tr("Error"), i18n.tr("Failed to set up the background service"));
        }

        check_background_status();
      });
    });
  }

  function open_gallery(gallery_id, title) {
    pageStack.push(galleryComponent, {
      galleryId: gallery_id,
      title: title,
    })
  }

  function refresh_previews() {
    previewMain.refresh();
    previewAlternative.refresh();
  }

  function on_gallery_close() {
    refresh_previews()
  }

  function trigger_next_wallpaper() {
    python.call("manager.trigger_next_wallpaper", [], function(ok) {
      if (ok) {
        console.log("Wallpaper changed");
      } else {
        console.log("Failed to change the wallpaper");
        root.do_popup(
          i18n.tr("Next wallpaper"),
          i18n.tr("Failed to change the wallpaper :("),
        )
      }
    });
  }

  function remove_background_module() {
    show_loading();

    python.call("manager.remove_background_module", [], function(ok) {
      hide_loading();

      if (ok)
        console.log("Systemd service uninstalled");
      else
        console.log("Failed to uninstall the Systemd service");

      root.do_popup(
        i18n.tr("Background service"),
        (ok
         ? i18n.tr("Wallpaper Ninja has been disabled")
         : i18n.tr("Failed to disable Wallpaper Ninja"))
      );

      check_background_status();
    });
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
        leftPadding: units.gu(0)
        rightPadding: units.gu(0)
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
            width: parent.width
            topPadding: units.gu(6)
            bottomPadding: units.gu(6)

            Row {
              spacing: units.gu(1)
              padding: units.gu(2)
              width: parent.width - padding * 2

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
                text: i18n.tr('Your ninja takes care of your Ubuntu Touch wallpaper')
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
                  text: i18n.tr('Wallpaper Ninja is running')
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
              id: controlsCol
              anchors.left: parent.left
              anchors.right: parent.right
              spacing: units.gu(1)

              Row {
                spacing: units.gu(3)
                anchors.horizontalCenter: parent.horizontalCenter

                Button {
                  enabled: bannerEnabled.visible;
                  text: i18n.tr("Disable")
                  color: LomiriColors.red
                  width: Math.max(units.gu(15),
                                  Math.min(units.gu(35),
                                           controlsCol.width/2.0 - parent.spacing - units.gu(2)))
                  onClicked: root.remove_background_module()
                }

                Button {
                  id: changenowButton
                  text: i18n.tr("Next wallpaper")
                  color: LomiriColors.purple
                  width: Math.max(units.gu(15),
                                  Math.min(units.gu(35),
                                           controlsCol.width/2.0 - parent.spacing - units.gu(2)))
                  enabled: (bannerEnabled.visible);
                  onClicked: trigger_next_wallpaper()
                }
              }
            }


            ContentBox {
              width: parent.width
              icon: "folder-symbolic"
              title: i18n.tr("Main wallpapers")
              showSwitch: false

              MiniGalleryPreview {
                id: previewMain
                galleryId: "main"
                maxImages: 32
                backend: backendReady ? python : null
                onClicked: root.open_gallery("main", i18n.tr("Main wallpapers"));
              }
            }


            ContentBox {
              width: parent.width
              icon: "folder-symbolic"
              title: i18n.tr("Alternative wallpapers")
              showSwitch: false

              MiniGalleryPreview {
                id: previewAlternative
                galleryId: "alternative"
                backend: backendReady ? python : null
                maxImages: 32
                onClicked: root.open_gallery("alternative", i18n.tr("Alternative wallpapers"));
              }

              Label {
                text: i18n.tr('For day and night')
                wrapMode: Text.WordWrap
              }
            }


            ContentBox {
              width: parent.width
              icon: "media-playlist-shuffle"
              title: i18n.tr("Order")
              showSwitch: false

              BetterOptionSelector {
                id: orderSelector
                maxVisibleItems: 5
                expanded: true
                model: [
                  i18n.tr("As shown in gallery"),
                  i18n.tr("Reverse gallery"),
                  i18n.tr("Random"),
                  i18n.tr("Random without repeating"),
                ]
              }
            }


            ContentBox {
              id: intervalTimer
              width: parent.width
              icon: "timer"
              title: i18n.tr("Wallpaper timer")
              showSwitch: true
              checked: false

              BetterOptionSelector {
                id: intervalSelector
                expanded: false
                enabled: (intervalTimer.checked)

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
                enabled: (intervalTimer.checked && intervalSelector.selectedIndex >= 1)

                Label {
                  text: i18n.tr("Repeat every")
                  width: units.gu(16)
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


            ContentBox {
              id: daynightSwitching
              width: parent.width
              icon: "night-mode"
              title: i18n.tr("Day and night wallpapers")
              showSwitch: true
              checked: false

              Row {
                spacing: units.gu(0.5)
                enabled: (daynightSwitching.checked)

                Label {
                  text: i18n.tr('Main')
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
                  text: ":"
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
                enabled: (daynightSwitching.checked)

                Label {
                  text: i18n.tr('Alternative')
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
                  text: ":"
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


            ContentBox {
              width: parent.width
              icon: "settings"
              title: i18n.tr("Miscellaneous")
              showSwitch: false

              LabelAndSwitch {
                id: deletePreviousCheckbox
                text: i18n.tr("Hide Wallpaper Ninja images from the Ubuntu Touch Settings app")
                checked: false
              }

              LabelAndSwitch {
                id: strictTimeCheckbox
                text: i18n.tr("Precise timing (may increase battery usage)")
                checked: false
              }
            }

            ContentBox {
              width: parent.width
              icon: "info"
              title: i18n.tr("Notes")
              showSwitch: false

              Column {
                spacing: units.gu(1)
                anchors.left: parent.left
                anchors.right: parent.right

                Repeater {
                  model: [
                    i18n.tr("Before uninstalling, make sure Wallpaper Ninja is disabled"),
                    i18n.tr("Only JPG and PNG images are supported"),
                    i18n.tr("Invalid images might fallback to the default Ubuntu wallpaper"),
                    i18n.tr("The wallpaper will always change on boot"),
                    i18n.tr("Without precise timing, wallpaper changes may be delayed by up to one minute to save battery life."),
                    i18n.tr("The wallpaper timer resets on every day/night switch"),
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
        onClicked: do_apply()
      }
    }
  }

  Component {
    id: galleryComponent

    GalleryManager {
      galleryId: "main"
      backend: python
      title: i18n.tr("Main wallpapers")
      onClose: on_gallery_close()
    }
  }

  Component {
    id: invalidDialog

    Dialog {
      id: dlg
      title: i18n.tr("Popup title")
      text: i18n.tr("Popup text")

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

      const N_MODULES = 2;
      let loaded = 0;

      setHandler("python-log", console.log); // Capture output of log.py

      importModule('manager', function() {
        root.backendReady = (++loaded >= N_MODULES);

        python.call('manager.pull_config', [], function(cfg) {
          console.log('Stored configuration: ' + JSON.stringify(cfg));
          pull_settings_from_cfg(cfg);
        })

        root.check_background_status();
      });

      importModule('gallery', function() {
        root.backendReady = (++loaded >= N_MODULES);
      });
    }

    onError: {
      console.log("python error: " + traceback);
    }
  }
}
