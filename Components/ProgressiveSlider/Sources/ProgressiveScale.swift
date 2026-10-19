import Foundation

/// A piecewise-linear mapping between a slider track (`0...1`) and a value range
/// whose step size changes from segment to segment.
///
/// Use it to give the low end of a range fine-grained steps and the high end
/// coarse ones:
///
/// ```swift
/// // 0 → 1 in steps of 0.1, then 1 → 10 in steps of 1.
/// let scale = ProgressiveScale(from: 0, [
///     .to(1, step: 0.1),
///     .to(10, step: 1),
/// ])
///
/// scale.value(atPosition: 0.5)   // 1.0 (10 of 19 steps in)
/// scale.snapped(3.4)             // 3.0
/// scale.value(after: 0.9)        // 1.0
/// scale.value(after: 1)          // 2.0
/// ```
///
/// Every value the scale produces is a *stop*: a segment's lower bound plus a
/// whole number of its steps, or the segment's upper bound. Stops are rounded to
/// the decimal precision of the step, so `0.1 * 3` comes back as `0.3`, not
/// `0.30000000000000004`.
///
/// By default each segment's share of the track is proportional to its number of
/// steps, so every step is the same distance apart on screen. Give a segment a
/// `weight` to control its share explicitly.
public struct ProgressiveScale: Hashable, Sendable {

    /// One stretch of the scale, from the previous segment's upper bound (or the
    /// scale's lower bound) up to and including `upperBound`.
    public struct Segment: Hashable, Sendable {
        /// The value at which this segment ends (inclusive).
        public var upperBound: Double
        /// The distance between neighbouring stops inside this segment.
        public var step: Double
        /// The relative share of the track this segment occupies, compared with
        /// the other segments' weights. `nil` uses the segment's number of steps.
        public var weight: Double?

        public init(upTo upperBound: Double, step: Double, weight: Double? = nil) {
            self.upperBound = upperBound
            self.step = step
            self.weight = weight
        }

        /// A segment that ends at `upperBound` and moves in increments of `step`.
        public static func to(_ upperBound: Double, step: Double, weight: Double? = nil) -> Segment {
            Segment(upTo: upperBound, step: step, weight: weight)
        }
    }

    /// The smallest value on the scale.
    public let lowerBound: Double
    /// The segments in ascending order.
    public let segments: [Segment]

    private let spans: [Span]

    /// Creates a scale that starts at `lowerBound` and runs through `segments` in order.
    ///
    /// - Precondition: `segments` is non-empty, every bound is finite and greater
    ///   than the one before it, every step is finite and positive, and every
    ///   explicit weight is finite and positive.
    public init(from lowerBound: Double, _ segments: [Segment]) {
        precondition(!segments.isEmpty, "ProgressiveScale needs at least one segment")
        precondition(lowerBound.isFinite, "ProgressiveScale lower bound must be finite")

        var spans: [Span] = []
        var lower = lowerBound
        var weights: [Double] = []
        for segment in segments {
            precondition(segment.upperBound.isFinite && segment.upperBound > lower,
                         "Segment bound \(segment.upperBound) must be finite and greater than \(lower)")
            precondition(segment.step.isFinite && segment.step > 0,
                         "Segment step \(segment.step) must be finite and positive")
            if let weight = segment.weight {
                precondition(weight.isFinite && weight > 0, "Segment weight \(weight) must be finite and positive")
            }
            let digits = max(Self.fractionDigits(of: lower), Self.fractionDigits(of: segment.step))
            spans.append(Span(lower: lower, upper: segment.upperBound, step: segment.step,
                              start: 0, end: 0, fractionDigits: digits))
            weights.append(segment.weight ?? (segment.upperBound - lower) / segment.step)
            lower = segment.upperBound
        }

        let total = weights.reduce(0, +)
        var start = 0.0
        for index in spans.indices {
            let end = index == spans.count - 1 ? 1 : start + weights[index] / total
            spans[index].start = start
            spans[index].end = end
            start = end
        }

        self.lowerBound = lowerBound
        self.segments = segments
        self.spans = spans
    }

    /// The largest value on the scale.
    public var upperBound: Double { spans[spans.count - 1].upper }

    /// The full range of values the scale covers.
    public var range: ClosedRange<Double> { lowerBound...upperBound }

    /// The values where one segment hands over to the next, including both ends.
    public var boundaries: [Double] { [lowerBound] + spans.map(\.upper) }

    /// Every stop on the scale, in ascending order.
    ///
    /// Builds the whole array on each call, so avoid it on scales with a very
    /// large number of steps.
    public var stops: [Double] {
        var stops = [lowerBound]
        for span in spans {
            var k = 1.0
            while true {
                let stop = span.clean(span.lower + k * span.step)
                if stop >= span.upper { break }
                stops.append(stop)
                k += 1
            }
            stops.append(span.upper)
        }
        return stops
    }

    // MARK: - Mapping

    /// The track position (`0...1`) of `value`. Values outside the scale are clamped.
    public func position(for value: Double) -> Double {
        guard !value.isNaN else { return 0 }
        let span = spans[spanIndex(containing: value)]
        let v = min(max(value, span.lower), span.upper)
        return span.start + (v - span.lower) / (span.upper - span.lower) * (span.end - span.start)
    }

    /// The stop nearest to the track `position` (`0...1`). Positions outside the
    /// track are clamped.
    public func value(atPosition position: Double) -> Double {
        guard !position.isNaN else { return lowerBound }
        let p = min(max(position, 0), 1)
        let span = spans.first { p <= $0.end } ?? spans[spans.count - 1]
        let fraction = span.end > span.start ? (p - span.start) / (span.end - span.start) : 0
        return span.snap(span.lower + fraction * (span.upper - span.lower))
    }

    /// The stop nearest to `value`. Values outside the scale are clamped.
    public func snapped(_ value: Double) -> Double {
        guard !value.isNaN else { return lowerBound }
        return spans[spanIndex(containing: value)].snap(value)
    }

    /// The step size in effect at `value`. A boundary value belongs to the
    /// segment that ends there.
    public func step(at value: Double) -> Double {
        spans[spanIndex(containing: value)].step
    }

    /// The number of fraction digits needed to display stops near `value`
    /// without losing precision. Handy for formatting.
    public func fractionDigits(at value: Double) -> Int {
        spans[spanIndex(containing: value)].fractionDigits
    }

    /// The first stop greater than `value`, or the upper bound if there is none.
    public func value(after value: Double) -> Double {
        guard !value.isNaN else { return lowerBound }
        guard value < upperBound else { return upperBound }
        guard value >= lowerBound else { return lowerBound }
        let span = spans.first { value < $0.upper }!
        let k = ((value - span.lower) / span.step + Self.tolerance).rounded(.down) + 1
        let next = span.clean(span.lower + k * span.step)
        return next >= span.upper ? span.upper : next
    }

    /// The last stop less than `value`, or the lower bound if there is none.
    public func value(before value: Double) -> Double {
        guard !value.isNaN else { return lowerBound }
        guard value > lowerBound else { return lowerBound }
        guard value <= upperBound else { return upperBound }
        let span = spans.last { value > $0.lower }!
        let k = ((value - span.lower) / span.step - Self.tolerance).rounded(.up) - 1
        return span.clean(span.lower + k * span.step)
    }

    // MARK: - Private

    /// Slack, in units of one step, for floating-point error when counting steps.
    private static let tolerance = 1e-9

    private func spanIndex(containing value: Double) -> Int {
        spans.firstIndex { value <= $0.upper } ?? spans.count - 1
    }

    /// The number of decimal places in `x`, up to 15.
    static func fractionDigits(of x: Double) -> Int {
        let magnitude = abs(x)
        guard magnitude > 0 else { return 0 }
        for digits in 0..<15 {
            let scaled = magnitude * pow(10, Double(digits))
            let rounded = scaled.rounded()
            if rounded != 0 && abs(scaled - rounded) <= tolerance * rounded {
                return digits
            }
        }
        return 15
    }

    private struct Span: Hashable, Sendable {
        var lower: Double
        var upper: Double
        var step: Double
        var start: Double
        var end: Double
        var fractionDigits: Int

        func clean(_ x: Double) -> Double {
            let factor = pow(10, Double(fractionDigits))
            return (x * factor).rounded() / factor
        }

        func snap(_ raw: Double) -> Double {
            let v = min(max(raw, lower), upper)
            let candidate = clean(lower + ((v - lower) / step).rounded() * step)
            if candidate >= upper || upper - v < abs(v - candidate) {
                return upper
            }
            return candidate
        }
    }
}

// MARK: - Formatting

extension ProgressiveScale: CustomStringConvertible {
    /// For example `0…1 by 0.1, 1…10 by 1`.
    public var description: String {
        spans.map { "\(Self.plain($0.lower))…\(Self.plain($0.upper)) by \(Self.plain($0.step))" }
            .joined(separator: ", ")
    }

    /// `value` with as many decimals as it has, in the current locale. Used as the
    /// default VoiceOver value by both sliders.
    func accessibilityDescription(of value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...Self.fractionDigits(of: value))))
    }

    private static func plain(_ x: Double) -> String {
        x == x.rounded() && abs(x) < 1e15 ? String(Int64(x)) : String(x)
    }
}

// MARK: - Presets

extension ProgressiveScale {
    /// A scale whose step grows tenfold at every power-of-ten boundary.
    ///
    /// `decades(through: 1000, initialStep: 0.1)` produces
    /// 0…1 by 0.1, 1…10 by 1, 10…100 by 10 and 100…1000 by 100.
    ///
    /// - Parameters:
    ///   - lowerBound: The smallest value. Decades that end at or below it are skipped.
    ///   - upperBound: The largest value. It doesn't need to be a power of ten.
    ///   - initialStep: The step of the first decade, which ends at `initialStep * 10`.
    public static func decades(from lowerBound: Double = 0, through upperBound: Double, initialStep: Double) -> ProgressiveScale {
        precondition(initialStep.isFinite && initialStep > 0, "initialStep must be finite and positive")
        precondition(upperBound > lowerBound, "upperBound must be greater than lowerBound")

        let initialDigits = fractionDigits(of: initialStep)
        var segments: [Segment] = []
        var step = initialStep
        var decade = 0
        while true {
            let boundary = round(step * 10, toDigits: max(0, initialDigits - decade - 1))
            if boundary >= upperBound {
                segments.append(.to(upperBound, step: step))
                break
            }
            if boundary > lowerBound {
                segments.append(.to(boundary, step: step))
            }
            step = boundary
            decade += 1
        }
        return ProgressiveScale(from: lowerBound, segments)
    }

    private static func round(_ x: Double, toDigits digits: Int) -> Double {
        let factor = pow(10, Double(digits))
        return (x * factor).rounded() / factor
    }
}
