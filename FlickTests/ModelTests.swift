import Foundation
import Testing
@testable import Flick

@MainActor
struct ModelTests {
    private func freshSettings() -> AppSettings {
        let suite = UserDefaults(suiteName: "tests.\(UUID().uuidString)")!
        return AppSettings(defaults: suite)
    }

    @Test func readerParsesHeadingsIntoSections() {
        let (blocks, titles) = ReaderModel.parse("""
        # One
        first para
        continues

        second para
        # Two
        third
        """)
        #expect(titles == ["One", "Two"])
        #expect(blocks.count == 5)
        #expect(blocks[1].section == 0)
        #expect(blocks[4].section == 1)
        if case .paragraph(_, let text, _) = blocks[1] {
            #expect(text == "first para continues")
        } else {
            Issue.record("expected a paragraph")
        }
    }

    @Test func readerWithoutHeadingsHasOneSection() {
        let (blocks, titles) = ReaderModel.parse("just some text\n\nand more")
        #expect(titles == ["Start"])
        #expect(blocks.count == 2)
    }

    @Test func slidesNavigateWithinBounds() {
        let slides = SlidesModel(defaults: freshSettings().defaults)
        slides.loadSample()
        #expect(slides.count == 6)
        #expect(slides.apply(.right) == "First slide")
        #expect(slides.apply(.left) == "Next slide")
        #expect(slides.index == 1)
        slides.crown(2.2)
        #expect(slides.index == 3)
        slides.crown(-5)
        #expect(slides.index == 0)
        #expect(slides.apply(.down) == "Blanked")
        #expect(slides.context.label(for: .down) == "Unblank")
        _ = slides.apply(.left)
        #expect(slides.isBlanked == false, "moving on unblanks")
    }

    @Test func prompterSpeedClampsAndLegendFollowsState() {
        let prompter = PrompterModel(settings: freshSettings())
        prompter.loadSample()
        for _ in 0..<40 { _ = prompter.apply(.up) }
        #expect(prompter.speed == PrompterModel.maxSpeed)
        for _ in 0..<40 { _ = prompter.apply(.down) }
        #expect(prompter.speed == PrompterModel.minSpeed)
        #expect(prompter.context.label(for: .tap) == "Play")
        _ = prompter.apply(.tap)
        #expect(prompter.isPlaying)
        #expect(prompter.context.label(for: .tap) == "Pause")
        prompter.pause()
    }

    @Test func photosStarRemoveAndBounds() {
        let photos = PhotosModel()
        photos.loadSample()
        let count = photos.count
        #expect(count == 5)
        #expect(photos.apply(.up) == "Starred")
        #expect(photos.context.badge == "star.fill")
        #expect(photos.apply(.down) == "Removed")
        #expect(photos.count == count - 1)
        #expect(photos.context.badge == nil)
        for _ in 0..<10 { _ = photos.apply(.left) }
        #expect(photos.index == photos.count - 1)
        #expect(photos.apply(.left) == "Last one")
    }

    @Test func hubReversesHorizontalWhenAsked() {
        let settings = freshSettings()
        settings.reverseHorizontal = true
        let hub = SwipeHub(settings: settings)
        hub.setMode(.slides)
        hub.slides.loadSample()
        hub.handle(SwipeEvent(direction: .right, source: .phone))
        #expect(hub.slides.index == 1, "a right flick means next when reversed")
        #expect(hub.context.label(for: .right) == "Next")
        #expect(hub.context.label(for: .left) == "Previous")
    }
}
