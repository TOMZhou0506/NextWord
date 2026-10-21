import Foundation

extension Int {
    // "1 word", "3 words": a count with the right singular or plural noun.
    func counted(_ singular: String, plural: String? = nil) -> String {
        "\(self) \(self == 1 ? singular : (plural ?? singular + "s"))"
    }
}
