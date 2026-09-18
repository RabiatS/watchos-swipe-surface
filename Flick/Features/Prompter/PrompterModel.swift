import Foundation
import Observation

/// A script that scrolls past a reading line at a steady pace. Tap starts and
/// stops it; up and down change the pace; left and right jump.
@MainActor
@Observable
final class PrompterModel: ModeController {
    let mode = Mode.prompter
    private let settings: AppSettings

    private(set) var title = "No script"
    private(set) var text = ""
    private(set) var isSample = false

    /// Points per second.
    private(set) var speed: Double
    private(set) var isPlaying = false
    /// Offset at the moment playback last started or was last adjusted.
    private var baseOffset: CGFloat = 0
    private var startedAt: Date?

    /// Reported by the view.
    var contentHeight: CGFloat = 1
    var viewportHeight: CGFloat = 1

    static let minSpeed = 10.0
    static let maxSpeed = 200.0
    private static let speedKey = "prompter.speed"

    init(settings: AppSettings) {
        self.settings = settings
        speed = settings.defaults.object(forKey: Self.speedKey) as? Double ?? 40
        restore()
    }

    var textSize: Double { settings.prompterTextSize }
    var isMirrored: Bool { settings.prompterMirror }

    /// The scroll offset at a given moment, for the animation timeline.
    func offset(at date: Date) -> CGFloat {
        guard isPlaying, let startedAt else { return baseOffset }
        return min(maxOffset, baseOffset + CGFloat(date.timeIntervalSince(startedAt) * speed))
    }

    var maxOffset: CGFloat { max(0, contentHeight - viewportHeight * 0.3) }

    var progress: Double {
        guard maxOffset > 0 else { return 0 }
        return min(1, max(0, currentOffset / maxOffset))
    }

    private var currentOffset: CGFloat { offset(at: .now) }

    // MARK: Content

    func load(url: URL) throws {
        let kept = try DocumentStore.keep(url, as: "script.txt", for: .prompter)
        text = try String(contentsOf: kept, encoding: .utf8)
        title = url.deletingPathExtension().lastPathComponent
        isSample = false
        restart()
    }

    func paste(_ newText: String, title: String = "Pasted script") throws {
        _ = try DocumentStore.write(Data(newText.utf8), as: "script.txt", for: .prompter)
        text = newText
        self.title = title
        isSample = false
        restart()
    }

    func loadSample() {
        guard let url = SampleContent.scriptURL,
              let sample = try? String(contentsOf: url, encoding: .utf8) else { return }
        DocumentStore.remove("script.txt", for: .prompter)
        text = sample
        title = "Sample script"
        isSample = true
        restart()
    }

    private func restore() {
        if let url = DocumentStore.url("script.txt", for: .prompter),
           let saved = try? String(contentsOf: url, encoding: .utf8) {
            text = saved
            title = "Your script"
            isSample = false
        } else {
            loadSample()
        }
    }

    // MARK: Control

    var context: PhoneContext {
        PhoneContext(
            mode: .prompter,
            title: title,
            subtitle: String(format: "%@ · %d pt/s · %d%%", isPlaying ? "Rolling" : "Paused", Int(speed), Int(progress * 100)),
            badge: isPlaying ? "play.fill" : "pause.fill",
            legend: PhoneContext.legend([
                (.up, "Faster"), (.down, "Slower"),
                (.left, "Back"), (.right, "Forward"),
                (.tap, isPlaying ? "Pause" : "Play"),
            ]))
    }

    func apply(_ direction: SwipeDirection) -> String {
        switch direction {
        case .tap:
            if isPlaying { pause() } else { play() }
            return isPlaying ? "Rolling" : "Paused"
        case .up:
            setSpeed(speed + 10)
            return "Faster, \(Int(speed)) pt/s"
        case .down:
            setSpeed(speed - 10)
            return "Slower, \(Int(speed)) pt/s"
        case .left:
            jump(by: -viewportHeight * 0.5)
            return "Back"
        case .right:
            jump(by: viewportHeight * 0.5)
            return "Forward"
        }
    }

    func crown(_ delta: Double) {
        jump(by: CGFloat(delta) * 40)
    }

    func play() {
        guard !isPlaying else { return }
        if currentOffset >= maxOffset { baseOffset = 0 }
        startedAt = .now
        isPlaying = true
    }

    func pause() {
        guard isPlaying else { return }
        baseOffset = currentOffset
        startedAt = nil
        isPlaying = false
    }

    func restart() {
        isPlaying = false
        startedAt = nil
        baseOffset = 0
    }

    func setSpeed(_ value: Double) {
        let clamped = min(Self.maxSpeed, max(Self.minSpeed, value))
        // Rebase so the change in pace does not jump the text.
        let now = currentOffset
        speed = clamped
        baseOffset = now
        if isPlaying { startedAt = .now }
        settings.defaults.set(speed, forKey: Self.speedKey)
    }

    private func jump(by amount: CGFloat) {
        let target = min(maxOffset, max(0, currentOffset + amount))
        baseOffset = target
        if isPlaying { startedAt = .now }
    }
}
