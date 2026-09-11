//
//  SheetChromeToolbar.swift
//  SakuttoSeat
//
//  refactor_favorite.md Phase 5（シート一覧の編集トグル + 閉じる。EditButton ではなく明示トグル）
//

import SwiftUI

struct SheetChromeToolbar: ToolbarContent {
    var isEditing: Bool
    var showsEditButton: Bool
    var editTitle: String
    var closeTitle: String
    var onToggleEdit: () -> Void
    var onClose: () -> Void

    var body: some ToolbarContent {
        if showsEditButton {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: onToggleEdit) {
                    if isEditing {
                        Image(systemName: "checkmark")
                            .fontWeight(.bold)
                    } else {
                        Text(editTitle)
                    }
                }
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(closeTitle, action: onClose)
        }
    }
}
