//
//  SimpleShufflePresenter.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/07.
//

import SwiftUI
import Combine

@MainActor
class SimpleShufflePresenter: ObservableObject {
    @Published var attendees: [String]
    
    init(attendees: [String]) {
        // 初期表示時もシャッフルした状態で保持
        self.attendees = attendees.shuffled()
    }
    
    func didTapShuffleButton() {
        // .easeInOut よりも .spring の方が「シャッフルしてる感」が出ます
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            attendees.shuffle()
        }
    }
}
