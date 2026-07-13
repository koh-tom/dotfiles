# Dotfiles submenu. This overrides only Omarchy's Setup > Config menu.

show_dotfiles_menu() {
  case $(menu "Dotfiles" "  Edit\n  Git\n󰒓  Doctor\n󰑐  Reapply\n  Spurs Mode") in
  *Edit*) open_in_editor "$HOME/dotfiles" ;;
  *Git*) terminal --dir="$HOME/dotfiles" lazygit ;;
  *Doctor*) terminal --dir="$HOME/dotfiles" bash -lc 'mise run doctor; printf "\nPress Enter to close"; read -r' ;;
  *Reapply*) terminal --dir="$HOME/dotfiles" bash -lc 'mise run apply; printf "\nPress Enter to close"; read -r' ;;
  *Spurs*) omarchy theme set Spurs ;;
  *) back_to show_setup_config_menu ;;
  esac
}

show_setup_config_menu() {
  case $(menu "Setup" "  Hyprland\n  Hypridle\n  Hyprlock\n  Hyprsunset\n  Swayosd\n󰌧  Walker\n󰍜  Waybar\n󰞅  XCompose\n  Dotfiles") in
  *Hyprland*) open_in_editor ~/.config/hypr/hyprland.conf ;;
  *Hypridle*) open_in_editor ~/.config/hypr/hypridle.conf && omarchy restart hypridle ;;
  *Hyprlock*) open_in_editor ~/.config/hypr/hyprlock.conf ;;
  *Hyprsunset*) open_in_editor ~/.config/hypr/hyprsunset.conf && omarchy restart hyprsunset ;;
  *Swayosd*) open_in_editor ~/.config/swayosd/config.toml && omarchy restart swayosd ;;
  *Walker*) open_in_editor ~/.config/walker/config.toml && omarchy restart walker ;;
  *Waybar*) open_in_editor ~/.config/waybar/config.jsonc && omarchy restart waybar ;;
  *XCompose*) open_in_editor ~/.XCompose && omarchy restart xcompose ;;
  *Dotfiles*) show_dotfiles_menu ;;
  *) show_setup_menu ;;
  esac
}
