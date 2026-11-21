// [dotfiles.lock] omarchy.lock (/usr/share/omarchy/shell/plugins/lock/LockView.qml) のコピーを改変。
// コピー元: Omarchy 4.0.0.alpha (/usr/share/omarchy/version) / pacman: omarchy 4.5.0-3
// stock との差分 (見た目だけ。認証・PAM・セッションロック・失敗処理は一切触っていない):
//   1. TextInput の伏せ字 (●) とカーソルを透明にし、代わりに文字数ぶんの葉っぱアイコン
//      (Nerd Font md_leaf / md_sprout) を並べる「leafGarden」を重ねた。1文字ごとに小さく弾んで生える。
//   2. 確認中 (authenticatingPassword) は直前の葉っぱを薄く呼吸させ、失敗時は葉っぱがしおれて落ち、
//      列が左右に揺れてから stock の失敗メッセージを出す。そのため placeholder の visible 条件に
//      !root.leafGhostVisible を足した。
//   3. 色はテーマ (Commons.Color.lock.*) から取るので、テーマを変えても追従する。
// Omarchy 更新後の再同期: stock の LockView.qml との diff を取り、「[dotfiles.lock]」印の箇所だけ移植する。
// Service.qml / FingerprintModel.js / poster.sh は stock と完全に同一 (diff で確認できる)。
import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Item {
  id: root

  // [dotfiles.lock] 葉っぱ表示用の状態 (見た目専用。パスワード本文は保持せず、文字数だけ)
  property int leafLastTypedCount: 0
  property int leafGhostCount: 0
  property bool leafWilting: false
  readonly property bool leafGhostVisible: passwordInput.text.length === 0 && leafGhostCount > 0
  readonly property int leafCount: passwordInput.text.length > 0 ? passwordInput.text.length : leafGhostCount
  readonly property int leafSize: Math.round(Style.font.heading * 1.5)
  readonly property int leafSpacing: Math.round(Style.font.heading * 0.35)

  onAuthenticatingPasswordChanged: {
    if (authenticatingPassword) {
      leafWilting = false
      leafGhostCount = leafLastTypedCount
    } else {
      // 成功時は何もしない (ロック画面ごと消える)。失敗は failedAttempts の増加で拾う。
      Qt.callLater(function() { if (!root.leafWilting) root.leafGhostCount = 0 })
    }
  }
  onFailedAttemptsChanged: {
    if (failedAttempts > 0 && leafGhostCount > 0) {
      leafWilting = true
      leafWiltTimer.restart()
      leafShake.restart()
    }
  }

  Timer {
    id: leafWiltTimer
    interval: 950
    onTriggered: { root.leafWilting = false; root.leafGhostCount = 0 }
  }

  Connections {
    target: passwordInput
    function onTextChanged() {
      if (passwordInput.text.length > 0) {
        root.leafLastTypedCount = passwordInput.text.length
        if (root.leafGhostCount > 0) { leafWiltTimer.stop(); root.leafWilting = false; root.leafGhostCount = 0 }
      }
    }
  }

  property string backgroundPath: ""
  property string videoPosterPath: ""
  property int backgroundVersion: 0
  property bool fingerprintConfigured: false
  property bool fingerprintUnavailable: false
  property bool authenticatingPassword: false
  property string failureMessage: ""
  property int failedAttempts: 0
  property bool inputEnabled: true
  property bool loadBackground: true
  property string passwordText: ""
  property bool syncingPasswordText: false

  readonly property string placeholderText: Commons.I18n.t("lock.enterPassword")
  readonly property int fieldWidth: 381
  readonly property int fieldHeight: 67
  readonly property int outlineThickness: 3
  readonly property int fieldFontSize: Math.round(Style.font.heading * 1.125)
  readonly property int passwordDotFontSize: Math.round(Style.font.heading * 1.33)
  readonly property int passwordDotLetterSpacing: Math.round(Style.font.heading * 0.19)
  // Space to keep clear on each side of the field for the fingerprint icon
  // (icon width plus a gap) so the centered dots never run under it.
  readonly property real fingerprintReserve: fingerprintConfigured ? Math.round(fingerprintIcon.implicitWidth + 12) : 0
  // Shrink the dots to fit once the password outgrows the field, so every
  // keystroke stays visible — otherwise long passwords clip with no feedback.
  readonly property real passwordDotScale: dotMetrics.advanceWidth > 0
    ? Math.min(1, (passwordInput.width - 4) / dotMetrics.advanceWidth)
    : 1
  readonly property bool showPasswordCursor: inputEnabled && !authenticatingPassword && failureMessage.length === 0
  readonly property bool errorState: failureMessage.length > 0
  readonly property var inputBorderSpec: errorState
    ? Border.surfaceSpec("lock", "border-error", Commons.Color.lock.borderError, root.outlineThickness, "border-alpha")
    : Border.surfaceSpec("lock", "border-active", Commons.Color.lock.borderActive, root.outlineThickness, "border-alpha")

  // A video wallpaper shows its still poster: nothing plays behind the lock.
  readonly property bool video: Util.isVideoPath(root.backgroundPath)

  signal submitPassword(string password)
  signal passwordTextEdited(string password)
  signal clearFailureRequested()
  signal wakeRequested()

  function forcePasswordFocus() {
    passwordInput.forceActiveFocus()
  }

  function clearPassword() {
    passwordTextEdited("")
  }

  // Waking a DPMS-blanked display can stall the compositor for seconds while
  // the monitor modesets, so the wake key's release arrives late and client-side
  // key repeat floods the field with that character. A held key has no business
  // typing a password; only holding Backspace/Delete to clear stays useful.
  function dropsAutoRepeat(key) {
    return key !== Qt.Key_Backspace && key !== Qt.Key_Delete
  }

  function syncPasswordText() {
    if (passwordInput.text === passwordText) return
    syncingPasswordText = true
    passwordInput.text = passwordText
    syncingPasswordText = false
  }

  // The field loses focus while a password is checked (it is disabled then),
  // and forcing focus onto it would not stick until the check ends.
  function restorePasswordFocus() {
    if (inputEnabled && passwordInput.enabled && !passwordInput.activeFocus) forcePasswordFocus()
  }

  onPasswordTextChanged: syncPasswordText()
  onInputEnabledChanged: {
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  // A VT switch, which the NVIDIA driver forces around every suspend, takes the
  // keyboard away and Qt drops the field's focus with it. Nothing gives it back
  // when the keyboard returns, so typing went nowhere until the field was clicked.
  Window.onActiveFocusItemChanged: Qt.callLater(restorePasswordFocus)
  Component.onCompleted: {
    syncPasswordText()
    if (inputEnabled) Qt.callLater(forcePasswordFocus)
  }

  // Measures the masked password at full size; passwordDotScale compares this
  // against the field width to decide how far the dots must shrink to fit.
  TextMetrics {
    id: dotMetrics
    font.family: Style.font.family
    font.pixelSize: root.passwordDotFontSize
    font.letterSpacing: root.passwordDotLetterSpacing
    text: "●".repeat(passwordInput.text.length)
  }

  Rectangle {
    anchors.fill: parent
    color: Commons.Color.background

    BackgroundMedia {
      id: wallpaper
      objectName: "lockWallpaper"
      anchors.fill: parent
      path: root.loadBackground ? (root.video ? root.videoPosterPath : root.backgroundPath) : ""
      version: root.backgroundVersion
      // Decode only once sized, at the lock's own size: an unsized first
      // request decoded the file at its native resolution, then again once
      // sized. That size is what the lock service keeps decoded ahead of the
      // lock, so the first frame has the wallpaper.
      cached: true
      constrainDecode: true
      decodeSize: Qt.size(width, height)
    }

    MultiEffect {
      anchors.fill: wallpaper
      source: wallpaper
      autoPaddingEnabled: false
      blurEnabled: root.loadBackground && wallpaper.ready
      blur: 1.0
      blurMax: 128
      blurMultiplier: 1.25
      contrast: -0.08
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
      onPositionChanged: root.wakeRequested()
    }

    BorderSurface {
      id: inputField
      width: root.fieldWidth
      height: root.fieldHeight
      anchors.centerIn: parent
      color: Commons.Color.lock.background
      borderSpec: root.inputBorderSpec
      radius: Style.cornerRadius
      clip: true

      TextInput {
        id: passwordInput
        anchors.fill: parent
        anchors.topMargin: inputField.borderTop
        // Reserve the fingerprint icon's width on both sides so the centered
        // dots stay symmetric and never slide under the icon as they grow.
        anchors.rightMargin: inputField.borderRight + 18 + root.fingerprintReserve
        anchors.bottomMargin: inputField.borderBottom
        anchors.leftMargin: inputField.borderLeft + 18 + root.fingerprintReserve
        verticalAlignment: TextInput.AlignVCenter
        horizontalAlignment: TextInput.AlignHCenter
        activeFocusOnPress: true
        clip: true
        enabled: root.inputEnabled && !root.authenticatingPassword
        readOnly: root.authenticatingPassword
        echoMode: TextInput.Password
        passwordCharacter: "\u25CF"
        passwordMaskDelay: 0
        // [dotfiles.lock] 伏せ字は leafGarden が描くので、本体の文字・選択は透明にする
        color: "transparent"
        selectionColor: "transparent"
        selectedTextColor: "transparent"
        font.family: Style.font.family
        font.pixelSize: text.length > 0 ? Math.max(1, Math.floor(root.passwordDotFontSize * root.passwordDotScale)) : root.fieldFontSize
        font.letterSpacing: text.length > 0 ? root.passwordDotLetterSpacing * root.passwordDotScale : 0
        cursorVisible: activeFocus && root.showPasswordCursor && text.length > 0
        // [dotfiles.lock] 透明な伏せ字の途中にカーソルが浮くので描かない
        cursorDelegate: Item { width: 0 }

        onTextChanged: {
          if (!root.syncingPasswordText) root.passwordTextEdited(text)
          if (text.length > 0) {
            root.wakeRequested()
          }
          if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
        }

        onAccepted: {
          var submitted = root.passwordText
          root.passwordTextEdited("")
          if (submitted.length > 0) root.submitPassword(submitted)
        }

        Keys.onPressed: function(event) {
          root.wakeRequested()
          if (event.isAutoRepeat && root.dropsAutoRepeat(event.key)) {
            event.accepted = true
            return
          }
          if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
            root.passwordTextEdited("")
            event.accepted = true
          }
        }
      }

      // [dotfiles.lock] ここから追加: 伏せ字の代わりの葉っぱの列 (Pond 風)。入力は受けない飾り。
      Item {
        id: leafGarden
        objectName: "leafGarden"
        anchors.fill: passwordInput
        clip: true
        visible: root.leafCount > 0

        // 長いパスワードでも全部見えるよう、stock の passwordDotScale と同じ考え方で縮める
        readonly property real naturalWidth: root.leafCount * root.leafSize + Math.max(0, root.leafCount - 1) * root.leafSpacing
        readonly property real fitScale: naturalWidth > 0 ? Math.min(1, (width - 4) / naturalWidth) : 1

        transform: Translate { id: leafShakeOffset }

        SequentialAnimation {
          id: leafShake
          NumberAnimation { target: leafShakeOffset; property: "x"; to: -10; duration: 55; easing.type: Easing.OutQuad }
          NumberAnimation { target: leafShakeOffset; property: "x"; to: 9; duration: 70 }
          NumberAnimation { target: leafShakeOffset; property: "x"; to: -6; duration: 65 }
          NumberAnimation { target: leafShakeOffset; property: "x"; to: 4; duration: 60 }
          NumberAnimation { target: leafShakeOffset; property: "x"; to: 0; duration: 70; easing.type: Easing.OutQuad }
        }

        Row {
          id: leafRow
          anchors.centerIn: parent
          spacing: root.leafSpacing
          scale: leafGarden.fitScale

          // 確認中は葉っぱ全体がゆっくり呼吸する
          SequentialAnimation on opacity {
            running: root.authenticatingPassword && root.leafGhostVisible
            loops: Animation.Infinite
            alwaysRunToEnd: true
            NumberAnimation { from: 1; to: 0.45; duration: 520; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.45; to: 1; duration: 520; easing.type: Easing.InOutSine }
          }

          Repeater {
            model: root.leafCount

            Text {
              id: leaf
              required property int index
              // 3枚に1枚は芽 (sprout)、ほかは葉っぱ。角度を少しずつ変えて手で並べた感じにする
              readonly property bool sprout: index % 3 === 2
              readonly property real restAngle: ((index * 37) % 31) - 15

              width: root.leafSize
              height: root.leafSize
              textFormat: Text.PlainText
              text: sprout ? "\u{F0E66}" : "\u{F032A}"
              color: leaf.wilted ? Commons.Color.lock.textError
                : (sprout ? Commons.Color.lock.text : Commons.Color.lock.borderActive)
              font.family: Style.font.family
              font.pixelSize: root.leafSize
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
              rotation: restAngle
              transformOrigin: Item.Bottom

              property bool wilted: false
              readonly property bool wiltRequested: root.leafWilting
              onWiltRequestedChanged: if (wiltRequested) wiltAnim.restart()

              Behavior on color { ColorAnimation { duration: 180 } }

              transform: Translate { id: leafDrop }

              // 生えるとき: 0 から少し大きめに弾んで 1 へ (確認中の再生成時は弾ませない)
              scale: 1
              Component.onCompleted: if (!root.leafGhostVisible) popIn.start()
              NumberAnimation {
                id: popIn
                target: leaf; property: "scale"
                from: 0; to: 1; duration: 260
                easing.type: Easing.OutBack; easing.overshoot: 2.2
              }

              // しおれるとき: 色が変わり、くたっと傾いて少し落ち、消える。少しずつ時間差をつける
              SequentialAnimation {
                id: wiltAnim
                ScriptAction { script: leaf.wilted = true }
                PauseAnimation { duration: Math.min(leaf.index, 12) * 25 }
                ParallelAnimation {
                  NumberAnimation { target: leaf; property: "rotation"; to: leaf.restAngle >= 0 ? 95 : -95; duration: 420; easing.type: Easing.InQuad }
                  NumberAnimation { target: leafDrop; property: "y"; to: root.leafSize * 0.6; duration: 520; easing.type: Easing.InQuad }
                  NumberAnimation { target: leaf; property: "scale"; to: 0.7; duration: 520 }
                  SequentialAnimation {
                    PauseAnimation { duration: 180 }
                    NumberAnimation { target: leaf; property: "opacity"; to: 0; duration: 340 }
                  }
                }
              }
            }
          }
        }
      }
      // [dotfiles.lock] ここまで追加

      Text {
        textFormat: Text.PlainText
        anchors.fill: passwordInput
        text: root.authenticatingPassword ? Commons.I18n.t("lock.checking") : (root.failureMessage.length > 0 ? root.failureMessage : root.placeholderText)
        // [dotfiles.lock] 葉っぱ (確認中・しおれ中) を出している間は文字を重ねない
        visible: passwordInput.text.length === 0 && !root.leafGhostVisible
        color: root.authenticatingPassword ? Commons.Color.lock.text : (root.failureMessage.length > 0 ? Commons.Color.lock.textError : Commons.Color.lock.placeholder)
        font.family: Style.font.family
        font.pixelSize: root.fieldFontSize
        font.italic: !root.authenticatingPassword && root.failureMessage.length > 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
      }

      // Fingerprint hint pinned inside the field's right edge when a sensor is
      // enrolled, so the user knows they can touch to unlock instead of typing.
      // Matches hyprlock, which draws its fingerprint icon in the same spot.
      // A reader the shell cannot reach crosses out rather than disappears, so
      // it stops inviting touches that can never unlock.
      Text {
        id: fingerprintIcon
        objectName: "fingerprintIndicator"
        textFormat: Text.PlainText
        anchors.right: parent.right
        anchors.rightMargin: inputField.borderRight + 18
        anchors.verticalCenter: parent.verticalCenter
        visible: root.fingerprintConfigured
        text: root.fingerprintUnavailable ? "󰺱" : "󰈷"
        color: root.fingerprintUnavailable ? Commons.Color.lock.textError : Commons.Color.lock.placeholder
        font.family: Style.font.family
        font.pixelSize: Math.round(root.fieldFontSize * 1.1)
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }
    }

    // The crossed-out icon has no meaning to a user who has never seen it — it
    // is not intuitive that it signals a broken reader — so the words carry the
    // explanation and the icon only reinforces it.
    Text {
      objectName: "fingerprintUnavailableNotice"
      textFormat: Text.PlainText
      anchors.top: inputField.bottom
      anchors.topMargin: 18
      anchors.horizontalCenter: inputField.horizontalCenter
      visible: root.fingerprintConfigured && root.fingerprintUnavailable
      text: Commons.I18n.t("lock.fingerprintUnavailable")
      color: Commons.Color.lock.textError
      font.family: Style.font.family
      font.pixelSize: Style.font.heading
      font.italic: true
      horizontalAlignment: Text.AlignHCenter
    }
  }
}
