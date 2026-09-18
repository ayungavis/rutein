import SwiftUI

public struct MapUnavailableView: View {
    public init() {}

    public var body: some View {
        VStack(spacing: Spacing.xs) {
            Text("detail.map.unavailable.title", bundle: .module)
                .font(AppFont.subheadlineStrong)

            Text("detail.map.unavailable.description", bundle: .module)
                .font(AppFont.subheadline)
        }
        .foregroundStyle(AppColor.textPrimary)
        .multilineTextAlignment(.center)
        .padding(Spacing.xl3)
        .frame(maxWidth: .infinity, minHeight: 160)
        .background(AppColor.bgBrandPrimary)
        .clipShape(.rect(cornerRadius: Radius.xl))
    }
}

#Preview {
    MapUnavailableView()
        .padding()
        .background(AppColor.bgBrandPrimary)
        .preferredColorScheme(.light)
}
