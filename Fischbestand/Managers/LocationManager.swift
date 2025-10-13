import Foundation
import CoreLocation

@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var latitude: Double?
    @Published private(set) var longitude: Double?
    @Published private(set) var locationName: String?
    @Published private(set) var isUpdating = false
    @Published var errorMessage: String?

    private let manager: CLLocationManager
    private let geocoder = CLGeocoder()

    override init() {
        let locationManager = CLLocationManager()
        manager = locationManager
        authorizationStatus = locationManager.authorizationStatus
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    func requestLocation() {
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startRequest()
        case .restricted, .denied:
            errorMessage = "Standortzugriff deaktiviert. Bitte aktiviere ihn in den Einstellungen."
        @unknown default:
            errorMessage = "Unbekannter Berechtigungsstatus für den Standortzugriff."
        }
    }

    private func startRequest() {
        guard !isUpdating else { return }
        isUpdating = true
        manager.requestLocation()
    }

    private func resolvePlacemark(for location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    self.errorMessage = "Standort konnte nicht ermittelt werden: \(error.localizedDescription)"
                    self.isUpdating = false
                    return
                }
                if let placemark = placemarks?.first {
                    self.locationName = Self.makeDescription(from: placemark)
                }
                self.isUpdating = false
            }
        }
    }

    private static func makeDescription(from placemark: CLPlacemark) -> String? {
        var components: [String] = []
        if let water = placemark.inlandWater ?? placemark.ocean {
            components.append(water)
        }
        if let locality = placemark.locality ?? placemark.subLocality ?? placemark.administrativeArea {
            components.append(locality)
        }
        if components.isEmpty, let name = placemark.name {
            components.append(name)
        }
        return components.isEmpty ? nil : components.joined(separator: ", ")
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
            switch authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                startRequest()
            case .restricted, .denied:
                errorMessage = "Standortzugriff deaktiviert. Bitte aktiviere ihn in den Einstellungen."
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            Task { @MainActor in
                isUpdating = false
            }
            return
        }
        Task { @MainActor in
            latitude = location.coordinate.latitude
            longitude = location.coordinate.longitude
            resolvePlacemark(for: location)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            errorMessage = "Standortfehler: \(error.localizedDescription)"
            isUpdating = false
        }
    }
}
