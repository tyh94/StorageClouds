//
//  FileStorageMigrator.swift
//  Storage
//
//  Created by Татьяна Макеева on 19.03.2026.
//

import Foundation
import Storage

public protocol FileStorageMigrator {
    func migrate(
        from fromStorage: FileStorage,
        to toStorage: FileStorage,
        in destinationFolder: StorageResource?
    ) async throws
}
