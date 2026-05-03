import Foundation
import Observation

@MainActor
protocol BluetoothServiceProtocol: AnyObject {
    var connectedDevice: PaddleDevice? { get }
    var discoveredDevices: [PaddleDevice] { get }
    var onPaddleEvent: ((PaddleEvent) -> Void)? { get set }

    func scanForDevices() async -> [PaddleDevice]
    func connect(to device: PaddleDevice) async
    func disconnect()
    func startStreaming()
    func stopStreaming()
    func handleIncomingSerialText(_ text: String)
}

func parsePaddleLine(_ line: String) -> PaddleEvent? {
    let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleaned.isEmpty else { return nil }

    let tokens = cleaned.split(whereSeparator: \.isWhitespace).map(String.init)
    guard let first = tokens.first?.uppercased() else { return nil }

    switch first {
    case "MOTION":
        guard tokens.count >= 2, let motionValue = Double(tokens[1]) else { return nil }
        return PaddleEvent(type: .motion, motionValue: motionValue)

    case "HIT":
        guard let motionIndex = tokens.firstIndex(where: { $0.uppercased() == "MOTION" }) else { return nil }
        guard motionIndex >= 3, motionIndex + 1 < tokens.count else { return nil }
        guard let impactStrength = Int(tokens[motionIndex - 1]) else { return nil }
        guard let motionValue = Double(tokens[motionIndex + 1]) else { return nil }

        let zoneText = tokens[1..<(motionIndex - 1)].joined(separator: " ").uppercased()
        let zone = PaddleZone(rawValue: zoneText) ?? .unknown
        guard zone != .unknown else { return nil }

        return PaddleEvent(
            type: .hit,
            zone: zone,
            impactStrength: impactStrength,
            motionValue: motionValue
        )

    default:
        return nil
    }
}

@MainActor
@Observable
final class MockBluetoothService: BluetoothServiceProtocol {
    private(set) var connectedDevice: PaddleDevice?
    private(set) var discoveredDevices: [PaddleDevice] = []

    var onPaddleEvent: ((PaddleEvent) -> Void)?

    @ObservationIgnored
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
            selector: #selector(handleMockTelemetry),
            userInfo: nil,
            repeats: true
        )
    }

    func stopStreaming() {
        streamTimer?.invalidate()
        streamTimer = nil
    }

    func handleIncomingSerialText(_ text: String) {
        text.split(whereSeparator: \.isNewline)
            .compactMap { parsePaddleLine(String($0)) }
            .forEach { onPaddleEvent?($0) }
    }

    private static func randomTelemetryLine() -> String {
        if Int.random(in: 0...3) == 0 {
            return "MOTION \(String(format: "%.2f", Double.random(in: 0.25...3.35)))"
        }

        let zones = [
            PaddleZone.top.rawValue,
            PaddleZone.bottom.rawValue,
            PaddleZone.left.rawValue,
            PaddleZone.right.rawValue,
            PaddleZone.centerFront.rawValue,
            PaddleZone.centerBack.rawValue
        ]
        let zone = zones.randomElement() ?? PaddleZone.top.rawValue
        let impactStrength = Int.random(in: 180...940)
        let motionValue = String(format: "%.2f", Double.random(in: 0.25...3.35))
        return "HIT \(zone) \(impactStrength) MOTION \(motionValue)"
    }

    @objc private func handleMockTelemetry() {
        handleIncomingSerialText(Self.randomTelemetryLine() + "\n")
    }
}
