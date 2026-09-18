import SwiftUI

struct BriefCardView: View {
    static let width: CGFloat = 1080

    let name: String
    let summary: String
    let rows: [BriefRow]
    let showsMarkerNotice: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl4) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text(verbatim: name)
                    .font(AppFont.display)
                    .foregroundStyle(AppColor.textPrimary)

                Text(verbatim: summary)
                    .font(AppFont.headline)
                    .foregroundStyle(AppColor.textSecondary)
            }

            BriefTimelineView(rows: rows)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("brief.estimate.title", bundle: .module)
                Text("brief.estimate.detail", bundle: .module)

                if showsMarkerNotice {
                    Text("brief.markers.title", bundle: .module)
                }
            }
            .font(AppFont.footnote)
            .foregroundStyle(AppColor.textSecondary)
        }
        .padding(Spacing.xl6)
        .frame(width: Self.width, alignment: .leading)
        .background(AppColor.bgBrandPrimary)
        .environment(\.colorScheme, .light)
    }
}

#Preview {
    BriefCardView(
        name: "Ridge Loop",
        summary: "20.0 km · 5 hr · 15:00 /km",
        rows: [
            BriefRow(id: 0, offset: "+00:00", label: "Start", name: nil, detail: "0.0 km", isGenerated: false),
            BriefRow(
                id: 1,
                offset: "+01:15",
                label: "GPX checkpoint",
                name: "Water point",
                detail: "5.0 km and 1,100 m",
                isGenerated: false,
            ),
            BriefRow(id: 2, offset: "+05:00", label: "Finish", name: nil, detail: "20.0 km", isGenerated: false),
        ],
        showsMarkerNotice: true,
    )
    .scaleEffect(0.3)
    .preferredColorScheme(.light)
}
