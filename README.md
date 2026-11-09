# Radish

Virtual screens shaped like your iPad. A tiny macOS menu bar app that gives your Mac a display at your iPad's exact size, so Jump Desktop and other remote desktop apps fill the whole screen with sharp HiDPI and no letterbox.

**[Download](https://github.com/brendanrong/Radish/releases/latest/download/Radish.dmg)** · [Website](https://brendanrong.github.io/Radish/) · macOS 15 or later

## What it does

- **A proper app window** (open Radish from Finder or the menu bar, ⌘,): displays in a sidebar, resolution grids, virtual screen settings. The menu bar stays as the quick switcher
- **Virtual screens** with exact presets for every current iPad (iPad Pro 11" M4 is 2420 × 1668) plus custom sizes
- **HiDPI "looks like" sizes**: sharpest at 2x like iPadOS, or more space at 1.125x, 1.25x, 1.5x, or 1x native
- **Mirror Other Displays** (one desktop in the iPad's shape, lid open or closed) or **Use as Main Display**, and portrait
- **Resolution picker** for every display, including HiDPI modes System Settings hides
- **Restores resolutions** you pick when a display reconnects or the Mac wakes
- **`radish://on`**, **`radish://off`**, **`radish://toggle`** for Shortcuts and scripts

## With Jump Desktop

1. Menu bar radish → **New Virtual Screen** → your iPad. Accept Launch at Login.
2. Turn on **Mirror Other Displays**.
3. In Jump Desktop on the iPad, turn on **Retina resolution** and connect.

## Build

```sh
./build.sh                               # build/Radish.app, signed with your Developer ID if present
build/Radish.app/Contents/MacOS/Radish --list-displays   # every display and the modes it exposes
build/Radish.app/Contents/MacOS/Radish --snapshot /tmp/s  # renders every window page, light and dark
NOTARY_PROFILE=Cherry-Notary ./release.sh 0.1.0          # notarized build/Radish.dmg
```

No Xcode project and no dependencies. Virtual screens use the private `CGVirtualDisplay` API in CoreGraphics (declared in `Sources/CVirtualDisplay`), which means no Mac App Store. Logs go to `~/Library/Logs/Radish.log`.

The icon is `Resources/AppIcon.svg`, rendered with `Tools/render_icon.sh`.

## License

MIT. See [LICENSE](LICENSE).
