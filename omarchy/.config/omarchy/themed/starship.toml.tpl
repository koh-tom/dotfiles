add_newline = true

format = """
${custom.directory}\
$git_branch\
$git_status\
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

[aws]
format = "[$symbol $profile ]($style)"
symbol = "💭"
style = "bold fg:{{ color3 }}"
