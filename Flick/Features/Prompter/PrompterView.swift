import SwiftUI
import UniformTypeIdentifiers

struct PrompterView: View {
    @Environment(SwipeHub.self) private var hub
    @State private var importing = false
    @State private var importError: String?

    private var model: PrompterModel { hub.prompter }

    var body: some View {
        GeometryReader { geo in
            let readingLine = geo.size.height * 0.3
            TimelineView(.animation(minimumInterval: 1 / 60, paused: !model.isPlaying)) { timeline in
                Text(model.text)
                    .font(.system(size: model.textSize, weight: .medium))
                    .lineSpacing(model.textSize * 0.35)
                    .foregroundStyle(.white)
                    .frame(width: geo.size.width - 48, alignment: .leading)
                    .padding(.horizontal, 24)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { h in
                        model.contentHeight = h
                    }
                    .offset(y: readingLine - model.offset(at: timeline.date))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .clipped()
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.6))
                    .frame(height: 2)
                    .offset(y: readingLine)
                    .accessibilityHidden(true)
            }
            .scaleEffect(x: model.isMirrored ? -1 : 1)
            .onAppear { model.viewportHeight = geo.size.height }
            .onChange(of: geo.size.height) { _, h in model.viewportHeight = h }
        }
        .background(Color.black)
        .overlay(alignment: .bottom) { status }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.plainText, UTType("net.daringfireball.markdown") ?? .plainText]) { result in
            do {
                try model.load(url: try result.get())
                hub.contentChanged()
            } catch {
                importError = error.localizedDescription
            }
        }
        .alert("Could not open", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK") {}
        } message: {
            Text(importError ?? "")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Import text", systemImage: "folder") { importing = true }
                    Button("Paste script", systemImage: "doc.on.clipboard") { paste() }
                    Button("Restart", systemImage: "backward.end") { model.restart(); hub.contentChanged() }
                    Toggle("Mirror for glass", systemImage: "flip.horizontal", isOn: Binding(
                        get: { hub.settings.prompterMirror },
                        set: { hub.settings.prompterMirror = $0 }
                    ))
                    Button("Load sample script", systemImage: "sparkles") {
                        model.loadSample()
                        hub.contentChanged()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Prompter options")
            }
        }
    }

    private var status: some View {
        HStack(spacing: 12) {
            Image(systemName: model.isPlaying ? "play.fill" : "pause.fill")
            Text("\(Int(model.speed)) pt/s")
                .monospacedDigit()
            Spacer()
            Text(model.title)
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.55), in: Capsule())
        .padding(12)
    }

    private func paste() {
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            importError = "The clipboard has no text."
            return
        }
        do {
            try model.paste(text)
            hub.contentChanged()
        } catch {
            importError = error.localizedDescription
        }
    }
}
