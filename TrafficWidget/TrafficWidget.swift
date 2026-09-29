import WidgetKit
import SwiftUI

// MARK: - Widget Data Models

struct WidgetPingData: Codable {
    let avg_latency_ms: Double
    let latest_latency_ms: Double
    let latest_packet_loss: Double
    let target: String?
    
    enum CodingKeys: String, CodingKey {
        case avg_latency_ms, latest_latency_ms, latest_packet_loss, target
    }
    
    init(avg_latency_ms: Double, latest_latency_ms: Double, latest_packet_loss: Double, target: String?) {
        self.avg_latency_ms = avg_latency_ms
        self.latest_latency_ms = latest_latency_ms
        self.latest_packet_loss = latest_packet_loss
        self.target = target
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func flex(_ key: CodingKeys) -> Double {
            if let value = try? container.decode(Double.self, forKey: key) { return value }
            if let str = try? container.decode(String.self, forKey: key), let value = Double(str) { return value }
            return 0.0
        }
        avg_latency_ms = flex(.avg_latency_ms)
        latest_latency_ms = flex(.latest_latency_ms)
        latest_packet_loss = flex(.latest_packet_loss)
        target = try? container.decode(String.self, forKey: .target)
    }
}

struct WidgetTrafficData: Codable {
    let day_gb: Double
    let day_limit: Double
    let month_gb: Double
    let month_limit: Double
    let ping: WidgetPingData?
    
    enum CodingKeys: String, CodingKey {
        case day_gb, day_limit, month_gb, month_limit, ping
    }
    
    init(day_gb: Double, day_limit: Double, month_gb: Double, month_limit: Double, ping: WidgetPingData?) {
        self.day_gb = day_gb
        self.day_limit = day_limit
        self.month_gb = month_gb
        self.month_limit = month_limit
        self.ping = ping
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func decodeFlexible(_ key: CodingKeys) -> Double {
            if let value = try? container.decode(Double.self, forKey: key) { return value }
            if let str = try? container.decode(String.self, forKey: key),
               let value = Double(str) { return value }
            return 0.0
        }
        day_gb = decodeFlexible(.day_gb)
        day_limit = decodeFlexible(.day_limit)
        month_gb = decodeFlexible(.month_gb)
        month_limit = decodeFlexible(.month_limit)
        ping = try? container.decode(WidgetPingData.self, forKey: .ping)
    }
    
    static var placeholder: WidgetTrafficData {
        WidgetTrafficData(
            day_gb: 4.2,
            day_limit: 15.0,
            month_gb: 128.5,
            month_limit: 500.0,
            ping: WidgetPingData(
                avg_latency_ms: 24.0,
                latest_latency_ms: 24.0,
                latest_packet_loss: 0.0,
                target: "raspberrypi.local"
            )
        )
    }
}

// MARK: - Timeline Provider

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), data: .placeholder, error: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), data: .placeholder, error: nil)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let sharedDefaults = UserDefaults(suiteName: "group.com.koka.TrafficMonitor")
        let serverURLString = sharedDefaults?.string(forKey: "serverURL") ?? ""
        
        guard let url = URL(string: serverURLString) else {
            let entry = SimpleEntry(date: Date(), data: nil, error: "URL not set")
            let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
            completion(timeline)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            var entryData: WidgetTrafficData? = nil
            var entryError: String? = nil
            
            if error != nil {
                entryError = "Conn Error"
            } else if let data = data {
                do {
                    entryData = try JSONDecoder().decode(WidgetTrafficData.self, from: data)
                } catch {
                    entryError = "Decode Error"
                }
            } else {
                entryError = "No Data"
            }
            
            let entry = SimpleEntry(date: Date(), data: entryData, error: entryError)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }.resume()
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let data: WidgetTrafficData?
    let error: String?
}

// MARK: - UI Components

struct TrafficCardView: View {
    let title: String
    let iconName: String
    let used: Double
    let limit: Double
    let iconColor: Color
    
    var fraction: Double {
        min(used / max(limit, 1.0), 1.0)
    }
    
    var percentInt: Int {
        Int(min((used / max(limit, 1.0)) * 100, 999))
    }
    
    var remaining: Double {
        max(limit - used, 0.0)
    }
    
    var statusGradient: [Color] {
        if fraction < 0.7 {
            return [.blue, .cyan]
        } else if fraction < 0.9 {
            return [.orange, .yellow]
        } else {
            return [.red, .orange]
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header Row: Icon + Title + Percent Badge
            HStack(spacing: 4) {
                Image(systemName: iconName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Spacer(minLength: 2)
                
                Text("\(percentInt)%")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(statusGradient.first)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(statusGradient.first!.opacity(0.12))
                    )
            }
            
            // Value Row: Used GB & Total Limit
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.1f", used))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("GB")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer(minLength: 2)
                Text("of \(Int(limit)) GB")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: statusGradient,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * fraction))
                }
            }
            .frame(height: 7)
            
            // Remaining GB
            HStack {
                Text(String(format: "%.1f GB left", remaining))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
                )
        )
    }
}

struct SmallStatBlock: View {
    let title: String
    let icon: String
    let used: Double
    let limit: Double
    let color: Color
    
    var fraction: Double {
        min(used / max(limit, 1.0), 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer(minLength: 2)
                Text("\(String(format: "%.1f", used)) / \(Int(limit)) GB")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.8), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * fraction))
                }
            }
            .frame(height: 7)
        }
    }
}

// MARK: - Main Entry View

struct TrafficWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let error = entry.error {
                VStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                    Text(error)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let data = entry.data {
                if family == .systemMedium {
                    VStack(spacing: 8) {
                        // Header Row
                        HStack(alignment: .center) {
                            HStack(spacing: 6) {
                                Image(systemName: "network")
                                   .font(.system(size: 12, weight: .bold))
                                   .foregroundColor(.blue)
                                Text("Traffic Monitor")
                                   .font(.system(.caption, design: .rounded, weight: .bold))
                                   .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            if let ping = data.ping {
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(ping.latest_packet_loss > 0.05 ? Color.red : Color.green)
                                        .frame(width: 5, height: 5)
                                    Text(String(format: "%.0f ms", ping.latest_latency_ms > 0 ? ping.latest_latency_ms : ping.avg_latency_ms))
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(Color.primary.opacity(0.05))
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                        
                        // Cards Dashboard
                        HStack(spacing: 8) {
                            TrafficCardView(
                                title: "Today",
                                iconName: "sun.max.fill",
                                used: data.day_gb,
                                limit: data.day_limit,
                                iconColor: .orange
                            )
                            
                            TrafficCardView(
                                title: "Month",
                                iconName: "calendar",
                                used: data.month_gb,
                                limit: data.month_limit,
                                iconColor: .blue
                            )
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        // Header
                        HStack {
                            Image(systemName: "network")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.blue)
                            Text("Traffic")
                                .font(.system(.caption, design: .rounded, weight: .bold))
                            Spacer()
                        }
                        
                        SmallStatBlock(
                            title: "Today",
                            icon: "sun.max.fill",
                            used: data.day_gb,
                            limit: data.day_limit,
                            color: .orange
                        )
                        
                        SmallStatBlock(
                            title: "Month",
                            icon: "calendar",
                            used: data.month_gb,
                            limit: data.month_limit,
                            color: .blue
                        )
                        
                        Spacer(minLength: 0)
                        
                        if let ping = data.ping {
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(ping.latest_packet_loss > 0.05 ? Color.red : Color.green)
                                    .frame(width: 5, height: 5)
                                Text(String(format: "%.0f ms", ping.latest_latency_ms > 0 ? ping.latest_latency_ms : ping.avg_latency_ms))
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.primary.opacity(0.05))
                            )
                        }
                    }
                }
            } else {
                VStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Widget Bundle Configuration

struct TrafficWidget: Widget {
    let kind: String = "TrafficWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(macOS 14.0, *) {
                TrafficWidgetEntryView(entry: entry)
                    .containerBackground(.fill.tertiary, for: .widget)
            } else {
                TrafficWidgetEntryView(entry: entry)
                    .padding()
                    .background()
            }
        }
        .configurationDisplayName("Traffic Monitor")
        .description("Keep track of your daily and monthly traffic.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
