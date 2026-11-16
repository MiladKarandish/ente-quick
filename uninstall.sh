#!/bin/sh
# Remove what install.sh added. Your Ente data and logins are NOT deleted.
#   ./uninstall.sh --dry-run   show what would be removed
#   ./uninstall.sh --purge     also delete the Personal account's local data
set -e
DRY=0; PURGE=0
for a in "$@"; do case $a in --dry-run) DRY=1;; --purge) PURGE=1;; *) echo "unknown option: $a" >&2; exit 2;; esac; done
run() { if [ $DRY = 1 ]; then echo "would run: $*"; else "$@"; fi; }

BIN="$HOME/.local/bin"; APPS="$HOME/.local/share/applications"

if [ $DRY = 0 ]; then
  pkill -f "$HOME/.local/opt/enteauth-personal/enteauth" 2>/dev/null && echo "closed Ente Auth (Personal)" || true
fi
for f in "$BIN/ente-quick" "$BIN/enteauth-personal-update" \
         "$APPS/ente-quick.desktop" "$APPS/enteauth-personal.desktop" "$APPS/enteauth.desktop"; do
  [ -e "$f" ] && run rm -f "$f"
done
[ -d "$HOME/.local/opt/enteauth-personal" ] && run rm -rf "$HOME/.local/opt/enteauth-personal"
[ -d "$HOME/.local/state/ente-quick" ] && run rm -rf "$HOME/.local/state/ente-quick"
run update-desktop-database "$APPS" 2>/dev/null || true

# keyboard shortcut
python3 - "$BIN/ente-quick" "$DRY" <<'EOF'
import ast, subprocess, sys
cmd, dry = sys.argv[1], sys.argv[2] == "1"
K = "org.gnome.settings-daemon.plugins.media-keys"
g = lambda *a: subprocess.run(["gsettings", *a], capture_output=True, text=True, check=True).stdout.strip()
paths = ast.literal_eval(g("get", K, "custom-keybindings").replace("@as ", ""))
for p in list(paths):
    if ast.literal_eval(g("get", f"{K}.custom-keybinding:{p}", "command")) == cmd:
        paths.remove(p)
        if dry:
            print(f"would remove shortcut {p}")
        else:
            g("set", K, "custom-keybindings", repr(paths))
            subprocess.run(["gsettings", "reset-recursively", f"{K}.custom-keybinding:{p}"], check=False)
            print("removed keyboard shortcut")
EOF

# Clipboard Indicator exclusions
CI="$HOME/.local/share/gnome-shell/extensions/clipboard-indicator@tudmotu.com"
if [ -d "$CI/schemas" ]; then
  S="gsettings --schemadir $CI/schemas"; K=org.gnome.shell.extensions.clipboard-indicator
  new=$(python3 -c '
import ast,sys; l=ast.literal_eval(sys.argv[1].replace("@as ",""))
print(repr([a for a in l if a not in ("local.ente.Quick","io.ente.auth","io.ente.autw")]))' "$($S get $K excluded-apps)")
  run $S set $K excluded-apps "$new"
fi

if [ $PURGE = 1 ]; then
  [ -d "$HOME/.local/share/io.ente.autw" ] && run rm -rf "$HOME/.local/share/io.ente.autw"
  echo "note: the Personal key may remain in your keyring under 'io.ente.autw/FlutterSecureStorage'"
  echo "      (remove it with Seahorse / 'Passwords and Keys' if you want)."
fi
echo "Done.$([ $DRY = 1 ] && echo ' (dry run, nothing changed)')"
