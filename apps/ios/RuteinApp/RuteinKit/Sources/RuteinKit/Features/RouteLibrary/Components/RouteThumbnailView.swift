import SwiftUI

public struct RouteThumbnailView: View {
    private let outline: [RouteOutlinePoint]

    public init(outline: [RouteOutlinePoint]) {
        self.outline = outline
    }

    public var body: some View {
        Canvas { context, size in
            guard let trace = trace(in: size) else { return }

            context.stroke(
                trace,
                with: .color(AppColor.textPrimary),
                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round),
            )
        }
        .frame(width: 78, height: 78)
        .background(AppColor.bgBrandPrimary)
        .clipShape(.rect(cornerRadius: Radius.md))
        .accessibilityHidden(true)
    }

    private func trace(in size: CGSize) -> Path? {
        guard outline.count > 1,
              let west = outline.map(\.longitude).min(),
              let east = outline.map(\.longitude).max(),
              let south = outline.map(\.latitude).min(),
              let north = outline.map(\.latitude).max()
        else {
            return nil
        }

        let inset = Spacing.md
        let box = CGSize(width: size.width - inset * 2, height: size.height - inset * 2)
        let scale = min(
            box.width / max(east - west, .leastNormalMagnitude),
            box.height / max(north - south, .leastNormalMagnitude),
        )

        guard scale.isFinite else {
            return nil
        }

        let origin = CGPoint(
            x: inset + (box.width - (east - west) * scale) / 2,
            y: inset + (box.height - (north - south) * scale) / 2,
        )

        var path = Path()

        for (index, point) in outline.enumerated() {
            let placed = CGPoint(
                x: origin.x + (point.longitude - west) * scale,
                y: origin.y + (north - point.latitude) * scale,
            )

            if index == 0 {
                path.move(to: placed)
            } else {
                path.addLine(to: placed)
            }
        }

        return path
    }
}

#Preview {
    RouteThumbnailView(
        outline: (0 ..< 40).map { step in
            RouteOutlinePoint(
                latitude: -8.3635 + Double(step) * 0.0006,
                longitude: 115.4612 + sin(Double(step) / 6) * 0.01,
            )
        },
    )
    .padding()
    .background(AppColor.bgBrandPrimary)
    .preferredColorScheme(.light)
}
