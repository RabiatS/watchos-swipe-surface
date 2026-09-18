import SwiftUI
import UniformTypeIdentifiers

struct ReaderView: View {
    @Environment(SwipeHub.self) private var hub
    @State private var position = ScrollPosition(edge: .top)
    @State private var importing = false
    @State private var importError: String?

    private var model: ReaderModel { hub.reader }

    private struct Metrics: Equatable {
        var offset: CGFloat
        var viewport: CGFloat
        var content: CGFloat
    }

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(model.blocks) { block in
                        blockView(block, width: geo.size.width - 40)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollPosition($position)
            .onScrollGeometryChange(for: Metrics.self) { g in
                Metrics(offset: g.contentOffset.y + g.contentInsets.top,
                        viewport: g.containerSize.height,
                        content: g.contentSize.height)
            } action: { _, m in
                model.offset = m.offset
                model.viewportHeight = m.viewport
                model.contentHeight = m.content
            }
            .onScrollTargetVisibilityChange(idType: String.self, threshold: 0.2) { ids in
                if let first = ids.first { model.visibleBlockID = first }
            }
            .onChange(of: model.scrollVersion) { _, _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    switch model.scrollTarget {
                    case .block(let id): position.scrollTo(id: id, anchor: .top)
                    case .y(let y): position.scrollTo(y: y)
                    case nil: break
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .overlay(alignment: .bottom) {
            if model.showsControls { controls }
        }
        .animation(.snappy, value: model.showsControls)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf, .plainText, UTType("net.daringfireball.markdown") ?? .plainText]) { result in
            handleImport(result)
        }
        .alert("Could not open", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK") {}
        } message: {
            Text(importError ?? "")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Import file", systemImage: "folder") { importing = true }
                    Button("Paste text", systemImage: "doc.on.clipboard") { pasteText() }
                    Button("Load sample recipe", systemImage: "fork.knife") {
                        model.loadSample()
                        hub.contentChanged()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Reader options")
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: ReaderBlock, width: CGFloat) -> some View {
        switch block {
        case .heading(_, let text, _):
            Text(text)
                .font(.system(size: model.textSize * 1.3, weight: .bold, design: .rounded))
                .padding(.top, 10)
                .id(block.id)
        case .paragraph(_, let text, _):
            Text(text)
                .font(.system(size: model.textSize))
                .lineSpacing(model.textSize * 0.25)
                .id(block.id)
        case .page(_, let index, _):
            Group {
                if let image = model.pages?.image(at: index, width: width) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    Rectangle()
                        .fill(Color(.secondarySystemBackground))
                        .aspectRatio(1 / (model.pages?.aspectRatio(at: index) ?? 1.4), contentMode: .fit)
                }
            }
            .frame(width: width)
            .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
            .id(block.id)
        }
    }

    private var controls: some View {
        @Bindable var settings = hub.settings
        return HStack(spacing: 14) {
            Image(systemName: "textformat.size.smaller")
            Slider(value: $settings.readerTextSize, in: 14...40, step: 1)
                .accessibilityLabel("Text size")
            Image(systemName: "textformat.size.larger")
            Text("\(Int(model.progress * 100))%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private func handleImport(_ result: Result<URL, any Error>) {
        do {
            let url = try result.get()
            try model.load(url: url)
            hub.contentChanged()
        } catch {
            importError = error.localizedDescription
        }
    }

    private func pasteText() {
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
