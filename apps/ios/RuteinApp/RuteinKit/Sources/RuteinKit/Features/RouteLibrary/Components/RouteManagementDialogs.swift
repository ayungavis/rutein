import SwiftUI

struct RouteManagementDialogs: ViewModifier {
    let viewModel: RouteLibraryViewModel

    @Binding var renameText: String

    func body(content: Content) -> some View {
        content
            .alert(
                Text("library.rename.title", bundle: .module),
                isPresented: .constant(viewModel.renaming != nil),
            ) {
                renameActions
            }
            .alert(
                Text("library.duplicate.title", bundle: .module),
                isPresented: .constant(viewModel.duplicate != nil),
                presenting: viewModel.duplicate,
            ) { _ in
                duplicateActions
            } message: { duplicate in
                Text("library.duplicate.message \(duplicate.existing.name)", bundle: .module)
            }
            .confirmationDialog(
                Text("library.delete.title", bundle: .module),
                isPresented: .constant(viewModel.deleting != nil),
                titleVisibility: .visible,
                presenting: viewModel.deleting,
            ) { _ in
                deleteActions
            } message: { target in
                Text("library.delete.message \(target.name)", bundle: .module)
            }
    }

    @ViewBuilder
    private var renameActions: some View {
        TextField(
            String(localized: "library.rename.field", bundle: .module),
            text: $renameText,
        )

        Button {
            viewModel.renaming = nil
        } label: {
            Text("common.cancel", bundle: .module)
        }

        Button {
            let name = renameText

            Task { await viewModel.commitRename(name) }
        } label: {
            Text("library.rename.confirm", bundle: .module)
        }
    }

    @ViewBuilder
    private var duplicateActions: some View {
        Button {
            Task { await viewModel.openDuplicateOriginal() }
        } label: {
            Text("library.duplicate.open", bundle: .module)
        }

        Button {
            viewModel.importDuplicateCopy()
        } label: {
            Text("library.duplicate.copy", bundle: .module)
        }
    }

    @ViewBuilder
    private var deleteActions: some View {
        Button(role: .destructive) {
            Task { await viewModel.confirmDelete() }
        } label: {
            Text("library.delete.action", bundle: .module)
        }

        Button(role: .cancel) {
            viewModel.deleting = nil
        } label: {
            Text("common.cancel", bundle: .module)
        }
    }
}
