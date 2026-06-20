//
//  AvailableStorageSetupViewModel.swift
//  FamilyFoodDiary
//
//  Created by Татьяна Макеева on 13.01.2026.
//

import Storage
import SwiftUI

@MainActor
@Observable
public final class AvailableStorageSetupViewModel {
    public let storages: [any AvailableStorageSetup]
    public let completion: (StorageResource, DiskStorageActivatorType) -> Void
    
    public init(
        storages: [any AvailableStorageSetup],
        completion: @escaping (StorageResource, DiskStorageActivatorType) -> Void
    ) {
        self.storages = storages
        self.completion = completion
    }
    
    public func complete(resource: StorageResource, storage: DiskStorageActivatorType) {
        completion(resource, storage)
    }
}
