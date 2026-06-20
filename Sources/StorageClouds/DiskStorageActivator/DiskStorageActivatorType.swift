//
//  DiskStorageActivatorType.swift
//  Storage
//
//  Created by Татьяна Макеева on 03.03.2025.
//

import Foundation

public enum DiskStorageActivatorType: Codable, Equatable, Sendable {
    case yandexDisk(clientID: String)
    case googleDrive(clientID: String)
}
