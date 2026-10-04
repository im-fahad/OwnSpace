# OwnSpace

A free, open-source Mac cleaner. It finds caches, logs, Xcode leftovers and package caches,
shows how much space each takes, and moves what you pick to the Trash.

No account, no subscription, no network access. Everything happens on your Mac.

## What it cleans

| Category | Where |
|---|---|
| App caches | `~/Library/Caches` |
| Logs | `~/Library/Logs` |
| Xcode | DerivedData, Archives, Products, iOS and watchOS DeviceSupport |
| Simulators | `~/Library/Developer/CoreSimulator/Caches` (your simulators stay) |
| Package caches | npm, pnpm, Gradle, `~/.cache` |
| Trash | `~/.Trash` |

Every item is moved to the Trash, so you can put it back. Only items already in the Trash are
deleted for good. OwnSpace never touches anything outside the folders above.

## Build

Requires macOS 14 or later and Xcode (or the Swift toolchain).

```sh
swift run ownspace          # run it straight away
swift test                  # run the tests
scripts/build-app.sh        # build dist/OwnSpace.app, ad-hoc signed
```

## Full Disk Access

Some folders, such as the Trash, are readable only with Full Disk Access. OwnSpace shows a link
when it hits one. Turn it on in System Settings → Privacy & Security → Full Disk Access.

## License

MIT
