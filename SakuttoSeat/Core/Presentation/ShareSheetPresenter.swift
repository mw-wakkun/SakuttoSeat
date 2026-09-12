//
//  ShareSheetPresenter.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 4（UIActivityViewController の唯一の窓口）
//

import UIKit

@MainActor
enum ShareSheetPresenter {
    /// 最前面 VC へ即座にシェアシートを提示する
    static func present(items: [Any]) {
        guard let topViewController = UIApplication.shared.topViewController else { return }

        let activityVC = UIActivityViewController(activityItems: items, applicationActivities: nil)

        if let popoverController = activityVC.popoverPresentationController {
            popoverController.sourceView = topViewController.view
            popoverController.sourceRect = CGRect(
                x: topViewController.view.bounds.midX,
                y: topViewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popoverController.permittedArrowDirections = []
        }

        topViewController.present(activityVC, animated: true, completion: nil)
    }

    /// シート閉じ終わりなど、提示可能な状態になるまで待ってからシェアする
    static func presentWhenReady(items: [Any]) async {
        await waitUntilPresentable()
        present(items: items)
    }

    /// ルート上に presented VC が無い／遷移中でない状態をポーリングで待つ
    static func waitUntilPresentable(timeoutNanoseconds: UInt64 = 2_000_000_000) async {
        let started = DispatchTime.now().uptimeNanoseconds
        while DispatchTime.now().uptimeNanoseconds - started < timeoutNanoseconds {
            if Task.isCancelled { return }
            if isRootPresentable() {
                return
            }
            do {
                try await Task.sleep(nanoseconds: 50_000_000)
            } catch {
                return
            }
        }
    }

    private static func isRootPresentable() -> Bool {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            // シーンなし（ユニットテスト）＝待つ対象がない
            return true
        }
        guard let window = scene.windows.first(where: \.isKeyWindow),
              let root = window.rootViewController else {
            return false
        }

        // ルート／別シートが残っている間は提示しない
        if root.presentedViewController != nil {
            return false
        }

        if let top = UIApplication.shared.topViewController,
           top.isBeingDismissed || top.isBeingPresented {
            return false
        }

        return true
    }
}
