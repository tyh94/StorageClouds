//
//  FileStorageTokenFactory.swift
//  StorageClouds
//
//  Created by Татьяна Макеева on 20.06.2026.
//

import MKVNetwork
import Storage

public enum FileStorageTokenFactoryType {
    case googleDrive
    case yandex
}

public typealias FileStorageTokenFactory = Factory<FileStorageTokenFactoryType, TokenStorage>

public extension FileStorageTokenFactory {
    convenience init(keyStorage: KeyValueStorage) {
        self.init { storage in
            switch storage {
            case .googleDrive:
                return FileStorageTokenService(
                    key: "GoogleDriveTokenKey",
                    storage: keyStorage
                )
            case .yandex:
                return FileStorageTokenService(
                    key: "YandexDiskTokenKey",
                    storage: keyStorage
                )
            }
        }
    }
}
