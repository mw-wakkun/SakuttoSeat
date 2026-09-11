//
//  SeatingTemplateListView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/08/15.
//  refactor_favorite.md Phase 5（行 UI とシートクロムを共有部品へ。@Query は触らない）
//  refactor_templateListView.md Phase 0
//  `_既知の課題`: 削除は `modelContext.delete` であり Gateway を通らない。子 VIPER 化は Phase 2。
//

import SwiftUI
import SwiftData

struct SeatingTemplateListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \SeatingLayoutTemplate.createdAt, order: .reverse)
    private var templates: [SeatingLayoutTemplate]
    
    let onSelect: (SeatingLayoutTemplate) -> Void
    
    // 追加: 編集モードを管理する状態変数
    @State private var editMode: EditMode = .inactive
    
    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    // お気に入り画面と同様の、空状態のUI
                    VStack(spacing: 16) {
                        // テンプレート用のアイコン（お好みで "folder" などに変更してください）
                        Image(systemName: "square.grid.2x2")
                            .font(.system(size: 64))
                            .foregroundColor(.gray.opacity(0.4))
                        
                        Text("保存されたテンプレートはありません")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(templates) { template in
                            Button {
                                // 編集モード中は誤操作を防ぐため読み込み処理を無効化
                                if editMode == .inactive {
                                    onSelect(template)
                                    dismiss()
                                }
                            } label: {
                                SavedListRow(
                                    title: template.name,
                                    subtitle: String(localized: "テーブル数: \(template.tables.count)")
                                )
                                .padding(.vertical, 4)
                            }
                            .foregroundColor(.primary)
                        }
                        .onDelete(perform: deleteTemplate)
                    }
                    // リストに編集状態を連携させる
                    .environment(\.editMode, $editMode)
                }
            }
            .navigationTitle("テンプレート読込")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SheetChromeToolbar(
                    isEditing: editMode == .active,
                    showsEditButton: !templates.isEmpty,
                    editTitle: String(localized: "編集"),
                    closeTitle: String(localized: "閉じる"),
                    onToggleEdit: {
                        withAnimation {
                            editMode = (editMode == .active) ? .inactive : .active
                        }
                    },
                    onClose: { dismiss() }
                )
            }
        }
    }
    
    private func deleteTemplate(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(templates[index])
        }
        
        // 全て削除された場合は自動的に編集モードを解除する
        if templates.count <= offsets.count {
            editMode = .inactive
        }
    }
}
