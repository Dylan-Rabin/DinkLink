import Foundation
import Observation

@MainActor
protocol BluetoothServiceProtocol: AnyObject {
    var connectedDevice: PaddleDevice? { get }
    var discoveredDevices: [PaddleDevice] { get }
    var onShotEvent: ((ShotEvent) -> Void)? { get set }

    func scanForDevices() async -> [PaddleDevice]
    func connect(to device: PaddleDevice) async
    func disconnect()
    func startStreaming()
    func stopStreaming()
}

@MainActor
// The mock service is also observable so connected-device changes can flow into
// SwiftUI views using the same Observation system as the view models.
@Observable
final class MockBluetoothService: BluetoothServiceProtocol {
    private(set) var connectedDevice: PaddleDevice?
    private(set) var discoveredDevices: [PaddleDevice] = []

    var onShotEvent: ((ShotEvent) -> Void)?

    @ObservationIgnored
    private var streamTimer: Timer?

    func scanForDevices() async -> [PaddleDevice] {
        // External data seam: a production build would replace this mock list with
        // real device discovery or an API-backed hardware lookup.
        try? await Task.sleep(for: .milliseconds(600))
        discoveredDevices = [
            PaddleDevice(name: "DL Pro Paddle", batteryLevel: 92),
            PaddleDevice(name: "CourtSense One", batteryLevel: 81),
            PaddleDevice(name: "SpinCore Trainer", batteryLevel: 67)
        ]
        return discoveredDevices
    }

    func connect(to device: PaddleDevice) async {
        try? await Task.sleep(for: .milliseconds(500))
        connectedDevice = PaddleDevice(
            id: device.id,
            name: device.name,
            batteryLevel: device.batteryLevel,
            isConnected: true
        )
        discoveredDevices = discoveredDevices.map { current in
            PaddleDevice(
                id: current.id,
                name: current.name,
                batteryLevel: current.batteryLevel,
                isConnected: current.id == device.id
            )
        }
    }

    func disconnect() {
        stopStreaming()
        connectedDevice = nil
        discoveredDevices = discoveredDevices.map { device in
            PaddleDevice(
                id: device.id,
                name: device.name,
                batteryLevel: device.batteryLevel,
                isConnected: false
            )
        }
    }

    func startStreaming() {
        guard streamTimer == nil else { return }
        // This timer mimics a live telemetry feed so the UI can react as if
        // paddle data were arriving continuously from a connected service.
        streamTimer = Timer.scheduledTimer(
            timeInterval: 0.75,
            target: self,
            selector: #selector(handleMockShot),
            userInfo: nil,
            repeats: true
        )
    }

    func stopStreaming() {
        streamTimer?.invalidate()
        streamTimer = nil
    }

    private static func randomShot() -> ShotEvent {
        ShotEvent(
            speedMPH: Double.random(in: 12 ... 48),
            hitSweetSpot: Int.random(in: 0 ... 100) > 28,
            spinRPM: Double.random(in: 900 ... 2600)
        )
    }

    @objc private func handleMockShot() {
        onShotEvent?(Self.randomShot())
    }
}
