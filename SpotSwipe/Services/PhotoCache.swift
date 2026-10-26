import UIKit

/// Lädt Fotos einmal und hält sie im Speicher. Gleichzeitige Anfragen für dasselbe Foto teilen sich einen Download.
final class PhotoCache {
    static let shared = PhotoCache()

    private let cache = NSCache<NSString, UIImage>()
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    init() {
        cache.countLimit = 80
    }

    func cachedImage(for photo: PlacePhoto, maxWidth: Int) -> UIImage? {
        cache.object(forKey: Self.key(photo, maxWidth) as NSString)
    }

    func image(for photo: PlacePhoto, maxWidth: Int, using service: any PlacesService) async -> UIImage? {
        let key = Self.key(photo, maxWidth)
        if let image = cache.object(forKey: key as NSString) { return image }
        if let running = inFlight[key] { return await running.value }

        let task = Task<UIImage?, Never> {
            guard let data = try? await service.photoData(for: photo, maxWidth: maxWidth),
                  let image = UIImage(data: data) else { return nil }
            return await image.byPreparingForDisplay() ?? image
        }
        inFlight[key] = task
        let image = await task.value
        inFlight[key] = nil
        if let image { cache.setObject(image, forKey: key as NSString) }
        return image
    }

    private static func key(_ photo: PlacePhoto, _ maxWidth: Int) -> String {
        "\(photo.name)@\(maxWidth)"
    }
}
