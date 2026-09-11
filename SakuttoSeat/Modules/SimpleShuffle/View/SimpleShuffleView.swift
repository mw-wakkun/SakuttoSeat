//
//  SimpleShuffleView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/07.
//  refactor_AttendeeList.md Phase 5（ViewData の number + 安定 id。アニメーションはここ）
//

import SwiftUI

struct SimpleShuffleView: View {
    // Presenter の所有権は 3 モジュールで @StateObject に統一している
    // （@ObservedObject では親の再評価ごとに Presenter が作り直され、シャッフル結果が失われる）
    @StateObject var presenter: SimpleShufflePresenter

    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    ForEach(presenter.viewData.rows) { row in
                        NumberedPersonRow(
                            number: row.number,
                            name: row.name,
                            accessory: "番席",
                            tint: .blue
                        )
                    }
                } header: {
                    Text("シャッフル結果")
                } footer: {
                    Text("この番号の席に座ってもらいましょう。")
                }
            }

            AdBannerView()
                .frame(width: 320, height: 50)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGroupedBackground))
        }
        .navigationTitle("番号札")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    presenter.didTapShare()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body)
                }

                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        presenter.didTapShuffle()
                    }
                } label: {
                    Image(systemName: "shuffle")
                        .font(.body).bold()
                }
            }
        }
        .shareFlow(presenter.share)
    }
}
