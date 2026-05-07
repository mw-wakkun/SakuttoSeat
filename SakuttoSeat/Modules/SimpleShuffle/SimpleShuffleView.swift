//
//  SimpleShuffleView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/07.
//

import SwiftUI

struct SimpleShuffleView: View {
    // 1. 引数を Presenter に変更
    @StateObject var presenter: SimpleShufflePresenter
    
    var body: some View {
        List {
            Section {
                // 2. presenter.attendees を参照するように修正
                ForEach(presenter.attendees, id: \.self) { name in
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 32, height: 32)
                            if let index = presenter.attendees.firstIndex(of: "\(name)") {
                                Text("\(index + 1)")
                                    .font(.system(.subheadline, design: .rounded))
                                    .bold()
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        // 3. presenter から名前を取得
                        Text(name)
                            .font(.body)
                            .padding(.leading, 8)
                        
                        Spacer()
                        
                        Text("番席")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("シャッフル結果")
            } footer: {
                Text("この番号の席に座ってもらいましょう。")
            }
        }
        .navigationTitle("番号札モード")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // 4. Presenter のメソッドを呼び出す
                Button("再シャッフル") {
                    presenter.didTapShuffleButton()
                }
            }
        }
    }
}
