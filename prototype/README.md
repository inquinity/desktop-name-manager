# Prototype

`dnm-prototype.swift` is the single-file proof of concept that validated stamping labels
into per-Desktop wallpapers on macOS 27. It is not the product; the app will be built
from the specification.

```sh
swiftc -O -o dnm-prototype dnm-prototype.swift

./dnm-prototype "Status Report"      # label the current Desktop
./dnm-prototype clear                # put the original wallpaper back
./dnm-prototype list                 # every Desktop and its label
./dnm-prototype --preview /tmp/p.jpg --verbose "Status Report"   # render only
```

Labeled images and `manifest.json` live in
`~/Library/Application Support/dnm-prototype/`. What testing it showed is in
[../docs/research/findings.md](../docs/research/findings.md).
