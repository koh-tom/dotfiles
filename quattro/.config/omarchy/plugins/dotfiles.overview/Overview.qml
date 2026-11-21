// Workspace Overview — Mac の Mission Control 風のワークスペース一覧 (Omarchy shell の overlay プラグイン)
//
//   開く:   SUPER+ALT+SPACE (quattro/.config/hypr/personal/overview.lua)
//           hyprctl dispatch 'hl.dsp.global("omarchy:panel.dotfiles.overview")' でも可
//   操作:   クリック = そのワークスペース / ウィンドウへ移動
//           ウィンドウをドラッグして別のワークスペースに落とす = ウィンドウを移動
//           ← → ↑ ↓ / h j k l = 選択、Enter = 移動、1〜9 = その番号へ、Esc・空白クリック = 閉じる
//           右端の「+」= 空いているワークスペースへ
//
// サムネイルは Quickshell の ScreencopyView でウィンドウごとにライブ取得する。
// 有効化は shell.json の plugins[] に { "id": "dotfiles.overview" } があること。
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  property int selectedIndex: 0
  // [{ id, name, active, monitor, windows: [{ toplevel, x, y, w, h, title, cls }] }]
  property var workspaces: []

  // ドラッグ中のウィンドウ
  property string dragAddress: ""
  property string dragTitle: ""
  property point dragPoint: Qt.point(0, 0)

  property color background: Commons.Color.menu.background
  property color foreground: Commons.Color.menu.text
  property color border: Commons.Color.menu.border
  property color accent: Commons.Color.menu.selectedBackground
  property color accentText: Commons.Color.menu.selectedText
  property color scrim: Commons.Color.menu.scrim
  readonly property int cornerRadius: Math.max(8, Style.cornerRadius)
  property string fontFamily: Style.font.menuFamily

  readonly property int slotCount: workspaces.length + 1 // 最後は「+」
  readonly property int columns: Math.max(1, Math.min(slotCount, slotCount <= 4 ? slotCount : Math.ceil(slotCount / 2)))

  // ---------------------------------------------------------------- 開閉

  function open(payloadJson) {
    Hyprland.refreshMonitors()
    Hyprland.refreshWorkspaces()
    Hyprland.refreshToplevels()
    root.rebuild()
    var active = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
    root.selectedIndex = 0
    for (var i = 0; i < root.workspaces.length; i++)
      if (root.workspaces[i].id === active) root.selectedIndex = i
    root.dragAddress = ""
    root.opened = true
    // refreshToplevels は非同期で、直後は lastIpcObject が空のことがある。少し待って作り直す
    refreshSoon.restart()
    refreshLater.restart()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
    root.dragAddress = ""
  }

  function dismiss() {
    root.close()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "dotfiles.overview")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  // ---------------------------------------------------------------- Hyprland 操作

  function dispatch(expression) {
    Quickshell.execDetached(["hyprctl", "dispatch", expression])
  }

  function goWorkspace(id) {
    root.dismiss()
    root.dispatch("hl.dsp.focus({ workspace = \"" + id + "\" })")
  }

  function goEmptyWorkspace() {
    root.dismiss()
    root.dispatch("hl.dsp.focus({ workspace = \"empty\" })")
  }

  function focusWindow(address) {
    root.dismiss()
    root.dispatch("hl.dsp.focus({ window = \"address:" + address + "\" })")
  }

  function moveWindow(address, workspaceId) {
    root.dispatch("hl.dsp.window.move({ workspace = \"" + workspaceId + "\", follow = false, window = \"address:" + address + "\" })")
    refreshSoon.restart()
  }

  // ---------------------------------------------------------------- モデル

  function monitorGeometry(monitor) {
    if (!monitor) return { x: 0, y: 0, w: 1920, h: 1080 }
    var scale = monitor.scale > 0 ? monitor.scale : 1
    return { x: monitor.x, y: monitor.y, w: monitor.width / scale, h: monitor.height / scale }
  }

  function rebuild() {
    var list = []
    var byId = {}
    var wsValues = Hyprland.workspaces.values
    for (var i = 0; i < wsValues.length; i++) {
      var ws = wsValues[i]
      if (!ws || ws.id <= 0) continue // special workspace (ドロップダウン等) は出さない
      var entry = {
        id: ws.id,
        name: String(ws.name || ws.id),
        active: Hyprland.focusedWorkspace === ws,
        monitor: ws.monitor,
        geo: root.monitorGeometry(ws.monitor),
        windows: []
      }
      byId[ws.id] = entry
      list.push(entry)
    }

    var tops = Hyprland.toplevels.values
    for (var j = 0; j < tops.length; j++) {
      var t = tops[j]
      var ipc = t ? t.lastIpcObject : null
      // lastIpcObject の配列は QVariantList なので Array.isArray では判定できない
      if (!ipc || !ipc.workspace || !ipc.at || !ipc.size || ipc.at.length < 2 || ipc.size.length < 2) continue
      var target = byId[ipc.workspace.id]
      if (!target || ipc.hidden) continue
      target.windows.push({
        toplevel: t,
        address: String(ipc.address || t.address || "").replace(/^0x/, "0x"),
        x: ipc.at[0] - target.geo.x,
        y: ipc.at[1] - target.geo.y,
        w: ipc.size[0],
        h: ipc.size[1],
        floating: !!ipc.floating,
        title: String(ipc.title || ""),
        cls: String(ipc["class"] || "")
      })
    }
    // フローティングは手前に描く
    for (var k = 0; k < list.length; k++)
      list[k].windows.sort(function(a, b) { return (a.floating ? 1 : 0) - (b.floating ? 1 : 0) })

    list.sort(function(a, b) { return a.id - b.id })
    root.workspaces = list
    if (root.selectedIndex >= root.slotCount) root.selectedIndex = root.slotCount - 1
  }

  Timer {
    id: refreshSoon
    interval: 120
    onTriggered: {
      Hyprland.refreshWorkspaces()
      Hyprland.refreshToplevels()
      Qt.callLater(root.rebuild)
    }
  }

  Timer {
    id: refreshLater
    interval: 450
    onTriggered: root.rebuild()
  }

  // 開いている間にウィンドウが増減・移動したら作り直す
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (!root.opened) return
      var n = event && event.name ? String(event.name) : ""
      if (/^(openwindow|closewindow|movewindow|createworkspace|destroyworkspace|changefloatingmode|fullscreen)/.test(n))
        refreshSoon.restart()
    }
  }

  // ---------------------------------------------------------------- 選択

  function activateSelected() {
    if (root.selectedIndex >= root.workspaces.length) root.goEmptyWorkspace()
    else root.goWorkspace(root.workspaces[root.selectedIndex].id)
  }

  function moveSelection(dx, dy) {
    var i = root.selectedIndex + dx + dy * root.columns
    if (i < 0 || i >= root.slotCount) return
    root.selectedIndex = i
  }

  function slotAt(point) {
    for (var i = 0; i < cardRepeater.count; i++) {
      var card = cardRepeater.itemAt(i)
      if (!card) continue
      var p = card.mapFromItem(content, point.x, point.y)
      if (p.x >= 0 && p.y >= 0 && p.x <= card.width && p.y <= card.height) return i
    }
    return -1
  }

  // ---------------------------------------------------------------- 画面

  OverlayWindow {
    id: panel
    shown: root.opened
    WlrLayershell.namespace: "dotfiles-overview"

    Item {
      id: content
      anchors.fill: parent

      Rectangle {
        anchors.fill: parent
        color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.82)
      }

      MouseArea {
        anchors.fill: parent
        onClicked: root.dismiss()
      }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          var k = event.key
          if (k === Qt.Key_Escape) root.dismiss()
          else if (k === Qt.Key_Left || k === Qt.Key_H) root.moveSelection(-1, 0)
          else if (k === Qt.Key_Right || k === Qt.Key_L) root.moveSelection(1, 0)
          else if (k === Qt.Key_Up || k === Qt.Key_K) root.moveSelection(0, -1)
          else if (k === Qt.Key_Down || k === Qt.Key_J) root.moveSelection(0, 1)
          else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) root.activateSelected()
          else if (k >= Qt.Key_1 && k <= Qt.Key_9) root.goWorkspace(k - Qt.Key_0)
          else return
          event.accepted = true
        }
      }

      Text {
        id: heading
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: grid.top
        anchors.bottomMargin: 28
        text: "Workspaces"
        color: root.foreground
        opacity: 0.85
        font.family: root.fontFamily
        font.pixelSize: 22
        font.weight: Font.DemiBold
      }

      Grid {
        id: grid
        anchors.centerIn: parent
        columns: root.columns
        spacing: 28

        // 1枚のカード幅: 画面に収まる最大 (上限 520px)
        readonly property real cardWidth: Math.min(520,
          (content.width * 0.9 - spacing * (root.columns - 1)) / root.columns)
        readonly property real cardHeight: cardWidth * 9 / 16

        scale: root.opened ? 1 : 0.94
        opacity: root.opened ? 1 : 0
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 140 } }

        Repeater {
          id: cardRepeater
          model: root.slotCount

          delegate: Item {
            id: card
            required property int index
            readonly property bool isAdd: index >= root.workspaces.length
            readonly property var ws: isAdd ? null : root.workspaces[index]
            readonly property bool selected: root.selectedIndex === index
            readonly property bool dropTarget: root.dragAddress !== "" && root.slotAt(root.dragPoint) === index

            width: grid.cardWidth
            height: isAdd ? grid.cardHeight : grid.cardWidth * (ws.geo.h / ws.geo.w)

            Rectangle {
              id: frame
              anchors.fill: parent
              radius: root.cornerRadius
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
              border.width: card.selected || card.dropTarget ? 3 : 1
              border.color: card.selected || card.dropTarget ? root.accent : Qt.rgba(root.border.r, root.border.g, root.border.b, 0.35)
              scale: hover.containsMouse && root.dragAddress === "" ? 1.03 : 1
              Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
              Behavior on border.width { NumberAnimation { duration: 100 } }

              // 「+」カード
              Text {
                visible: card.isAdd
                anchors.centerIn: parent
                text: "+"
                color: root.foreground
                opacity: 0.6
                font.pixelSize: 64
                font.family: root.fontFamily
              }

              // ワークスペースの縮小図
              Item {
                id: screen
                visible: !card.isAdd
                anchors.fill: parent
                anchors.margins: 6
                clip: true
                readonly property real k: card.isAdd ? 1 : width / card.ws.geo.w

                Repeater {
                  model: card.isAdd ? [] : card.ws.windows
                  delegate: Rectangle {
                    id: win
                    required property var modelData
                    x: modelData.x * screen.k
                    y: modelData.y * screen.k
                    width: Math.max(8, modelData.w * screen.k)
                    height: Math.max(8, modelData.h * screen.k)
                    radius: Math.max(3, root.cornerRadius * screen.k)
                    color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
                    border.width: winHover.containsMouse ? 2 : 0
                    border.color: root.accent
                    opacity: root.dragAddress === modelData.address ? 0.35 : 1
                    clip: true

                    ScreencopyView {
                      id: thumb
                      anchors.fill: parent
                      captureSource: root.opened && win.modelData.toplevel ? win.modelData.toplevel.wayland : null
                      live: root.opened
                      paintCursor: false
                      constraintSize: Qt.size(win.width * 2, win.height * 2)
                    }

                    // サムネイルが取れないときはアプリ名
                    Text {
                      visible: !thumb.hasContent
                      anchors.centerIn: parent
                      width: parent.width - 8
                      horizontalAlignment: Text.AlignHCenter
                      elide: Text.ElideRight
                      text: win.modelData.cls || win.modelData.title
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: 11
                    }

                    MouseArea {
                      id: winHover
                      anchors.fill: parent
                      hoverEnabled: true
                      preventStealing: true
                      property point pressAt: Qt.point(0, 0)
                      onPressed: function(mouse) { pressAt = Qt.point(mouse.x, mouse.y) }
                      onPositionChanged: function(mouse) {
                        if (!pressed) return
                        var moved = Math.abs(mouse.x - pressAt.x) + Math.abs(mouse.y - pressAt.y)
                        if (root.dragAddress === "" && moved > 8) {
                          root.dragAddress = win.modelData.address
                          root.dragTitle = win.modelData.cls || win.modelData.title
                        }
                        if (root.dragAddress !== "") root.dragPoint = win.mapToItem(content, mouse.x, mouse.y)
                      }
                      onReleased: function(mouse) {
                        if (root.dragAddress === "") return
                        var target = root.slotAt(root.dragPoint)
                        var address = root.dragAddress
                        root.dragAddress = ""
                        if (target < 0) return
                        if (target >= root.workspaces.length) {
                          root.dispatch("hl.dsp.window.move({ workspace = \"empty\", follow = false, window = \"address:" + address + "\" })")
                          refreshSoon.restart()
                        } else if (root.workspaces[target].id !== card.ws.id) {
                          root.moveWindow(address, root.workspaces[target].id)
                        }
                      }
                      onClicked: if (root.dragAddress === "") root.focusWindow(win.modelData.address)
                    }
                  }
                }
              }

              // 番号バッジ
              Rectangle {
                visible: !card.isAdd
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 10
                width: badge.implicitWidth + 16
                height: badge.implicitHeight + 6
                radius: height / 2
                color: card.ws && card.ws.active ? root.accent : Qt.rgba(root.background.r, root.background.g, root.background.b, 0.85)
                Text {
                  id: badge
                  anchors.centerIn: parent
                  text: card.ws ? card.ws.name : ""
                  color: card.ws && card.ws.active ? root.accentText : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: 13
                  font.weight: Font.DemiBold
                }
              }
            }

            // カード全体 (ウィンドウの無い所) のクリック
            MouseArea {
              id: hover
              anchors.fill: parent
              hoverEnabled: true
              z: -1
              onEntered: if (root.dragAddress === "") root.selectedIndex = card.index
              onClicked: card.isAdd ? root.goEmptyWorkspace() : root.goWorkspace(card.ws.id)
            }
          }
        }
      }

      // ドラッグ中にカーソルに付いてくる札
      Rectangle {
        visible: root.dragAddress !== ""
        x: root.dragPoint.x + 12
        y: root.dragPoint.y + 12
        width: dragLabel.implicitWidth + 20
        height: dragLabel.implicitHeight + 10
        radius: height / 2
        color: root.accent
        Text {
          id: dragLabel
          anchors.centerIn: parent
          text: root.dragTitle
          color: root.accentText
          font.family: root.fontFamily
          font.pixelSize: 13
        }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: grid.bottom
        anchors.topMargin: 24
        text: "クリックで移動 · ウィンドウをドラッグで別のワークスペースへ · ←→↑↓ / Enter · 1〜9 · Esc"
        color: root.foreground
        opacity: 0.5
        font.family: root.fontFamily
        font.pixelSize: 12
      }
    }
  }
}
