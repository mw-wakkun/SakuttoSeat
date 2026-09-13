//
//  InteractivePopGestureController.swift
//  SakuttoSeat
//
//  v2.1 Phase 3（発表中に戻るスワイプで参加者一覧へ落ちないようにする）
//

import SwiftUI

/// ホストの interactive pop を一時的に切る。発表 Cover 中だけ使う。
struct InteractivePopGestureController: UIViewControllerRepresentable {
    var isEnabled: Bool

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.apply(isEnabled: isEnabled)
    }

    static func dismantleUIViewController(_ uiViewController: Controller, coordinator: ()) {
        uiViewController.apply(isEnabled: true)
    }

    final class Controller: UIViewController {
        private var desiredEnabled = true

        func apply(isEnabled: Bool) {
            desiredEnabled = isEnabled
            navigationController?.interactivePopGestureRecognizer?.isEnabled = isEnabled
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            navigationController?.interactivePopGestureRecognizer?.isEnabled = desiredEnabled
        }
    }
}
