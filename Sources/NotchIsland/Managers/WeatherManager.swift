import Foundation

class WeatherManager: ObservableObject {
    @Published var weather = WeatherInfo()

    private var refreshTimer: Timer?

    init() {
        refresh()
        let t = Timer(timeInterval: 1800, repeats: true) { [weak self] _ in self?.refresh() }
        RunLoop.main.add(t, forMode: .common)
        refreshTimer = t
    }

    deinit { refreshTimer?.invalidate() }

    func refresh() {
        DispatchQueue.main.async { self.weather.isError = false }
        let manualCity = SettingsManager.shared.weatherCity.trimmingCharacters(in: .whitespaces)
        if manualCity.isEmpty {
            fetchLocation { [weak self] lat, lon, city in self?.fetchWeather(lat: lat, lon: lon, city: city) }
        } else {
            geocode(city: manualCity) { [weak self] lat, lon in
                if let lat, let lon {
                    self?.fetchWeather(lat: lat, lon: lon, city: manualCity)
                } else {
                    DispatchQueue.main.async { self?.weather.isError = true }
                }
            }
        }
    }

    // MARK: – Private

    private func geocode(city: String, completion: @escaping (Double?, Double?) -> Void) {
        let encoded = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city
        guard let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=1&language=en&format=json") else {
            completion(nil, nil); return
        }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data,
                  let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first   = results.first,
                  let lat     = first["latitude"]  as? Double,
                  let lon     = first["longitude"] as? Double
            else { completion(nil, nil); return }
            completion(lat, lon)
        }.resume()
    }

    private func fetchLocation(completion: @escaping (Double, Double, String) -> Void) {
        guard let url = URL(string: "http://ip-api.com/json") else {
            DispatchQueue.main.async { self.weather.isError = true }
            return
        }
        let task = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }
            guard error == nil,
                  let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let lat  = json["lat"] as? Double,
                  let lon  = json["lon"] as? Double
            else {
                DispatchQueue.main.async { self.weather.isError = true }
                return
            }
            completion(lat, lon, json["city"] as? String ?? "")
        }
        task.resume()

        // Mark error if no response within 8 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self, !self.weather.isLoaded else { return }
            self.weather.isError = true
        }
    }

    private func fetchWeather(lat: Double, lon: Double, city: String) {
        var comps = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        comps.queryItems = [
            .init(name: "latitude",         value: String(lat)),
            .init(name: "longitude",        value: String(lon)),
            .init(name: "current",          value: "temperature_2m,apparent_temperature,weathercode"),
            .init(name: "temperature_unit", value: "celsius"),
            .init(name: "forecast_days",    value: "1"),
        ]
        guard let url = comps.url else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self else { return }
            guard error == nil,
                  let data,
                  let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let current = json["current"] as? [String: Any],
                  let temp    = current["temperature_2m"] as? Double,
                  let code    = current["weathercode"] as? Int
            else {
                DispatchQueue.main.async { self.weather.isError = true }
                return
            }
            let feels = current["apparent_temperature"] as? Double ?? temp
            DispatchQueue.main.async {
                self.weather = WeatherInfo(
                    temperature: temp,
                    feelsLike:   feels,
                    weatherCode: code,
                    city:        city,
                    isLoaded:    true,
                    isError:     false
                )
            }
        }.resume()
    }
}
