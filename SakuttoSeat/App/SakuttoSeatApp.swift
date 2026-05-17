//
//  SakuttoSeatApp.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//

import SwiftUI
import GoogleMobileAds

@main
struct SakuttoSeatApp: App {
    var body: some Scene {
        WindowGroup {
            AttendeeListRouter.assembleModule()
                .task {
                    await MobileAds.shared.start()
                }
        }
    }
}
