import Foundation
import Network
import Observation

/// Publishes the device's current network reachability.
/// Observed by SyncService to trigger queue drains when connectivity is restored.
@MainActor
@Observable
final class NetworkMonitor {
    private(set) var isConnected: Bool = false

    @ObservationIgnored
    private let monitor = NWPathMonitor()
    @ObservationIgnored
    private let queue = DispatchQueue(label: "com.dinklink.networkmonitor", qos: .utility)

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isConnected = connected
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
