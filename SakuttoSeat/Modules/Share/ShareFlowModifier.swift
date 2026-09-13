//
//  ShareFlowModifier.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 5（共有 UI の宣言を 1 箇所に集約）
//
//  もとは SeatingChartView / SimpleShuffleView に重複していた
//  「選択シート + 広告確認アラート + 広告未準備アラート」の宣言。
//  refactor_Ad.md Phase 4（未準備アラート文言を RewardedAdCopy に単一化）
//  v2.1 Phase 1（形式別確認と CSV 失敗）
//

import SwiftUI

extension View {
    /// 画面に共有フロー（選択シート・各種アラート）を取り付ける
    func shareFlow(_ presenter: SharePresenter) -> some View {
        modifier(ShareFlowModifier(presenter: presenter))
    }
}

struct ShareFlowModifier: ViewModifier {
    @ObservedObject var presenter: SharePresenter

    func body(content: Content) -> some View {
        content
            .sheet(item: selectionBinding) { _ in
                ShareSelectionView(isExportUnlocked: presenter.isExportUnlocked) { kind in
                    presenter.didSelectKind(kind)
                }
            }
            .onDisappear {
                presenter.cancelRunningTask()
            }
            .alert(
                alertTitle,
                isPresented: alertIsPresentedBinding,
                presenting: presentedAlert,
                actions: { alert in
                    alertButtons(for: alert)
                },
                message: { alert in
                    alertMessage(for: alert)
                }
            )
    }

    private var selectionBinding: Binding<ShareRoute?> {
        Binding(
            get: {
                guard case .selection = presenter.route else { return nil }
                return presenter.route
            },
            set: { newValue in
                if newValue == nil, case .selection = presenter.route {
                    presenter.dismissRoute()
                }
            }
        )
    }

    private var presentedAlert: ShareAlert? {
        if case .alert(let alert) = presenter.route { return alert }
        return nil
    }

    private var alertIsPresentedBinding: Binding<Bool> {
        Binding(
            get: { presentedAlert != nil },
            set: { isPresented in
                if !isPresented, case .alert = presenter.route {
                    presenter.dismissRoute()
                }
            }
        )
    }

    private var alertTitle: String {
        switch presentedAlert {
        case .confirmImageShareWithAd:
            return ShareCopy.title(for: .image)
        case .confirmHighResImageShareWithAd:
            return ShareCopy.title(for: .highResImage)
        case .confirmCSVExportWithAd:
            return ShareCopy.title(for: .csv)
        case .adNotReady:
            return RewardedAdCopy.notReadyTitle
        case .imageExportFailed:
            return ShareCopy.imageExportFailedTitle
        case .csvExportFailed:
            return ShareCopy.csvExportFailedTitle
        case .none:
            return ""
        }
    }

    @ViewBuilder
    private func alertButtons(for alert: ShareAlert) -> some View {
        switch alert {
        case .confirmImageShareWithAd, .confirmHighResImageShareWithAd, .confirmCSVExportWithAd:
            Button("キャンセル", role: .cancel) { }
            Button("OK") { presenter.didConfirmExport() }
        case .adNotReady, .imageExportFailed, .csvExportFailed:
            Button("OK", role: .cancel) { }
        }
    }

    private func alertMessage(for alert: ShareAlert) -> Text {
        switch alert {
        case .confirmImageShareWithAd:
            Text(ShareCopy.confirmMessage(for: .image))
        case .confirmHighResImageShareWithAd:
            Text(ShareCopy.confirmMessage(for: .highResImage))
        case .confirmCSVExportWithAd:
            Text(ShareCopy.confirmMessage(for: .csv))
        case .adNotReady:
            Text(RewardedAdCopy.notReadyMessage)
        case .imageExportFailed:
            Text(ShareCopy.imageExportFailedMessage)
        case .csvExportFailed:
            Text(ShareCopy.csvExportFailedMessage)
        }
    }
}
