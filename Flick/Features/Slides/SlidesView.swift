import PhotosUI
import SwiftUI

struct SlidesView: View {
    @Environment(SwipeHub.self) private var hub
    @State private var importing = false
    @State private var selection: [PhotosPickerItem] = []
    @State private var importError: String?

    private var model: SlidesModel { hub.slides }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                if let image = model.image(width: geo.size.width) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .id(model.index)
                        .transition(.opacity)
                        .accessibilityLabel("Slide \(model.index + 1) of \(model.count)")
                } else {
                    ContentUnavailableView {
                        Label("No deck", systemImage: "rectangle.on.rectangle")
                    } description: {
                        Text("Import a PDF, or choose images. Keynote, PowerPoint and Google Slides all export PDF.")
                    }
                    .foregroundStyle(.white)
                }
                if model.isBlanked {
                    Color.black
                        .overlay {
                            Text("Blanked")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.35))
                        }
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: model.index)
            .animation(.easeInOut(duration: 0.2), value: model.isBlanked)
        }
        .overlay(alignment: .bottom) {
            if model.showsPresenterBar && model.count > 0 { presenterBar }
        }
        .animation(.snappy, value: model.showsPresenterBar)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf]) { result in
            do {
                try model.load(pdf: try result.get())
                hub.contentChanged()
            } catch {
                importError = error.localizedDescription
            }
        }
        .onChange(of: selection) { _, items in
            guard !items.isEmpty else { return }
            Task {
                var images: [UIImage] = []
                for item in items {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                model.load(images: images)
                hub.contentChanged()
                selection = []
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
                    Button("Import PDF", systemImage: "folder") { importing = true }
                    PhotosPicker(selection: $selection, maxSelectionCount: 100, matching: .images) {
                        Label("Choose images", systemImage: "photo.stack")
                    }
                    Button("Reset timer", systemImage: "timer") { model.resetTimer(); hub.contentChanged() }
                    Button("Load sample deck", systemImage: "sparkles") {
                        model.loadSample()
                        hub.contentChanged()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Slides options")
            }
        }
    }

    private var presenterBar: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            HStack(spacing: 14) {
                Text("\(model.index + 1) / \(model.count)")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                Divider().frame(height: 16)
                Image(systemName: model.isTimerRunning ? "timer" : "pause.circle")
                Text(Self.clock(model.elapsed(at: timeline.date)))
                    .font(.subheadline.monospacedDigit())
                Spacer()
                Text(model.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(12)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let s = Int(seconds)
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
