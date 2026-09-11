//
//  FavoriteGroupSheetView.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 4（Router が組み立てるシート。Phase 5 で FavoriteGroup モジュールへ移す）
//

import SwiftUI

struct FavoriteGroupSheetView: View {
    let groups: [FavoriteGroupSnapshot]
    let onSelect: (FavoriteGroupID) -> Void
    let onDelete: (IndexSet) -> Void
    let onClose: () -> Void

    @State private var displayedGroups: [FavoriteGroupSnapshot]

    init(
        groups: [FavoriteGroupSnapshot],
        onSelect: @escaping (FavoriteGroupID) -> Void,
        onDelete: @escaping (IndexSet) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.groups = groups
        self.onSelect = onSelect
        self.onDelete = onDelete
        self.onClose = onClose
        _displayedGroups = State(initialValue: groups)
    }

    var body: some View {
        NavigationStack {
            Group {
                List {
                    if displayedGroups.isEmpty {
                        Section {
                            VStack(spacing: 16) {
                                Image(systemName: "star.slash")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray.opacity(0.5))
                                Text("登録されているグループはありません")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .listRowInsets(EdgeInsets())
                        }
                    } else {
                        Section {
                            ForEach(displayedGroups) { group in
                                Button(action: {
                                    onSelect(group.id)
                                }) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(group.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(group.memberSummary)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .onDelete { offsets in
                                displayedGroups.remove(atOffsets: offsets)
                                onDelete(offsets)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("お気に入りグループ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { onClose() }
                }
            }
        }
        .onChange(of: groups) { _, newGroups in
            displayedGroups = newGroups
        }
    }
}
