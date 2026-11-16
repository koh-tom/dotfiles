add_newline = true

format = """
${custom.directory}\
$git_branch\
$git_status\
${custom.push_personal}${custom.push_lab}\
$nix_shell\
$python\
$aws\
$fill\
$cmd_duration\
$time\
\n$character\
"""

[fill]
symbol = "·"
style = "fg:{{ color8 }}"

[directory]
disabled = true

[custom.directory]
command = "bash ~/.config/zsh/scripts/starship_directory.sh"
when = "true"
format = "$output"

[git_branch]
symbol = ""
style = "bold fg:{{ accent }} bg:{{ color0 }}"
format = "[](fg:{{ color0 }})[$symbol $branch ]($style)"

[git_status]
style = "bold fg:{{ color1 }} bg:{{ color0 }}"
format = "[$all_status$ahead_behind]($style)[](fg:{{ color0 }}) "

[cmd_duration]
min_time = 2000
style = "fg:{{ color3 }}"
format = "[](fg:{{ color3 }})[󱎫 $duration](fg:{{ background }} bg:{{ color3 }})[](fg:{{ color3 }}) "

[time]
disabled = false
time_format = "%R"
format = "[](fg:{{ color0 }})[ $time](fg:{{ color4 }} bg:{{ color0 }})[](fg:{{ color0 }})"

[character]
success_symbol = "[❯](bold fg:{{ accent }})"
error_symbol = "[❯](bold fg:{{ color1 }})"
vimcmd_symbol = "[V](bold fg:{{ color2 }}) "

# push認証を常時表示 (ghpushで切替)。personal=緑 / lab=赤。値で色を変えるため2モジュール構成
[custom.push_personal]
when = '[ "$GH_PUSH_AS" != lab ]'
command = "echo personal"
format = "[](fg:{{ color2 }})[ push:$output ]($style)[](fg:{{ color2 }}) "
style = "bold fg:{{ background }} bg:{{ color2 }}"

[custom.push_lab]
when = '[ "$GH_PUSH_AS" = lab ]'
command = "echo lab"
format = "[](fg:{{ color1 }})[ push:$output ]($style)[](fg:{{ color1 }}) "
style = "bold fg:{{ background }} bg:{{ color1 }}"


[nix_shell]
symbol = "❄ "
format = "[](fg:{{ color6 }})[$symbol$name ]($style)[](fg:{{ color6 }}) "
style = "bold fg:{{ background }} bg:{{ color6 }}"

[aws]
format = "[$symbol $profile ]($style)"
symbol = "💭"
style = "bold fg:{{ color3 }}"
