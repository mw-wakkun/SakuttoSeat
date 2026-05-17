//
//  AttendeeListView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//

import SwiftUI

struct AttendeeListView: View {
    @StateObject var presenter: AttendeeListPresenter
    @State private var newName: String = ""
    @State private var isShowingResetAlert = false
    @FocusState private var isTextFieldFocused: Bool
    @State private var isNavigateToSeatingChart = false
    @State private var isNavigateToSimpleShuffle = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    if presenter.attendees.isEmpty {
                        Spacer()
                        VStack(spacing: 24) {
                            inputSection
                            emptyStateView
                                .padding(.horizontal, 24)
                        }
                        Spacer()
                    } else {
                        inputSection
                        attendeeList
                    }
                    Spacer()
                        .frame(height: presenter.attendees.isEmpty ? 140 : 190)
                }
                
                VStack(spacing: 0) {
                    shuffleButton
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                        .background(Color(.systemBackground))
                    
                    AdBannerView()
                        .frame(width: 320, height: 50)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemBackground))
                }
            }
            .navigationTitle("サクッと席決め")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.sakuttoBlueStart, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    resetButton
                }
            }
            .alert("参加者のリセット", isPresented: $isShowingResetAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("全員削除", role: .destructive) {
                    presenter.didTapResetButton()
                }
            } message: {
                Text("参加者リストを全員削除してもよろしいですか？")
            }
            .onAppear {
                presenter.onAppear()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTextFieldFocused = true
                }
            }
            .onTapGesture {
                isTextFieldFocused = false
            }
            .navigationDestination(isPresented: $isNavigateToSeatingChart) {
                presenter.makeSeatingChartView()
            }
            .navigationDestination(isPresented: $isNavigateToSimpleShuffle) {
                presenter.makeSimpleShuffleView()
            }
        }
    }
}

// MARK: - Subviews
private extension AttendeeListView {
    var inputSection: some View {
        HStack {
            TextField("参加者の名前を入力", text: $newName)
                .textFieldStyle(.roundedBorder)
                .focused($isTextFieldFocused)
                .onSubmit { addAttendeeProcess() }
                .submitLabel(.done)
            
            Button(action: addAttendeeProcess) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(newName.isEmpty ? .gray.opacity(0.4) : .sakuttoBlueStart)
            }
            .disabled(newName.isEmpty)
        }
        .padding()
    }
    
    var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 80))
                .foregroundColor(.sakuttoBlueStart.opacity(0.3))
            
            Text("参加者を追加してください")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    var attendeeList: some View {
        List {
            ForEach(Array(presenter.attendees.enumerated()), id: \.element.id) { index, attendee in
                AttendeeRow(index: index, name: attendee.name)
            }
            .onDelete { offsets in
                presenter.didDeleteAttendee(at: offsets)
            }
        }
        .listStyle(.insetGrouped)
    }
    
    var shuffleButton: some View {
        VStack(spacing: 12) {
            // 1. 本格的な座席表ボタン
            Button(action: {
                isTextFieldFocused = false
                isNavigateToSeatingChart = true
            }) {
                buttonLabel(text: "座席表で決める", icon: "square.grid.2x2.fill", isPrimary: true)
            }
            .disabled(presenter.attendees.isEmpty || !newName.isEmpty)
            
            // 2. サクッと番号札ボタン
            Button(action: {
                isTextFieldFocused = false
                isNavigateToSimpleShuffle = true
            }) {
                buttonLabel(text: "番号札で決める（シンプル）", icon: "list.number", isPrimary: false)
            }
            .disabled(presenter.attendees.isEmpty || !newName.isEmpty)
        }
        .opacity((presenter.attendees.isEmpty || !newName.isEmpty) ? 0.5 : 1.0)
    }
    
    // ボタンの見た目を生成するヘルパー関数
    private func buttonLabel(text: String, icon: String, isPrimary: Bool) -> some View {
        HStack {
            Image(systemName: icon)
            Text(text)
        }
        .font(.headline).bold()
        .foregroundColor(isPrimary ? .white : .blue)
        .frame(maxWidth: .infinity)
        .frame(height: 56) // 高さを固定して揃える
        .background(
            isPrimary ?
            AnyView(Color.sakuttoGradient) :
                AnyView(Color.blue.opacity(0.1))
        )
        .cornerRadius(15)
        .shadow(
            color: (isPrimary ? Color.sakuttoBlueStart : Color.blue).opacity(0.3),
            radius: 8, x: 0, y: 4
        )
    }
    
    private var resetButton: some View {
        Button(action: {
            isShowingResetAlert = true
        }) {
            Image(systemName: "trash")
        }
        .disabled(presenter.attendees.isEmpty)
        .opacity(presenter.attendees.isEmpty ? 0.3 : 1.0)
    }
    
    func addAttendeeProcess() {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        presenter.didTapAddButton(name: trimmedName)
        newName = ""
        isTextFieldFocused = true
    }
}

struct AttendeeRow: View {
    let index: Int
    let name: String
    
    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(Color.sakuttoBlueStart.opacity(0.1))
                    .frame(width: 35, height: 35)
                
                Text("\(index + 1)")
                    .font(.system(.subheadline, design: .rounded))
                    .bold()
                    .foregroundColor(.sakuttoBlueStart)
            }
            
            Text(name)
                .font(.body)
            
            Spacer()
            
            Text("番席")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Theme Colors
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
