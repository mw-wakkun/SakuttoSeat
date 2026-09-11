//
//  AttendeeListView.swift
//  SakuttoSeat
//
//  Created by masafumi wakugawa on 2026/05/05.
//

import SwiftUI
import SwiftData

struct AttendeeListView: View {
    @StateObject var presenter: AttendeeListPresenter
    // 一括追加シートの表示状態管理
    @State private var isShowingBulkAddSheet = false
    @State private var bulkInputText = ""
    @State private var newName: String = ""
    @State private var isShowingResetAlert = false
    @FocusState private var isTextFieldFocused: Bool

    // MARK: - SwiftDataのモデルコンテキスト
    @Environment(\.modelContext) private var modelContext

    // MARK: - お気に入り機能用のState
    @Query(sort: \GroupFavorite.createdAt, order: .reverse) private var favoriteGroups: [GroupFavorite]
    @State private var isShowingSaveAlert = false
    @State private var isShowingLimitAlert = false
    @State private var isShowingFavoriteSheet = false
    @State private var newGroupName: String = ""
    @State private var limitAlertMessage = ""

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
                        .frame(height: presenter.attendees.isEmpty ? 200 : 240)
                }

                VStack(spacing: 0) {
                    shuffleButton
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                        .background(Color(.systemBackground).opacity(0.9))

                    AdBannerView()
                        .frame(width: 320, height: 50)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemBackground).opacity(0.9))
                }
            }
            .navigationTitle("サクッと席決め")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.sakuttoBlueStart, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("参加者のリセット", isPresented: $isShowingResetAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("全員削除", role: .destructive) {
                    presenter.didTapResetButton()
                }
            } message: {
                Text("参加者リストを全員削除してもよろしいですか？")
            }
            .alert("お気に入り登録", isPresented: $isShowingSaveAlert) {
                TextField("グループ名（例: 同期、〇〇課）", text: $newGroupName)
                Button("キャンセル", role: .cancel) { newGroupName = "" }
                Button("保存") {
                    saveCurrentAttendeesProcess()
                }
            } message: {
                Text("現在のメンバーをグループとして保存します。")
            }
            .alert("お気に入り上限", isPresented: $isShowingLimitAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(limitAlertMessage)
            }
            .sheet(isPresented: $isShowingFavoriteSheet) {
                favoriteGroupSheetView
            }
            .sheet(isPresented: $isShowingBulkAddSheet) {
                bulkAddSheetView
            }
            .onAppear {
                presenter.attachFavoriteGateway(SwiftDataGroupFavoriteGateway(context: modelContext))
                presenter.onAppear()
                isTextFieldFocused = true
            }
            .onTapGesture {
                isTextFieldFocused = false
            }
            .navigationDestination(item: $presenter.destination) { destination in
                presenter.view(for: destination)
            }
        }
    }

    private func onSaveButtonTapped() {
        switch presenter.favoriteSaveAvailability() {
        case .available:
            isShowingSaveAlert = true
        case .limitReached(let currentCount, let limit):
            limitAlertMessage =
                "保存できるグループは最大\(limit)個までとなっています（現在\(currentCount)個）。新しいグループを保存するには、お気に入り一覧から既存のグループを削除してください。"
            isShowingLimitAlert = true
        }
    }
}

// MARK: - サブビュー（お気に入り関連・一括追加）
private extension AttendeeListView {
    func saveCurrentAttendeesProcess() {
        let trimmedGroupName = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedGroupName.isEmpty else { return }

        presenter.didTapSaveFavoriteGroup(name: trimmedGroupName)
        newGroupName = ""
    }

    var bulkAddSheetView: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("改行またはカンマ（、）区切りで参加者名を入力・ペーストしてください。")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                TextEditor(text: $bulkInputText)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            .padding()
            .navigationTitle("参加者の一括追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        bulkInputText = ""
                        isShowingBulkAddSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        presenter.didTapBulkAddButton(text: bulkInputText)
                        bulkInputText = ""
                        isShowingBulkAddSheet = false
                    }
                    .disabled(bulkInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    var favoriteGroupSheetView: some View {
        NavigationStack {
            Group {
                List {
                    if favoriteGroups.isEmpty {
                        Section {
                            VStack(spacing: 16) {
                                Image(systemName: "star.slash")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray.opacity(0.5))
                                Text("登録されているグループはありません")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 120)
                            .listRowInsets(EdgeInsets())
                        }
                    } else {
                        Section {
                            ForEach(favoriteGroups, id: \.id) { group in
                                Button(action: {
                                    presenter.didSelectFavoriteGroup(group)
                                    isShowingFavoriteSheet = false
                                }) {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(group.name)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        Text(group.members.joined(separator: ", "))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .onDelete { offsets in
                                presenter.didDeleteFavoriteGroups(at: offsets)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("お気に入りグループ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") { isShowingFavoriteSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

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
            actionButtons

            VStack(spacing: 12) {
                Button(action: {
                    isTextFieldFocused = false
                    presenter.destination = .seatingChart
                }) {
                    buttonLabel(text: "座席表で決める", icon: "square.grid.2x2.fill", isPrimary: true)
                }
                .disabled(presenter.attendees.isEmpty || !newName.isEmpty)

                Button(action: {
                    isTextFieldFocused = false
                    presenter.destination = .simpleShuffle
                }) {
                    buttonLabel(text: "番号札で決める（シンプル）", icon: "list.number", isPrimary: false)
                }
                .disabled(presenter.attendees.isEmpty || !newName.isEmpty)
            }
            .opacity((presenter.attendees.isEmpty || !newName.isEmpty) ? 0.5 : 1.0)
        }
    }

    var actionButtons: some View {
        ActionButtonsView(
            button1: .init(title: "お気に入り", icon: "star.fill", color: .orange, action: {
                isTextFieldFocused = false
                isShowingFavoriteSheet = true
            }),
            button2: .init(title: "一括入力", icon: "list.star", color: .blue, action: {
                isTextFieldFocused = false
                isShowingBulkAddSheet = true
            }),
            button3: .init(title: "保存", icon: "square.and.arrow.down", color: .green, action: {
                isTextFieldFocused = false
                onSaveButtonTapped()
            }, isDisabled: presenter.attendees.isEmpty),
            button4: .init(title: "削除", icon: "trash", color: .red, action: {
                isShowingResetAlert = true
            }, isDisabled: presenter.attendees.isEmpty)
        )
    }

    private func buttonLabel(text: String, icon: String, isPrimary: Bool) -> some View {
        HStack {
            Image(systemName: icon)
            Text(text)
        }
        .font(.headline).bold()
        .foregroundColor(isPrimary ? .white : .blue)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
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

    func addAttendeeProcess() {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        newName = ""
        presenter.didTapAddButton(name: trimmedName)
        isTextFieldFocused = true
    }
}
