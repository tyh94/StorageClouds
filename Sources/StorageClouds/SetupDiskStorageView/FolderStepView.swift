//
//  FolderStepView.swift
//  FamilyFoodDiary
//
//  Created by Татьяна Макеева on 12.01.2026.
//

import Storage
import SwiftUI

struct FolderStepView: View {
    @Bindable var viewModel: SetupDiskStorageViewModel
    let step: SetupDiskStorageViewModel.Step
    @State private var showingAlertAddFolder = false
    @Environment(\.dismiss) private var dismiss
    @State private var folderName = ""
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    var filteredResources: [StorageResource] {
        if searchText.isEmpty {
            return step.resources
        } else {
            return step.resources.filter { resource in
                resource.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredResources) { resource in
                ResourceRow(resource: resource, isSelectable: true) {
                    Task {
                        await viewModel.loadFolder(resource)
                    }
                }
                .onAppear {
                    if resource == filteredResources.last,
                       step.nextOffsetToken != nil {
                        Task {
                            await viewModel.loadNextPage(for: step.current)
                        }
                    }
                }
            }
            
            if step.isLoadingNext {
                ProgressView()
                    .frame(maxWidth: .infinity)
            }
        }
        .listStyle(.plain)
        .navigationBarBackButtonHidden()
        .navigationTitle((step.current?.name ?? "").isEmpty ? Text(viewModel.storageName) : Text(step.current?.name ?? ""))
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text("Search", bundle: .module)
        )
        .focused($isSearchFocused)
        .onSubmit(of: .search) {
            isSearchFocused = false
        }
        .toolbar {
            if viewModel.path.count > 1 {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        isSearchFocused = false
                        searchText = ""
                        viewModel.goBack()
                    } label: {
                        HStack {
                            Image(systemName: "chevron.backward")
                            Text("Back", bundle: .module)
                        }
                    }
                }
            }
            
            if case .loaded = viewModel.status {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isSearchFocused = false
                        showingAlertAddFolder = true
                    } label: {
                        Label {
                            Text("Add folder", bundle: .module)
                        } icon: {
                            Image(systemName: "folder.badge.plus")
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            isSearchFocused = false
                            await viewModel.saveCurrentFolder()
                        }
                    } label: {
                        Text("Select", bundle: .module)
                    }
                }
            }
        }
        .alert(Text("Enter folder name", bundle: .module), isPresented: $showingAlertAddFolder) {
            TextField(String(localized: "Enter folder name", bundle: .module), text: $folderName)
            Button(String(localized: "Cancel", bundle: .module), action: { showingAlertAddFolder = false })
            Button(String(localized: "Add", bundle: .module), action: createFolder).disabled(folderName.isEmpty)
        }
    }
    
    private func createFolder() {
        Task {
            await viewModel.createFolder(folderName)
            folderName = ""
            showingAlertAddFolder = false
        }
    }
}

import MKVNetwork

#Preview {
    NavigationStack {
        FolderStepView(
            viewModel: SetupDiskStorageViewModel(
                storageName: "Test",
                diskActivator: DiskStorageActivatorMock(),
                fileStorageBuilder: { _ in FileStorageMock() },
                folderChosen: { _ in
                    
                }
            ),
            step: SetupDiskStorageViewModel.Step(
                resources: [.preview(), .preview()],
                current: StorageResource.preview()
            )
        )
    }
}
