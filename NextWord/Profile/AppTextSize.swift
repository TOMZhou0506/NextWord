import SwiftUI

// Read the system size outside the override so changes remain relative to iOS settings.
struct AppTextSizeModifier: ViewModifier {
    @AppStorage("readingSize") private var textSize = "standard"
    @Environment(\.dynamicTypeSize) private var systemSize

    private var effectiveSize: DynamicTypeSize {
        let sizes = DynamicTypeSize.allCases.sorted()
        let offset = textSize == "extraLarge" ? 2 : textSize == "large" ? 1 : 0
        let index = sizes.firstIndex(of: systemSize) ?? 0
        return sizes[min(index + offset, sizes.count - 1)]
    }

    func body(content: Content) -> some View {
        content.dynamicTypeSize(effectiveSize)
    }
}
