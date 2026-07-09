import Foundation
import Combine

// MARK: - Data Models

struct TrafficData: Codable {
    let day_gb: Double
    let day_limit: Double
    let month_gb: Double
    let month_limit: Double

    enum CodingKeys: String, CodingKey {
        case day_gb, day_limit, month_gb, month_limit
    }

    // Гибкий декодер: принимает и число, и строку
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        func decodeFlexible(_ key: CodingKeys) -> Double {
            if let value = try? container.decode(Double.self, forKey: key) { return value }
            if let str = try? container.decode(String.self, forKey: key),
               let value = Double(str) { return value }
            return 0.0
        }

        day_gb    = decodeFlexible(.day_gb)
        day_limit = decodeFlexible(.day_limit)
        month_gb  = decodeFlexible(.month_gb)
        month_limit = decodeFlexible(.month_limit)
    }
}



// MARK: - TrafficManager

final class TrafficManager: ObservableObject {
    static let shared = TrafficManager()

    @Published var trafficData: TrafficData?
    @Published var lastUpdated: String = "Loading..."
    @Published var errorMessage: String?
    // Настройки, хранящиеся в UserDefaults
    @Published var serverURL: String {
        didSet { UserDefaults.standard.set(serverURL, forKey: "serverURL") }
    }

    private var timer: Timer?

    // MARK: Init

    private init() {
        let saved = UserDefaults.standard.string(forKey: "serverURL") ?? ""
        serverURL = saved.isEmpty ? "" : saved

        fetchData()
        setupTimer()
    }

    // MARK: Timer

    func setupTimer() {
        timer?.invalidate()
        let interval = UserDefaults.standard.double(forKey: "refreshInterval")
        let actualInterval = max(interval, 30)

        timer = Timer.scheduledTimer(withTimeInterval: actualInterval, repeats: true) { [weak self] _ in
            self?.fetchData()
        }
    }

    // MARK: Fetch

    func fetchData() {
        guard let url = URL(string: serverURL) else {
            DispatchQueue.main.async { self.errorMessage = "Invalid URL" }
            return
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self else { return }

            DispatchQueue.main.async {
                if let error = error {
                    self.errorMessage = "Connection Error"
                    print("TrafficMonitor fetch error: \(error.localizedDescription)")
                    return
                }

                if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    self.errorMessage = "Server Error (\(httpResponse.statusCode))"
                    print("TrafficMonitor HTTP error: \(httpResponse.statusCode)")
                    return
                }

                guard let data else {
                    self.errorMessage = "No Data"
                    return
                }

#if DEBUG
                if let str = String(data: data, encoding: .utf8) {
                    print("TrafficMonitor JSON: \(str)")
                }
#endif

                do {
                    let decoded = try JSONDecoder().decode(TrafficData.self, from: data)
                    self.trafficData = decoded
                    self.errorMessage = nil

                    let formatter = DateFormatter()
                    formatter.timeStyle = .medium
                    self.lastUpdated = "Updated: \(formatter.string(from: Date()))"
                } catch {
                    print("TrafficMonitor decode error: \(error)")
                    self.errorMessage = "Format Error"
                }
            }
        }.resume()
    }

}
