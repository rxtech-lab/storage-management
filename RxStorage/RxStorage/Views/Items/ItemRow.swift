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
                .accessibilityIdentifier("item-row")

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

// Preview disabled - generated types have different initializers
// TODO: Update preview to use generated StorageItem type
