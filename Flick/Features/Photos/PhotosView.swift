import AVKit
import PhotosUI
import SwiftUI

/// A movie picked from the library, copied to a temporary file.
struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = URL.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + received.file.pathExtension)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedMovie(url: copy)
        }
    }
}

struct PhotosView: View {
    @Environment(SwipeHub.self) private var hub
    @State private var selection: [PhotosPickerItem] = []
    @State private var isLoading = false

    private var model: PhotosModel { hub.photos }

    var body: some View {
        ZStack {
            Color.black
            if let item = model.current {
                media(item)
                    .id(item.id)
                    .transition(.opacity)
            } else {
                ContentUnavailableView {
                    Label("No photos", systemImage: "photo.on.rectangle.angled")
                } description: {
                    Text("Choose some from the library, or load the sample set.")
                }
                .foregroundStyle(.white)
            }
            if isLoading {
                ProgressView("Loading")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: model.current?.id)
        .overlay(alignment: .topTrailing) {
            if model.current?.isStarred == true {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                    .shadow(radius: 4)
                    .padding(16)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if model.count > 0 {
                Text("\(model.index + 1) of \(model.count)\(model.isSample ? "  ·  sample set" : "")")
                    .font(.caption.monospacedDigit())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.5), in: Capsule())
                    .foregroundStyle(.white)
                    .padding(.bottom, 10)
            }
        }
        .onChange(of: selection) { _, items in
            guard !items.isEmpty else { return }
            Task { await load(items) }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    PhotosPicker(selection: $selection, maxSelectionCount: 60,
                                 matching: .any(of: [.images, .videos])) {
                        Label("Choose from library", systemImage: "photo.stack")
                    }
                    Button("Load sample set", systemImage: "sparkles") {
                        model.loadSample()
                        hub.contentChanged()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Photos options")
            }
        }
    }

    @ViewBuilder
    private func media(_ item: MediaItem) -> some View {
        switch item.kind {
        case .image(let image):
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: model.fillsScreen ? .fill : .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .accessibilityLabel("Photo \(model.index + 1) of \(model.count)")
        case .video:
            VideoPlayer(player: model.player)
                .accessibilityLabel("Video \(model.index + 1) of \(model.count)")
        }
    }

    private func load(_ items: [PhotosPickerItem]) async {
        isLoading = true
        defer { isLoading = false; selection = [] }
        var images: [UIImage] = []
        var videos: [URL] = []
        for item in items {
            if item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                if let movie = try? await item.loadTransferable(type: PickedMovie.self) {
                    videos.append(movie.url)
                }
            } else if let data = try? await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) {
                images.append(image)
            }
        }
        model.replace(images: images, videos: videos)
        hub.contentChanged()
    }
}
