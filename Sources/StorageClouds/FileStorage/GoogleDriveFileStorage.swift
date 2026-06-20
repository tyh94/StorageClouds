//
//  GoogleDriveFileStorage.swift
//  Storage
//
//  Created by Татьяна Макеева on 11.07.2025.
//

import Foundation
import GoogleSignIn
import GTMSessionFetcherCore
import MKVNetwork
import Storage

final class GoogleDriveFileStorage: FileStorage, @unchecked Sendable {
    enum StorageError: LocalizedError {
        case notAuthorized
        case invalidPath
        case fileNotFound(String)
        case uploadFailed
        case fileAlreadyExists(name: String)
        
        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Not authorized to access Google Drive."
            case .invalidPath:
                return "Invalid file path."
            case let .fileNotFound(file):
                return "File \(file) not found on Google Drive."
            case .uploadFailed:
                return "Failed to upload file to Google Drive."
            case .fileAlreadyExists(let name):
                return "File named \(name) already exists."
            }
        }
    }
    
    private let rootPath: String
    private let logger: Logger?
    private let network: NetworkManaging
    
    private let baseURL = URL(string: "https://www.googleapis.com/drive/v3")!
    private let uploadURL = URL(string: "https://www.googleapis.com/upload/drive/v3/files")!
    
    init(
        rootPath: String,
        network: NetworkManaging,
        logger: Logger? = nil
    ) {
        self.rootPath = rootPath
        self.logger = logger
        self.network = network
    }
    
    func resource(
        fileName: String,
        at resource: StorageResource?
    ) async throws -> StorageResource {
        let folderId = folderId(at: resource)
        return try await findFileResource(name: fileName, inFolder: folderId)
    }
    
    func resource(
        folderName: String,
        at resource: StorageResource?
    ) async throws -> StorageResource {
        let folderId = folderId(at: resource)
        guard let folder = try await findFolder(name: folderName, in: folderId) else {
            throw StorageError.fileNotFound(folderName)
        }
        
        return StorageResource(
            id: folder.id,
            name: folderName,
            path: folderName,
            type: .dir,
            modified: folder.modifiedTime ?? Date.distantPast
        )
    }
    
    func data(for resource: StorageResource) async throws -> Data {
        try await data(fileId: resource.id)
    }
    
    private func data(fileId: String) async throws -> Data {
        logger?.logGoogle("Loading data for fileName: \(fileId)", level: .debug)
        let url = baseURL.appendingPathComponent("files/\(fileId)")
        let parameters: Request.Query<String> = ["alt": "media"]
        
        return try await network.dataRequest(
            url: url,
            method: .get,
            parameters: .query(parameters)
        )
    }
    
    func getFolder(at folderName: String) async throws -> StorageResource {
        let query = "'\(rootPath)' in parents and name = '\(folderName)' and mimeType = 'application/vnd.google-apps.folder' and trashed = false"
        let parameters: Request.Query<String> = [
            "pageSize": "1",
            "q": query,
        ]
        let url = baseURL.appendingPathComponent("files")
        let response: GoogleDriveFileList = try await network.dataRequest(
            url: url,
            method: .get,
            parameters: .query(parameters)
        )
        guard let file = response.files.first else {
            throw StorageError.fileNotFound(folderName)
        }
        return convertToStorageResource(file, parent: nil)
    }
    
    func getResources(
        at resource: StorageResource?,
        limit: Int,
        offsetToken: String?
    ) async throws -> (resources: [StorageResource], nextOffsetToken: String?)  {
        logger?.logGoogle("Fetching resources at: \(String(describing: resource)), limit: \(limit), offset: \(offsetToken ?? "empty")", level: .debug)

        let url = baseURL.appendingPathComponent("files")
        
        let query: String
        
        if let resource = resource, !resource.path.isEmpty {
            // Запрос для конкретной папки
            query = "'\(resource.id)' in parents and trashed = false"
        } else {
            // Корневой запрос - получаем файлы из корня + shared with me
            query = "(('\(rootPath)' in parents) or (sharedWithMe = true)) and trashed = false"
        }
        
        var parameters: Request.Query<String> = [
            "pageSize": "\(limit)",
            "orderBy": "name",
            "q": query,
        ]
        
        if let pageToken = offsetToken, !pageToken.isEmpty {
            parameters["pageToken"] = pageToken
        }
        
        let response: GoogleDriveFileList = try await network.dataRequest(
            url: url,
            method: .get,
            parameters: .query(parameters)
        )
        
        let resources = response.files.map { file in
            convertToStorageResource(file, parent: resource)
        }
        
        return (resources, response.nextPageToken)
    }
    
    private func convertToStorageResource(_ file: GoogleDriveFile, parent: StorageResource?) -> StorageResource {
        let type: StorageResource.ItemType
        
        switch file.mimeType {
        case "application/vnd.google-apps.folder":
            type = .dir
            
        case let mime where mime.hasPrefix("application/vnd.google-apps.") == true:
            // Обработка Google Docs
            let exportLink = file.exportLinks?["application/pdf"]
            ?? "https://docs.google.com/document/d/\(file.id)/edit"
            type = .file(url: exportLink, previewURL: nil)
            
        default:
            let downloadURL = file.webContentLink
            ?? "https://drive.google.com/file/d/\(file.id)/view"
            type = .file(url: downloadURL, previewURL: nil)
        }
        let path = [parent?.path, file.name].compactMap { $0 }.joined(separator: "/")
        
        let modifiedDate = file.modifiedTime ?? Date.distantPast
        
        return StorageResource(
            id: file.id,
            name: file.name,
            path: path,
            type: type,
            modified: modifiedDate
        )
    }
    
    func createFolder(at resource: StorageResource?, folderName: String) async throws -> StorageResource {
        logger?.logGoogle("Creating folder at: \(resource?.path ?? "root") folderName: \(folderName)", level: .info)
   
        let folderId: String
        if let resource = resource, !resource.path.isEmpty {
            folderId = resource.id
        } else {
            folderId = rootPath
        }
        let url = baseURL.appendingPathComponent("files")
        let parameters: Request.Query<String> = [
            "name": folderName,
            "mimeType": "application/vnd.google-apps.folder",
            "parents": [folderId]
        ]
        
        let file: GoogleDriveFile = try await network.dataRequest(
            url: url,
            method: .post,
            headers: [.contentTypeJSON],
            parameters: .body(parameters)
        )
        return convertToStorageResource(file, parent: resource)
    }
    
    private func folderId(at resource: StorageResource?) -> String {
        if let resource = resource, !resource.path.isEmpty {
            return resource.id
        } else {
            return rootPath
        }
    }
    
    func createFile(at resource: StorageResource?, fileName: String, with data: Data?) async throws -> StorageResource {
        logger?.logGoogle("Creating file at: \(resource?.path ?? "root") fileName: \(fileName)", level: .info)
        
        let folderId = folderId(at: resource)
        if let _ = try? await findFileResource(name: fileName, inFolder: folderId) {
            throw StorageError.fileAlreadyExists(name: fileName)
        }
        let metadata: [String: Any] = [
            "name": fileName,
            "parents": [folderId]
        ]
        let boundary = "----WebKitFormBoundary\(UUID().uuidString)"
        var body = Data()

        // Часть 1: JSON метаданные
        body.append("--\(boundary)\r\n")
        body.append("Content-Type: application/json; charset=UTF-8\r\n\r\n")
        body.append(try JSONSerialization.data(withJSONObject: metadata))
        body.append("\r\n")
        
        // Часть 2: Файл
        if let fileData = data {
            body.append("--\(boundary)\r\n")
            body.append("Content-Type: application/octet-stream\r\n\r\n")
            body.append(fileData)
            body.append("\r\n")
        }
        
        body.append("--\(boundary)--\r\n")
        
        // URL multipart загрузки
        let url = URL(string: "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart")!
        
        let file: GoogleDriveFile = try await network.uploadRequest(
            data: body,
            url: url,
            method: .post,
            headers: [
                .contentType("multipart/related; boundary=\(boundary)")
            ]
        )
        
        return convertToStorageResource(file, parent: resource)
    }
    
    func updateFile(at resource: StorageResource, with data: Data) async throws {
        logger?.logGoogle("Updating file at: \(resource.path)", level: .info)
        
        let fileId = resource.id
        let url = URL(string: "https://www.googleapis.com/upload/drive/v3/files/\(fileId)?uploadType=media")!
        
        // Заголовок Content-Type можно задать, например, application/octet-stream,
        // или если знаешь точный тип, передать его
        let headers: [HTTPHeader] = [
            .contentType("application/octet-stream")
        ]
        
        // Используем uploadRequest, который возвращает Data, но тут результат можно проигнорировать
        _ = try await network.uploadRequest(
            data: data,
            url: url,
            method: .patch,
            headers: headers,
            parameters: nil
        )
        
        logger?.logGoogle("File \(fileId) updated successfully", level: .info)
    }
    
    func renameFile(at resource: StorageResource, with filename: String) async throws {
        let fileId = resource.id
        
        let url = baseURL.appendingPathComponent("files/\(fileId)")
        
        let body = [
            "name": filename
        ]
        
        do {
            let _: GoogleDriveFile = try await network.dataRequest(
                url: url,
                method: .patch,
                parameters: .body(body)
            )
            logger?.logGoogle("Successfully renamed file from \(resource.name) to \(filename)", level: .debug)
        } catch {
            logger?.logGoogle("Failed to rename file from \(resource.name) to \(filename): \(error.localizedDescription)", level: .error)
            throw error
        }
    }
    
    func renameFolder(at resource: StorageResource, with filename: String) async throws {
        logger?.logGoogle("Renaming folder from: \(resource.name) to: \(filename)", level: .info)
        
        let folderId = resource.id
        
        let url = baseURL.appendingPathComponent("files/\(folderId)")
        
        let body = [
            "name": filename
        ]
        
        do {
            let _: GoogleDriveFile = try await network.dataRequest(
                url: url,
                method: .patch,
                parameters: .body(body)
            )
            logger?.logGoogle("Successfully renamed folder from \(resource.name) to \(filename)", level: .debug)
        } catch {
            logger?.logGoogle("Failed to rename folder from \(resource.name) to \(filename): \(error.localizedDescription)", level: .error)
            throw error
        }
    }
    
    func moveFile(from pathFrom: String, to pathTo: String) async throws {
        logger?.logGoogle("Moving file from: \(pathFrom) to: \(pathTo)", level: .info)
        
//        let fileId = try await resolvePath(pathFrom)!
//        let (newParentId, newName) = try await resolveParentAndName(path: pathTo)
//        
//        let url = baseURL.appendingPathComponent("files/\(fileId)")
//        let parameters: Request.Query<String> = [
//            "name": newName,
//            "addParents": newParentId,
//            "removeParents": "root" // Удаляем из корня, можно уточнить
//        ]
//        
//        let _: GoogleDriveFile = try await network.dataRequest(
//            url: url,
//            method: .patch,
//            headers: [.authorization(bearerToken: token), .contentTypeJSON],
//            parameters: .body(parameters))
    }
    
    func delete(at resource: StorageResource) async throws {
        logger?.logGoogle("Deleting item at: \(resource)", level: .info)
        
        let url = baseURL.appendingPathComponent("files/\(resource.id)")
        
        try await network.dataRequest(
            url: url,
            method: .delete
        )
    }
    
    func deleteAll() async throws {
        logger?.logGoogle("Performing full cleanup", level: .info)
    }
    
    // MARK: - Private methods
    
    private func resolvePath(_ path: String) async throws -> String? {
        // Обработка корневой папки
        if path.isEmpty || path == "/" {
            return "root"
        }
        
        // Нормализация пути
        let normalizedPath = path
            .replacingOccurrences(of: "//", with: "/")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        // Разбиваем путь на компоненты
        let components = normalizedPath.split(separator: "/").map(String.init)
        var currentFolderId = "root" // Начинаем с корневой папки
        
        for component in components {
            guard let nextId = try await findFolder(
                name: component,
                in: currentFolderId
            )?.id else {
                return nil
            }
            currentFolderId = nextId
        }
        
        return currentFolderId
    }
    
    private func findFileResource(name: String, inFolder folderId: String) async throws -> StorageResource {
        let url = baseURL.appendingPathComponent("files")
        
        let query = """
            '\(folderId)' in parents and \
            name = '\(name)' and \
            mimeType != 'application/vnd.google-apps.folder' and \
            trashed = false
        """
        
        let parameters: Request.Query<String> = [
            "q": query,
            "pageSize": "1",  // Нас интересует только первое совпадение
            "orderBy": "name"
        ]
        
        let response: GoogleDriveFileList = try await network.dataRequest(
            url: url,
            method: .get,
            parameters: .query(parameters)
        )
        
        if let file = response.files.first {
            return convertToStorageResource(file, parent: nil)
        } else {
            throw StorageError.fileNotFound("file \(name) in folder \(folderId)")
        }
    }

    private func findFolder(name: String, in parentId: String) async throws -> GoogleDriveFile? {
        let url = baseURL.appendingPathComponent("files")
        let escapedName = name.replacingOccurrences(of: "'", with: "\\'")
        
        let query = """
            '\(parentId)' in parents and \
            name = '\(escapedName)' and \
            mimeType = 'application/vnd.google-apps.folder' and \
            trashed = false
        """
        
        let parameters: Request.Query<String> = [
            "q": query,
            "pageSize": "1",  // Нас интересует только первое совпадение
            "orderBy": "name"
        ]
        
        let response: GoogleDriveFileList = try await network.dataRequest(
            url: url,
            method: .get,
            parameters: .query(parameters)
        )
        return response.files.first
    }
    
    private func getOrCreateRootFolder() async throws -> String? {
        
        let url = baseURL.appendingPathComponent("files")
        let parameters: Request.Query<String> = [
            "q": "name='\(rootPath)' and mimeType='application/vnd.google-apps.folder' and trashed=false",
            "fields": "files(id)"
        ]
        
        let response: GoogleDriveFileList = try await network.dataRequest(
            url: url,
            method: .get,
            parameters: .query(parameters))
        
        if let folder = response.files.first {
            logger?.logGoogle("Using existing root folder", level: .info)
            return folder.id
        }
        
        return nil
    }
    
    private func findItem(name: String, parentId: String, isDirectory: Bool) async throws -> String {
        let url = baseURL.appendingPathComponent("files")
        
        var q = "name='\(name)' and '\(parentId)' in parents and trashed=false"
        if isDirectory {
            q += " and mimeType='application/vnd.google-apps.folder'"
        }
        
        let parameters: Request.Query<String> = [
            "q": q,
            "fields": "files(id)"
        ]
        
        let response: GoogleDriveFileList = try await network.dataRequest(
            url: url,
            method: .get,
            parameters: .query(parameters))
        
        guard let file = response.files.first else {
            logger?.logGoogle("Item not found: \(name)", level: .error)
            throw StorageError.fileNotFound("file \(name) in parentId \(parentId)")
        }
        
        return file.id
    }
}

// MARK: - Модели данных

private struct GoogleDriveWebContentLink: Codable {
    let webContentLink: String
}

private struct GoogleDriveFile: Codable {
    let id: String
    let name: String
    let mimeType: String
    let modifiedTime: Date?
    let size: String?
    let webContentLink: String?
    // Для Google Docs файлов
    let exportLinks: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case id, name, mimeType, modifiedTime, size, webContentLink, exportLinks
    }
}

private struct GoogleDriveFileList: Codable {
    let files: [GoogleDriveFile]
    let nextPageToken: String?
}

private struct GoogleUploadSession: Codable {
    let uploadURL: URL?
    let method: HTTPMethod
    let fileId: String
}

extension Logger {
    fileprivate func logGoogle(
        _ message: String,
        level: LogLevel,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        log(
            message,
            level: level,
            type: .google,
            file: file,
            function: function,
            line: line
        )
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
