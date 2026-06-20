//
//  GoogleTokenRefresher.swift
//  Storage
//
//  Created by Татьяна Макеева on 16.07.2025.
//

import Foundation
import MKVNetwork
import GoogleSignIn
import Storage

final class GoogleSDKTokenRefresher: TokenRefreshHandler {
    enum Error: Swift.Error {
        case notAuthorized
    }

    private let tokenStorage: TokenStorage

    init(tokenStorage: TokenStorage) {
        self.tokenStorage = tokenStorage
    }

    func refreshToken() async throws -> String {
        // Если текущий пользователь есть — пробуем обновить токен
        if let user = GIDSignIn.sharedInstance.currentUser {
            return try await refreshAndSave(user: user)
        }

        // Попытка восстановить предыдущий вход
        let newToken: String = try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let token = user?.accessToken.tokenString {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: Error.notAuthorized)
                }
            }
        }
        try tokenStorage.saveToken(newToken)
        return newToken
    }

    private func refreshAndSave(user: GIDGoogleUser) async throws -> String {
        let newToken: String = try await withCheckedThrowingContinuation { continuation in
            user.refreshTokensIfNeeded { updatedUser, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let token = updatedUser?.accessToken.tokenString {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: Error.notAuthorized)
                }
            }
        }

        try tokenStorage.saveToken(newToken)
        return newToken
    }
}
