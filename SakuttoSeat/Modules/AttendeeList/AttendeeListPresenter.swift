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
        attendees = interactor.removeAttendee(at: offsets)
    }
    
    func didTapResetButton() {
        attendees = interactor.resetAttendees()
    }
}
