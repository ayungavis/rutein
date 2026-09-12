import RuteinKit
import Testing

@Suite("Loadable")
struct LoadableTests {
    @Test("Content survives a refresh and a failure")
    func retainsPreviousAcrossStates() {
        let loaded = Loadable<[String]>.loaded(["Ridge Loop"])
        let refreshing = Loadable<[String]>.loading(previous: loaded.value)
        let failed = Loadable<[String]>.failed(.storage, previous: refreshing.value)

        #expect(refreshing.value == ["Ridge Loop"])
        #expect(failed.value == ["Ridge Loop"])
    }

    @Test("Idle carries nothing")
    func idleCarriesNothing() {
        #expect(Loadable<[String]>.idle.value == nil)
    }
}
