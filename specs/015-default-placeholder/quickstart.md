# Quickstart: live check for spec 015

Live checks change the real wallpaper (principle VII). They need live control: ask first, then announce with
`say "Requesting lyve control"` and, when done, `say "Completed using lyve control"`.

## Before

```bash
cp "$HOME/Library/Application Support/com.apple.wallpaper/Store/Index.plist" "$TMPDIR/Index.plist.backup"
```

```bash
export DNM_STORE_DIR="$(mktemp -d)"
```

Use the `dnm` built from this branch (`just build`) and quote `dnm --version` in the record.

## Steps

1. In System Settings > Wallpaper, choose **Golden Gate** (dynamic) for the current Desktop. Run `dnm set Test` and
   `echo $?`. Expect "This wallpaper is not supported yet: macOS reports the default wallpaper when dynamic or
   unsupported wallpapers are selected. Nothing was changed.", exit code 3, and the dynamic wallpaper still showing.
2. Repeat with **Macintosh** (dynamic) and, if offered, an aerial wallpaper. Note whether each is refused by this
   reason or another one (an aerial may report its video and be refused as a video).
3. Look through System Settings > Wallpaper for any choice that is the plain default still. If one exists, choose
   it, run `dnm set Test`, and record whether it is refused (spec edge case: it should be).
4. Choose an Apple still (for example Sonoma). Run `dnm set Test`, check the label, then `dnm remove`: labeled and
   restored as in 0.3.0.

## After

Restore with `dnm remove` where a label was set, and choose the original wallpaper again. Restore `Index.plist` from
the backup only if the wallpapers are not as they were. Remove the throwaway store.

## Record

Date, macOS version, `dnm --version`, and the outcome of each step, in this file under a "Results" heading.

## Results

2026-11-20, macOS 27.2.1, `dnm --version` 0.3.1 build 34 (41c304e), throwaway store, on the second display. The
built-in display showed a label from another session's throwaway store and was left alone. Wallpapers chosen by the
maintainer in System Settings; what macOS reported was read with `NSWorkspace.desktopImageURL(for:)`.

| Step | Wallpaper | Reported | `dnm set Test` | Result |
|---|---|---|---|---|
| 1 | Golden Gate (dynamic) | the stand-in | refused with the spec 015 reason, exit 3 | pass: wallpaper unchanged, nothing stored |
| 2 | Macintosh (dynamic) | the stand-in | refused, exit 3 | pass |
| 2 | an aerial | the stand-in | refused, exit 3 | pass (aerials report the stand-in too) |
| 3, 4 | the plain still offered in Settings (`Mac Blue.heic`) | its own file | labeled, exit 0; `dnm remove` restored it | pass: a real still is not mistaken for the stand-in |

`Index.plist` was backed up first and not restored (not needed: `dnm remove` restored the only label set; the
maintainer resets the chosen wallpapers).
