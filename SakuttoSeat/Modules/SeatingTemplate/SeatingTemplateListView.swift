//
//  SeatingTemplateListView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/08/15.
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
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.name)
                                        .font(.headline)
                                    Text("テーブル数: \(template.tables.count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
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
                // 左側: 編集ボタン（タップでチェックマークに切り替え）
                ToolbarItem(placement: .navigationBarLeading) {
                    if !templates.isEmpty {
                        Button {
                            withAnimation {
                                editMode = (editMode == .active) ? .inactive : .active
                            }
                        } label: {
                            if editMode == .active {
                                Image(systemName: "checkmark")
                                    .fontWeight(.bold)
                            } else {
                                Text("編集")
                            }
                        }
                    }
                }
                
                // 右側: 閉じるボタン（左から移動）
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
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
