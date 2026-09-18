import SwiftUI

struct TrackSelectionView: View {
    let pending: PendingImport
    let onChoose: (RouteCandidate) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("import.select.title", bundle: .module)
                    .font(AppFont.display)
                    .foregroundStyle(AppColor.textPrimary)

                Text("import.select.subtitle", bundle: .module)
                    .font(AppFont.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
            }

            ScrollView {
                VStack(spacing: Spacing.xl) {
                    ForEach(pending.choices) { candidate in
                        Button {
                            onChoose(candidate)
                        } label: {
                            row(candidate)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button(role: .cancel, action: onCancel) {
                Text("common.cancel", bundle: .module)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glass)
            .controlSize(.large)
        }
        .padding(Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.bgBrandPrimary)
        .tint(AppColor.textPrimary)
    }

    private func row(_ candidate: RouteCandidate) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(verbatim: candidate.name ?? fallbackName(candidate))
                .font(AppFont.headline)
                .foregroundStyle(AppColor.textPrimary)

            Text(
                candidate.kind == .track
                    ? "import.select.track \(candidate.id + 1) \(candidate.pointCount)"
                    : "import.select.route \(candidate.id + 1) \(candidate.pointCount)",
                bundle: .module,
            )
            .font(AppFont.footnote)
            .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
    }

    private func fallbackName(_ candidate: RouteCandidate) -> String {
        String(localized: "import.select.unnamed \(candidate.id + 1)", bundle: .module)
    }
}

#Preview {
    TrackSelectionView(
        pending: PendingImport(
            name: "wikiloc-mt-agung",
            data: Data(),
            document: GPXDocument(
                candidates: [
                    RouteCandidate(id: 0, kind: .track, name: "Ascent", segments: [previewSegment]),
                    RouteCandidate(id: 1, kind: .track, name: nil, segments: [previewSegment]),
                ],
                waypoints: [],
            ),
        ),
        onChoose: { _ in },
        onCancel: {},
    )
    .preferredColorScheme(.light)
}

private let previewSegment = (0 ..< 40).map { step in
    TrackPoint(latitude: Double(step) * 0.001, longitude: 0, elevation: 100, timestamp: nil)
}
