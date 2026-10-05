import DesktopNameCore
import Foundation
import Testing

/// Local-only check that the read-only store reader copes with the real, private wallpaper store on this
/// Mac. It reads the file and prints counts only; it never writes, and it prints no paths or identifiers.
@Suite struct RealStoreReaderTests {
    @Test(.enabled(if: FileManager.default.fileExists(atPath: WallpaperStoreReader.defaultURL.path)))
    func theReaderParsesTheRealStore() throws {
        let reader = WallpaperStoreReader()
        // A name that cannot be in the store: the store must still parse, and report "not referenced".
        let absent = try #require(reader.references(to: "00000000-0000-0000-0000-000000000000.dnm.jpg"))   // hygiene-allow: a name that cannot exist
        #expect(!absent.isReferenced)
        // Every stamp name the tool itself knows, if any, can be looked up without error.
        let store = Store(directory: Store.defaultDirectory())
        let manifest = try store.readManifest()
        var referenced = 0
        for stamp in manifest.stamps where reader.references(to: stamp.fileName)?.isReferenced == true { referenced += 1 }
        print("real store: parsed; \(manifest.stamps.count) known stamps, \(referenced) still referenced by macOS")
    }
}
