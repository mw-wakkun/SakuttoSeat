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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                inputSection
                
                ZStack {
                    if presenter.attendees.isEmpty {
                        emptyStateView
                    } else {
                        attendeeList
                    }
                }
                
                shuffleButton
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
                // 初回起動時にキーボードを自動展開
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isTextFieldFocused = true
                }
            }
            .onTapGesture {
                isTextFieldFocused = false
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
        Button(action: {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                presenter.didTapShuffleButton()
            }
        }) {
            Text("席をシャッフルする")
                .font(.headline).bold()
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.sakuttoGradient)
                .cornerRadius(15)
                .shadow(color: .sakuttoBlueStart.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .padding()
        .disabled(presenter.attendees.count < 2)
    }
    
    var resetButton: some View {
        Button(role: .destructive) {
            isShowingResetAlert = true
        } label: {
            Text("リセット")
                .font(.subheadline).bold()
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.2))
                .cornerRadius(20)
        }
        .disabled(presenter.attendees.isEmpty)
    }
    
    func addAttendeeProcess() {
        guard !newName.isEmpty else { return }
        presenter.didTapAddButton(name: newName)
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
