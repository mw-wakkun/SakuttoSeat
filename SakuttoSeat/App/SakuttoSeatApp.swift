//
//  SakuttoSeatApp.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//

import SwiftUI
import GoogleMobileAds
import SwiftData

@main
struct SakuttoSeatApp: App {
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
    }
    
    var body: some Scene {
        WindowGroup {
            AttendeeListRouter.assembleModule()
                .task {
                    await MobileAds.shared.start()
                }
        }
        .modelContainer(for: GroupFavorite.self)
    }
}
