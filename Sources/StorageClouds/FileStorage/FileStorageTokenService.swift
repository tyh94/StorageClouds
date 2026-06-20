//
//  FileStorageTokenService.swift
//  Storage
//
//  Created by Татьяна Макеева on 11.07.2025.
//

import MKVNetwork
import Storage

public struct FileStorageTokenService: TokenStorage {
    private let key: String
    private let storage: KeyValueStorage
    
    public init(key: String, storage: KeyValueStorage) {
        self.key = key
        self.storage = storage
    }
    
    public func getToken() -> String? {
        try? storage.object(forKey: key)
    }
    
    public func saveToken(_ token: String) throws {
        try storage.set(token, forKey: key)
    }
    
    public func removeToken() throws {
        try storage.removeObject(forKey: key)
    }
}
