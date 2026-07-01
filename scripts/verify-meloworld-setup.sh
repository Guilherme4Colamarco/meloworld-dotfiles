#!/usr/bin/env bash
set -euo pipefail

fail=0
say() { printf '%s\n' "$*"; }
check() {
  local name="$1"; shift
  if "$@" >/tmp/hermes-verify-check.$$ 2>&1; then
    say "PASS $name"
  else
    say "FAIL $name"
    sed 's/^/  /' /tmp/hermes-verify-check.$$ || true
    fail=1
  fi
}

say "== meloworld setup verification =="

check "mango config parses" mango -c "$HOME/.config/mango/config.conf" -p
check "quickshell active config" bash -lc "qs list --all 2>&1 | grep -F 'Config path: $HOME/.config/quickshell/shell.qml'"
check "launcher uses exclusive keyboard focus" bash -lc "grep -F 'WlrLayershell.keyboardFocus: LauncherState.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None' '$HOME/.config/quickshell/launcher/AppLauncher.qml'"
check "launcher focus delay present" bash -lc "grep -F 'id: focusDelay' '$HOME/.config/quickshell/launcher/AppLauncher.qml' && grep -F 'onTriggered: searchBar.forceActiveFocus()' '$HOME/.config/quickshell/launcher/AppLauncher.qml'"
check "mango exports DBus/Wayland env" bash -lc "grep -F 'dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP' '$HOME/.config/mango/config.conf'"
check "mango ABNT2 fallback autostart" bash -lc "grep -F 'setxkbmap -layout br -variant abnt2 -model pc105 -option caps:escape' '$HOME/.config/mango/config.conf'"
check "kitty config parses" kitty +runpy 'from kitty.config import load_config; bad=[]; load_config("/home/geko/.config/kitty/kitty.conf", accumulate_bad_lines=bad); print("bad", len(bad)); raise SystemExit(0 if len(bad)==0 else 1)'
check "launcher IPC toggles" bash -lc "qs ipc call launcher toggle >/dev/null && sleep 0.2 && qs ipc call launcher toggle >/dev/null"
check "no critical quickshell runtime errors" bash -lc "! qs log --no-color 2>&1 | tail -220 | grep -Ei 'FATAL|Error:|Cannot assign|TypeError|Process failed|requestActivate'"
check "waydroid desktop entries hidden" bash -lc "if compgen -G '$HOME/.local/share/applications/waydroid.*.desktop' >/dev/null; then ! grep -L '^NoDisplay=true$' $HOME/.local/share/applications/waydroid.*.desktop | grep .; fi"

rm -f /tmp/hermes-verify-check.$$
exit "$fail"
