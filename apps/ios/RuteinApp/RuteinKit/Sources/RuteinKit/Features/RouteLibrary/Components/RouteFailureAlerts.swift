import SwiftUI

struct RouteFailureAlerts: ViewModifier {
    let viewModel: RouteLibraryViewModel

    func body(content: Content) -> some View {
        content
            .alert(
                Text("import.failed.title", bundle: .module),
                isPresented: .constant(viewModel.importFailure != nil),
            ) {
                dismissButton
            } message: {
                if let failure = viewModel.importFailure {
                    Text(failure, bundle: .module)
                }
            }
            .alert(
                Text("library.open.title", bundle: .module),
                isPresented: .constant(viewModel.openFailure != nil),
            ) {
                dismissButton
            } message: {
                if let failure = viewModel.openFailure {
                    Text(failure, bundle: .module)
                }
            }
            .alert(
                Text("library.rename.title", bundle: .module),
                isPresented: .constant(viewModel.renameFailure != nil),
            ) {
                dismissButton
            } message: {
                if let failure = viewModel.renameFailure {
                    Text(failure, bundle: .module)
                }
            }
    }

    private var dismissButton: some View {
        Button {
            viewModel.dismissFailure()
        } label: {
            Text("import.failed.dismiss", bundle: .module)
        }
    }
}
