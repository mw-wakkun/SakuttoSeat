//
//  SimpleShuffleView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/07.
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
                    presenter.didTapShuffleButton()
                } label: {
                    Image(systemName: "shuffle")
                        .font(.body).bold()
                }
            }
        }
        .shareFlow(presenter.share)
    }
}

// MARK: - 番号札モード用スナップショット
struct SimpleShuffleSnapshotView: View {
    let attendees: [String]

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("【サクッと席決め】")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.secondary)
                Text("シャッフル結果（番号札）")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            .padding(.top, 8)

            VStack(spacing: 8) {
                ForEach(Array(attendees.enumerated()), id: \.offset) { index, name in
                    HStack {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 32, height: 32)
                            Text("\(index + 1)")
                                .font(.system(.subheadline, design: .rounded))
                                .bold()
                                .foregroundColor(.blue)
                        }

                        Text(name)
                            .font(.body)
                            .foregroundColor(.primary)
                            .padding(.leading, 8)

                        Spacer()

                        Text("番席")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(8)
                }
            }
        }
        .padding(20)
    }
}
