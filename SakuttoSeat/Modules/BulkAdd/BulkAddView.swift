//
//  BulkAddView.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5（一括追加の子 VIPER）
//  入力・プレースホルダ・区切り説明をこの View に閉じる。パースは親 Interactor。
//

import SwiftUI

struct BulkAddView: View {
    @StateObject var presenter: BulkAddPresenter

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(presenter.viewData.delimiterHint)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextEditor(text: textBinding)
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
                        presenter.didTapCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        presenter.didTapConfirm()
                    }
                    .disabled(!presenter.viewData.canConfirm)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { presenter.viewData.text },
            set: { presenter.didChangeText($0) }
        )
    }
}

#if DEBUG
#Preview("一括追加") {
    BulkAddView(presenter: BulkAddPresenter(output: nil))
}
#endif
