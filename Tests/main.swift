import Foundation
import CoreGraphics

func check(_ condition: Bool, _ message: String) {
    if !condition { fatalError(message) }
}
var policy = ScrollPolicy()
check(policy.factor(trackpad: false, horizontalAxis: false) == -1, "Mouse vertical default")
check(policy.factor(trackpad: false, horizontalAxis: true) == 1, "Horizontal default")
check(policy.factor(trackpad: true, horizontalAxis: false) == 1, "Trackpad preserved")
check(!policy.isTrackpad(continuous: false, phase: 0, momentum: 0), "Wheel detection")
check(policy.isTrackpad(continuous: true, phase: 0, momentum: 0), "Smooth default")
policy.continuousAsMouse = true
check(!policy.isTrackpad(continuous: true, phase: 0, momentum: 0), "Smooth mouse override")
check(policy.isTrackpad(continuous: true, phase: 1, momentum: 0), "Gesture protected")
check(policy.isTrackpad(continuous: true, phase: 0, momentum: 2), "Momentum protected")
policy.reverseTrackpad = true
policy.horizontal = true
check(policy.factor(trackpad: true, horizontalAxis: true) == -1, "Trackpad horizontal")
policy.mouseSpeed = 2
check(policy.factor(trackpad: false, horizontalAxis: false) == -2, "Mouse speed")
check(policy.factor(trackpad: true, horizontalAxis: false) == -1, "Trackpad speed unchanged")
policy.enabled = false
check(policy.factor(trackpad: false, horizontalAxis: false) == 1, "Disabled pass-through")
print("All scroll policy checks passed")

// Exercise actual CGEvent storage as well as the pure policy.
let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 2, wheel1: 3, wheel2: -2, wheel3: 0)!
event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 3.5)
event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 30)
let originalX = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
ScrollPolicy().apply(to: event)
check(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == -3, "Actual line delta reversed")
check(event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1) == -3.5, "Fixed-point delta reversed")
check(event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1) == -30, "Pixel delta reversed")
check(event.getIntegerValueField(.scrollWheelEventDeltaAxis2) == originalX, "Actual horizontal unchanged")
event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
event.setIntegerValueField(.scrollWheelEventScrollPhase, value: 1)
ScrollPolicy().apply(to: event)
check(event.getIntegerValueField(.scrollWheelEventDeltaAxis1) == -3, "Actual trackpad event unchanged")
print("CGEvent integration checks passed")
