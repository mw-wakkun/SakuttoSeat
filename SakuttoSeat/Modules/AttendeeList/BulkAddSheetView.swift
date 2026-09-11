//
//  BulkAddSheetView.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 4（Router が組み立てるシート。Phase 5 で BulkAdd モジュールへ移す）
//

import SwiftUI

struct BulkAddSheetView: View {
    @State private var bulkInputText = ""
    let onConfirm: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("改行またはカンマ（、）区切りで参加者名を入力・ペーストしてください。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextEditor(text: $bulkInputText)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            .padding()
            .navigationTitle("参加者の一括追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        bulkInputText = ""
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        onConfirm(bulkInputText)
                        bulkInputText = ""
                    }
                    .disabled(bulkInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
