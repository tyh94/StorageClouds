//
//  DiskStorageActivatorMock.swift
//  Storage
//
//  Created by Татьяна Макеева on 24.04.2025.
//

import Foundation

public struct DiskStorageActivatorMock: DiskStorageActivator {
    public var type: DiskStorageActivatorType = .yandexDisk(clientID: "")
    
    public var startPath: String = ""
    
    public init() {}
    
    public func authorizeAndSaveToken() async throws {
        try await Task.sleep(for: .seconds(2))
        throw NSError(domain: "", code: 0)
    }
    
    public func handleURL(_ url: URL) -> Bool {
        true
    }
    
    public func activate() throws {
        throw NSError(domain: "", code: 0)
    }
}
