//
//  DiskStorageActivator.swift
//  Storage
//
//  Created by Татьяна Макеева on 03.03.2025.
//

import Foundation

public protocol DiskStorageActivator: Sendable {
    var startPath: String { get }
    var type: DiskStorageActivatorType { get }
    
    func activate() throws
    @MainActor func authorizeAndSaveToken() async throws
    @discardableResult
    func handleURL(_ url: URL) -> Bool
}

public enum DiskStorageActivatorError: LocalizedError {
    case authCanceled(Error)

    public var errorDescription: String? {
        switch self {
        case .authCanceled(let reason):
            return "Authorization was cancelled. Reason: \(reason.localizedDescription)"
        }
    }
}
