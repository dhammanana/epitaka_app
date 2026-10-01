set shell := ["bash", "-uc"]

bundle := "build/linux/x64/release/bundle"
deb := "epitaka-linux-x64.deb"

# Upstream tags releases without bumping pubspec (v1.1.1 sits on a pubspec that
# still reads 1.1.0), so the tag is the truer version. It is stamped into the
# build as well as the package, otherwise the app compares its stale pubspec
# version against the GitHub tag and nags about an update it already is.
version := `t=$(git describe --tags --abbrev=0 2>/dev/null); t=${t#v}; t=${t%%+*}; echo "${t:-$(grep -E '^version:' pubspec.yaml | cut -d' ' -f2 | cut -d'+' -f1)}"`
# The build number always comes from pubspec — tags carry no equivalent, and
# omitting it while passing --build-name makes flutter drop it to 0.
build_number := `v=$(grep -E '^version:' pubspec.yaml | cut -d' ' -f2); n=${v#*+}; echo "$([ "$n" = "$v" ] && echo 0 || echo "$n")"`

# List all commands
default:
    @just --list

# Rebuild the Linux release from the current source, repackage, install and restart
linux-update: linux-build linux-deb linux-install linux-restart

# Update this checkout from upstream main, with its release tags
pull:
    git pull --ff-only origin main
    git fetch origin --tags --force

# Build the Linux release, stamped with the release tag's version
linux-build:
    @echo "Building version {{version}} ({{build_number}})"
    flutter build linux --release --build-name={{version}} --build-number={{build_number}}

# Package the Linux build as a .deb
linux-deb:
    install/linux/build-deb.sh "{{version}}" "{{bundle}}" "{{deb}}"

# Local builds keep the pubspec version, so apt sees "already the newest
# version" and silently skips the install; --reinstall forces it. The check
# fails the recipe (and so the restart) if the old app code is still in place.
# Install the .deb, forcing a reinstall, and check it landed
linux-install:
    sudo apt install --reinstall -y ./{{deb}}
    cmp -s {{bundle}}/lib/libapp.so /opt/epitaka/lib/libapp.so || { echo "Install did not land: /opt/epitaka/lib/libapp.so differs from the new build" >&2; exit 1; }

# Restart the installed Linux app
linux-restart:
    #!/usr/bin/env bash
    set -uo pipefail
    pkill -x epitaka && sleep 1
    gtk-launch epitaka >/dev/null 2>&1 &
    echo "ePitaka restarted"

android_pkg := "com.dn.epitaka"
android_apk := "build/app/outputs/flutter-apk/app-prod-debug.apk"
# Content databases: re-sent when the desktop copy changed since the last send.
android_content_dbs := "epitaka.db epitaka_en.db dpd-dictionary.db"
# User data (bookmarks, history, notes, search index): sent only when the
# phone has none, never overwritten, so nothing added on the phone is lost.
android_user_dbs := "app_data.db"
# What was last sent, per database. Under build/, so `flutter clean` just
# makes the next android-db re-send everything.
android_sent_dir := "build/android-db-sent"

# Build the current source, replace the app on the connected phone and start it
android-update: android-build android-install android-start

# Debug, because only a debuggable app accepts files into its private folder
# (run-as), and a release build needs the developer's signing key.
# Build a debug APK of the current source
android-build:
    flutter build apk --debug --flavor prod

# A Play Store install is signed with the developer's key, so Android refuses
# to update it with this build; it is uninstalled first, which deletes its
# data. Later runs update in place and keep the phone's data.
# Install the APK on the phone, replacing the app
android-install:
    #!/usr/bin/env bash
    set -euo pipefail
    adb get-state >/dev/null
    if ! out=$(adb install -r "{{android_apk}}" 2>&1); then
        if grep -q INSTALL_FAILED_UPDATE_INCOMPATIBLE <<<"$out"; then
            echo "The installed app is signed with another key. Uninstalling it (its data on the phone is deleted)."
            adb uninstall "{{android_pkg}}"
            adb install "{{android_apk}}"
        else
            echo "$out" >&2
            exit 1
        fi
    fi
    echo "Installed $(adb shell dumpsys package {{android_pkg}} | grep -m1 versionName | tr -d ' ')"

# The app writes indexes into its databases on both machines, so the phone's
# copy never matches the desktop's; the change check compares the desktop
# file (and its -wal) against what was last sent instead. The desktop files
# are open with unsaved pages in their -wal files, so each is snapshotted.
# Copy new or changed desktop databases into the app on the phone
android-db:
    #!/usr/bin/env bash
    set -euo pipefail
    src=$(cat "$HOME/.local/share/epitaka_db_path" 2>/dev/null || echo "$HOME/.local/share/com.dn.epitaka")
    tmp=$(mktemp -d)
    trap 'rm -rf "$tmp"' EXIT
    mkdir -p "{{android_sent_dir}}"
    adb shell am force-stop "{{android_pkg}}"
    adb shell run-as "{{android_pkg}}" mkdir -p app_flutter
    send() {
        local db=$1 stamp=$2
        echo "$db: snapshot and copy…"
        sqlite3 "$src/$db" ".backup '$tmp/$db'"
        adb push "$tmp/$db" "/data/local/tmp/$db"
        adb shell "cat /data/local/tmp/$db | run-as {{android_pkg}} sh -c 'cat > app_flutter/$db'"
        adb shell rm "/data/local/tmp/$db"
        # A stale -wal next to a replaced file would be replayed onto it.
        adb shell run-as "{{android_pkg}}" rm -f "app_flutter/$db-wal" "app_flutter/$db-shm"
        local sent got
        sent=$(stat -c %s "$tmp/$db")
        got=$(adb shell run-as "{{android_pkg}}" stat -c %s "app_flutter/$db")
        rm "$tmp/$db"
        if [ "$sent" != "$got" ]; then
            echo "$db: copy is incomplete ($got of $sent bytes)" >&2
            exit 1
        fi
        echo "$stamp" > "{{android_sent_dir}}/$db"
        echo "$db: copied ($sent bytes)"
    }
    on_phone() { adb shell run-as "{{android_pkg}}" test -e "app_flutter/$1"; }
    for db in {{android_content_dbs}}; do
        stamp=$(stat -c '%s %Y' "$src/$db" "$src/$db-wal" 2>/dev/null | tr '\n' ' ' || true)
        if on_phone "$db" && [ "$stamp" = "$(cat "{{android_sent_dir}}/$db" 2>/dev/null)" ]; then
            echo "$db: unchanged since the last send, kept"
        else
            send "$db" "$stamp"
        fi
    done
    for db in {{android_user_dbs}}; do
        if on_phone "$db"; then
            echo "$db: the phone has its own, kept"
        else
            send "$db" "first copy"
        fi
    done

# Start the app on the phone
android-start:
    adb shell monkey -p "{{android_pkg}}" -c android.intent.category.LAUNCHER 1 >/dev/null
    @echo "ePitaka started on the phone"
