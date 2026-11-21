// Claude Code mission control — 動いている Claude Code セッションの一覧 (Omarchy shell の overlay プラグイン)
//
//   開く:   omarchy-shell shell toggle dotfiles.claude (キーバインドとバーの ✳ ピルから)
//   操作:   クリック / Enter = そのセッションの WezTerm タブ・ペインへ移動してウィンドウを前に出す
//           ↑ ↓ / j k = 選択、1〜9 = その番号へ、r = 再読み込み、Esc・外側クリック = 閉じる
//
// 一覧は scripts/claude-sessions (wezterm cli list + hook が書く状態ファイル) の JSON。
// 開いた時と、開いている間は 2 秒ごとに読み直す。経過時間の表示は 1 秒ごとに進める。
// 有効化は shell.json の plugins[] に { "id": "dotfiles.claude" } があること。
import QtQuick
import Quickshell
import Quickshell.Io
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
  // claude-sessions の出力そのまま: [{ pane_id, tab_id, title, project, cwd, state, since, prompt, message, focused, ... }]
  property var sessions: []
  property bool loaded: false
  property string loadError: ""
  property real nowSec: Date.now() / 1000

  readonly property string helper: Quickshell.env("HOME") + "/dotfiles/scripts/claude-sessions"

  property color background: Commons.Color.menu.background
  property color foreground: Commons.Color.menu.text
  property color border: Commons.Color.menu.border
  property color selectedBackground: Commons.Color.menu.selectedBackground
  property color selectedText: Commons.Color.menu.selectedText
  property color scrim: Commons.Color.menu.scrim
  readonly property int cornerRadius: Math.max(8, Style.cornerRadius)
  property string fontFamily: Style.font.menuFamily

  // 状態の色: 作業中は Claude のオレンジ (WezTerm のタブ・バーのピルと同じ)、許可待ちは urgent、入力待ちは accent
  readonly property color workingColor: "#d97757"
  readonly property color waitingColor: Commons.Color.accent
  readonly property color attentionColor: Commons.Color.urgent

  // ---------------------------------------------------------------- 開閉

  function open(payloadJson) {
    root.selectedIndex = 0
    root.nowSec = Date.now() / 1000
    root.opened = true
    root.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.close()
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide((root.manifest && root.manifest.id) || "dotfiles.claude")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  // ---------------------------------------------------------------- データ

  function refresh() {
    if (!lister.running) lister.running = true
  }

  function applyListing(text) {
    var list
    try {
      list = JSON.parse(String(text || "[]"))
    } catch (e) {
      root.loadError = "claude-sessions の出力を読めませんでした"
      root.loaded = true
      return
    }
    if (!list || typeof list.length !== "number") list = []
    // 選択はペイン単位で保つ (並びが変わっても同じセッションを指す)
    var selectedPane = root.selectedIndex < root.sessions.length ? root.sessions[root.selectedIndex].pane_id : -1
    root.sessions = list
    root.loadError = ""
    root.loaded = true
    root.nowSec = Date.now() / 1000
    var index = 0
    for (var i = 0; i < list.length; i++)
      if (list[i].pane_id === selectedPane) index = i
    root.selectedIndex = Math.min(index, Math.max(0, list.length - 1))
  }

  Process {
    id: lister
    running: false
    command: [root.helper]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyListing(text)
    }
  }

  Timer {
    interval: 2000
    repeat: true
    running: root.opened
    onTriggered: root.refresh()
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.opened
    onTriggered: root.nowSec = Date.now() / 1000
  }

  // ---------------------------------------------------------------- 表示用

  function stateLabel(state) {
    if (state === "working") return "作業中"
    if (state === "waiting") return "入力待ち"
    if (state === "attention") return "許可待ち"
    return "不明"
  }

  function stateColor(state) {
    if (state === "working") return root.workingColor
    if (state === "waiting") return root.waitingColor
    if (state === "attention") return root.attentionColor
    return Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.4)
  }

  function formatElapsed(since) {
    if (since === null || since === undefined) return ""
    var s = Math.max(0, Math.floor(root.nowSec - since))
    if (s < 60) return s + "秒"
    var m = Math.floor(s / 60)
    if (m < 60) return m + "分"
    var h = Math.floor(m / 60)
    if (h < 24) return h + "時間" + (m % 60 > 0 ? (m % 60) + "分" : "")
    return Math.floor(h / 24) + "日"
  }

  function countOf(state) {
    var n = 0
    for (var i = 0; i < root.sessions.length; i++)
      if (root.sessions[i].state === state) n++
    return n
  }

  readonly property string summary: {
    var parts = []
    var a = countOf("attention"), w = countOf("waiting"), k = countOf("working")
    if (a > 0) parts.push("許可待ち " + a)
    if (w > 0) parts.push("入力待ち " + w)
    if (k > 0) parts.push("作業中 " + k)
    return parts.join(" · ")
  }

  // ---------------------------------------------------------------- 操作

  function jumpTo(index) {
    if (index < 0 || index >= root.sessions.length) return
    var pane = root.sessions[index].pane_id
    root.dismiss()
    Quickshell.execDetached([root.helper, "--jump", String(pane)])
  }

  function moveSelection(delta) {
    if (root.sessions.length === 0) return
    root.selectedIndex = (root.selectedIndex + delta + root.sessions.length) % root.sessions.length
  }

  // ---------------------------------------------------------------- 画面

  OverlayWindow {
    id: panel
    shown: root.opened
    WlrLayershell.namespace: "dotfiles-claude"

    Item {
      id: content
      anchors.fill: parent

      Rectangle {
        anchors.fill: parent
        color: root.scrim
      }

      // 外側クリックで閉じる
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
          else if (k === Qt.Key_Up || k === Qt.Key_K || (k === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier)) || k === Qt.Key_Backtab) root.moveSelection(-1)
          else if (k === Qt.Key_Down || k === Qt.Key_J || k === Qt.Key_Tab) root.moveSelection(1)
          else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space) root.jumpTo(root.selectedIndex)
          else if (k >= Qt.Key_1 && k <= Qt.Key_9) root.jumpTo(k - Qt.Key_1)
          else if (k === Qt.Key_R) root.refresh()
          else return
          event.accepted = true
        }
      }

      Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(820, content.width * 0.9)
        height: Math.min(content.height * 0.85, column.implicitHeight + 40)
        radius: root.cornerRadius
        color: root.background
        border.width: 1
        border.color: Qt.rgba(root.border.r, root.border.g, root.border.b, 0.35)
        clip: true

        scale: root.opened ? 1 : 0.96
        opacity: root.opened ? 1 : 0
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 120 } }

        // カードの中のクリックで閉じないように受け止める
        MouseArea { anchors.fill: parent }

        Column {
          id: column
          anchors.fill: parent
          anchors.margins: 20
          spacing: 14

          // 見出し
          Item {
            width: parent.width
            height: heading.implicitHeight

            Text {
              id: heading
              anchors.left: parent.left
              text: "✳ Claude Code"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: 20
              font.weight: Font.DemiBold
            }

            Text {
              anchors.right: parent.right
              anchors.verticalCenter: heading.verticalCenter
              text: root.sessions.length > 0 ? root.sessions.length + " セッション" + (root.summary !== "" ? "  ·  " + root.summary : "") : ""
              color: root.foreground
              opacity: 0.6
              font.family: root.fontFamily
              font.pixelSize: 13
            }
          }

          Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(root.border.r, root.border.g, root.border.b, 0.25)
          }

          // 空・読み込み中・エラー
          Text {
            visible: root.sessions.length === 0
            width: parent.width
            topPadding: 18
            bottomPadding: 18
            horizontalAlignment: Text.AlignHCenter
            text: root.loadError !== "" ? root.loadError
              : !root.loaded ? "読み込み中…"
              : "動いている Claude Code セッションはありません"
            color: root.foreground
            opacity: 0.6
            font.family: root.fontFamily
            font.pixelSize: 14
          }

          ListView {
            id: list
            visible: root.sessions.length > 0
            width: parent.width
            height: Math.min(contentHeight, content.height * 0.85 - 140)
            clip: true
            spacing: 6
            interactive: contentHeight > height
            boundsBehavior: Flickable.StopAtBounds
            model: root.sessions
            currentIndex: root.selectedIndex

            delegate: Rectangle {
              id: row
              required property var modelData
              required property int index
              readonly property bool selected: root.selectedIndex === index
              readonly property color tint: root.stateColor(modelData.state)
              readonly property string detail: modelData.state === "attention" && modelData.message ? modelData.message
                : modelData.prompt ? "› " + modelData.prompt : ""

              width: list.width
              height: 64
              radius: Math.max(6, root.cornerRadius - 2)
              color: selected ? root.selectedBackground : "transparent"
              border.width: selected ? 1 : 0
              border.color: Qt.rgba(row.tint.r, row.tint.g, row.tint.b, 0.6)

              // 左端の状態バー
              Rectangle {
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 4
                height: parent.height - 20
                radius: 2
                color: row.tint
              }

              // 番号 (1〜9 で選べる)
              Text {
                id: number
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
                width: 14
                text: row.index < 9 ? String(row.index + 1) : ""
                color: root.foreground
                opacity: 0.4
                font.family: root.fontFamily
                font.pixelSize: 13
              }

              // 状態の札
              Rectangle {
                id: badge
                anchors.left: number.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: 86
                height: 26
                radius: 13
                color: Qt.rgba(row.tint.r, row.tint.g, row.tint.b, 0.18)
                border.width: 1
                border.color: Qt.rgba(row.tint.r, row.tint.g, row.tint.b, 0.55)

                Rectangle {
                  id: dot
                  anchors.left: parent.left
                  anchors.leftMargin: 10
                  anchors.verticalCenter: parent.verticalCenter
                  width: 8
                  height: 8
                  radius: 4
                  color: row.tint
                  // 作業中はゆっくり明滅
                  SequentialAnimation on opacity {
                    running: root.opened && row.modelData.state === "working"
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 700; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 700; easing.type: Easing.InOutSine }
                    onRunningChanged: if (!running) dot.opacity = 1
                  }
                }

                Text {
                  anchors.left: dot.right
                  anchors.leftMargin: 6
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.stateLabel(row.modelData.state)
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: 12
                  font.weight: Font.DemiBold
                }
              }

              // 右端: 経過時間
              Column {
                id: meta
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 86
                spacing: 2

                Text {
                  width: parent.width
                  horizontalAlignment: Text.AlignRight
                  text: row.modelData.since !== null && row.modelData.since !== undefined
                    ? root.formatElapsed(row.modelData.since)
                    : "—"
                  color: root.foreground
                  opacity: 0.85
                  font.family: root.fontFamily
                  font.pixelSize: 13
                }

                Text {
                  width: parent.width
                  horizontalAlignment: Text.AlignRight
                  text: row.modelData.state_source === "hook" ? "この状態で" : "タイトルから推定"
                  color: root.foreground
                  opacity: 0.4
                  font.family: root.fontFamily
                  font.pixelSize: 10
                }
              }

              // 中央: プロジェクト · タイトル / 最後の入力
              Column {
                anchors.left: badge.right
                anchors.leftMargin: 14
                anchors.right: meta.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4

                Row {
                  width: parent.width
                  spacing: 8

                  Text {
                    id: project
                    text: row.modelData.project || "?"
                    color: row.selected ? root.selectedText : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                  }

                  Text {
                    width: Math.max(0, parent.width - project.implicitWidth - tabLabel.implicitWidth - 16)
                    anchors.baseline: project.baseline
                    text: row.modelData.title || ""
                    elide: Text.ElideRight
                    color: root.foreground
                    opacity: 0.75
                    font.family: root.fontFamily
                    font.pixelSize: 13
                  }

                  Text {
                    id: tabLabel
                    anchors.baseline: project.baseline
                    text: (row.modelData.focused ? "表示中 · " : "") + "pane " + row.modelData.pane_id
                    color: root.foreground
                    opacity: 0.35
                    font.family: root.fontFamily
                    font.pixelSize: 11
                  }
                }

                Text {
                  width: parent.width
                  visible: row.detail !== ""
                  text: row.detail
                  elide: Text.ElideRight
                  maximumLineCount: 1
                  color: row.modelData.state === "attention" ? row.tint : root.foreground
                  opacity: row.modelData.state === "attention" ? 0.95 : 0.55
                  font.family: root.fontFamily
                  font.pixelSize: 12
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.selectedIndex = row.index
                onClicked: root.jumpTo(row.index)
              }
            }
          }

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "クリック / Enter で移動 · ↑↓ / j k · 1〜9 · r 再読み込み · Esc"
            color: root.foreground
            opacity: 0.45
            font.family: root.fontFamily
            font.pixelSize: 11
          }
        }
      }
    }
  }
}
