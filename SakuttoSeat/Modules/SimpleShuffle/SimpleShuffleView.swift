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

    // MARK: - アンロック・広告管理
    @StateObject private var adManager = RewardedAdManager.shared

    @State private var showingShareOptions = false
    @State private var pendingShareSelection: ShareSelectionKind?
    @State private var showingImageShareAdAlert = false
    @State private var showingAdNotReadyAlert = false

    private var shareText: String {
        var text = "【サクッと席決め】シャッフル結果\n"
        for (index, name) in presenter.attendees.enumerated() {
            text += "\(index + 1)番席: \(name)\n"
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

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
                    showingShareOptions = true
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
        .sheet(isPresented: $showingShareOptions, onDismiss: {
            guard let pendingShareSelection else { return }
            self.pendingShareSelection = nil

            Task { @MainActor in
                await ShareSheetPresenter.waitUntilPresentable()
                switch pendingShareSelection {
                case .text:
                    ShareSheetPresenter.present(items: [shareText])
                case .image:
                    showingImageShareAdAlert = true
                }
            }
        }) {
            ShareSelectionView { kind in
                pendingShareSelection = kind
            }
        }
        .alert("画像で共有", isPresented: $showingImageShareAdAlert) {
            Button("キャンセル", role: .cancel) { }
            Button("OK") {
                Task { @MainActor in
                    await playRewardedAdThenShareImage()
                }
            }
        } message: {
            Text("動画広告を視聴して画像を出力しますか？")
        }
        .alert("広告を読み込み中", isPresented: $showingAdNotReadyAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("広告の準備ができていません。しばらく待ってからもう一度お試しください。")
        }
    }

    @MainActor
    private func playRewardedAdThenShareImage() async {
        do {
            try await RewardedAdPresenter.present()
            guard let image = ImageExportRenderer.renderSimpleShuffle(attendees: presenter.attendees) else {
                return
            }
            await ShareSheetPresenter.presentWhenReady(items: [image])
        } catch RewardedAdError.notReady {
            showingAdNotReadyAlert = true
        } catch {
            // notEarned / failed
        }
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
