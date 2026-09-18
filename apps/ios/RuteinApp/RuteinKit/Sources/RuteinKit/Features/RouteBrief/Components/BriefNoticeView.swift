import SwiftUI

struct BriefNoticeView: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: symbol)
                .font(AppFont.footnote)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title, bundle: .module)
                Text(detail, bundle: .module)
            }
            .font(AppFont.footnote)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(AppColor.textPrimary)
        .padding(Spacing.xl)
        .background(AppColor.textPrimary.opacity(0.06))
        .clipShape(.rect(cornerRadius: Radius.xl))
    }
}

#Preview {
    BriefNoticeView(
        title: "brief.estimate.title",
        detail: "brief.estimate.detail",
        symbol: "info.circle",
    )
    .padding()
    .background(AppColor.bgBrandPrimary)
    .preferredColorScheme(.light)
}
