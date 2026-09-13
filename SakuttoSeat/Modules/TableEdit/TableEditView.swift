//
//  TableEditView.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 5（子 VIPER モジュール化）
//  Entity の @State 焼き込みを廃止し、Presenter の ViewData だけを読む。
//  シートの開閉は親（SeatingChartPresenter.route）が Output 経由で制御する。
//

import SwiftUI

/// テーブル編集画面
struct TableEditView: View {
    @StateObject var presenter: TableEditPresenter

    var body: some View {
        NavigationStack {
            Form {
                basicSection
                layoutSection
                deleteSection
            }
            .navigationTitle("テーブル編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            presenter.didTapSave()
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { presenter.didTapCancel() }
                }
            }
            .alert(
                VenueExpansionCopy.seatShortageTitle,
                isPresented: seatShortageBinding
            ) {
                Button(VenueExpansionCopy.seatShortageCancel, role: .cancel) { }
                Button(VenueExpansionCopy.seatShortagePrimary, role: .destructive) {
                    presenter.didConfirmApplyDespiteSeatShortage()
                }
            } message: {
                Text(VenueExpansionCopy.seatShortageMessage)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - セクション

private extension TableEditView {
    var viewData: TableEditViewData { presenter.viewData }

    var basicSection: some View {
        Section("基本設定") {
            TextField("テーブル名（例: テーブルA・最大\(viewData.maxInputLength)文字）", text: nameBinding)

            Stepper("定員: \(viewData.capacity)人", value: capacityBinding, in: viewData.capacityRange)
            Stepper("横の列数: \(viewData.columnCount)列", value: columnCountBinding, in: viewData.columnCountRange)

            Toggle("すべてのテーブルに適用", isOn: applyToAllBinding)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    var layoutSection: some View {
        Section("会場レイアウト（向き）") {
            directionPad
            layoutTextField
        }
    }

    var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    presenter.didTapDelete()
                }
            } label: {
                HStack {
                    Spacer()
                    Text("このテーブルを削除")
                    Spacer()
                }
            }
        }
    }

    // 十字の方向ボタン
    var directionPad: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                directionButton(.top, icon: "arrow.up")
                Spacer()
            }
            HStack(spacing: 16) {
                directionButton(.left, icon: "arrow.left")
                Spacer()
                directionButton(.right, icon: "arrow.right")
            }
            HStack {
                Spacer()
                directionButton(.bottom, icon: "arrow.down")
                Spacer()
            }
            HStack {
                Spacer()
                Button(action: { withAnimation { presenter.didSelectLayoutDirection(.none) } }) {
                    Text("指定なし")
                        .font(.caption)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(
                            Capsule()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
    }

    func directionButton(_ direction: LayoutDirection, icon: String) -> some View {
        let isSelected = viewData.layoutDirection == direction
        return Button(action: { withAnimation { presenter.didSelectLayoutDirection(direction) } }) {
            Image(systemName: icon)
                .font(.title2)
                .padding(10)
                .background(
                    Circle()
                        .fill(isSelected ? Color.blue.opacity(0.85) : Color(.secondarySystemGroupedBackground))
                )
                .foregroundColor(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    // テキストのプリセットと自由入力
    var layoutTextField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ラベル（例：窓際／ステージ側）")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Menu {
                    ForEach(viewData.layoutTextPresets, id: \.self) { preset in
                        Button(preset) { presenter.didChangeLayoutText(preset) }
                    }
                } label: {
                    Label("よく使う語", systemImage: "tag")
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(6)
                }

                TextField("例: 窓際（\(viewData.maxInputLength)文字まで）", text: layoutTextBinding)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}

// MARK: - Bindings（入力は必ず Presenter を通す）

private extension TableEditView {
    var nameBinding: Binding<String> {
        Binding(
            get: { presenter.viewData.name },
            set: { presenter.didChangeName($0) }
        )
    }

    var layoutTextBinding: Binding<String> {
        Binding(
            get: { presenter.viewData.layoutText },
            set: { presenter.didChangeLayoutText($0) }
        )
    }

    var capacityBinding: Binding<Int> {
        Binding(
            get: { presenter.viewData.capacity },
            set: { presenter.didChangeCapacity($0) }
        )
    }

    var columnCountBinding: Binding<Int> {
        Binding(
            get: { presenter.viewData.columnCount },
            set: { presenter.didChangeColumnCount($0) }
        )
    }

    var applyToAllBinding: Binding<Bool> {
        Binding(
            get: { presenter.viewData.applyToAllTables },
            set: { presenter.didToggleApplyToAllTables($0) }
        )
    }

    var seatShortageBinding: Binding<Bool> {
        Binding(
            get: { presenter.route == .seatShortage },
            set: { isPresented in
                if !isPresented, presenter.route == .seatShortage {
                    presenter.dismissRoute()
                }
            }
        )
    }
}

#if DEBUG
#Preview("テーブル編集") {
    TableEditView(
        presenter: TableEditPresenter(
            interactor: TableEditInteractor(
                draft: TableEditDraft(
                    tableID: UUID(),
                    name: "テーブルA",
                    capacity: 4,
                    columnCount: 2
                )
            ),
            output: nil
        )
    )
}
#endif
