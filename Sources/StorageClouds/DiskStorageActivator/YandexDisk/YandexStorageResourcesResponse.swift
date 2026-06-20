//
//  YandexStorageResourcesResponse.swift
//  Storage
//
//  Created by Татьяна Макеева on 04.03.2025.
//

import Foundation

struct YandexStorageResourcesResponse: Codable {
    struct Embedded: Codable {
        struct Item: Codable {
            enum ItemType: String, Codable {
                case dir
                case file
            }
            let name: String
            let path: String
            let type: ItemType
            let created: String
            let modified: String
            
            let file: String?
            let preview: String?
        }
        
        let items: [Item]
        let total: Int
    }
    
    enum CodingKeys: String, CodingKey {
        case embedded = "_embedded"
        case path, created, modified
    }
    
    let embedded: Embedded
    let path: String
    let created: String
    let modified: String
}
