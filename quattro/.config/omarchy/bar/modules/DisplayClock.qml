// 時刻だけを見出し用のセリフ体 (イタリック) で大きめに出すバーモジュール。Pond の「時計がデザインの顔」を参考にした。
// (dotfiles: quattro/.config/omarchy/bar/modules/DisplayClock.qml)
//
// shell.json の bar.layout に { "id": "display-clock", "type": "qml",
//   "source": "~/.config/omarchy/bar/modules/DisplayClock.qml" } で置く。
// 日付とカレンダーは隣の標準 omarchy.clock (format を日付だけにする) に任せる。
//
// settings (任意):
//   format      string  Qt の時刻書式 (既定 "HH:mm")
//   fontFamily  string  既定 "Noto Serif Display" (noto-fonts に含まれる)
//   italic      bool    既定 true
//   fontSize    number  px (既定: バーの文字より少し大きく)
//   color       string  既定はテーマの foreground
//   onClick     string  クリック時に dispatch する Hyprland の Lua 式 (既定: カレンダーを開く)
import QtQuick
import Quickshell
import qs.Commons as Commons

Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  property date now: new Date()

  implicitWidth: label.implicitWidth + 12
  implicitHeight: label.implicitHeight

  Timer {
    // 分の変わり目に合わせて更新する
    interval: 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.now = new Date()
  }

  Text {
    id: label
    anchors.centerIn: parent
    text: Qt.formatTime(root.now, root.setting("format", "HH:mm"))
    color: root.setting("color", "") || Commons.Color.foreground
    font.family: root.setting("fontFamily", "Noto Serif Display")
    font.italic: root.setting("italic", true)
    font.weight: Font.Medium
    font.pixelSize: root.setting("fontSize", Commons.Style.font.heading)
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Quickshell.execDetached(["hyprctl", "dispatch",
      root.setting("onClick", 'hl.dsp.global("omarchy:panel.omarchy.clock")')])
  }
}
