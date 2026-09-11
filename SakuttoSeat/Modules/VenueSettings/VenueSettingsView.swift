//
//  VenueSettingsView.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 5（旧 SettingsSheetView の子 VIPER モジュール化）
//  列数の課金ルールは VenueSettingsInteractor、広告提示は VenueSettingsRouter が持つ。
//

import SwiftUI

/// 設定シート（会場設定ハブ）
struct VenueSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var presenter: VenueSettingsPresenter

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Text("テーブルの並び列数")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Picker(selection: selectionBinding, label: Text("")) {
                        ForEach(presenter.viewData.selectableRange, id: \.self) { count in
                            Text("\(count)列").tag(count)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()

                    Text(presenter.viewData.noticeText)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)

                Spacer()
            }
            .padding()
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("適用") { presenter.didTapApply() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .alert("広告の準備ができていません。", isPresented: adNotReadyBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("広告の準備ができていません。しばらく待ってからもう一度お試しください。")
            }
            .alert(
                "\(FeatureLimit.freeColumnCount + 1)列以上はアンロックが必要です",
                isPresented: requireUnlockBinding,
                presenting: requestedColumnCount
            ) { _ in
                Button("キャンセル", role: .cancel) { }
                Button("動画を視聴して解放") { presenter.didConfirmWatchAd() }
            } message: { requested in
                Text("\(requested)列以上のレイアウトを利用するには動画広告の視聴が必要です。")
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Bindings

private extension VenueSettingsView {
    var selectionBinding: Binding<Int> {
        Binding(
            get: { presenter.viewData.selectedColumnCount },
            set: { presenter.didChangeSelection($0) }
        )
    }

    var requestedColumnCount: Int? {
        if case .requireUnlock(let requested) = presenter.route { return requested }
        return nil
    }

    var requireUnlockBinding: Binding<Bool> {
        Binding(
            get: { requestedColumnCount != nil },
            set: { isPresented in
                if !isPresented, case .requireUnlock = presenter.route {
                    presenter.dismissRoute()
                }
            }
        )
    }

    var adNotReadyBinding: Binding<Bool> {
        Binding(
            get: { presenter.route == .adNotReady },
            set: { isPresented in
                if !isPresented, presenter.route == .adNotReady {
                    presenter.dismissRoute()
                }
            }
        )
    }
}

#if DEBUG
#Preview("会場設定") {
    VenueSettingsView(
        presenter: VenueSettingsPresenter(
            interactor: VenueSettingsInteractor(
                currentColumnCount: 2,
                featureUnlock: FeatureUnlockState()
            ),
            router: VenueSettingsRouter(rewardedAd: RewardedAdGatewayBase()),
            output: nil
        )
    )
}
#endif
