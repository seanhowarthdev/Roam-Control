import Foundation

/// This build treats map coordinates inside the GCJ-02 bounds as GCJ-02.
/// Convert only at the device boundary; stored targets and map markers stay unchanged.
enum WGS84CoordinateConverter {
    static func fromMap(latitude: Double, longitude: Double) -> (latitude: Double, longitude: Double) {
        guard latitude.isFinite, longitude.isFinite,
              (0.8293...55.8271).contains(latitude),
              (72.004...137.8347).contains(longitude) else {
            return (latitude, longitude)
        }

        var result = (latitude: latitude, longitude: longitude)
        // Solve the inverse iteratively instead of subtracting the offset just once.
        for _ in 0..<10 {
            let delta = offset(latitude: result.latitude, longitude: result.longitude)
            let latitudeError = result.latitude + delta.latitude - latitude
            let longitudeError = result.longitude + delta.longitude - longitude
            result.latitude -= latitudeError
            result.longitude -= longitudeError
            if max(abs(latitudeError), abs(longitudeError)) < 1e-9 { break }
        }
        return result
    }

    private static func offset(latitude: Double, longitude: Double) -> (latitude: Double, longitude: Double) {
        let x = longitude - 105
        let y = latitude - 35
        let common = (20 * sin(6 * x * .pi) + 20 * sin(2 * x * .pi)) * 2 / 3
        var latitudeDelta = -100 + 2 * x + 3 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        latitudeDelta += common
        latitudeDelta += (20 * sin(y * .pi) + 40 * sin(y * .pi / 3)) * 2 / 3
        latitudeDelta += (160 * sin(y * .pi / 12) + 320 * sin(y * .pi / 30)) * 2 / 3
        var longitudeDelta = 300 + x + 2 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        longitudeDelta += common
        longitudeDelta += (20 * sin(x * .pi) + 40 * sin(x * .pi / 3)) * 2 / 3
        longitudeDelta += (150 * sin(x * .pi / 12) + 300 * sin(x * .pi / 30)) * 2 / 3

        let radians = latitude * .pi / 180
        let eccentricitySquared = 0.006693421622965943
        let magic = 1 - eccentricitySquared * pow(sin(radians), 2)
        let radius = 6_378_245.0 / sqrt(magic)
        latitudeDelta *= 180 / (radius * (1 - eccentricitySquared) / magic * .pi)
        longitudeDelta *= 180 / (radius * cos(radians) * .pi)
        return (latitudeDelta, longitudeDelta)
    }
}
