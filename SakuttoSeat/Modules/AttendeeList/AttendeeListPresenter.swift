//
//  AttendeeListPresenter.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//

import SwiftUI
import Combine
import SwiftData

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
            attendees = interactor.removeAttendee(at: offsets)
        }
    }
    
    func didTapResetButton() {
        attendees = interactor.resetAttendees()
    }
    
    // MARK: - お気に入りグループ機能
    /// 現在の参加者を新しいグループとしてお気に入りに保存する
    func didTapSaveFavoriteGroup(name: String, context: ModelContext) {
        let memberNames = attendees.map { $0.name }
        let newFavorite = GroupFavorite(name: name, members: memberNames)
        
        // SwiftDataのデータベースに保存
        context.insert(newFavorite)
        try? context.save()
    }
    
    /// 選択されたお気に入りグループから参加者リストを上書き読み込みする
    func didSelectFavoriteGroup(_ group: GroupFavorite) {
        // 現在のリストをリセット
        _ = interactor.resetAttendees()
        
        // グループに保存されている名前を順番にインスペクター経由で追加
        var updatedAttendees: [Attendee] = []
        for name in group.members {
            updatedAttendees = interactor.addAttendee(name: name)
        }
        
        // 画面の表示を更新
        attendees = updatedAttendees
    }
    
    /// お気に入りグループをデータベースから削除する
    func didDeleteFavoriteGroup(_ group: GroupFavorite, context: ModelContext) {
        context.delete(group)
        try? context.save()
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
