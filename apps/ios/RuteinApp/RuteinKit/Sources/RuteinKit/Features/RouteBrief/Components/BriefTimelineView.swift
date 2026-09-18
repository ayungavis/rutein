import SwiftUI

struct BriefTimelineView: View {
    let rows: [BriefRow]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            ForEach(rows) { row in
                HStack(alignment: .top, spacing: Spacing.md) {
                    marker(isGenerated: row.isGenerated)

                    Text(verbatim: row.offset)
                        .font(AppFont.subheadlineStrong)
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(width: 84, alignment: .leading)

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(verbatim: row.name ?? row.label)
                            .font(AppFont.subheadline)
                            .foregroundStyle(AppColor.textPrimary)

                        if !row.detail.isEmpty {
                            Text(verbatim: row.detail)
                                .font(AppFont.footnote)
                                .foregroundStyle(AppColor.textSecondary)
                        }

                        if row.isGenerated {
                            Text("brief.legend.generated", bundle: .module)
                                .font(AppFont.footnote)
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func marker(isGenerated: Bool) -> some View {
        Circle()
            .fill(isGenerated ? AppColor.bgBrandPrimary : AppColor.bgPrimary)
            .overlay(Circle().strokeBorder(AppColor.bgPrimary, lineWidth: 2))
            .frame(width: Spacing.xl, height: Spacing.xl)
            .padding(.top, Spacing.xs)
            .accessibilityHidden(true)
    }
}

#Preview {
    BriefTimelineView(
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
            BriefRow(
                id: 2,
                offset: "+02:30",
                label: "Distance marker",
                name: nil,
                detail: "10.0 km",
                isGenerated: true,
            ),
            BriefRow(id: 3, offset: "+05:00", label: "Finish", name: nil, detail: "20.0 km", isGenerated: false),
        ],
    )
    .padding()
    .background(AppColor.bgBrandPrimary)
    .preferredColorScheme(.light)
}
