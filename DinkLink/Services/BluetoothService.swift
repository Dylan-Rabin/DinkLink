import Combine
import Foundation

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
final class MockBluetoothService: ObservableObject, BluetoothServiceProtocol {
    @Published private(set) var connectedDevice: PaddleDevice?
    @Published private(set) var discoveredDevices: [PaddleDevice] = []

    var onShotEvent: ((ShotEvent) -> Void)?

    private var streamTimer: Timer?

    func scanForDevices() async -> [PaddleDevice] {
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
