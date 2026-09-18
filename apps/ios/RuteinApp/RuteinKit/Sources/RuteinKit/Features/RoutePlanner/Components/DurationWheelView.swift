import SwiftUI

public struct DurationWheelView: View {
    @Binding private var hours: Int
    @Binding private var minutes: Int

    public init(hours: Binding<Int>, minutes: Binding<Int>) {
        _hours = hours
        _minutes = minutes
    }

    public var body: some View {
        HStack(spacing: 0) {
            wheel(
                selection: $hours,
                range: 0 ... 48,
                unit: Text("plan.unit.hours", bundle: .module),
            )

            wheel(
                selection: $minutes,
                range: 0 ... 59,
                unit: Text("plan.unit.minutes", bundle: .module),
            )
        }
        .frame(height: 160)
        .background(AppColor.textPrimary.opacity(0.06))
        .clipShape(.rect(cornerRadius: Radius.xl))
    }

    private func wheel(selection: Binding<Int>, range: ClosedRange<Int>, unit: Text) -> some View {
        HStack(spacing: Spacing.xs) {
            Picker(selection: selection) {
                ForEach(Array(range), id: \.self) { value in
                    Text(value, format: .number.precision(.integerLength(2)))
                        .font(AppFont.headline)
                        .foregroundStyle(AppColor.textPrimary)
                }
            } label: {
                unit
            }
            .labelsHidden()
            #if os(iOS)
                .pickerStyle(.wheel)
            #endif

            unit
                .font(AppFont.subheadlineStrong)
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    @Previewable @State var hours = 5
    @Previewable @State var minutes = 0

    return DurationWheelView(hours: $hours, minutes: $minutes)
        .padding()
        .background(AppColor.bgBrandPrimary)
        .preferredColorScheme(.light)
}
