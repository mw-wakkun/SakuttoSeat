//
//  UnlockSheetView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/08/17.
//

import SwiftUI

struct UnlockSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let onWatchAd: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
                .padding(.top, 10)
            
            Text("機能制限の解除")
                .font(.headline)
            
            Text("無料枠で保存できるのは各3個までです。\n短い動画広告を1回視聴すると、「お気に入りグループ」と「座席表テンプレート」の両方が無制限に保存できるようになります！")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                Button(action: {
                    onWatchAd()
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                        Text("動画を観てまとめて解除")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                
                Button("キャンセル") {
                    dismiss()
                }
                .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
        .padding()
        .presentationDetents([.height(340)])
    }
}
