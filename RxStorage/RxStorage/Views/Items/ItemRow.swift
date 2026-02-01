//
//  ItemRow.swift
//  RxStorage
//
//  Created by Qiwei Li on 1/29/26.
//
import RxStorageCore
import SwiftUI

struct ItemRow: View {
    let item: StorageItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(.headline)

            if let description = item.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        ItemRow(item: .init(id: 1, title: "Hi", description: nil, categoryId: 1, locationId: 1, authorId: 1, parentId: 1, price: 1, visibility: .public, images: [], createdAt: .now, updatedAt: .now, previewUrl: ""))
    }
}
