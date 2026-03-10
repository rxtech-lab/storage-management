//
//  EntityItemsCard.swift
//  RxStorage
//
//  Card component showing a list of items belonging to an entity
//

import RxStorageCore
import SwiftUI

/// Card showing items that belong to an entity (author, category, location)
struct EntityItemsCard: View {
    let items: [StorageItem]
    let totalItems: Int
    let onSeeAll: () -> Void
    var onItemTapped: ((StorageItem) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                onSeeAll()
            } label: {
                HStack {
                    Label("Items", systemImage: "shippingbox")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    if totalItems > 0 {
                        Text("\(totalItems)")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    if totalItems > items.count {
                        Text("See All")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()
                .padding(.leading, 16)

            if items.isEmpty {
                Text("No items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if let onItemTapped {
                        Button {
                            onItemTapped(item)
                        } label: {
                            ItemRow(item: item)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    } else {
                        NavigationLink(value: item) {
                            ItemRow(item: item)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }

                    if index < items.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
        }
        .background(Color.secondarySystemGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
