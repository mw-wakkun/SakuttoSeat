//
//  ActionButtonsView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/08/16.
//

import SwiftUI

struct ActionButtonsView: View {
    struct ButtonConfig {
        let title: String
        let icon: String
        let color: Color
        let action: () -> Void
        var isDisabled: Bool = false
    }
    
    let button1: ButtonConfig
    let button2: ButtonConfig
    let button3: ButtonConfig
    let button4: ButtonConfig

    var body: some View {
        HStack(spacing: 6) {
            SingleActionButton(config: button1)
            SingleActionButton(config: button2)
            SingleActionButton(config: button3)
            SingleActionButton(config: button4)
        }
    }
}

struct SingleActionButton: View {
    let config: ActionButtonsView.ButtonConfig
    
    var body: some View {
        Button(action: config.action) {
            VStack(spacing: 4) {
                Image(systemName: config.icon)
                    .font(.body)
                Text(config.title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(config.color.opacity(0.1))
            .cornerRadius(8)
            .foregroundColor(config.color)
        }
        .disabled(config.isDisabled)
        .opacity(config.isDisabled ? 0.3 : 1.0)
    }
}
