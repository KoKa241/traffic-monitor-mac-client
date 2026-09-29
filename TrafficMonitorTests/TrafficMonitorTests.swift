import XCTest
@testable import TrafficMonitor

final class TrafficMonitorTests: XCTestCase {

    // MARK: - Testing Data Models & JSON Decoding

    func testTrafficDataDecodingWithDoubles() throws {
        let json = """
        {
            "day_gb": 1.5,
            "day_limit": 5.0,
            "month_gb": 45.2,
            "month_limit": 100.0,
            "ping": {
                "avg_latency_ms": 25.4,
                "worst_latency_ms": 120.0,
                "avg_packet_loss": 0.5,
                "max_packet_loss": 2.0,
                "latest_latency_ms": 20.1,
                "latest_packet_loss": 0.0,
                "target": "8.8.8.8",
                "total_checks": 100
            }
        }
        """.data(using: .utf8)!

        let data = try JSONDecoder().decode(TrafficData.self, from: json)
        
        XCTAssertEqual(data.day_gb, 1.5)
        XCTAssertEqual(data.day_limit, 5.0)
        XCTAssertEqual(data.month_gb, 45.2)
        XCTAssertEqual(data.month_limit, 100.0)
        
        let ping = try XCTUnwrap(data.ping)
        XCTAssertEqual(ping.avg_latency_ms, 25.4)
        XCTAssertEqual(ping.worst_latency_ms, 120.0)
        XCTAssertEqual(ping.avg_packet_loss, 0.5)
        XCTAssertEqual(ping.max_packet_loss, 2.0)
        XCTAssertEqual(ping.latest_latency_ms, 20.1)
        XCTAssertEqual(ping.latest_packet_loss, 0.0)
        XCTAssertEqual(ping.target, "8.8.8.8")
        XCTAssertEqual(ping.total_checks, 100)
    }

    func testTrafficDataDecodingWithStrings() throws {
        // Our flexible decoder should handle numbers provided as strings
        let json = """
        {
            "day_gb": "2.5",
            "day_limit": "10",
            "month_gb": "50.5",
            "month_limit": "150.0"
        }
        """.data(using: .utf8)!

        let data = try JSONDecoder().decode(TrafficData.self, from: json)
        
        XCTAssertEqual(data.day_gb, 2.5)
        XCTAssertEqual(data.day_limit, 10.0)
        XCTAssertEqual(data.month_gb, 50.5)
        XCTAssertEqual(data.month_limit, 150.0)
        XCTAssertNil(data.ping)
    }
    
    func testPingDataFlexibleDecoding() throws {
        let json = """
        {
            "avg_latency_ms": "30.0",
            "worst_latency_ms": "150",
            "avg_packet_loss": "1.5",
            "max_packet_loss": "5",
            "latest_latency_ms": "25.0",
            "latest_packet_loss": "0",
            "target": "example.com",
            "total_checks": 50
        }
        """.data(using: .utf8)!

        let ping = try JSONDecoder().decode(PingData.self, from: json)
        
        XCTAssertEqual(ping.avg_latency_ms, 30.0)
        XCTAssertEqual(ping.worst_latency_ms, 150.0)
        XCTAssertEqual(ping.avg_packet_loss, 1.5)
        XCTAssertEqual(ping.max_packet_loss, 5.0)
        XCTAssertEqual(ping.latest_latency_ms, 25.0)
        XCTAssertEqual(ping.latest_packet_loss, 0.0)
        XCTAssertEqual(ping.target, "example.com")
        XCTAssertEqual(ping.total_checks, 50)
    }

    func testIncompleteDataHandling() throws {
        let json = """
        {
            "day_gb": 1.0,
            "month_gb": 10.0
        }
        """.data(using: .utf8)!

        let data = try JSONDecoder().decode(TrafficData.self, from: json)
        
        // Missing fields should safely default to 0.0 according to our flexible decoder
        XCTAssertEqual(data.day_gb, 1.0)
        XCTAssertEqual(data.day_limit, 0.0)
        XCTAssertEqual(data.month_gb, 10.0)
        XCTAssertEqual(data.month_limit, 0.0)
    }

    // MARK: - Testing UserDefaults Integration

    func testTrafficManagerUserDefaultsFallback() {
        // Backup the original URL
        let originalURL = UserDefaults.standard.string(forKey: "serverURL")
        
        // Test setting a new URL
        let testURL = "http://test.local/traffic"
        TrafficManager.shared.serverURL = testURL
        
        // Verify it was written to UserDefaults
        XCTAssertEqual(UserDefaults.standard.string(forKey: "serverURL"), testURL)
        
        // Restore
        if let originalURL = originalURL {
            TrafficManager.shared.serverURL = originalURL
        }
    }

    // MARK: - Testing Widget Data Models



    // MARK: - Integration / Combine Tests
    
    func testTrafficManagerPublishesDataOrError() {
        // This tests that fetching data actually updates the @Published properties.
        let expectation = XCTestExpectation(description: "Wait for TrafficManager to fetch data or error out")
        
        // Backup URL
        let originalURL = TrafficManager.shared.serverURL
        TrafficManager.shared.serverURL = "invalid url with spaces"
        
        var receivedError: String? = nil
        
        let cancellable = TrafficManager.shared.$errorMessage
            .dropFirst() // Ignore the initial value
            .sink { error in
                if error != nil {
                    receivedError = error
                    expectation.fulfill()
                }
            }
        
        // Trigger fetch with bad URL
        TrafficManager.shared.fetchData()
        
        wait(for: [expectation], timeout: 5.0)
        
        XCTAssertNotNil(receivedError, "TrafficManager should publish an error message when a bad URL is provided")
        
        // Restore
        TrafficManager.shared.serverURL = originalURL
        cancellable.cancel()
    }
}
