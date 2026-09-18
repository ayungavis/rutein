import SwiftUI

struct SharePreviewView: View {
    @Environment(\.dismiss) private var dismiss

    let text: String
    let card: BriefImage
    let imageName: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            Text("brief.share.disclosure", bundle: .module)
                .font(AppFont.footnote)
                .foregroundStyle(AppColor.textSecondary)

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    if let image = card.image {
                        image
                            .resizable()
                            .scaledToFit()
                            .clipShape(.rect(cornerRadius: Radius.xl))
                            .accessibilityLabel(Text("brief.share.image", bundle: .module))
                    }

                    if let explanation = card.explanation {
                        Text(explanation, bundle: .module)
                            .font(AppFont.footnote)
                            .foregroundStyle(AppColor.textSecondary)
                    }

                    Text(verbatim: text)
                        .font(AppFont.subheadline)
                        .foregroundStyle(AppColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }

            actions
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.bgBrandPrimary)
        .tint(AppColor.textPrimary)
    }

    private var actions: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                Button {
                    dismiss()
                } label: {
                    Text("common.cancel", bundle: .module)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)

                ShareLink(item: text) {
                    Text("brief.share.text", bundle: .module)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(AppColor.bgPrimary)
            }

            if let image = card.image {
                ShareLink(
                    item: image,
                    preview: SharePreview(imageName, image: image),
                ) {
                    Text("brief.share.image.action", bundle: .module)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
        }
    }
}

#Preview {
    SharePreviewView(
        text: "Ridge Loop\n20.0 km · 5 hr · 15:00 /km\nDistance-based estimate.",
        card: .timelineTooLong,
        imageName: "Ridge Loop",
    )
    .preferredColorScheme(.light)
}
