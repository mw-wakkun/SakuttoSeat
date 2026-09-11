//
//  SheetChromeToolbar.swift
//  SakuttoSeat
//
//  refactor_favorite.md Phase 5（シート一覧の編集トグル + 閉じる。EditButton ではなく明示トグル）
//  refactor_favorite.md Phase 6（閉じる / 編集の accessibilityLabel・Hint。未指定なら見た目文言のみ）
//

import SwiftUI

struct SheetChromeToolbar: ToolbarContent {
    var isEditing: Bool
    var showsEditButton: Bool
    var editTitle: String
    var closeTitle: String
    var editAccessibilityLabel: String? = nil
    var editAccessibilityHint: String? = nil
    var closeAccessibilityHint: String? = nil
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
                .accessibilityLabel(editAccessibilityLabel ?? editTitle)
                .modifier(OptionalAccessibilityHint(hint: editAccessibilityHint))
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(closeTitle, action: onClose)
                .modifier(OptionalAccessibilityHint(hint: closeAccessibilityHint))
        }
    }
}
