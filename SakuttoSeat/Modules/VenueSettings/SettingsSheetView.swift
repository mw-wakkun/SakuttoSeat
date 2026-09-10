//
//  SettingsSheetView.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 1（ファイル分割）
//  Phase 5 でこのフォルダに Presenter / Interactor / Router を追加して
//  独立した子 VIPER モジュールにし、型名も VenueSettingsView へ改名する。
//

import SwiftUI

/// 設定シート（会場設定ハブ）
///
/// 現状は列数の課金ルール（`applySelection`）を View 内に抱えている。
/// Phase 5 で `VenueSettingsInteractor` へ移送する。
struct SettingsSheetView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var globalTableColumnCount: Int
    @Binding var sessionUnlockedColumns: Bool
    @ObservedObject var adManager: RewardedAdManager
    
    @State private var tempSelection: Int = 2
    @State private var pendingColumnCount: Int? = nil
    @State private var showingAdNotReadyAlertLocal: Bool = false
    @State private var showingRequireUnlockAlert: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(spacing: 12) {
                    Text("テーブルの並び列数")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Picker(selection: $tempSelection, label: Text("")) {
                        ForEach(1...10, id: \.self) { i in
                            Text("\(i)列").tag(i)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    
                    Text("※1〜2列は無料で即時利用できます。3列以上は動画広告視聴による解放が必要です。")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("適用") {
                        applySelection()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .onAppear {
                tempSelection = globalTableColumnCount
            }
            .alert("広告の準備ができていません。", isPresented: $showingAdNotReadyAlertLocal) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("広告の準備ができていません。しばらく待ってからもう一度お試しください。")
            }
            .alert("3列以上はアンロックが必要です", isPresented: $showingRequireUnlockAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("動画を視聴して解放") {
                    if adManager.isAdReady {
                        // ユーザーが選択した列数を一時保持
                        pendingColumnCount = tempSelection
                        adManager.showAd {
                            // 動画視聴完了後に保持した列数を反映
                            if let pendingCount = pendingColumnCount {
                                sessionUnlockedColumns = true
                                globalTableColumnCount = pendingCount
                                pendingColumnCount = nil
                                dismiss()
                            }
                        }
                    } else {
                        adManager.loadAd()
                        showingAdNotReadyAlertLocal = true
                    }
                }
            } message: {
                Text("3列以上のレイアウトを利用するには動画広告の視聴が必要です。")
            }
        }
    }
    
    private func applySelection() {
        // 1〜2列は即時適用
        if tempSelection <= 2 {
            globalTableColumnCount = tempSelection
            dismiss()
            return
        }
        
        // 3列以上は解放済みであれば適用
        if sessionUnlockedColumns {
            globalTableColumnCount = tempSelection
            dismiss()
            return
        }
        
        // それ以外は解放アラートを表示して広告再生を促す
        showingRequireUnlockAlert = true
    }
}
