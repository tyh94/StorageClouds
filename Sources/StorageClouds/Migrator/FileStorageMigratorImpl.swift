//
//  FileStorageMigratorImpl.swift
//  FamilyBook
//
//  Created by Татьяна Макеева on 20.03.2026.
//

import Foundation
import Storage

public final class FileStorageMigratorImpl: FileStorageMigrator {
    private indirect enum Error: LocalizedError {
        case fileMigrationFailed(String, Swift.Error)
    }
    
    private let logger: Logger?
    private let batchSize = 50
    
    public init(logger: Logger?) {
        self.logger = logger
    }
    
    public func migrate(
        from fromStorage: FileStorage,
        to toStorage: FileStorage,
        in destinationFolder: StorageResource?
    ) async throws {
        var offsetToken: String? = nil
        var hasMore = true
        
        while hasMore {
            let (resources, nextToken) = try await fromStorage.getResources(
                at: nil,
                limit: batchSize,
                offsetToken: offsetToken
            )
            
            for item in resources {
                try await copyItem(
                    item: item,
                    from: fromStorage,
                    to: toStorage,
                    toFolder: destinationFolder
                )
            }
            
            offsetToken = nextToken
            hasMore = nextToken != nil
        }
    }
    
    private func copyItem(
        item: StorageResource,
        from fromStorage: FileStorage,
        to toStorage: FileStorage,
        toFolder: StorageResource?
    ) async throws {
        switch item.type {
        case .dir:
            let newFolder = try await toStorage.createFolder(
                at: toFolder,
                folderName: item.name
            )
            
            var offsetToken: String? = nil
            var hasMore = true
            
            while hasMore {
                let (contents, nextToken) = try await fromStorage.getResources(
                    at: item,
                    limit: batchSize,
                    offsetToken: offsetToken
                )
                
                for contentItem in contents {
                    try await copyItem(
                        item: contentItem,
                        from: fromStorage,
                        to: toStorage,
                        toFolder: newFolder
                    )
                }
                
                offsetToken = nextToken
                hasMore = nextToken != nil
            }
            
        case .file:
            try await copyFile(
                item,
                from: fromStorage,
                to: toStorage,
                toFolder: toFolder
            )
        }
    }
    
    private func copyFile(
        _ file: StorageResource,
        from fromStorage: FileStorage,
        to toStorage: FileStorage,
        toFolder: StorageResource?
    ) async throws {
        do {
            let fileData = try await fromStorage.data(for: file)
            
            _ = try await toStorage.createFile(
                at: toFolder,
                fileName: file.name,
                with: fileData
            )
            
            logger?.debug("✅ Файл перенесен: \(file.name)", type: .migrate)
        } catch {
            logger?.error("❌ Ошибка переноса файла \(file.name): \(error)", type: .migrate)
            throw Error.fileMigrationFailed(file.name, error)
        }
    }
}
