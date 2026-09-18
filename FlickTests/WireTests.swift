import Foundation
import Testing
@testable import Flick

struct WireTests {
    @Test func swipeSurvivesTheRoundTrip() throws {
        let event = SwipeEvent(direction: .left, distance: 80, speed: 900, source: .watch)
        let data = try #require(Wire.encode(.swipe(event)))
        guard case .swipe(let decoded) = try #require(Wire.decodeMessage(data)) else {
            Issue.record("wrong case")
            return
        }
        #expect(decoded.id == event.id)
        #expect(decoded.direction == .left)
        #expect(abs(decoded.sentAt.timeIntervalSince(event.sentAt)) < 0.001)
    }

    @Test func contextLegendIsAPlainObject() throws {
        let context = PhoneContext(mode: .slides, title: "Deck", subtitle: "1 of 6", badge: "timer",
                                   legend: PhoneContext.legend([(.left, "Next"), (.tap, "Hide bar")]))
        let data = try #require(Wire.encode(context))
        let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let legend = try #require(json["legend"] as? [String: String])
        #expect(legend["left"] == "Next")
        let back = try #require(Wire.decodeContext(data))
        #expect(back == context)
        #expect(back.label(for: .tap) == "Hide bar")
        #expect(back.label(for: .up) == nil)
    }

    @Test func dictionaryFormsCarryMessagesAndContext() throws {
        let info = Wire.userInfo(for: .setMode(.prompter))
        guard case .setMode(let mode) = try #require(Wire.message(from: info)) else {
            Issue.record("wrong case")
            return
        }
        #expect(mode == .prompter)
        let ctx = Wire.applicationContext(for: .empty)
        #expect(Wire.context(from: ctx) == PhoneContext.empty)
        #expect(Wire.context(from: ["other": Data()]) == nil)
    }
}
