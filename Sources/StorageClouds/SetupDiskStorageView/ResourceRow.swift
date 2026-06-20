//
//  ResourceRow.swift
//  FamilyFoodDiary
//
//  Created by Татьяна Макеева on 12.01.2026.
//

import Storage
import SwiftUI

struct ResourceRow: View {
    let resource: StorageResource
    let isSelectable: Bool
    let onTap: (() -> Void)?
    
    var body: some View {
        HStack {
            Image(systemName: resource.isFile ? "doc" : "folder")
            
            Text(resource.name)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            if !resource.isFile {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !resource.isFile {
                onTap?()
            }
        }
    }
}
