# ente-quick

Two Ente Auth accounts (Work + Personal) side by side on Linux, plus a
keyboard popup to search and copy 2FA codes from both without opening the apps.

> Unofficial. Not affiliated with or endorsed by Ente. It contains no Ente code;
> it works with an Ente Auth you already installed (the `.deb` build).

## What's in here

| File | What it does |
|---|---|
| `bin/ente-quick` | The popup (Python, GTK4/libadwaita). `Ctrl+Alt+A` → type → `Enter` copies the code. |
| `bin/enteauth-personal-update` | Builds the **Personal** copy of Ente Auth from the installed one. Re-run after every Ente Auth update. |
| `install.sh` | Installs everything: scripts, Personal copy, menu entries, shortcut, clipboard-history exclusions. Safe to re-run. |

## How the second account works

Ente Auth (Linux, Flutter) bakes its app ID `io.ente.auth` into the launcher and
the secure-storage plugin. That ID decides the data folder, the keyring entry
and the single-instance lock. The Personal copy is the same build with the ID
changed to `io.ente.autw` (same length, one byte each), so it gets its own data
in `~/.local/share/io.ente.autw` and its own keyring entry. No rebuild needed.

- **Ente Auth (Work)**: the original install (`/usr/share/enteauth`)
- **Ente Auth (Personal)**: `~/.local/opt/enteauth-personal`

## How the popup works

- Reads each app's `auth_secret_key` from the GNOME keyring (same as the app does),
  decrypts the local SQLite DB in memory (libsodium secretstream), computes
  TOTP/Steam codes locally. Nothing decrypted is written to disk.
- Codes reflect each app's last sync; the apps don't need to be running.
- Copy is done from the popup's own window, so Clipboard Indicator's
  `excluded-apps` keeps codes out of history. The process then stays in the
  background as clipboard owner and clears it after 30 s (or exits early if you
  copy something else). Falls back to `wl-copy` if the compositor refuses.
- Pinned codes first, then most used (`~/.local/state/ente-quick/usage.json`
  stores only hashed names and counts). Trashed codes hidden. HOTP shows "use app".

## Security notes

- The popup can read codes only from the logged-in user's **unlocked** GNOME
  keyring. Any program running as you can already do the same: that is how
  Ente Auth stores its key on Linux. This tool adds no new access.
- Codes are copied to the clipboard and cleared after 30 seconds. Other
  clipboard managers than Clipboard Indicator may still record them; exclude
  the app IDs `local.ente.Quick`, `io.ente.auth` and `io.ente.autw` there.
- Ente Auth's own app lock (PIN/password inside the app) is **not** applied to
  the popup. If you rely on it, lock your screen or don't install the popup.

## Install / reinstall

```sh
./install.sh                                         # default shortcut Ctrl+Alt+A
ENTE_QUICK_SHORTCUT='<Super>semicolon' ./install.sh  # pick another
```

Note: re-running closes the Personal copy if it is open (it gets rebuilt).

## After an Ente Auth update

```sh
enteauth-personal-update
```

## License

MIT. See [LICENSE](LICENSE).

## Tested on

Ubuntu 26.04, GNOME 50 (Wayland), Ente Auth 4.4.26.
