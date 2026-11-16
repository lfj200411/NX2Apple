import Foundation
import Testing
import ShellUI
@testable import ShellHost

@Suite struct BCMipSettingsTests {
    @Test func independentThresholdsPersistAndTurningOffHidesThem() throws {
        let profile = try LauncherProfile.parse(Data("""
        {"schema":1,"game":"0400486024DEC000","settings":[
          {"env":"DM_NVN_BC_MIP_SKIP","kind":"toggle","note":"","section":"Game","label":"Reduce BC texture memory","default":"1"},
          {"env":"DM_NVN_BC_MIP_MIN_WIDTH","kind":"choice","note":"","section":"Game","label":"Minimum texture width","default":"512","options":[["256","256 px"],["512","512 px"],["1024","1024 px"]],"needs":"DM_NVN_BC_MIP_SKIP=1"},
          {"env":"DM_NVN_BC_MIP_MIN_HEIGHT","kind":"choice","note":"","section":"Game","label":"Minimum texture height","default":"512","options":[["256","256 px"],["512","512 px"],["1024","1024 px"]],"needs":"DM_NVN_BC_MIP_SKIP=1"}]}
        """.utf8))
        let box = try Sandbox()
        let defaults = box.defaults("0400486024DEC000")
        let store = GameSettingsStore(profile: profile, defaults: defaults)
        #expect(store.set("DM_NVN_BC_MIP_MIN_WIDTH", to: "1024"))
        #expect(store.set("DM_NVN_BC_MIP_MIN_HEIGHT", to: "256"))
        #expect(SettingsPresenter.sections(profile: profile, values: store.values()).first?.rows.count == 3)
        #expect(store.set("DM_NVN_BC_MIP_SKIP", to: "0"))
        let again = GameSettingsStore(profile: profile, defaults: defaults)
        #expect(again.values()["DM_NVN_BC_MIP_MIN_WIDTH"] == "1024")
        #expect(again.values()["DM_NVN_BC_MIP_MIN_HEIGHT"] == "256")
        #expect(again.values()["DM_NVN_BC_MIP_SKIP"] == "0")
        #expect(SettingsPresenter.sections(profile: profile, values: again.values()).first?.rows.map(\.id) == ["DM_NVN_BC_MIP_SKIP"])
        #expect(!again.set("DM_NVN_BC_MIP_MIN_WIDTH", to: "garbage"))
        again.reset()
        #expect(again.values()["DM_NVN_BC_MIP_SKIP"] == "1")
        #expect(again.values()["DM_NVN_BC_MIP_MIN_WIDTH"] == "512")
        #expect(again.values()["DM_NVN_BC_MIP_MIN_HEIGHT"] == "512")
    }
}
