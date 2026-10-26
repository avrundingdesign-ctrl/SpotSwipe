import SwiftUI

/// Verlauf in Fotofarben, solange ein Bild lädt oder keins existiert.
struct PhotoPlaceholder: View {
    let seed: String

    var body: some View {
        let (top, bottom) = Theme.photoPalette(for: seed)
        LinearGradient(colors: [top, bottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Ein Foto eines Orts, gefüllt in den verfügbaren Rahmen.
struct PlacePhotoView: View {
    let photo: PlacePhoto?
    let seed: String
    var maxWidth = 1200

    @Environment(AppModel.self) private var app
    @State private var image: UIImage?

    var body: some View {
        Color.clear
            .overlay { PhotoPlaceholder(seed: seed) }
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                }
            }
            .clipped()
            .task(id: photo?.name) { await load() }
            .accessibilityHidden(true)
    }

    private func load() async {
        guard let photo else {
            image = nil
            return
        }
        if let cached = PhotoCache.shared.cachedImage(for: photo, maxWidth: maxWidth) {
            image = cached
            return
        }
        image = nil
        let loaded = await PhotoCache.shared.image(for: photo, maxWidth: maxWidth, using: app.places)
        withAnimation(.easeOut(duration: 0.25)) { image = loaded }
    }
}
