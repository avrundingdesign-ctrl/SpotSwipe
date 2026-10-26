import MapKit
import SwiftUI

/// Vollbild-Karte mit fester Nadel in der Mitte. Die Kartenmitte wird zum Suchort.
struct MapPinPicker: View {
    let radius: Double
    var onConfirm: (SearchLocation) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var position: MapCameraPosition
    @State private var center: GeoPoint
    @State private var address: Geocoder.Address?
    @State private var isMoving = false
    @State private var lookup: Task<Void, Never>?

    init(start: GeoPoint, radius: Double, onConfirm: @escaping (SearchLocation) -> Void) {
        self.radius = radius
        self.onConfirm = onConfirm
        _center = State(initialValue: start)
        _position = State(initialValue: .region(MKCoordinateRegion(
            center: start.coordinate,
            latitudinalMeters: radius * 3.2,
            longitudinalMeters: radius * 3.2
        )))
    }

    var body: some View {
        Map(position: $position) {
            MapCircle(center: center.coordinate, radius: radius)
                .foregroundStyle(Theme.accent.opacity(0.09))
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, dash: [7, 7]))
            UserAnnotation()
        }
        .mapControls {}
        .onMapCameraChange(frequency: .continuous) { context in
            center = GeoPoint(context.region.center)
            isMoving = true
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            isMoving = false
            lookUpAddress(for: GeoPoint(context.region.center))
        }
        .overlay { pin.allowsHitTesting(false) }
        .ignoresSafeArea()
        .overlay(alignment: .top) { topBar }
        .overlay(alignment: .bottom) { bottomCard }
        .task { lookUpAddress(for: center) }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            GlassIconButton(systemImage: "chevron.left", label: "Zurück") { dismiss() }
            Text("Karte unter der Nadel bewegen")
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(1)
                .foregroundStyle(Theme.textPrimary)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .glassEffect(.regular, in: Capsule())
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var pin: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(Theme.accent).frame(width: 44, height: 44)
                Circle().fill(.white).frame(width: 16, height: 16)
            }
            .shadow(color: .black.opacity(0.25), radius: 9, y: 8)
            Rectangle().fill(Theme.accent).frame(width: 4, height: 14)
            Ellipse().fill(.black.opacity(0.22)).frame(width: 18, height: 7)
        }
        .offset(y: isMoving ? -36 : -30)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isMoving)
        .accessibilityHidden(true)
    }

    private var bottomCard: some View {
        VStack(alignment: .trailing, spacing: 14) {
            GlassIconButton(systemImage: "location.fill", label: "Zu meinem Standort", size: 48) {
                withAnimation { position = .userLocation(fallback: position) }
            }
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hier wird gesucht")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Text(address?.title ?? "Ort wird ermittelt …")
                        .font(.system(size: 22, weight: .heavy))
                        .lineLimit(1)
                        .redacted(reason: address == nil ? .placeholder : [])
                    Text([address?.city, "Umkreis \(Formatters.radius(radius))"].compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textSecondary)
                }
                Button("Hier suchen") {
                    onConfirm(SearchLocation(name: address?.title ?? "Gewählter Ort", subtitle: address?.city, point: center))
                }
                .buttonStyle(PrimaryButtonStyle(height: 56))
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(20)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 25, y: 20)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func lookUpAddress(for point: GeoPoint) {
        lookup?.cancel()
        lookup = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            let result = await Geocoder.address(for: point)
            guard !Task.isCancelled else { return }
            address = result
        }
    }
}
