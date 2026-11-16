#!/bin/sh
# Build and install a second Ente Auth on Android under a new app ID.
#
#   android/build-apk.sh                 pull Ente Auth from the connected phone, build, install
#   android/build-apk.sh path/to.apk     use this APK instead
#
# Env: ENTE_ANDROID_ID (default io.ente.auth.personal)
#      ENTE_ANDROID_LABEL (default "Ente Auth (Personal)")
#      ENTE_SOURCE_PKG (default io.ente.auth.independent; Play Store build is io.ente.auth)
#
# Re-run after each Ente Auth update. The signing key in ~/.local/share/ente-quick
# must stay the same, or the update won't install over the existing app. Back it up.
set -e
NEW_ID="${ENTE_ANDROID_ID:-io.ente.auth.personal}"
LABEL="${ENTE_ANDROID_LABEL:-Ente Auth (Personal)}"
SRC_PKG="${ENTE_SOURCE_PKG:-io.ente.auth.independent}"
APKTOOL_VER=3.0.3
SIGNER_VER=1.3.0
T="$HOME/.cache/ente-quick/tools"
W="$HOME/.cache/ente-quick/android"
K="$HOME/.local/share/ente-quick"
mkdir -p "$T" "$W" "$K"; chmod 700 "$K"

for t in java keytool curl; do command -v $t >/dev/null || { echo "missing: $t" >&2; exit 1; }; done
[ -f "$T/apktool-$APKTOOL_VER.jar" ] || curl -fL --progress-bar -o "$T/apktool-$APKTOOL_VER.jar" \
  "https://github.com/iBotPeaches/Apktool/releases/download/v$APKTOOL_VER/apktool_$APKTOOL_VER.jar"
[ -f "$T/uber-apk-signer-$SIGNER_VER.jar" ] || curl -fL --progress-bar -o "$T/uber-apk-signer-$SIGNER_VER.jar" \
  "https://github.com/patrickfav/uber-apk-signer/releases/download/v$SIGNER_VER/uber-apk-signer-$SIGNER_VER.jar"

if [ -n "$1" ]; then
  cp "$1" "$W/source.apk"
else
  command -v adb >/dev/null || { echo "missing: adb (or pass an APK path)" >&2; exit 1; }
  P=$(adb shell pm path "$SRC_PKG" | sed -n 's/^package://p' | tr -d '\r')
  [ -n "$P" ] || { echo "$SRC_PKG not found on the phone (set ENTE_SOURCE_PKG?)" >&2; exit 1; }
  [ "$(echo "$P" | wc -l)" = 1 ] || { echo "split APK install not supported; pass an APK file" >&2; exit 1; }
  adb pull "$P" "$W/source.apk" >/dev/null
fi

echo "• unpacking"
rm -rf "$W/dec" "$W/out"
java -jar "$T/apktool-$APKTOOL_VER.jar" d -s -f -q -o "$W/dec" "$W/source.apk"
OLD_ID=$(grep -oE 'package="[^"]+"' "$W/dec/AndroidManifest.xml" | cut -d'"' -f2)
echo "  $OLD_ID → $NEW_ID ($LABEL)"
OLD_RE=$(printf '%s' "$OLD_ID" | sed 's/\./\\./g')
sed -i -e "s/$OLD_RE/$NEW_ID/g" -e "s/android:label=\"Ente Auth\"/android:label=\"$LABEL\"/g" "$W/dec/AndroidManifest.xml"
if grep -rlqa "$OLD_ID" "$W/dec"/*.dex "$W/dec/lib" 2>/dev/null; then
  echo "warning: $OLD_ID is hardcoded in the app's code; the copy may misbehave" >&2
fi

echo "• rebuilding and signing"
java -jar "$T/apktool-$APKTOOL_VER.jar" b -q "$W/dec" -o "$W/out/unsigned.apk"
if [ ! -f "$K/android.jks" ]; then
  (umask 077; head -c 24 /dev/urandom | base64 | tr -d '/+=' > "$K/android.pass")
  keytool -genkeypair -keystore "$K/android.jks" -storepass "$(cat "$K/android.pass")" -alias ente-quick \
    -keyalg RSA -keysize 4096 -validity 36500 -dname "CN=ente-quick" >/dev/null 2>&1
  chmod 600 "$K/android.jks"
  echo "  new signing key: $K/android.jks (back it up with android.pass)"
fi
PASS=$(cat "$K/android.pass")
java -jar "$T/uber-apk-signer-$SIGNER_VER.jar" -a "$W/out/unsigned.apk" -o "$W/out/signed" \
  --ks "$K/android.jks" --ksAlias ente-quick --ksPass "$PASS" --ksKeyPass "$PASS" >"$W/sign.log" 2>&1 \
  || { cat "$W/sign.log" >&2; exit 1; }
APK=$(ls "$W"/out/signed/*.apk)
cp "$APK" "$W/ente-auth-$NEW_ID.apk"
echo "  built: $W/ente-auth-$NEW_ID.apk"

if [ -z "$1" ] || adb get-state >/dev/null 2>&1; then
  echo "• installing (confirm on the phone if asked)"
  adb install -r "$W/ente-auth-$NEW_ID.apk" | tail -1
fi
