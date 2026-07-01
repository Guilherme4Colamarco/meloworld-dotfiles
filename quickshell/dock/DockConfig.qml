import QtQuick
import Quickshell.Io

pragma Singleton

QtObject {
    property var pinnedApps: []
    property var dockState: null
    
    function init() {
        dockState = Qt.createComponent("../dock/DockState.qml").createObject(this)
        if (dockState) {
            pinnedApps = dockState.pinnedApps
        }
    }
    
    function pinApp(appId, name, icon) {
        if (!dockState) init()
        dockState.pinApp(appId, name, icon)
        pinnedApps = dockState.pinnedApps
    }
    
    function unpinApp(appId) {
        if (!dockState) init()
        dockState.unpinApp(appId)
        pinnedApps = dockState.pinnedApps
    }
    
    function isPinned(appId) {
        if (!dockState) init()
        return dockState.isPinned(appId)
    }
    
    Component.onCompleted: init()
}
