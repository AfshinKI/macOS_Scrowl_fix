import Foundation
import CoreGraphics

struct ScrollPolicy {
    var enabled = true
    var reverseMouse = true
    var reverseTrackpad = false
    var vertical = true
    var horizontal = false
    var mouseSpeed = 1.0
    var continuousAsMouse = false

    // Public event APIs do not expose a reliable physical device ID. Phase-bearing
    // gestures are trackpad input; unphased continuous input can be overridden.
    func isTrackpad(continuous: Bool, phase: Int64, momentum: Int64) -> Bool {
        phase != 0 || momentum != 0 || (continuous && !continuousAsMouse)
    }

    func factor(trackpad: Bool, horizontalAxis: Bool) -> Double {
        guard enabled else { return 1 }
        let reverse = trackpad ? reverseTrackpad : reverseMouse
        let axis = horizontalAxis ? horizontal : vertical
        return (reverse && axis ? -1 : 1) * (trackpad ? 1 : mouseSpeed)
    }
}

extension ScrollPolicy {
    func apply(to event: CGEvent) {
        let trackpad = isTrackpad(continuous: event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0,
            phase: event.getIntegerValueField(.scrollWheelEventScrollPhase), momentum: event.getIntegerValueField(.scrollWheelEventMomentumPhase))
        let axes: [(Bool, [CGEventField])] = [
            (false, [.scrollWheelEventDeltaAxis1, .scrollWheelEventFixedPtDeltaAxis1, .scrollWheelEventPointDeltaAxis1]),
            (true, [.scrollWheelEventDeltaAxis2, .scrollWheelEventFixedPtDeltaAxis2, .scrollWheelEventPointDeltaAxis2])]
        for (horizontal, fields) in axes {
            let factor = factor(trackpad: trackpad, horizontalAxis: horizontal)
            if factor == 1 { continue }
            // Setting a line delta also recalculates fixed-point and pixel deltas.
            // Snapshot all representations before writing any of them.
            let values = fields.map { event.getDoubleValueField($0) * factor }
            for (field, value) in zip(fields, values) {
                event.setDoubleValueField(field, value: value)
            }
        }
    }
}
