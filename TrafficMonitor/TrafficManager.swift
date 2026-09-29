import Foundation
import Combine
import WidgetKit

// MARK: - Data Models

struct PingData: Codable {
    let avg_latency_ms: Double
    let worst_latency_ms: Double
    let avg_packet_loss: Double
    let max_packet_loss: Double
    let latest_latency_ms: Double
    let latest_packet_loss: Double
    let target: String
    let total_checks: Int

    enum CodingKeys: String, CodingKey {
        case avg_latency_ms, worst_latency_ms, avg_packet_loss, max_packet_loss
        case latest_latency_ms, latest_packet_loss, target, total_checks
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        func flex(_ key: CodingKeys) -> Double {
            if let v = try? c.decode(Double.self, forKey: key) { return v }
            if let s = try? c.decode(String.self, forKey: key), let v = Double(s) { return v }
            return 0.0
        }

        avg_latency_ms    = flex(.avg_latency_ms)
        worst_latency_ms  = flex(.worst_latency_ms)
        avg_packet_loss   = flex(.avg_packet_loss)
        max_packet_loss   = flex(.max_packet_loss)
        latest_latency_ms = flex(.latest_latency_ms)
        latest_packet_loss = flex(.latest_packet_loss)
        target            = (try? c.decode(String.self, forKey: .target)) ?? ""
        total_checks      = (try? c.decode(Int.self,    forKey: .total_checks)) ?? 0
    }
}

struct TrafficData: Codable {
    let day_gb: Double
    let day_limit: Double
    let month_gb: Double
    let month_limit: Double
    let ping: PingData?

    enum CodingKeys: String, CodingKey {
        case day_gb, day_limit, month_gb, month_limit, ping
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

        day_gb      = decodeFlexible(.day_gb)
        day_limit   = decodeFlexible(.day_limit)
        month_gb    = decodeFlexible(.month_gb)
        month_limit = decodeFlexible(.month_limit)
        ping        = try? container.decode(PingData.self, forKey: .ping)
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
        didSet { 
            UserDefaults.standard.set(serverURL, forKey: "serverURL") 
            if let sharedDefaults = UserDefaults(suiteName: "group.com.koka.TrafficMonitor") {
                sharedDefaults.set(serverURL, forKey: "serverURL")
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }

    private var timer: Timer?

    // MARK: Init

    private init() {
        let saved = UserDefaults.standard.string(forKey: "serverURL") ?? ""
        serverURL = saved.isEmpty ? "" : saved

        if let sharedDefaults = UserDefaults(suiteName: "group.com.koka.TrafficMonitor") {
            sharedDefaults.set(serverURL, forKey: "serverURL")
        }

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
                    WidgetCenter.shared.reloadAllTimelines()
                } catch {
                    print("TrafficMonitor decode error: \(error)")
                    self.errorMessage = "Format Error"
                }
            }
        }.resume()
    }

}
