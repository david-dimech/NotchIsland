import Foundation

class WeatherManager: ObservableObject {
    @Published var weather = WeatherInfo()

    private var refreshTimer: Timer?

    init() {
        refresh()
        // Refresh every 30 minutes
        let t = Timer(timeInterval: 1800, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(t, forMode: .common)
        refreshTimer = t
    }

    deinit { refreshTimer?.invalidate() }

    func refresh() {
        fetchLocation { [weak self] lat, lon, city in
            self?.fetchWeather(lat: lat, lon: lon, city: city)
        }
    }

    // MARK: – Private

    private func fetchLocation(completion: @escaping (Double, Double, String) -> Void) {
        guard let url = URL(string: "http://ip-api.com/json") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let lat  = json["lat"] as? Double,
                  let lon  = json["lon"] as? Double
            else { return }
            let city = json["city"] as? String ?? ""
            completion(lat, lon, city)
        }.resume()
    }

    private func fetchWeather(lat: Double, lon: Double, city: String) {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude",          value: String(lat)),
            .init(name: "longitude",         value: String(lon)),
            .init(name: "current",           value: "temperature_2m,apparent_temperature,weathercode"),
            .init(name: "temperature_unit",  value: "celsius"),
            .init(name: "forecast_days",     value: "1"),
        ]
        guard let url = comps.url else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self,
                  let data,
                  let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current"] as? [String: Any],
                  let temp    = current["temperature_2m"] as? Double,
                  let code    = current["weathercode"] as? Int
            else { return }
            let feels = current["apparent_temperature"] as? Double ?? temp
            DispatchQueue.main.async {
                self.weather = WeatherInfo(
                    temperature: temp,
                    feelsLike:   feels,
                    weatherCode: code,
                    city:        city,
                    isLoaded:    true
                )
            }
        }.resume()
    }
}
