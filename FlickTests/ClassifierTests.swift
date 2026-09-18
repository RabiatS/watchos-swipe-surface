import CoreGraphics
import Testing
@testable import Flick

struct ClassifierTests {
    let classifier = SwipeClassifier()

    @Test func horizontalFlickIsLeftOrRight() {
        let left = classifier.classify(translation: CGSize(width: -80, height: 4),
                                       predictedEnd: CGSize(width: -120, height: 6),
                                       velocity: CGSize(width: -900, height: 20))
        #expect(left?.direction == .left)
        let right = classifier.classify(translation: CGSize(width: 60, height: -3),
                                        predictedEnd: CGSize(width: 90, height: -4),
                                        velocity: CGSize(width: 700, height: -10))
        #expect(right?.direction == .right)
    }

    @Test func verticalFlickIsUpOrDown() {
        let up = classifier.classify(translation: CGSize(width: 2, height: -70),
                                     predictedEnd: CGSize(width: 3, height: -100),
                                     velocity: CGSize(width: 10, height: -800))
        #expect(up?.direction == .up)
        let down = classifier.classify(translation: CGSize(width: -5, height: 50),
                                       predictedEnd: CGSize(width: -6, height: 70),
                                       velocity: CGSize(width: -20, height: 600))
        #expect(down?.direction == .down)
    }

    @Test func diagonalIsIgnored() {
        let reading = classifier.classify(translation: CGSize(width: 60, height: 55),
                                          predictedEnd: CGSize(width: 90, height: 80),
                                          velocity: CGSize(width: 600, height: 550))
        #expect(reading == nil)
    }

    @Test func shortSlowDragIsIgnoredButShortFastFlickCounts() {
        let brush = classifier.classify(translation: CGSize(width: 12, height: 0),
                                        predictedEnd: CGSize(width: 14, height: 0),
                                        velocity: CGSize(width: 40, height: 0))
        #expect(brush == nil)
        let flick = classifier.classify(translation: CGSize(width: 15, height: 0),
                                        predictedEnd: CGSize(width: 90, height: 0),
                                        velocity: CGSize(width: 1500, height: 0))
        #expect(flick?.direction == .right)
    }
}
