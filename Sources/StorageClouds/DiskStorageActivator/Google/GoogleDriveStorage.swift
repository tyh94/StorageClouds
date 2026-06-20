//
//  GoogleDriveStorage.swift
//  Storage
//
//  Created by Татьяна Макеева on 11.07.2025.
//

import GoogleSignIn
import MKVNetwork
import Storage
import UIKit

final class GoogleDriveStorage: DiskStorageActivator {
    enum StorageError: LocalizedError {
        case notAuthorized
        case invalidRootViewController
        case tokenRetrievalFailed
        
        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Access not authorized"
            case .invalidRootViewController:
                return "Invalid root view controller"
            case .tokenRetrievalFailed:
                return "Failed to retrieve authentication token"
            }
        }
    }
    
    let type: DiskStorageActivatorType
    let startPath: String = "root"
    
    private let clientID: String
    private let scopes: [String]
    private let tokenStorage: TokenStorage
    private let logger: Storage.Logger?
    
    @MainActor private var authorizationContinuation: CheckedContinuation<String, Error>?
    
    init(
        type: DiskStorageActivatorType,
        clientID: String,
        tokenStorage: TokenStorage,
        scopes: [String] = ["https://www.googleapis.com/auth/drive"],
        logger: Storage.Logger? = nil
    ) {
        self.type = type
        self.clientID = clientID
        self.scopes = scopes
        self.tokenStorage = tokenStorage
        self.logger = logger
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
    }
    
    func activate() throws {
        // Конфигурация уже выполнена в init
    }
    
    @MainActor func authorizeAndSaveToken() async throws {
        if let currentUser = GIDSignIn.sharedInstance.currentUser {
            let token = currentUser.accessToken.tokenString
            try tokenStorage.saveToken(token)
            return
        }

        guard let rootVC = await getRootViewController() else {
            throw StorageError.invalidRootViewController
        }

        let token = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            GIDSignIn.sharedInstance.signIn(
                withPresenting: rootVC,
                hint: nil,
                additionalScopes: scopes
            ) { result, error in
                let token = result?.user.accessToken.tokenString
                
                if let error = error as NSError? {
                    if error.code == -5 {
                        continuation.resume(
                            throwing: DiskStorageActivatorError.authCanceled(
                                error.localizedDescription
                            )
                        )
                    } else {
                        continuation.resume(throwing: error)
                    }
                    return
                }
                
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let token else {
                    continuation.resume(throwing: StorageError.notAuthorized)
                    return
                }
                continuation.resume(returning: token)
            }
        }

        try tokenStorage.saveToken(token)
    }

    
    func logout() {
        GIDSignIn.sharedInstance.signOut()
    }
    
    func handleURL(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
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
