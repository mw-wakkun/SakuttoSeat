//
//  SakuttoSeatApp.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//  refactor_groupFavorite.md Phase 4（Container + Gateway を assemble へ注入）
//

import SwiftUI
import GoogleMobileAds
import SwiftData

@main
struct SakuttoSeatApp: App {
    private let modelContainer: ModelContainer
    private let favoriteGateway: GroupFavoriteGatewayBase

    init() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.sakuttoBlueStart)
        
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white, .font: UIFont.boldSystemFont(ofSize: 17)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        UINavigationBar.appearance().tintColor = .white

        // GroupFavorite は Core/Persistence。画面モジュール（FavoriteGroup）ではない。
        // お気に入り Gateway は assemble 時点で注入する（View onAppear の後差しはしない）。
        // 座席表テンプレの attach は本計画の範囲外。Environment 用に同一コンテナを付ける。
        let container = try! ModelContainer(
            for: GroupFavorite.self, SeatingLayoutTemplate.self
        )
        self.modelContainer = container
        self.favoriteGateway = SwiftDataGroupFavoriteGateway(
            context: container.mainContext
        )
    }
    
    var body: some Scene {
        WindowGroup {
            AttendeeListRouter.assembleModule(favoriteGateway: favoriteGateway)
                .task {
                    // start 完了後にだけリワードを preload。バナーは Representable 側でも start を待つ。
                    await MobileAds.shared.start()
                    SessionRewardedAd.shared.preload()
                }
        }
        .modelContainer(modelContainer)
    }
}
