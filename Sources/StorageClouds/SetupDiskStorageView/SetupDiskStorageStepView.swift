//
//  SetupDiskStorageStepView.swift
//  FamilyFoodDiary
//
//  Created by Татьяна Макеева on 11.01.2026.
//

import Observation
import Storage
import SwiftUI

struct SetupDiskStorageView: View {
    @State var viewModel: SetupDiskStorageViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var paths = [SetupDiskStorageViewModel.Step]()
    @ViewBuilder
    var content: some View {
        switch viewModel.status {
        case .loaded:
            NavigationStack(path: $viewModel.path) {
                VStack {
                    ProgressView()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationDestination(for: SetupDiskStorageViewModel.Step.self) { step in
                    FolderStepView(viewModel: viewModel, step: step)
                }
            }
        case .loading, .idle:
            VStack {
                ProgressView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case let .error(error):
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
                
                Text("Something went wrong", bundle: .module)
                    .font(.headline)
                
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                HStack(spacing: 16) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Close", bundle: .module)
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        Task {
                            await viewModel.onAppear()
                        }
                    } label: {
                        Text("Retry", bundle: .module)
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }
    }
    
    var body: some View {
        content
            .task {
                await viewModel.onAppear()
            }
            .onAppear {
                viewModel.onAuthorizationCancelled = {
                    dismiss()
                }
            }
    }
}

import MKVNetwork

#Preview {
    SetupDiskStorageView(
        viewModel: SetupDiskStorageViewModel(
            storageName: "Test",
            diskActivator: DiskStorageActivatorMock(),
            fileStorageBuilder: { _ in FileStorageMock() },
            folderChosen: { _ in
                
            }
        )
    )
}
