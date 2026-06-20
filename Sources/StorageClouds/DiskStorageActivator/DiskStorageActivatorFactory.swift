//
//  DiskStorageActivatorFactory.swift
//  Storage
//
//  Created by Татьяна Макеева on 14.05.2025.
//

import Foundation
import MKVNetwork
import Storage

public enum DiskStorageActivatorFactory {
    public static func build(
        _ type: DiskStorageActivatorType,
        tokenStorage: TokenStorage,
        logger: Storage.Logger? = nil
    ) -> DiskStorageActivator {
        switch type {
        case let .yandexDisk(clientID):
            return YandexDiskStorage(
                type: type,
                clientID: clientID,
                tokenStorage: tokenStorage,
                logger: logger
            )
        case let .googleDrive(clientID):
            return GoogleDriveStorage(
                type: type,
                clientID: clientID,
                tokenStorage: tokenStorage,
                logger: logger
            )
        }
    }
}
