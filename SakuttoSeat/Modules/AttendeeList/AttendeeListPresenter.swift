//
//  AttendeeListPresenter.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//

import SwiftUI
import Combine

@MainActor
class AttendeeListPresenter: ObservableObject {
    @Published private(set) var attendees: [Attendee] = []
    
    private let interactor: AttendeeListInteractorProtocol
    private let router: AttendeeListRouter
    
    init(interactor: AttendeeListInteractorProtocol, router: AttendeeListRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onAppear() {
        attendees = interactor.fetchAttendees()
    }
    
    func didTapAddButton(name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        attendees = interactor.addAttendee(name: trimmedName)
    }
    
    func didTapShuffleButton() {
        attendees = interactor.shuffleAttendees()
    }
    
    func didDeleteAttendee(at offsets: IndexSet) {
        offsets.forEach { _ in
            // 本来はinteractorで削除しますが、戻り値を受け取って更新
            attendees = interactor.removeAttendee(at: offsets)
        }
    }
    
    func didTapResetButton() {
        attendees = interactor.resetAttendees()
    }
    
    // MARK: - Navigation Methods
    
    /// 座席表への遷移用View生成
    func makeSeatingChartView() -> AnyView {
        return router.makeSeatingChartView(attendees: self.attendees)
    }
    
    /// 番号札への遷移用View生成
    func makeSimpleShuffleView() -> AnyView {
        let names = attendees.map { $0.name }
        return router.makeSimpleShuffleView(attendees: names)
    }
}
