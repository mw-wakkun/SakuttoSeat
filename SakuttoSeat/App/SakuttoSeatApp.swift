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
    private let persistence: PersistenceBootstrap

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

        // バナー Representable の start() より前に置く。TestFlight 実機でもテスト広告にする。
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = ["D374BA5B-0A77-495D-BF7A-3284400B242E"]

        // GroupFavorite / SeatingLayoutTemplate は Core/Persistence。画面モジュールではない。
        // Gateway は assemble 時点で注入する（View onAppear の後差しはしない）。
        do {
            let container = try ModelContainer(
                for: GroupFavorite.self, SeatingLayoutTemplate.self
            )
            persistence = .ready(
                container: container,
                favoriteGateway: SwiftDataGroupFavoriteGateway(
                    context: container.mainContext
                ),
                templateGateway: SwiftDataSeatingTemplateGateway(
                    context: container.mainContext
                )
            )
        } catch {
            print("保存箱（ModelContainer）の初期化に失敗しました: \(error)")
            persistence = .failed(message: error.localizedDescription)
        }
    }
    
    var body: some Scene {
        WindowGroup {
            switch persistence {
            case .ready(let container, let favoriteGateway, let templateGateway):
                AttendeeListRouter.assembleModule(
                    favoriteGateway: favoriteGateway,
                    templateGateway: templateGateway
                )
                .task {
                    // start 完了後にだけリワードを preload。バナーは Representable 側でも start を待つ。
                    MobileAds.shared.requestConfiguration.testDeviceIdentifiers = ["D374BA5B-0A77-495D-BF7A-3284400B242E"]
                    await MobileAds.shared.start()
                    SessionRewardedAd.shared.preload()
                }
                .modelContainer(container)
            case .failed(let message):
                PersistenceStartupErrorView(message: message)
            }
        }
    }
}

/// 保存箱の起動結果。失敗時は強制終了せず修復用エラー画面へ切り替える。
private enum PersistenceBootstrap {
    case ready(
        container: ModelContainer,
        favoriteGateway: GroupFavoriteGatewayBase,
        templateGateway: SeatingTemplateGatewayBase
    )
    case failed(message: String)
}

/// 保存領域が開けないときの修復案内。再起動以外の操作は持たない。
private struct PersistenceStartupErrorView: View {
    let message: String

    var body: some View {
        ContentUnavailableView {
            Label("保存データを開けません", systemImage: "exclamationmark.triangle")
        } description: {
            Text("起動時の保存領域の初期化に失敗しました。アプリを再起動してください。\n\n\(message)")
        }
    }
}
