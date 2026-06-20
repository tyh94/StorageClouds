//
//  YandexDiskStorage.swift
//  Storage
//
//  Created by Татьяна Макеева on 03.03.2025.
//

import Foundation
import SwiftUI
import YandexLoginSDK
import MKVNetwork
import Storage

final class YandexDiskStorage: DiskStorageActivator {
    enum Error: LocalizedError {
        case invalidRootViewController
        
        var errorDescription: String? {
            switch self {
            case .invalidRootViewController:
                return "Invalid root view controller"
            }
        }
    }
    let startPath: String = "/"
    
    let type: DiskStorageActivatorType
    
    private let clientID: String
    private let logger: Storage.Logger?
    private let tokenStorage: TokenStorage
    
    @MainActor private var authorizationContinuation: CheckedContinuation<String, Swift.Error>?
    
    init(
        type: DiskStorageActivatorType,
        clientID: String,
        tokenStorage: TokenStorage,
        logger: Storage.Logger? = nil
    ) {
        self.type = type
        self.clientID = clientID
        self.logger = logger
        self.tokenStorage = tokenStorage
        YandexLoginSDK.shared.add(observer: self)
    }
    
    func activate() throws {
        try YandexLoginSDK.shared.activate(with: clientID)
    }
    
    @MainActor func authorizeAndSaveToken() async throws {
        guard let rootViewController = await getRootViewController() else {
            throw Error.invalidRootViewController
        }
        
        let token = try await withCheckedThrowingContinuation { continuation in
            self.authorizationContinuation = continuation
            do {
                try activate()
                try YandexLoginSDK.shared.authorize(
                    with: rootViewController,
                    customValues: nil,
                    authorizationStrategy: .webOnly
                )
            } catch {
                continuation.resume(throwing: error)
            }
        }
        try tokenStorage.saveToken(token)
    }
    
    func handleURL(_ url: URL) -> Bool {
        do {
            try YandexLoginSDK.shared.handleOpenURL(url)
            return true
        } catch {
            logger?.error("Handler URL failed: \(error.localizedDescription)", type: .yandex)
            return false
        }
    }
}

extension YandexDiskStorage: YandexLoginSDKObserver {
    func didFinishLogin(with result: Result<LoginResult, Swift.Error>) {
        switch result {
        case let .success(loginResult):
            let token = loginResult.token
            DispatchQueue.main.async {
                self.authorizationContinuation?.resume(returning: token)
                self.authorizationContinuation = nil
            }
        case let .failure(error):
            DispatchQueue.main.async {
                self.authorizationContinuation?.resume(throwing: DiskStorageActivatorError.authCanceled(error))
                self.authorizationContinuation = nil
            }
        }
    }
    
    @MainActor
    private func getRootViewController() async -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return nil
        }
        return rootViewController
    }
}
