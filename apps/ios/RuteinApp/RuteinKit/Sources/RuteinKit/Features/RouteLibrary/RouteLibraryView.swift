import SwiftUI

public struct RouteLibraryView: View {
    @State private var viewModel = RouteLibraryViewModel()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            heading
            Spacer(minLength: Spacing.xl)
            illustration
            Spacer(minLength: Spacing.xl)
            actions
        }
        .padding(.top, Spacing.xl6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.background.ignoresSafeArea())
        #if os(iOS)
            .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("library.empty.title", bundle: .module)
                .font(AppFont.display)
                .foregroundStyle(AppColor.textPrimary)

            Text("library.empty.description", bundle: .module)
                .font(AppFont.subheadline)
                .foregroundStyle(AppColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.xl)
    }

    private var illustration: some View {
        Image("libraryEmpty", bundle: .module)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: 284)
            .accessibilityHidden(true)
    }

    private var actions: some View {
        VStack(spacing: Spacing.md) {
            Button {} label: {
                Text("library.import.action", bundle: .module)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .tint(AppColor.textPrimary)

            Text("library.privacy.footnote", bundle: .module)
                .font(AppFont.footnote)
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Spacing.xl4)
    }
}

#Preview {
    NavigationStack {
        RouteLibraryView()
    }
}
