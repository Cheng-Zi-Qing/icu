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

## Verification

Development verification:

```bash
./icu --verify
```

Optional release smoke check:

```bash
VERIFY_MACOS_SHELL_PACKAGE_CHECK=1 ./icu --verify
```

This runs:

- `swift build`
- manual runtime checks
- `swift test` only when full Xcode is active
- optional `.app` packaging + bundle structure validation

If the machine only has Command Line Tools, `swift test` is skipped explicitly. That is the supported lightweight mode.

## Signing

If you already have a Developer ID certificate:

```bash
ICU_PACKAGE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
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

Notes:

- Do not enable notarization without a valid signing identity.
- This repository only wires the notarization entrypoint. It does not claim success without real Apple credentials.

## Runtime Resources

The packaged `.app` embeds these read-only runtime resources inside the bundle:

- `assets/`
- `builder/`
- `config/copy/base.json`
- `tools/avatar_builder_bridge.py`

User-writeable settings do not live in the bundle. They are stored at:

```bash
~/Library/Application Support/ICU/config/settings.json
```

Speech override copy is stored at:

```bash
~/Library/Application Support/ICU/config/copy/active.json
```

## Python Boundary

Python is now retained only for avatar generation bridge work:

- `tools/avatar_builder_bridge.py`
- `builder/`

Desktop pet startup, AppKit windows, menu interactions, theme runtime, state transitions, and bubble rendering no longer depend on the old Python startup path.
