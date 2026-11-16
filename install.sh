#!/bin/sh
# Install the Ente Auth Work/Personal setup and the ente-quick popup.
# Safe to re-run. Requires Ente Auth installed at /usr/share/enteauth (the .deb).
set -e
cd "$(dirname "$0")"
BIN="$HOME/.local/bin"
APPS="$HOME/.local/share/applications"
SHORTCUT="${ENTE_QUICK_SHORTCUT:-<Control><Alt>a}"
mkdir -p "$BIN" "$APPS"

[ -x /usr/share/enteauth/enteauth ] || { echo "Ente Auth not found in /usr/share/enteauth — install it first." >&2; exit 1; }
for t in python3 wl-copy wl-paste perl; do command -v $t >/dev/null || { echo "missing: $t" >&2; exit 1; }; done
python3 -c 'import gi; gi.require_version("Gtk","4.0"); gi.require_version("Adw","1"); gi.require_version("Secret","1")' \
  || { echo "missing: python3-gi with GTK4, libadwaita and libsecret typelibs" >&2; exit 1; }

echo "• scripts"
install -m 755 bin/ente-quick bin/enteauth-personal-update "$BIN/"

echo "• Personal copy of Ente Auth"
"$BIN/enteauth-personal-update"

echo "• menu entries"
# The original install becomes "Work" (user-level override of the system entry).
sed -e 's/^Name=Ente Auth$/Name=Ente Auth (Work)/' \
    -e 's/^GenericName=.*/GenericName=Ente Authenticator – Work account/' \
    /usr/share/applications/enteauth.desktop > "$APPS/enteauth.desktop"
cat > "$APPS/enteauth-personal.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Ente Auth (Personal)
GenericName=Ente Authenticator – Personal account
Icon=enteauth
Exec=$HOME/.local/opt/enteauth-personal/enteauth
Categories=Utility;
Keywords=Authentication;2FA;personal;
StartupNotify=false
StartupWMClass=io.ente.autw
EOF
cat > "$APPS/ente-quick.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Ente Codes (quick copy)
Comment=Search and copy 2FA codes from Work and Personal Ente Auth
Icon=enteauth
Exec=$BIN/ente-quick
Categories=Utility;
Keywords=2FA;OTP;code;totp;auth;
StartupNotify=true
EOF
update-desktop-database "$APPS" 2>/dev/null || true

echo "• keyboard shortcut ($SHORTCUT)"
python3 - "$BIN/ente-quick" "$SHORTCUT" <<'EOF'
import ast, subprocess, sys
cmd, binding = sys.argv[1], sys.argv[2]
K = "org.gnome.settings-daemon.plugins.media-keys"
P = "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"
g = lambda *a: subprocess.run(["gsettings", *a], capture_output=True, text=True, check=True).stdout.strip()
paths = ast.literal_eval(g("get", K, "custom-keybindings").replace("@as ", ""))
for p in paths:  # already installed → update in place
    if ast.literal_eval(g("get", f"{K}.custom-keybinding:{p}", "command")) == cmd:
        break
else:
    n = 0
    while f"{P}custom{n}/" in paths:
        n += 1
    p = f"{P}custom{n}/"
    paths.append(p)
    g("set", K, "custom-keybindings", repr(paths))
s = f"{K}.custom-keybinding:{p}"
g("set", s, "name", "Ente codes"); g("set", s, "command", cmd); g("set", s, "binding", binding)
EOF

CI="$HOME/.local/share/gnome-shell/extensions/clipboard-indicator@tudmotu.com"
if [ -d "$CI/schemas" ]; then
  echo "• Clipboard Indicator: ignore copies from Ente apps"
  S="gsettings --schemadir $CI/schemas"; K=org.gnome.shell.extensions.clipboard-indicator
  new=$(python3 -c '
import ast,sys; l=ast.literal_eval(sys.argv[1].replace("@as ",""))
for a in ("local.ente.Quick","io.ente.auth","io.ente.autw"):
    a in l or l.append(a)
print(repr(l))' "$($S get $K excluded-apps)")
  $S set $K excluded-apps "$new"
fi

echo "Done. Press $SHORTCUT for codes; run 'ente-quick --check' to see what it finds."
