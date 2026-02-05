#!/bin/bash
# ~/.config/zsh/scripts/starship_directory.sh

# Color Palette (Tokyo Night / Cool Ice)
COLORS=("#73daca" "#7dcfff" "#7aa2f7" "#bb9af7")
TEXT_COLOR="#1a1b26" # Deep dark
LEFT_SEP=""
RIGHT_SEP=""

# Bulletproof HOME replacement
if [[ "$PWD" == "$HOME"* ]]; then
    p="~${PWD#$HOME}"
else
    p="$PWD"
fi

# Split path into array
IFS='/' read -ra ADDR <<< "$p"

# Clean up parts array (handle root path properly)
PARTS=()
for part in "${ADDR[@]}"; do
    if [[ -n "$part" ]]; then
        PARTS+=("$part")
    elif [[ ${#PARTS[@]} -eq 0 && "$p" == /* ]]; then
        PARTS+=("/")
    fi
done

if [[ ${#PARTS[@]} -eq 0 ]]; then
    PARTS=("/")
fi

# Hex to RGB converter
hex_to_rgb() {
    local hex=${1#\#}
    printf "%d;%d;%d" $((16#${hex:0:2})) $((16#${hex:2:2})) $((16#${hex:4:2}))
}

OUTPUT=""
T_RGB=$(hex_to_rgb "$TEXT_COLOR")

for i in "${!PARTS[@]}"; do
    part="${PARTS[$i]}"
    
    # 最初のアイコン設定
    if [[ "$part" == "~" ]]; then
        part=" ~"
    elif [[ "$part" == "/" ]]; then
        part="󰣆 /"
    fi
    
    C_CUR=${COLORS[$((i % ${#COLORS[@]}))]}
    RGB_CUR=$(hex_to_rgb "$C_CUR")
    
    # 左端のセパレーター
    if [[ $i -eq 0 ]]; then
        OUTPUT+="\033[38;2;${RGB_CUR}m${LEFT_SEP}"
    fi
    
    # ディレクトリ名本体 (背景:カレント色, 文字:暗色)
    OUTPUT+="\033[48;2;${RGB_CUR}m\033[38;2;${T_RGB}m ${part} "
    
    # 右端のセパレーター
    if [[ $i -eq $(( ${#PARTS[@]} - 1 )) ]]; then
        # 最後は背景をデフォルト(透明)に戻して右丸を描画
        OUTPUT+="\033[0m\033[38;2;${RGB_CUR}m${RIGHT_SEP}\033[0m"
    else
        # 中間は、背景を「次の色」にして右丸を描画（重なり合うバッジを表現）
        C_NEXT=${COLORS[$(((i + 1) % ${#COLORS[@]}))]}
        RGB_NEXT=$(hex_to_rgb "$C_NEXT")
        OUTPUT+="\033[48;2;${RGB_NEXT}m\033[38;2;${RGB_CUR}m${RIGHT_SEP}"
    fi
done

# Starshipが後続のモジュールとの間に適切にスペースを入れられるよう、最後にスペースを1つ足す
echo -ne "${OUTPUT} "
