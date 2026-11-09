# macOS Shell Release Guide

## Local Build

Build a local `.app` bundle:

```bash
./icu --package-app
```

Default output:

```bash
dist/ICU.app
```

Check the bundle structure:

```bash
bash tools/check_macos_app_bundle.sh dist/ICU.app
```

## Release Template

A shell-ready environment template is available at:

```bash
tools/macos_shell_release.env.example
```

Recommended setup:

```bash
cp tools/macos_shell_release.env.example tools/macos_shell_release.env
$EDITOR tools/macos_shell_release.env
set -a
source tools/macos_shell_release.env
set +a
```

## Verification

Development verification:

```bash
./icu --verify
```

Optional release smoke check:

```bash
VERIFY_MACOS_SHELL_PACKAGE_CHECK=1 ./icu --verify
```

Release verification with detached runtime smoke check:

```bash
VERIFY_MACOS_SHELL_PACKAGE_CHECK=1 \
VERIFY_MACOS_SHELL_RUNTIME_SMOKE_CHECK=1 \
./icu --verify
```

This runs:

- `swift build`
- manual runtime checks
- `swift test` only when full Xcode is active
- optional `.app` packaging + bundle structure validation
- optional detached app runtime smoke check

If the machine only has Command Line Tools, `swift test` is skipped explicitly. That is the supported lightweight mode.

Verification boundaries:

- Bundle structure check proves packaging output shape (bundle layout, metadata, resource placement).
- Detached runtime smoke check proves the copied `.app` can launch from a detached run directory and initialize runtime paths/app-support root.
- Signing, notarization, and Gatekeeper acceptance are not covered by `./icu --verify`; those remain the next release phase.

## Signing

If you already have a Developer ID certificate:

```bash
ICU_PACKAGE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
./icu --package-app
```

Using the template file:

```bash
set -a
source tools/macos_shell_release.env
set +a
./icu --package-app
```

## Notarization

If `notarytool` keychain profile is configured:

```bash
ICU_PACKAGE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
ICU_PACKAGE_NOTARIZE=1 \
ICU_NOTARYTOOL_PROFILE="icu-notary" \
./icu --package-app
```

Template-driven final release commands:

```bash
set -a
source tools/macos_shell_release.env
set +a
VERIFY_MACOS_SHELL_PACKAGE_CHECK=1 \
VERIFY_MACOS_SHELL_RUNTIME_SMOKE_CHECK=1 \
./icu --verify
./icu --package-app
```

If notarization is enabled in the env file, the second command will package, sign, submit, wait, and staple in one run.

Notes:

- Do not enable notarization without a valid signing identity.
- This repository only wires the notarization entrypoint. It does not claim success without real Apple credentials.

## Runtime Resources

The packaged `.app` embeds these read-only runtime resources under `Contents/Resources/repo/`:

- `assets/` — pet frames, cursors, UI icons and pixel fonts
- `config/copy/` — the user-visible string catalog
- `config/wardrobe.json` — the wardrobe catalog

User-writeable settings do not live in the bundle:

```bash
~/Library/Application Support/ICU/config/settings.json
```

`edge_snap`, `timers` and `user` live in that file. If it does not exist, the app falls back to its
built-in defaults (or, in a source checkout, to `config/settings.json` in the repo) and writes the
file once you change a setting.

Copy overrides are merged on top of the bundled catalog:

```bash
~/Library/Application Support/ICU/config/copy/active.json
```
