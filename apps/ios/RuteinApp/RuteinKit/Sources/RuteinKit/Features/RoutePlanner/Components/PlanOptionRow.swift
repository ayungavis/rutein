import SwiftUI

struct PlanOptionRow<Detail: View>: View {
    let title: LocalizedStringKey
    let note: LocalizedStringKey

    @Binding var isOn: Bool

    @ViewBuilder let detail: Detail

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Toggle(isOn: $isOn) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title, bundle: .module)
                        .font(AppFont.subheadline)
                        .foregroundStyle(AppColor.textPrimary)

                    Text(note, bundle: .module)
                        .font(AppFont.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .tint(AppColor.bgPrimary)

            if isOn {
                detail
            }
        }
    }
}
