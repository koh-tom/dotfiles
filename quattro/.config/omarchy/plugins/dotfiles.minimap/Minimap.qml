// Workspace Minimap — Pond デスクトップのサイドバー風に、ワークスペースごとの
// ウィンドウをアプリアイコンで並べるバーウィジェット (omarchy.workspaces の置き換え)
//
//   左クリック   アイコン = そのウィンドウへフォーカス / グループ = そのワークスペースへ
//                「+」 = 空いているワークスペースへ
//   右ドラッグ   アイコンを別のグループ (か「+」) へ落とす = ウィンドウをそこへ移動
//                (左ドラッグはバー本体がウィジェットの並べ替えに使うので取れない)
//   ホイール     ワークスペースを前後に移動
//
// shell.json の bar.layout に { "id": "dotfiles.minimap" } を置くと有効になる。
// 設定 (エントリに書く。すべて省略可):
//   persistent  常に出すワークスペース数 (既定 5。空なら点で出す)
//   maxIcons    1グループに並べるアイコンの上限 (既定 6。超えた分は +N)
//   showPlus    末尾の「+」を出すか (既定 true)
//   iconSize    アイコンの一辺 (既定 Style.bar.iconCanvas)
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "dotfiles.minimap"

  // ---------------------------------------------------------------- 設定・見た目

  readonly property int persistent: Math.max(0, Math.min(10, Number(root.setting("persistent", 5)) || 0))
  readonly property int maxIcons: Math.max(1, Number(root.setting("maxIcons", 6)) || 6)
  readonly property bool showPlus: root.setting("showPlus", true) !== false
  readonly property int iconSize: Math.max(8, Number(root.setting("iconSize", Style.bar.iconCanvas)) || Style.bar.iconCanvas)

  // グループの内側の余白 (バーの太さ方向 / 並び方向)
  readonly property int padCross: Math.max(2, Math.floor((root.barSize - root.iconSize) / 2) - 2)
  readonly property int padAlong: Style.space(4)
  readonly property int thickness: root.iconSize + root.padCross * 2
  readonly property int iconGap: Style.space(3)
  readonly property int groupGap: Style.space(4)
  readonly property int radius: Math.max(4, Math.min(Math.round(root.thickness / 2), Style.cornerRadius > 0 ? Style.cornerRadius : 6))

  readonly property color fg: root.bar ? root.bar.foreground : Commons.Color.bar.text
  readonly property color accent: Commons.Color.accent
  readonly property color urgentColor: root.bar ? root.bar.urgent : Commons.Color.urgent
  readonly property string fontFamily: root.bar && root.bar.fontFamily ? root.bar.fontFamily : Style.fontFamily

  function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

  // ---------------------------------------------------------------- モニタ・ワークスペース番号
  // omarchy.workspaces と同じく、モニタごとに 10 個ずつのブロック (1-10, 11-20, ...) を持つ

  readonly property int slots: 10

  readonly property var monitor: {
    var window = root.QsWindow.window
    var screen = window ? window.screen : null
    return screen ? Hyprland.monitorFor(screen) : Hyprland.focusedMonitor
  }
  readonly property string monitorName: root.monitor ? root.monitor.name : ""

  property var blocks: ({})

  function readBlocks(text) {
    var next = {}
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var fields = lines[i].split("\t")
      if (fields.length >= 3 && fields[1] !== "") next[fields[1]] = parseInt(fields[0], 10)
    }
    root.blocks = next
  }

  FileView {
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/omarchy/monitor-workspaces"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readBlocks(text())
    onLoadFailed: root.readBlocks("")
  }

  function blockOf(id) { return Math.floor((id - 1) / root.slots) }
  function slotOf(id) { return (id - 1) % root.slots + 1 }

  function activeWorkspaceId() {
    return root.monitor && root.monitor.activeWorkspace ? root.monitor.activeWorkspace.id : -1
  }

  readonly property int block: {
    var b = root.blocks[root.monitorName]
    if (b !== undefined && !isNaN(b)) return b
    var active = root.activeWorkspaceId()
    return active > 0 ? root.blockOf(active) : 0
  }

  // 自分のブロックの先頭 persistent 個 + 存在するもの + 他モニタから来ている客
  function workspaceIds() {
    var base = root.block * root.slots
    var ids = []
    for (var p = 1; p <= root.persistent; p++) ids.push(base + p)
    var guests = []
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id <= 0) continue // special (minimized / scratchpad 等) は出さない
      if (root.blockOf(id) === root.block) {
        if (ids.indexOf(id) === -1) ids.push(id)
      } else if (values[i].monitor && values[i].monitor.name === root.monitorName) {
        if (guests.indexOf(id) === -1) guests.push(id)
      }
    }
    var active = root.activeWorkspaceId()
    if (active > 0 && ids.indexOf(active) === -1 && guests.indexOf(active) === -1) {
      if (root.blockOf(active) === root.block) ids.push(active)
      else guests.push(active)
    }
    ids.sort(function(a, b) { return a - b })
    guests.sort(function(a, b) { return a - b })
    return ids.concat(guests)
  }

  // ---------------------------------------------------------------- アイコン解決 (dock と同じ流儀)

  property var iconCache: ({})

  function iconFor(appId) {
    var key = String(appId || "")
    if (!key) return ""
    if (root.iconCache[key] !== undefined) return root.iconCache[key]
    var source = ""
    var entry = DesktopEntries.heuristicLookup(key)
    var name = entry && entry.icon ? String(entry.icon) : ""
    if (name.indexOf("file://") === 0 || name.indexOf("image://") === 0) source = name
    else if (name.charAt(0) === "/") source = "file://" + name
    else if (name) source = Quickshell.iconPath(name, true)
    if (!source) source = Quickshell.iconPath(key, true)
    if (!source) source = Quickshell.iconPath(key.toLowerCase(), true)
    if (!source) {
      // org.foo.Bar → bar
      var tail = key.split(".").pop()
      if (tail && tail !== key) source = Quickshell.iconPath(tail.toLowerCase(), true)
    }
    root.iconCache[key] = source
    return source
  }

  // アプリが入った/消えたらキャッシュを捨てる
  readonly property int appsRevision: DesktopEntries.applications.values.length
  onAppsRevisionChanged: { root.iconCache = ({}); root.scheduleRebuild() }

  // ---------------------------------------------------------------- モデル

  // [{ id, slot, active, windows: [{ address, appId, title, icon, focused, urgent }] }]
  property var groups: []
  property string groupsKey: ""
  property int plusId: -1

  function normalizeAddress(address) {
    var a = String(address || "")
    if (!a) return ""
    return a.indexOf("0x") === 0 ? a : "0x" + a
  }

  function rebuild() {
    var ids = root.workspaceIds()
    var active = root.activeWorkspaceId()
    var byId = {}
    var list = []
    for (var i = 0; i < ids.length; i++) {
      var g = { id: ids[i], slot: root.slotOf(ids[i]), active: ids[i] === active, windows: [] }
      byId[ids[i]] = g
      list.push(g)
    }

    var tops = Hyprland.toplevels.values
    for (var j = 0; j < tops.length; j++) {
      var t = tops[j]
      if (!t) continue
      var ipc = t.lastIpcObject
      var wsId = t.workspace ? t.workspace.id : (ipc && ipc.workspace ? ipc.workspace.id : -1)
      var target = byId[wsId]
      if (!target) continue
      var wl = t.wayland
      if (wl && wl.parent) continue // ダイアログは親アプリのアイコンで足りる
      var appId = wl && wl.appId ? String(wl.appId) : (ipc && ipc["class"] ? String(ipc["class"]) : "")
      var address = root.normalizeAddress(t.address || (ipc ? ipc.address : ""))
      if (!address) continue
      // lastIpcObject の配列は QVariantList なので Array.isArray では判定できない
      var at = ipc && ipc.at && ipc.at.length >= 2 ? ipc.at : null
      target.windows.push({
        address: address,
        appId: appId,
        title: String(t.title || (ipc ? ipc.title : "") || appId),
        icon: root.iconFor(appId),
        focused: !!t.activated,
        urgent: !!t.urgent,
        x: at ? Number(at[0]) : 0,
        y: at ? Number(at[1]) : 0
      })
    }

    for (var k = 0; k < list.length; k++)
      list[k].windows.sort(function(a, b) { return a.x - b.x || a.y - b.y })

    // 「+」: 自分のブロックで、窓が無く今見ていない最初の番号
    var base = root.block * root.slots
    var plus = -1
    for (var s = 1; s <= root.slots; s++) {
      var cand = base + s
      var g2 = byId[cand]
      if (cand !== active && (!g2 || g2.windows.length === 0)) { plus = cand; break }
    }

    var key = JSON.stringify([list, plus])
    if (key === root.groupsKey) return
    root.groupsKey = key
    root.plusId = plus
    root.groups = list
  }

  function scheduleRebuild() { rebuildTimer.restart() }

  Timer {
    id: rebuildTimer
    interval: 60
    onTriggered: root.rebuild()
  }

  // refreshToplevels は非同期なので、答えが返ってきた頃にもう一度作り直す
  Timer {
    id: rebuildLater
    interval: 350
    onTriggered: root.rebuild()
  }

  Timer {
    id: refreshTimer
    interval: 80
    onTriggered: {
      Hyprland.refreshToplevels()
      root.scheduleRebuild()
      rebuildLater.restart()
    }
  }

  // モデルが増減したとき・見ているワークスペースが変わったとき
  readonly property int modelSignature: Hyprland.toplevels.values.length * 1000 + Hyprland.workspaces.values.length
  onModelSignatureChanged: root.scheduleRebuild()
  readonly property int shownWorkspace: root.activeWorkspaceId()
  onShownWorkspaceChanged: root.scheduleRebuild()
  onBlockChanged: root.scheduleRebuild()
  onPersistentChanged: root.scheduleRebuild()
  onMonitorChanged: root.scheduleRebuild()

  Component.onCompleted: {
    Hyprland.refreshToplevels()
    root.scheduleRebuild()
    rebuildLater.restart()
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event && event.name ? String(event.name) : ""
      // omarchy.workspaces と同じ補正: どのモニタが切り替わったかはイベントから分からない
      var switched = name === "workspacev2" && root.monitor !== null && root.monitor.focused
      if (switched || name === "moveworkspacev2" || name === "changeworkspaceid") {
        Hyprland.refreshMonitors()
        Hyprland.refreshWorkspaces()
      }
      if (/^(openwindow|closewindow|movewindow|windowtitle)/.test(name)) refreshTimer.restart()
      else if (/^(workspace|createworkspace|destroyworkspace|activewindow|urgent|focusedmon|moveworkspace|renameworkspace|changeworkspaceid|activespecial)/.test(name)) root.scheduleRebuild()
    }
  }

  // ---------------------------------------------------------------- Hyprland 操作

  function dispatch(expression) {
    Quickshell.execDetached(["hyprctl", "dispatch", expression])
  }

  function focusWorkspace(id) {
    if (id <= 0) return
    if (root.blockOf(id) === root.block && root.monitorName) {
      root.dispatch("o.workspaces.focus(" + root.slotOf(id) + ", \"" + root.monitorName + "\")")
    } else {
      root.dispatch("hl.dsp.focus({ workspace = \"" + id + "\" })")
    }
  }

  function focusEmpty() {
    if (root.plusId > 0) root.focusWorkspace(root.plusId)
    else root.dispatch("hl.dsp.focus({ workspace = \"empty\" })")
  }

  function focusWindow(address) {
    root.dispatch("hl.dsp.focus({ window = \"address:" + address + "\" })")
  }

  function moveWindow(address, workspace) {
    root.dispatch("hl.dsp.window.move({ workspace = \"" + workspace + "\", follow = false, window = \"address:" + address + "\" })")
    refreshTimer.restart()
  }

  // ---------------------------------------------------------------- クリック
  // バーは各ウィジェットの上に自前の MouseArea を被せて左ボタンを取り、
  // クリックを「クリック対象」の triggerPress(button) に回す。ここでは
  // ウィジェット自体を対象にし、ホバー中の部品で行き先を決める。

  property int heldButtons: Qt.NoButton

  function triggerPress(button) {
    for (var i = 0; i < groupRepeater.count; i++) {
      var group = groupRepeater.itemAt(i)
      if (!group || !group.hovered) continue
      var address = group.hoveredAddress()
      if (address) root.focusWindow(address)
      else root.focusWorkspace(group.modelData.id)
      return
    }
    if (plusButton.visible && plusButton.hovered) root.focusEmpty()
  }

  // ---------------------------------------------------------------- ホイール

  property real wheelAccumulator: 0

  function scrollWorkspaces(delta) {
    var wheel = Util.wheelSteps(root.wheelAccumulator, delta)
    root.wheelAccumulator = wheel.remainder
    if (wheel.steps === 0) return
    var ids = root.workspaceIds()
    var index = ids.indexOf(root.activeWorkspaceId())
    if (index === -1) return
    var target = ids[Util.clamp(index - wheel.steps, 0, ids.length - 1)]
    if (target !== ids[index]) root.focusWorkspace(target)
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    onWheel: function(wheel) {
      root.scrollWorkspaces(wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.angleDelta.x)
      wheel.accepted = true
    }
  }

  // ---------------------------------------------------------------- 右ドラッグでウィンドウ移動

  property string dragAddress: ""
  property string dragIcon: ""
  property string dragAppId: ""
  property int dragFromId: -1
  property point dragPoint: Qt.point(0, 0)
  // -1 = どこでもない、-2 = 「+」、それ以外 = groups の添字
  readonly property int dropIndex: root.dragAddress !== "" ? root.dropIndexAt(root.dragPoint) : -1

  function contains(item, point) {
    if (!item || !item.visible) return false
    var p = item.mapFromItem(root, point.x, point.y)
    return p.x >= 0 && p.y >= 0 && p.x <= item.width && p.y <= item.height
  }

  function dropIndexAt(point) {
    for (var i = 0; i < groupRepeater.count; i++)
      if (root.contains(groupRepeater.itemAt(i), point)) return i
    if (root.contains(plusButton, point)) return -2
    return -1
  }

  function finishDrag() {
    var address = root.dragAddress
    var index = root.dropIndex
    var from = root.dragFromId
    root.dragAddress = ""
    if (!address) return
    if (index === -2) {
      if (root.plusId > 0) root.moveWindow(address, root.plusId)
      else root.moveWindow(address, "empty")
    } else if (index >= 0 && index < root.groups.length && root.groups[index].id !== from) {
      root.moveWindow(address, root.groups[index].id)
    }
  }

  // ---------------------------------------------------------------- 描画

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: root.vertical ? root.barSize : content.implicitWidth + root.trailingGap
  implicitHeight: root.vertical ? content.implicitHeight + Style.space(4) : root.barSize

  Grid {
    id: content
    x: root.vertical ? Math.round((root.width - width) / 2) : 0
    y: root.vertical ? Style.space(2) : Math.round((root.height - height) / 2)
    rows: root.vertical ? -1 : 1
    columns: root.vertical ? 1 : -1
    spacing: root.groupGap
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter

    Repeater {
      id: groupRepeater
      model: root.groups

      delegate: Rectangle {
        id: group
        required property var modelData
        required property int index

        readonly property bool empty: modelData.windows.length === 0
        readonly property bool active: modelData.active
        readonly property bool dropTarget: root.dropIndex === index && root.dragFromId !== modelData.id
        readonly property bool hovered: groupHover.hovered
        readonly property var shown: modelData.windows.slice(0, root.maxIcons)
        readonly property int overflow: Math.max(0, modelData.windows.length - root.maxIcons)
        // 空のワークスペースは番号だけの細い枠 (標準の omarchy.workspaces と同じ見た目)
        readonly property int emptyLength: Math.max(Math.round(root.thickness * 0.75), emptyLabel.implicitWidth + 6)
        readonly property real along: empty ? emptyLength : icons.implicitLength + root.padAlong * 2

        function hoveredAddress() {
          for (var i = 0; i < iconRepeater.count; i++) {
            var icon = iconRepeater.itemAt(i)
            if (icon && icon.hovered) return icon.modelData.address
          }
          return ""
        }

        width: root.vertical ? root.thickness : along
        height: root.vertical ? along : root.thickness
        radius: root.radius
        color: active ? root.tint(root.accent, 0.22)
          : dropTarget ? root.tint(root.accent, 0.14)
          : empty ? (hovered ? root.tint(root.fg, 0.08) : "transparent")
          : root.tint(root.fg, hovered ? 0.12 : 0.06)
        border.width: active || dropTarget ? 1 : 0
        border.color: root.accent

        Behavior on width { enabled: !root.vertical; NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }
        Behavior on height { enabled: root.vertical; NumberAnimation { duration: Style.duration(120); easing.type: Easing.OutCubic } }
        Behavior on color { ColorAnimation { duration: Style.duration(120) } }

        HoverHandler { id: groupHover }

        // 空: 番号 (モニタごとのスロット番号。標準のワークスペース表示と同じ数字)
        Text {
          id: emptyLabel
          visible: group.empty
          anchors.centerIn: parent
          text: String(group.modelData.slot || group.modelData.id)
          color: group.active ? root.accent : root.fg
          opacity: group.active ? 1 : (group.hovered ? 0.9 : 0.55)
          font.family: root.fontFamily
          font.pixelSize: Math.round(root.thickness * 0.5)
          font.bold: group.active
        }

        // 窓あり: アイコンの列
        Grid {
          id: icons
          visible: !group.empty
          readonly property real implicitLength: root.vertical ? implicitHeight : implicitWidth
          anchors.centerIn: parent
          rows: root.vertical ? -1 : 1
          columns: root.vertical ? 1 : -1
          spacing: root.iconGap
          horizontalItemAlignment: Grid.AlignHCenter
          verticalItemAlignment: Grid.AlignVCenter

          Repeater {
            id: iconRepeater
            model: group.shown

            delegate: Item {
              id: iconItem
              required property var modelData
              readonly property bool hovered: iconHover.hovered
              readonly property bool dragged: root.dragAddress === modelData.address

              width: root.iconSize
              height: root.iconSize
              opacity: dragged ? 0.3 : 1

              Image {
                id: image
                anchors.fill: parent
                source: iconItem.modelData.icon
                sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                asynchronous: true
                cache: true
                scale: iconItem.hovered && root.dragAddress === "" ? 1.15 : 1
                Behavior on scale { NumberAnimation { duration: Style.duration(100) } }
              }

              // アイコンが無いアプリは頭文字
              Rectangle {
                visible: image.status !== Image.Ready
                anchors.fill: parent
                radius: Math.round(width * 0.25)
                color: root.tint(root.fg, 0.18)
                Text {
                  anchors.centerIn: parent
                  text: (iconItem.modelData.appId || iconItem.modelData.title || "?").replace(/^.*\./, "").charAt(0).toUpperCase()
                  color: root.fg
                  font.family: root.fontFamily
                  font.pixelSize: Math.round(root.iconSize * 0.7)
                  font.bold: true
                }
              }

              // フォーカス中の窓 = 下線 (縦バーでは左の縦線)、urgent = 点
              Rectangle {
                readonly property bool urgent: iconItem.modelData.urgent
                readonly property int mark: Math.round(root.iconSize * 0.5)
                visible: iconItem.modelData.focused || urgent
                width: urgent ? 4 : (root.vertical ? 2 : mark)
                height: urgent ? 4 : (root.vertical ? mark : 2)
                radius: Math.min(width, height) / 2
                color: urgent ? root.urgentColor : root.accent
                x: root.vertical ? -width - 1 : Math.round((parent.width - width) / 2)
                y: root.vertical ? Math.round((parent.height - height) / 2) : parent.height + 1
              }

              HoverHandler {
                id: iconHover
                onHoveredChanged: {
                  if (!root.bar) return
                  if (hovered && root.dragAddress === "") root.bar.showTooltip(iconItem, iconItem.modelData.title)
                  else root.bar.hideTooltip(iconItem)
                }
              }

              MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                preventStealing: true
                property point pressAt: Qt.point(0, 0)
                onPressed: function(mouse) { pressAt = Qt.point(mouse.x, mouse.y) }
                onPositionChanged: function(mouse) {
                  if (!pressed) return
                  var moved = Math.abs(mouse.x - pressAt.x) + Math.abs(mouse.y - pressAt.y)
                  if (root.dragAddress === "" && moved > 4) {
                    root.dragAddress = iconItem.modelData.address
                    root.dragIcon = iconItem.modelData.icon
                    root.dragAppId = iconItem.modelData.appId
                    root.dragFromId = group.modelData.id
                    if (root.bar) root.bar.hideTooltip(iconItem)
                  }
                  if (root.dragAddress !== "") root.dragPoint = iconItem.mapToItem(root, mouse.x, mouse.y)
                }
                onReleased: root.finishDrag()
                onCanceled: root.dragAddress = ""
              }
            }
          }

          Text {
            visible: group.overflow > 0
            text: "+" + group.overflow
            color: root.fg
            opacity: 0.7
            font.family: root.fontFamily
            font.pixelSize: Math.round(root.iconSize * 0.65)
          }
        }
      }
    }

    // 「+」: 空いているワークスペースへ
    Rectangle {
      id: plusButton
      visible: root.showPlus
      readonly property bool hovered: plusHover.hovered
      readonly property bool dropTarget: root.dropIndex === -2
      width: root.thickness
      height: root.thickness
      radius: root.radius
      color: dropTarget ? root.tint(root.accent, 0.14) : hovered ? root.tint(root.fg, 0.08) : "transparent"
      border.width: dropTarget ? 1 : 0
      border.color: root.accent

      HoverHandler { id: plusHover }

      Text {
        anchors.centerIn: parent
        text: "+"
        color: plusButton.dropTarget ? root.accent : root.fg
        opacity: plusButton.hovered || plusButton.dropTarget ? 0.9 : 0.45
        font.family: root.fontFamily
        font.pixelSize: Math.round(root.iconSize * 0.9)
      }
    }
  }

  // ドラッグ中にカーソルへ付いてくるアイコン
  Image {
    visible: root.dragAddress !== "" && root.dragIcon !== ""
    z: 100
    width: root.iconSize
    height: root.iconSize
    x: root.dragPoint.x - width / 2
    y: root.dragPoint.y - height / 2
    source: root.dragIcon
    sourceSize: Qt.size(root.iconSize * 2, root.iconSize * 2)
    smooth: true
    opacity: 0.85
  }
}
