import Foundation

extension Double {
    /// Round to a given number of decimal places.
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }

    /// True if the value represents a gain (positive).
    var isGain: Bool { self > 0 }

    /// Sign string: "+" for positive, "" for zero/negative.
    var signString: String { self > 0 ? "+" : "" }
}
