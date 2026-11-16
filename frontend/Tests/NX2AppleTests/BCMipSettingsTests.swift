import XCTest
import SwiftUI
@testable import NX2Apple
@testable import NXCore
import NXModel
@testable import NXLauncher

/// Ocarina keeps native NDSR while its independent BC memory controls persist per game.
@MainActor final class BCMipSettingsTests: IsolatedDefaultsTestCase {
    func testOcarinaBCChoicesPersistAcrossLanguagesAndReset() throws {
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent("upscaler-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        let output = temporary.appendingPathComponent("launcher.json")
        let result = SystemProcessRunner().capture(ProcessLaunch(
            executable: "/usr/bin/env",
            arguments: ["python3", BuildFailureTests.engine.appendingPathComponent("dm/games/settings.py").path,
                        "0400486024DEC000", temporary.path, temporary.appendingPathComponent("missing-control.nacp").path, output.path],
            environment: ["PATH": ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin",
                          "SETTINGS_PLATFORM": "mac", "GFXAPI": "nvn", "DM_LANG": "en-US",
                          "PYTHONDONTWRITEBYTECODE": "1", "PYTHONNOUSERSITE": "1"], mergesErrors: true, timeout: 10))
        XCTAssertTrue(result.ok, "Run python3 tools/engine.py sync before testing: \(result.out)")
        let rows = try XCTUnwrap(LaunchList.parse(Data(contentsOf: output))?.settings)
        XCTAssertNil(rows.first { $0.env == "DM_UPSCALER" }, "Ocarina keeps its native NDSR network")
        let store = SavedChoices(domain: TestPreferences.domain(in: temporary, "bc-mips"))
        defer { store.reset(rows) }
        let fps = try XCTUnwrap(rows.first { $0.env == "DM_FPS_TARGET" })
        XCTAssertEqual(fps.options?.first?.first, "0")
        XCTAssertEqual(rows.first { $0.env == "DM_FPS_REAL" }?.def, "1")
        let toggle = try XCTUnwrap(rows.first { $0.env == "DM_NVN_BC_MIP_SKIP" })
        let width = try XCTUnwrap(rows.first { $0.env == "DM_NVN_BC_MIP_MIN_WIDTH" })
        let height = try XCTUnwrap(rows.first { $0.env == "DM_NVN_BC_MIP_MIN_HEIGHT" })
        XCTAssertEqual(toggle.def, "0", "Mac retains full texture quality by default")
        XCTAssertEqual(width.def, "512")
        XCTAssertEqual(height.def, "512")
        store.set(toggle, "1")
        store.set(width, "1024")
        store.set(height, "256")
        XCTAssertEqual(store.current(width.localized { L10n.string($0, .zh) }), "1024")
        XCTAssertEqual(store.current(height.localized { L10n.string($0, .zh) }), "256")
        XCTAssertEqual(width.localized { L10n.string($0, .zh) }.label, "贴图最小宽度")
        XCTAssertEqual(height.localized { L10n.string($0, .zh) }.label, "贴图最小高度")
        if let directory = ProcessInfo.processInfo.environment["NX_LAUNCHER_CAPTURE_DIR"] {
            try captureSettings(json: Data(contentsOf: output), temporary: temporary, domain: store.domain, directory: directory)
        }
        let game = LibraryGame(titleID: "0400486024DEC000", name: "Ocarina of Time")
        let legacyEnvironment = game.startEnvironment(controls: [:], settings: rows, mods: [], store: store, appReadsStore: false)
        XCTAssertEqual(legacyEnvironment["DM_NVN_BC_MIP_SKIP"], "1")
        XCTAssertEqual(legacyEnvironment["DM_NVN_BC_MIP_MIN_WIDTH"], "1024")
        XCTAssertEqual(legacyEnvironment["DM_NVN_BC_MIP_MIN_HEIGHT"], "256")
        store.reset(rows)
        XCTAssertEqual(store.current(toggle), "0")
        XCTAssertEqual(store.current(width), "512")
        XCTAssertEqual(store.current(height), "512")
    }

    private func captureSettings(json: Data, temporary: URL, domain: String, directory: String) throws {
        let app = temporary.appendingPathComponent("Ocarina.app"), output = URL(fileURLWithPath: directory)
        let dm = app.appendingPathComponent("Contents/Resources/dm")
        try FileManager.default.createDirectory(at: dm, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        try json.write(to: dm.appendingPathComponent("launcher.json"))
        try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": domain, "DMTitleID": "0400486024DEC000"], format: .xml, options: 0)
            .write(to: app.appendingPathComponent("Contents/Info.plist"))
        let game = LibraryGame(titleID: "0400486024DEC000", name: "The Legend of Zelda: Ocarina of Time", appPath: app.path)
        let file = temporary.appendingPathComponent("library.json")
        try JSONEncoder().encode([game]).write(to: file)
        let library = GameLibrary(file: file)
        let stores = LauncherStores(defaults: testDefaults)
        NSApplication.shared.setActivationPolicy(.accessory)
        for language in [Lang.en, .zh] {
            stores.localizer.lang = language
            let focus = PadFocus()
            let host = NSHostingView(rootView: LaunchOptionsView(m: stores.build, library: library, gameID: game.id)
                .environmentObject(focus).environmentObject(stores.localizer).launcherDropdownHost())
            let window = OffscreenWindow(size: NSSize(width: 600, height: 700))
            window.contentView = host
            window.orderFront(nil)
            RunLoop.main.run(until: Date().addingTimeInterval(0.5))
            focus.focused = "opt.DM_NVN_BC_MIP_SKIP"
            RunLoop.main.run(until: Date().addingTimeInterval(0.4))
            host.layoutSubtreeIfNeeded()
            let textures = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
            host.cacheDisplay(in: host.bounds, to: textures)
            try XCTUnwrap(textures.representation(using: .png, properties: [:])).write(to: output.appendingPathComponent("bc-mips-\(language.code).png"))
            window.orderOut(nil)
        }
    }
}
