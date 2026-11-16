// Waybar の custom/* モジュール + style.css の「ピル」デザインを Quattro バーで再現する汎用モジュール。
// (dotfiles: quattro/.config/omarchy/bar/modules/DotfilesPill.qml)
//
// shell.json の bar.layout に { "id": "...", "type": "qml",
//   "source": "~/.config/omarchy/bar/modules/DotfilesPill.qml", ...settings } で置く。
//
// settings (すべて任意。Waybar の同名キーに対応):
//   exec           string  実行コマンド (bash -lc)。出力は Waybar 形式 JSON かプレーンテキスト
//   interval       number  秒。0 以下なら起動時に1回だけ (Waybar の interval)
//   text           string  exec が無い/空のときの固定表示 (Waybar の format)
//   tooltip        string  JSON に tooltip が無いときの固定ツールチップ
//   onClick / onRightClick / onMiddleClick   string  クリック時コマンド
//   pill           bool    true なら alpha(fg, 0.12) の角丸背景 (style.css のピル)
//   color          string  文字色 (未指定はテーマの foreground)
//   classColors    object  { "<class>": "#rrggbb" } JSON の class ごとの文字色
//   classBackgrounds object { "<class>": "#rrggbb" } class ごとの背景色 (spurs の matchday)
//   classOpacity   object  { "<class>": 0.45 } class ごとの文字の不透明度
//   altText        object  { "<alt>": "glyph" } JSON の alt で表示を差し替え (Waybar の format "{icon}" + format-icons)
//   hideWhenEmpty  bool    出力テキストが空なら幅0 (Waybar で空出力のモジュールが消えるのと同じ)
//   padding        number  左右パディング px (style.css の padding: 0 Npx)
//   margin         number  右マージン px
//   fontSize       number  px (style.css の font-size)

import QtQuick
import Quickshell.Io

Item {
  id: root

  property var bar
  property string moduleName
  property var settings

  property string outputText: ""
  property string outputTooltip: ""
  property var outputClasses: []
  property string outputAlt: ""

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function firstMatch(map, fallback) {
    if (!map) return fallback
    for (var i = 0; i < outputClasses.length; i++) {
      var value = map[outputClasses[i]]
      if (value !== undefined && value !== null) return value
    }
    return fallback
  }

  function update(raw) {
    var trimmed = String(raw || "").trim()
    var data = null
    try { data = JSON.parse(trimmed) } catch (e) { data = null }

    if (data && typeof data === "object") {
      outputText = data.text !== undefined ? String(data.text) : ""
      outputTooltip = data.tooltip !== undefined ? String(data.tooltip) : ""
      var klass = data["class"] !== undefined ? data["class"] : (data.alt !== undefined ? data.alt : [])
      outputClasses = Array.isArray(klass) ? klass.map(String) : (klass === "" ? [] : [String(klass)])
      outputAlt = data.alt !== undefined ? String(data.alt) : ""
      var altText = setting("altText", null)
      if (altText && outputAlt !== "" && altText[outputAlt] !== undefined) outputText = String(altText[outputAlt])
    } else {
      outputText = trimmed
      outputTooltip = ""
      outputClasses = []
      outputAlt = ""
    }
  }

  readonly property string shownText: outputText !== "" ? outputText : String(setting("exec", "") === "" ? setting("text", "") : "")
  readonly property bool collapsed: setting("hideWhenEmpty", false) === true && shownText === ""
  readonly property color foreground: bar ? bar.foreground : "white"
  readonly property bool pill: setting("pill", false) === true
  readonly property real padding: Number(setting("padding", 10))
  readonly property real rightMargin: Number(setting("margin", 4))

  visible: !collapsed
  implicitWidth: collapsed ? 0 : label.implicitWidth + padding * 2 + rightMargin
  implicitHeight: bar ? bar.barSize : 26

  Rectangle {
    id: background
    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    width: parent.width - root.rightMargin
    height: parent.height - 6 // style.css: margin 3px 0
    radius: height / 2       // border-radius: 99px
    color: {
      var custom = root.firstMatch(root.setting("classBackgrounds", null), "")
      if (custom !== "") return custom
      if (!root.pill) return "transparent"
      return Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
    }
  }

  Text {
    id: label
    anchors.centerIn: background
    text: root.shownText
    textFormat: Text.PlainText
    font.family: bar ? bar.fontFamily : "JetBrainsMono Nerd Font"
    font.pixelSize: Number(root.setting("fontSize", 12))
    color: root.firstMatch(root.setting("classColors", null), String(root.setting("color", "")) || root.foreground)
    opacity: Number(root.firstMatch(root.setting("classOpacity", null), 1))
  }

  MouseArea {
    anchors.fill: background
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    hoverEnabled: true

    onEntered: {
      var tip = root.outputTooltip !== "" ? root.outputTooltip : String(root.setting("tooltip", ""))
      if (bar && tip !== "") bar.showTooltip(root, tip)
    }
    onExited: if (bar) bar.hideTooltip(root)

    onClicked: function(mouse) {
      var command = ""
      if (mouse.button === Qt.RightButton) command = String(root.setting("onRightClick", ""))
      else if (mouse.button === Qt.MiddleButton) command = String(root.setting("onMiddleClick", ""))
      else command = String(root.setting("onClick", ""))
      if (command !== "" && bar) {
        bar.run(command)
        refreshSoon.restart() // Waybar の signal 相当: 操作直後に表示を更新
      }
    }
  }

  Process {
    id: proc
    command: ["bash", "-lc", String(root.setting("exec", ""))]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.update(text)
    }
  }

  function refresh() {
    if (String(setting("exec", "")) !== "" && !proc.running) proc.running = true
  }

  Timer {
    id: poll
    interval: Math.max(1, Number(root.setting("interval", 0))) * 1000
    running: String(root.setting("exec", "")) !== "" && Number(root.setting("interval", 0)) > 0
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: refreshSoon
    interval: 600
    onTriggered: root.refresh()
  }

  Component.onCompleted: refresh()
}
