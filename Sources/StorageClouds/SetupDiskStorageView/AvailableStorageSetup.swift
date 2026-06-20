//
//  AvailableStorageSetup.swift
//  FamilyFoodDiary
//
//  Created by Татьяна Макеева on 12.01.2026.
//

import Storage
import SwiftUI

public protocol AvailableStorageSetup: Identifiable {
    var id: String { get }
    var name: LocalizedStringKey { get }
    
    var storageBuilder: (StorageResource?) -> FileStorage { get }
    var activator: DiskStorageActivator { get }
}

struct AvailableStorageSetupMock: AvailableStorageSetup {
    let id: String = UUID().uuidString
    let name: LocalizedStringKey = "Storage name"
    let storageBuilder: (StorageResource?) -> FileStorage = { _ in FileStorageMock() }
    let activator: DiskStorageActivator = DiskStorageActivatorMock()
}
