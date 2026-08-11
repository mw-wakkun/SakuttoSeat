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
        attendees = interactor.allAttendees()
    }
    
    func didTapAddButton(name: String) {
        // インタラクターがトリミングと検証を処理するため、PresenterはシンプルなままにするPolicyで統一
        attendees = interactor.add(name: name)
    }
    
    func didTapShuffleButton() {
        attendees = interactor.shuffle()
    }
    
    func didDeleteAttendee(at offsets: IndexSet) {
        offsets.forEach { _ in
            attendees = interactor.remove(atOffsets: offsets)
        }
    }
    
    func didTapResetButton() {
        attendees = interactor.removeAll()
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
        _ = interactor.removeAll()
        
        // グループに保存されている名前を順番にインスペクター経由で追加
        var updatedAttendees: [Attendee] = []
        for name in group.members {
            updatedAttendees = interactor.add(name: name)
        }
        
        // 画面の表示を更新
        attendees = updatedAttendees
    }
    
    /// 指定したお気に入りグループをデータベースから削除します。
    ///
    /// Presenter は @MainActor で動作しているため、メインスレッド上で同期的に削除処理を行い、
    /// 変更を永続化します。
    func didDeleteFavoriteGroup(_ group: GroupFavorite, context: ModelContext) {
        context.delete(group)
        try? context.save()
    }

    /// Presenter 自身で最新の一覧を ModelContext から取得してオブジェクトを解決します。
    func didDeleteFavoriteGroups(at offsets: IndexSet, context: ModelContext) {
        let descriptor = FetchDescriptor<GroupFavorite>(sortBy: [SortDescriptor(
            \GroupFavorite.createdAt, order: .reverse)])
        let currentList: [GroupFavorite] = (try? context.fetch(descriptor)) ?? []

        let groupsToDelete: [GroupFavorite] = offsets.compactMap { idx in
            guard currentList.indices.contains(idx) else { return nil }
            return currentList[idx]
        }

        // SwiftUI の List が内部で行うバッチ更新と競合しないよう、
        // 実際の削除処理は次の RunLoop に移して実行します。
        // また、アニメーションを無効化して安定的に一括削除・保存を行います。
        DispatchQueue.main.async {
            withTransaction(Transaction(animation: nil)) {
                for group in groupsToDelete {
                    context.delete(group)
                }
                do {
                    try context.save()
                } catch {
                    // 保存失敗時は診断のためログを出力します。
                    print("Failed to save context after deleting favorite groups: \(error)")
                }
            }
        }
    }
    
    // MARK: - ナビゲーション関連メソッド
    
    /// 座席表への遷移用View生成
    func makeSeatingChartView() -> AnyView {
        return router.makeSeatingChartView(attendees: self.attendees)
    }
    
    /// 番号札への遷移用View生成
    func makeSimpleShuffleView() -> AnyView {
        let names = attendees.map { $0.name }
        return router.makeSimpleShuffleView(attendees: names)
    }
    
    func didTapBulkAddButton(text: String) {
        interactor.add(fromText: text)
        // インタラクターから最新の参加者リストを取得して画面を更新
        attendees = interactor.allAttendees()
    }
}
