import SwiftUI
extension Binding where Value == Int {
    // Slider works with Double, but our settings are whole numbers.
    var asDouble: Binding<Double> {
        Binding<Double>(get: { Double(wrappedValue) }, set: { wrappedValue = Int($0) })
    }
}
