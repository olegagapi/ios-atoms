import Testing
@testable import ProgressiveSlider

/// 0 → 1 by 0.1, then 1 → 10 by 1.
private let twoSegments = ProgressiveScale(from: 0, [
    .to(1, step: 0.1),
    .to(10, step: 1),
])

/// 0 → 1 by 0.1, 1 → 10 by 1, 10 → 100 by 10.
private let threeSegments = ProgressiveScale(from: 0, [
    .to(1, step: 0.1),
    .to(10, step: 1),
    .to(100, step: 10),
])

/// Fine steps around zero, coarse steps further out.
private let aroundZero = ProgressiveScale(from: -10, [
    .to(-1, step: 1),
    .to(1, step: 0.1),
    .to(10, step: 1),
])

/// Steps that don't divide their segment evenly.
private let uneven = ProgressiveScale(from: 0, [
    .to(1, step: 0.3),
    .to(2, step: 0.4),
])

private let allScales = [twoSegments, threeSegments, aroundZero, uneven]

@Suite("ProgressiveScale")
struct ProgressiveScaleTests {

    @Test func stopsAreExactDecimals() {
        #expect(twoSegments.stops == [
            0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9,
            1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
        ])
        #expect(aroundZero.stops.prefix(10) == [-10, -9, -8, -7, -6, -5, -4, -3, -2, -1])
        #expect(aroundZero.stops.contains(-0.3))
        #expect(aroundZero.stops.contains(0.7))
    }

    @Test func unevenSegmentsAlwaysIncludeTheirBounds() {
        #expect(uneven.stops == [0, 0.3, 0.6, 0.9, 1, 1.4, 1.8, 2])
    }

    @Test(arguments: allScales)
    func everyStopRoundTripsThroughItsPosition(scale: ProgressiveScale) {
        for stop in scale.stops {
            #expect(scale.value(atPosition: scale.position(for: stop)) == stop)
            #expect(scale.snapped(stop) == stop)
        }
    }

    @Test(arguments: allScales)
    func roundTripSurvivesFloatPrecision(scale: ProgressiveScale) {
        // UISlider stores its value as Float.
        for stop in scale.stops {
            let position = Double(Float(scale.position(for: stop)))
            #expect(scale.value(atPosition: position) == stop)
        }
    }

    @Test(arguments: allScales)
    func positionsIncreaseStrictlyFromZeroToOne(scale: ProgressiveScale) {
        let positions = scale.stops.map(scale.position(for:))
        #expect(positions.first == 0)
        #expect(positions.last == 1)
        #expect(zip(positions, positions.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test func defaultWeightsSpaceEveryStepEvenly() {
        let positions = twoSegments.stops.map(twoSegments.position(for:))
        let gaps = zip(positions, positions.dropFirst()).map { $1 - $0 }
        for gap in gaps {
            #expect(abs(gap - 1.0 / 19) < 1e-12)
        }
        #expect(abs(twoSegments.position(for: 1) - 10.0 / 19) < 1e-12)
    }

    @Test func explicitWeightsSplitTheTrack() {
        let scale = ProgressiveScale(from: 0, [
            .to(1, step: 0.1, weight: 1),
            .to(100, step: 1, weight: 1),
        ])
        #expect(scale.position(for: 1) == 0.5)
        #expect(scale.position(for: 0.5) == 0.25)
        #expect(scale.value(atPosition: 0.5) == 1)
        #expect(scale.value(atPosition: 0.75) == 51) // 50.5 rounds up
        #expect(scale.value(atPosition: 0.7) == 41)
    }

    @Test func boundaryHasOnePosition() {
        // Approaching 1 from either segment lands on the same spot.
        let fromBelow = twoSegments.position(for: 1)
        let fromAbove = twoSegments.position(for: 1.000_000_1)
        #expect(abs(fromBelow - fromAbove) < 1e-6)
        #expect(twoSegments.value(atPosition: fromBelow) == 1)
    }

    @Test func snappingPicksTheNearestStop() {
        #expect(twoSegments.snapped(0.34) == 0.3)
        #expect(twoSegments.snapped(0.36) == 0.4)
        #expect(twoSegments.snapped(0.97) == 1)
        #expect(twoSegments.snapped(1.4) == 1)
        #expect(twoSegments.snapped(3.6) == 4)
        #expect(uneven.snapped(0.97) == 1)
        #expect(uneven.snapped(0.8) == 0.9)
        #expect(uneven.snapped(1.95) == 2)
    }

    @Test func positionSnapsInTrackSpace() {
        let step = 1.0 / 19
        #expect(twoSegments.value(atPosition: step * 3.4) == 0.3)
        #expect(twoSegments.value(atPosition: step * 3.6) == 0.4)
        #expect(twoSegments.value(atPosition: step * 12.4) == 3)
        #expect(twoSegments.value(atPosition: step * 12.6) == 4)
    }

    @Test func outOfRangeInputIsClamped() {
        #expect(twoSegments.position(for: -5) == 0)
        #expect(twoSegments.position(for: 50) == 1)
        #expect(twoSegments.value(atPosition: -1) == 0)
        #expect(twoSegments.value(atPosition: 2) == 10)
        #expect(twoSegments.snapped(-3) == 0)
        #expect(twoSegments.snapped(42) == 10)
        #expect(twoSegments.snapped(.nan) == 0)
        #expect(twoSegments.value(atPosition: .nan) == 0)
    }

    @Test(arguments: allScales)
    func steppingWalksEveryStopInOrder(scale: ProgressiveScale) {
        let stops = scale.stops
        for (current, next) in zip(stops, stops.dropFirst()) {
            #expect(scale.value(after: current) == next)
            #expect(scale.value(before: next) == current)
        }
        #expect(scale.value(after: scale.upperBound) == scale.upperBound)
        #expect(scale.value(before: scale.lowerBound) == scale.lowerBound)
    }

    @Test func steppingFromBetweenStops() {
        #expect(twoSegments.value(after: 0.35) == 0.4)
        #expect(twoSegments.value(before: 0.35) == 0.3)
        #expect(twoSegments.value(after: 1.5) == 2)
        #expect(twoSegments.value(before: 1.5) == 1)
        #expect(uneven.value(before: 0.95) == 0.9)
        #expect(uneven.value(after: 0.95) == 1)
    }

    @Test func stepAndPrecisionAtValue() {
        #expect(twoSegments.step(at: 0.5) == 0.1)
        #expect(twoSegments.step(at: 1) == 0.1)
        #expect(twoSegments.step(at: 1.5) == 1)
        #expect(twoSegments.fractionDigits(at: 0.5) == 1)
        #expect(twoSegments.fractionDigits(at: 5) == 0)
        #expect(threeSegments.step(at: 50) == 10)
    }

    @Test func boundariesAndRange() {
        #expect(threeSegments.boundaries == [0, 1, 10, 100])
        #expect(threeSegments.range == 0...100)
        #expect(aroundZero.range == -10...10)
    }

    @Test func fractionDigits() {
        #expect(ProgressiveScale.fractionDigits(of: 0) == 0)
        #expect(ProgressiveScale.fractionDigits(of: 1) == 0)
        #expect(ProgressiveScale.fractionDigits(of: 250) == 0)
        #expect(ProgressiveScale.fractionDigits(of: 0.1) == 1)
        #expect(ProgressiveScale.fractionDigits(of: 2.5) == 1)
        #expect(ProgressiveScale.fractionDigits(of: 0.05) == 2)
        #expect(ProgressiveScale.fractionDigits(of: -0.001) == 3)
        #expect(ProgressiveScale.fractionDigits(of: 1e-12) == 12)
    }

    @Test func tinyStepsKeepTheirPrecision() {
        let scale = ProgressiveScale(from: 0, [.to(0.001, step: 0.0001), .to(1, step: 0.001)])
        #expect(scale.stops.prefix(4) == [0, 0.0001, 0.0002, 0.0003])
        #expect(scale.value(after: 0.001) == 0.002)
    }
}

@Suite("ProgressiveScale.decades")
struct DecadesTests {

    @Test func matchesTheHandWrittenScale() {
        #expect(ProgressiveScale.decades(through: 100, initialStep: 0.1) == threeSegments)
    }

    @Test func boundariesAndStepsGrowTenfold() {
        let scale = ProgressiveScale.decades(through: 10_000, initialStep: 0.01)
        #expect(scale.boundaries == [0, 0.1, 1, 10, 100, 1000, 10_000])
        #expect(scale.segments.map(\.step) == [0.01, 0.1, 1, 10, 100, 1000])
    }

    @Test func upperBoundNeedNotBeAPowerOfTen() {
        let scale = ProgressiveScale.decades(through: 250, initialStep: 1)
        #expect(scale.boundaries == [0, 10, 100, 250])
        #expect(scale.segments.map(\.step) == [1, 10, 100])
        #expect(scale.stops.suffix(3) == [100, 200, 250])
    }

    @Test func decadesBelowTheLowerBoundAreSkipped() {
        let scale = ProgressiveScale.decades(from: 5, through: 1000, initialStep: 0.1)
        #expect(scale.boundaries == [5, 10, 100, 1000])
        #expect(scale.segments.map(\.step) == [1, 10, 100])
    }

    @Test func singleDecade() {
        let scale = ProgressiveScale.decades(through: 0.5, initialStep: 0.1)
        #expect(scale.boundaries == [0, 0.5])
        #expect(scale.stops == [0, 0.1, 0.2, 0.3, 0.4, 0.5])
    }
}
