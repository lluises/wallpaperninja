import QtQuick 2.12
import Lomiri.Components 1.3
import io.thp.pyotherside 1.4

Page {
    id: logsPage

    property string logText: ""
    property bool loading: true

    header: PageHeader {
        id: header
        title: i18n.tr("Logs")

        trailingActionBar.actions: [
            Action {
                iconName: "reload"
                text: i18n.tr("Refresh")
                enabled: !logsPage.loading     // ignore taps while a read is running
                onTriggered: logsPage.reload()
            }
        ]
    }

    Python {
        id: python

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl("../src/"));
            importModule("manager", function() {
                // Single read when the page is created
                logsPage.reload();
            });
        }

        onError: {
            console.error("Python error:", traceback);
            logsPage.loading = false;
            logsPage.logText = i18n.tr("Could not read logs.");
        }
    }

    // Called once on open and then only when the user taps Refresh
    function reload() {
        if (loading && logText !== "") return;   // a read is already in progress
        loading = true;
        python.call("manager.read_logs", [1024], function(result) {
            logText = Array.isArray(result) ? result.join("\n") : String(result);
            loading = false;
            scrollTimer.restart();
        });
    }

    Timer {
        id: scrollTimer
        interval: 0
        onTriggered: logFlick.contentY = Math.max(0, logFlick.contentHeight - logFlick.height)
    }

    Flickable {
        id: logFlick
        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        clip: true
        contentWidth: width
        contentHeight: logLabel.height + units.gu(4)

        Label {
            id: logLabel
            x: units.gu(2)
            y: units.gu(2)
            width: logFlick.width - units.gu(4)

            text: logsPage.logText !== "" ? logsPage.logText : i18n.tr("No logs.")
            textFormat: Text.PlainText
            wrapMode: Text.WrapAnywhere
            font.family: "Ubuntu Mono"
            fontSize: "small"
        }
    }

    /* ScrollBar { */
    /*     flickableItem: logFlick */
    /*     align: Qt.AlignTrailing */
    /* } */

    ActivityIndicator {
        anchors.centerIn: parent
        running: logsPage.loading
        visible: running
    }
}
