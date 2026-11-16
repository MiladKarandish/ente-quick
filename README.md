# ente-quick

Run two [Ente Auth](https://ente.io/auth) accounts side by side on Linux, and copy any 2FA code with a keyboard shortcut.

- **Two accounts:** a second Ente Auth install (e.g. Work + Personal) with its own data, login and keyring entry. Codes never mix or sync between them.
- **Quick copy:** press `Ctrl+Alt+A`, type a few letters, press `Enter`. The code is copied, kept out of clipboard history, and cleared after 30 s.

> Unofficial. Not affiliated with or endorsed by Ente. Contains no Ente code.

## Requirements

- GNOME on Wayland (tested: Ubuntu 26.04, GNOME 50, Ente Auth 4.4.26)
- Ente Auth installed from the official **`.deb`** (`/usr/share/enteauth`)
- Packages:

  ```sh
  sudo apt install python3-gi gir1.2-gtk-4.0 gir1.2-adw-1 gir1.2-secret-1 wl-clipboard libnotify-bin
  ```

## Install

```sh
git clone https://github.com/MiladKarandish/ente-quick.git
cd ente-quick
./install.sh
```

Then open **Ente Auth (Personal)** from the app menu and sign in to your second account. Your existing install becomes **Ente Auth (Work)**.

| Option | Effect |
|---|---|
| `ENTE_QUICK_SHORTCUT='<Super>semicolon' ./install.sh` | Use a different shortcut |
| `ENTE_SKIP_PERSONAL=1 ./install.sh` | Popup only, no second account |

Re-running `install.sh` is safe. It rebuilds the Personal copy, so close that app first.

## Usage

| Key | Action |
|---|---|
| `Ctrl+Alt+A` | Open / close the popup |
| type | Filter by name, account, tag, note, or `work` / `personal` |
| `↑` `↓` | Move selection |
| `Enter` or click | Copy code and close |
| `Esc` | Close |

Pinned codes come first, then the ones you copy most. `ente-quick --check` prints how many codes it finds per account.

**After every Ente Auth update**, run `enteauth-personal-update` so the Personal copy matches.

## Configuration

Edit the top of `bin/ente-quick`, then re-run `./install.sh`:

- `ACCOUNTS`: labels and app IDs (rename "Work"/"Personal" here)
- `CLIPBOARD_CLEAR_SECONDS`: default `30`

## How it works

- **Second account:** Ente Auth's app ID `io.ente.auth` decides its data folder, keyring entry and single-instance lock. The Personal copy is the same build with the ID changed to `io.ente.autw` (same length) in two files. No rebuild.
- **Popup:** reads each install's key from the GNOME keyring, decrypts its local database in memory, and computes TOTP/Steam codes. Nothing decrypted is written to disk. The apps don't need to be running, but codes reflect each app's last sync.

## Security

- The popup reads codes from your **unlocked** keyring, which any program running as you can already do. It adds no new access.
- **Ente Auth's in-app lock (PIN/password) does not apply to the popup.** Lock your screen when away.
- Clipboard history: `install.sh` excludes the popup and both apps in the Clipboard Indicator extension. For other clipboard managers, exclude `local.ente.Quick`, `io.ente.auth` and `io.ente.autw` yourself.

## Troubleshooting

| Problem | Fix |
|---|---|
| "not signed in" for an account | Sign in to that Ente Auth app once. |
| Personal copy won't start after an update | Run `enteauth-personal-update`. |
| A new code is missing | Open that Ente Auth app so it syncs. |
| HOTP code shows "use app" | Counter-based codes must be used in the app (it advances the counter). |

## Uninstall

```sh
./uninstall.sh --dry-run   # preview
./uninstall.sh             # remove everything install.sh added
./uninstall.sh --purge     # also delete the Personal account's local data
```

Your Work install and its data are never touched.

## Limitations

- Only the `.deb` install is supported (not Flatpak, AppImage or Snap).
- GNOME Wayland only. KDE or X11 need a different shortcut and clipboard setup.

## License

[MIT](LICENSE)
