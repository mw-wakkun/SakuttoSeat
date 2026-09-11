//
//  AppColor.swift
//  SakuttoSeat
//
//  refactor_AttendeeList.md Phase 1（AttendeeListView 末尾からのファイル分離）
//

import SwiftUI

extension Color {
    static let sakuttoBlueStart = Color(red: 0.0, green: 0.4, blue: 0.9)
    static let sakuttoBlueEnd = Color(red: 0.3, green: 0.7, blue: 1.0)

    static var sakuttoGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [.sakuttoBlueStart, .sakuttoBlueEnd]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
