//
//  BulkAddView.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 5（一括追加の子 VIPER）
//  入力・プレースホルダ・区切り説明をこの View に閉じる。パースは親 Interactor。
//  区切り説明はキーボード回避で高さが潰されないよう top inset に置き、折り返し高さを固定する。
//

import SwiftUI

struct BulkAddView: View {
    @StateObject var presenter: BulkAddPresenter

    var body: some View {
        NavigationStack {
            TextEditor(text: textBinding)
                .padding(8)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .padding(.horizontal)
                .padding(.bottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .safeAreaInset(edge: .top, spacing: 12) {
                    BulkAddDelimiterHint(text: presenter.viewData.delimiterHint)
                        .equatable()
                        .padding(.horizontal)
                        .padding(.top)
                }
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
                        .accessibilityHint(String(localized: "入力した参加者をリストに追加します"))
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

/// キーボード表示時の祖先ジオメトリアニメーションから切り離し、2行目のクリップ→復帰を防ぐ。
private struct BulkAddDelimiterHint: View, Equatable {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .geometryGroup()
    }
}

#if DEBUG
#Preview("一括追加") {
    BulkAddView(presenter: BulkAddPresenter(output: nil))
}
#endif
