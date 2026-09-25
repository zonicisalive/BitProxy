# BitProxy

Personal fork of [sing-box for Android](https://github.com/SagerNet/sing-box-for-android) (SFA),
the Android client of [sing-box](https://github.com/SagerNet/sing-box) by
[SagerNet](https://github.com/SagerNet). All the heavy lifting (the proxy engine, WireGuard,
the VPN service and the app itself) is their work; BitProxy only adds a layer on top. It imports WireGuard configs (for example
Proton VPN), gives every app and clone its own **VPN / Direct / Block** switch, and generates,
checks and applies the sing-box config inside the app. It replaces the Termux script
`conf-merger.py`. GPLv3, like upstream.

Upstream isn't stored in this repo. `versions.env` pins sing-box and SFA, and `patches/`
holds the BitProxy changes as `git format-patch` files. They're applied on top of every build.

App id: `com.zonicisalive.bitproxy`. It installs next to the official SFA app.

**Download:** [Releases](https://github.com/zonicisalive/BitProxy/releases). Use
`SFA-*-arm64-v8a.apk` for current phones. Updates install over the previous version.

## Features

- **Servers:** import WireGuard `.conf` files (any number). They're validated and stored in
  private app storage only. Pick a server, or choose **Fastest (auto)** with a check interval
  of 1–30 min. The Dashboard card shows latency, or "No response" when a server is down.
- **Apps:** a VPN / Direct / Block switch for each app, clone (user 999) and work profile,
  on the Dashboard and in the app picker. Rules match on Android user id, so reinstalled
  apps keep their setting. Blocked apps get no traffic and no DNS.
- **Everything stays in the tunnel:** Android's per-app VPN exclude lists are never used, so
  Always-on with "Block connections without VPN" works for every app. The routing happens
  inside sing-box.
- **No DNS leaks:** VPN apps resolve through the server's DNS inside the tunnel. Direct apps
  use normal DNS.
- **Automatic IPv6:** on networks with real IPv6, the server's IPv6 address is added to the
  tunnel. Otherwise it runs IPv4-only.
- **Trusted Wi-Fi:** networks where every app goes Direct (blocked apps stay blocked). Needs
  location permission set to "Allow all the time".
- **Always through VPN:** a domain list that uses the VPN even for apps not in the list.
- **Quick Settings tiles:** three tiles, each flipping one app between VPN and Direct.
- **New apps:** a notification asks "VPN, Direct or Block?" when an app is installed.
- **Safety:**
  - Apply checks the config with sing-box before using it, and the previous config can be
    restored.
  - The Dashboard shows the Always-on / Block state, and asks before stopping under lockdown.
  - **Recovery:** after 2+ minutes without any network, sing-box is restarted cleanly. If
    stopping or restarting hangs, the process is ended and the VPN restarted.
- **Diagnostics:** tunnel, DNS, IPv6 and Always-on state, clone detection, last Apply, and a
  **Recent events** log that survives the night. The export removes all private keys.

## Phone setup

1. Install the APK from [Releases](https://github.com/zonicisalive/BitProxy/releases)
   (`…-arm64-v8a.apk` for current phones). Allow notifications.
2. Settings → BitProxy → **Import .conf files**, then **Apps**, then **Apply**.
3. Start the VPN from the Dashboard and allow the VPN request.
4. Android: Settings → Network (on OxygenOS: Connection & sharing) → VPN → BitProxy ⚙ →
   **Always-on VPN** + **Block connections without VPN**. Turn Always-on off in other VPN
   apps first.
5. Battery: allow background activity / don't optimize. This is required, for example for
   the automatic restart after a hang.
6. Check it: BitProxy → **Leak test** in a VPN app (server IP) and in a Direct app (your own
   IP), then **Diagnostics**.

On OxygenOS, also turn off any setting that switches Wi-Fi off during sleep. BitProxy
recovers from it, but the phone has no network in that time.

## Troubleshooting

- **No internet but the VPN looks on:** open Diagnostics and read "Recent events" (network
  lost/back, restarts, stops), then use **Export log**. It contains no keys.
- **Over USB:** `adb logcat --pid=$(adb shell pidof com.zonicisalive.bitproxy)`. OxygenOS
  keeps only about 90 seconds of logcat, so the events log is the long-term record.

## Layout

| Path | What |
|---|---|
| `versions.env` | Pinned sing-box tag, SFA commit, Go / NDK / gomobile versions |
| `patches/android/` | BitProxy commits on top of SFA (new code lives in `io.nekohasekai.sfa.bitproxy`) |
| `patches/core/` | Commits on top of sing-box (none so far) |
| `build-release.sh` | Fresh clone of pinned upstream, apply patches, build libbox + APK, run unit tests |
| `.github/workflows/release.yml` | The same build on GitHub, signed and published as a release |
| `.github/workflows/auto-update.yml` | Daily: build and release new upstream versions automatically |
| `setup-android-dev.sh` | One-time toolchain setup (Go, JDK 17, Android SDK/NDK, emulator) on `/media/Absolute/dev` |
| `run.sh`, `gw` | Build + run on the emulator (never on a connected phone); Gradle with the right toolchain |
| `check-upstream.sh` | Try all patches on a newer upstream: apply, build libbox + APK, run unit tests |
| `export-patches.sh` | Regenerate `patches/` from the local `bitproxy` branches |
| `make-keystore.sh` | Optional helper to create a release signing key |
| `reference/` | `conf-merger.py`, the original script (not committed) |

## Building a signed APK

Create a key once and back it up; every update must be signed with the same key:

```bash
keytool -genkeypair -keystore /media/Absolute/dev/mykeys/bitproxy.keystore \
  -alias bitproxy -keyalg RSA -keysize 4096 -validity 36500
```

Put the password in `/media/Absolute/dev/mykeys/signing.properties` (chmod 600):

```
KEYSTORE_PASS=...
ALIAS_NAME=bitproxy
ALIAS_PASS=...
```

Build:

```bash
source /media/Absolute/dev/env.sh
RELEASE_KEYSTORE=/media/Absolute/dev/mykeys/bitproxy.keystore \
LOCAL_PROPERTIES="$(cat /media/Absolute/dev/mykeys/signing.properties)" \
WORK_DIR=/media/Absolute/dev/build-work ./build-release.sh
```

APKs end up in `build-work/sing-box-for-android/app/build/outputs/apk/other/release/`.
Install over USB with `adb install -r <apk>` (same key = settings kept).

Never copy the key into the `sing-box` checkout: upstream tracks a file at
`app/release.keystore`, so `git add -A` would commit your key. `build-release.sh` only uses
its own throwaway clone and deletes the copy afterwards.

## Release on GitHub

1. Repository secrets: `KEYSTORE_BASE64` (`base64 -w0 bitproxy.keystore`), `KEYSTORE_PASS`,
   `ALIAS_NAME`, `ALIAS_PASS`.
2. Actions → Release → Run workflow (or push a `v*` tag). APKs appear under Releases.

## Automatic updates

`auto-update.yml` runs every day (and on demand under Actions → Auto update):

1. It looks for a new **stable** sing-box tag (for example `v1.14.3`). It waits until the
   app's `main` branch reaches the same version (a "Bump version 1.14.3" commit with that
   `VERSION_NAME`). sing-box-for-android has no tags of its own.
2. It builds on that pair with the patches in this repo: libbox, unit tests, a signed APK.
3. **Success:** it publishes a release with **the same tag as sing-box** (`v1.14.3`) and
   commits the new versions to `versions.env`.
4. **Failure** (a patch conflict or a failing build/test): it opens an issue "BitProxy
   patches fail on sing-box v1.14.3" with a link to the log, and publishes nothing.

Manual runs of **Release** use the tag from `versions.env`, or `v1.14.2-r<run>` when that
release already exists (patch changes on the same upstream). Pre-releases (alpha, beta, rc)
are never picked up automatically.

## Upgrading to a new upstream release by hand

1. Try it first: `./check-upstream.sh` checks the newest sing-box release with SFA `main`.
   `./check-upstream.sh v1.15.0 dev` checks a specific pair. It says whether the patches
   apply, the build works and the tests pass, and shows where it failed if not. Tested:
   all patches apply and pass on sing-box 1.15.0-alpha.8 + SFA `dev`, and sing-box 1.15
   accepts every config BitProxy generates.
2. Read the sing-box changelog for removed or deprecated config fields. Update
   `ConfigGenerator` and the golden tests if anything BitProxy writes changed.
3. In the local checkouts: `git switch -c bitproxy-new <new tag / commit>` and
   `git am -3 /home/zonic/BitProxy/patches/…/*.patch`. Fix conflicts, rebuild libbox, and
   run the unit tests.
4. Update `versions.env`, run `./export-patches.sh`, commit.

## Testing checklist (before each release)

- Unit tests and release lint pass (`./gw :app:testOtherDebugUnitTest :app:lintVitalOtherRelease`).
- Emulator:
  - fresh install, import confs, pick apps, Apply, then start without reopening the app
  - reboot with Always-on
  - a second user (`adb shell pm create-user test`)
  - reinstall a listed app
  - switch networks
  - a 3-minute outage (`svc wifi disable; svc data disable`): the events log shows
    "network back … restarting VPN"
  - server down, IPv6 on and off
- Phone:
  - an overnight run
  - leak check: a VPN app shows the server IP, a Direct app your own IP, no IPv6 leak
  - clones (user 999) are detected in Diagnostics and routed
- The signing key is backed up. Changing it forces an uninstall.

## Source code and license

BitProxy is free software under the GNU General Public License v3.0 (see `LICENSE`), as are
sing-box and sing-box-for-android, which it is built from. The complete source of each
release is the upstream code at the versions in `versions.env` plus the patches in
`patches/`. `build-release.sh` rebuilds it exactly. BitProxy isn't affiliated with or
endorsed by SagerNet / sing-box; "sing-box" names the upstream project it's based on.

Thanks to [nekohasekai](https://github.com/nekohasekai) and the
[SagerNet](https://github.com/SagerNet) contributors for sing-box and its Android app, a
great piece of free software. If BitProxy is useful to you, consider supporting
[the upstream project](https://github.com/SagerNet/sing-box).
