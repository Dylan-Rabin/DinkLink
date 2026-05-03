import Testing
@testable import DinkLink

struct PaddleParserTests {
    @Test
    func parsesMotionOnlyLine() {
        let event = parsePaddleLine("MOTION 0.73")

        #expect(event?.type == .motion)
        #expect(event?.zone == nil)
        #expect(event?.impactStrength == nil)
        #expect(event?.motionValue == 0.73)
    }

    @Test
    func parsesTopHitLine() {
        let event = parsePaddleLine("HIT TOP 482 MOTION 1.24")

        #expect(event?.type == .hit)
        #expect(event?.zone == .top)
        #expect(event?.impactStrength == 482)
        #expect(event?.motionValue == 1.24)
    }

    @Test
    func parsesBottomHitLine() {
        let event = parsePaddleLine("HIT BOTTOM 530 MOTION 0.92")
        #expect(event?.zone == .bottom)
        #expect(event?.impactStrength == 530)
    }

    @Test
    func parsesLeftHitLine() {
        let event = parsePaddleLine("HIT LEFT 611 MOTION 1.43")
        #expect(event?.zone == .left)
        #expect(event?.impactStrength == 611)
    }

    @Test
    func parsesRightHitLine() {
        let event = parsePaddleLine("HIT RIGHT 455 MOTION 0.88")
        #expect(event?.zone == .right)
        #expect(event?.impactStrength == 455)
    }

    @Test
    func parsesCenterFrontHitLine() {
        let event = parsePaddleLine("HIT CENTER FRONT 720 MOTION 2.10")

        #expect(event?.type == .hit)
        #expect(event?.zone == .centerFront)
        #expect(event?.impactStrength == 720)
        #expect(event?.motionValue == 2.10)
    }

    @Test
    func parsesCenterBackHitLine() {
        let event = parsePaddleLine("HIT CENTER BACK 690 MOTION 1.97")

        #expect(event?.type == .hit)
        #expect(event?.zone == .centerBack)
        #expect(event?.impactStrength == 690)
        #expect(event?.motionValue == 1.97)
    }

    @Test
    func ignoresStartupLine() {
        #expect(parsePaddleLine("Starting XIAO ESP32C3 Paddle MVP...") == nil)
        #expect(parsePaddleLine("MPU6050 connected at 0x68.") == nil)
        #expect(parsePaddleLine("Calibrating IMU...") == nil)
        #expect(parsePaddleLine("Ready.") == nil)
    }

    @Test
    func handlesExtraWhitespace() {
        let event = parsePaddleLine("  HIT   CENTER   FRONT   720   MOTION   2.10 \n")

        #expect(event?.type == .hit)
        #expect(event?.zone == .centerFront)
        #expect(event?.impactStrength == 720)
        #expect(event?.motionValue == 2.10)
    }

    @Test
    func returnsNilForMalformedLines() {
        #expect(parsePaddleLine("HIT TOP MOTION 1.20") == nil)
        #expect(parsePaddleLine("MOTION banana") == nil)
        #expect(parsePaddleLine("HIT CENTER SIDE 500 MOTION 1.2") == nil)
    }
}
