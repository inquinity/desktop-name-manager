import Foundation

public struct SetLabelResult: Equatable, Sendable {
    public var label: Label
    public var displayName: String
    /// True when the Desktop already had a label that this one replaced.
    public var replaced: Bool
}

extension SetLabelResult {
    /// The line `dnm set` prints, for example: Labeled "Email" on Built-in Display (halo, light text, bottom-left, large).
    public var confirmation: String {
        "Labeled \"\(label.text.value)\" on \(displayName) (\(label.look.rawValue), \(label.textColor) text, \(label.position.rawValue), \(label.size.rawValue))."
    }
}

extension DesktopLabeler {
    /// Puts a label on the current Desktop of `display` (FR-001 to FR-009).
    ///
    /// Order matters for crash safety: the stamp file is written, then the manifest saved, then the
    /// wallpaper set. A failure at the last step is rolled back, so nothing half-applied is left behind.
    @discardableResult
    public func setLabel(_ text: LabelText, options: LabelOptions = LabelOptions(), on display: Display) throws -> SetLabelResult {
        // One run at a time: read, decide, write and set the wallpaper without another run interleaving.
        try store.exclusive { try performSetLabel(text, options: options, on: display) }
    }

    private func performSetLabel(_ text: LabelText, options: LabelOptions, on display: Display) throws -> SetLabelResult {
        try cleanUp()
        let current = try system.currentWallpaper(on: display)
        let manifest = try store.readManifest()

        // Where the unlabeled picture comes from: our own stamp's recorded original, or the wallpaper itself.
        let replacing: Stamp?
        let original: Original
        if let ours = stamp(for: current.url, in: manifest) {
            original = ours.original
            // Any of our labels showing here counts, whatever its record says: macOS gives new Desktops a
            // copy of the first Desktop's image, so one labeled image can be on several Desktops.
            replacing = ours
        } else {
            // A file named like ours that this store does not know (another store, a lost manifest) must not
            // become an "original": it would stack labels and be deleted by that store's cleanup.
            if let url = current.url, Cleanup.isOurFileName(url.lastPathComponent) {
                throw DnmError.failure("The wallpaper \(url.lastPathComponent) was made by this tool but is not in this store (another build or a lost manifest). Choose a wallpaper in System Settings > Wallpaper, then run again. Nothing was changed.")
            }
            switch try WallpaperKind.classify(current) {
            case .unsupported(let reason): throw DnmError.unsupportedWallpaper(reason)
            case .supported(let url): original = Self.original(from: current, url: url)
            }
            replacing = nil
        }

        // Render from the recorded original, never from a previous stamp, so labels do not stack.
        let baseURL = try Self.resolve(original)
        let base = try Backdrop.loadImage(at: baseURL)
        let backdrop = try Backdrop.compose(base: base, placement: Backdrop.Placement(Self.placement(of: original)), geometry: display.geometry)
        let rendered = try LabelRenderer.render(backdrop: backdrop, text: text, options: options, geometry: display.geometry)
        let data = try ImageWriter.encode(rendered.image)

        let id = UUID()
        let fileName = "\(id.uuidString).dnm.\(ImageWriter.fileExtension)"
        let stampURL = store.fileURL(named: fileName)
        try store.writeStampFile(data, named: fileName)

        let now = time.now
        let snapshot: Manifest
        do {
            snapshot = try store.transaction { manifest in
                let before = manifest
                // Bookkeeping only (for undo and prune): other Desktops may still show the old image, which
                // stays untouched on disk.
                if let replacing, let index = manifest.stamps.firstIndex(where: { $0.id == replacing.id }) {
                    if manifest.stamps[index].isActive { manifest.stamps[index].state = .retired(at: now, reason: .replaced) }
                    manifest.stamps[index].supersededBy = id
                }
                manifest.stamps.append(Stamp(id: id, fileName: fileName, label: rendered.label, original: original,
                                             displayUUID: display.uuid, displayName: display.name,
                                             pixelWidth: rendered.image.width,
                                             pixelHeight: rendered.image.height, createdAt: now))
                manifest.changes.removeAll { $0.displayUUID == display.uuid }
                manifest.changes.append(ChangeRecord(displayUUID: display.uuid, kind: replacing == nil ? .set : .replace, at: now,
                                                     produced: .stamp(id: id),
                                                     before: replacing.map { .stamp(id: $0.id) } ?? .original(original)))
                return before
            }
        } catch {
            store.removeFile(named: fileName)
            throw error
        }

        do {
            try apply(stampURL, placement: Self.stampPlacement(fill: original.fillColor), on: display)
        } catch {
            // Undo the bookkeeping so a failed set leaves nothing behind.
            try? store.transaction { $0 = snapshot }
            store.removeFile(named: fileName)
            throw error
        }
        return SetLabelResult(label: rendered.label, displayName: display.name, replaced: replacing != nil)
    }
}
