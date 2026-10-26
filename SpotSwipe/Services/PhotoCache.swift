import UIKit

/// Lädt Fotos einmal und hält sie im Speicher. Gleichzeitige Anfragen für dasselbe Foto teilen sich einen Download.
final class PhotoCache {
    static let shared = PhotoCache()

    private let cache = NSCache<NSString, UIImage>()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    init() {
        cache.countLimit = 80
    }

    func cachedImage(for photo: PlacePhoto) -> UIImage? {
        cache.object(forKey: photo.url.absoluteString as NSString)
    }

    func image(for photo: PlacePhoto, using service: any PlacesService) async -> UIImage? {
        if let image = cachedImage(for: photo) { return image }
        if let running = inFlight[photo.url] { return await running.value }

        let task = Task<UIImage?, Never> {
            guard let data = try? await service.photoData(for: photo),
                  let image = UIImage(data: data) else { return nil }
            return await image.byPreparingForDisplay() ?? image
        }
        inFlight[photo.url] = task
        let image = await task.value
        inFlight[photo.url] = nil
        if let image { cache.setObject(image, forKey: photo.url.absoluteString as NSString) }
        return image
    }
}
