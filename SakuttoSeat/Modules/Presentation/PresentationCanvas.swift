//
//  PresentationCanvas.swift
//  SakuttoSeat
//
//  v2.1 Phase 3（発表専用の全画面 View。VIPER にはしない。編集・広告・ナビは持たない）
//  v2.1 UI/UX（ヒント、スワイプ閉じは先頭時のみ、番号札列数、閉じるのヒット領域）
//

import SwiftUI

/// 投影用キャンバス。ホストは `fullScreenCover` で載せるだけ。
struct PresentationCanvas: View {
    let subject: PresentationSubject
    let onDismiss: () -> Void

    @State private var showsHint = true
    @State private var showsCloseControl = false
    @State private var isScrollAtTop = true
    @State private var hintTask: Task<Void, Never>?
    @State private var closeTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            canvasContent
                .allowsHitTesting(true)

            chromeOverlay
        }
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .simultaneousGesture(
            TapGesture().onEnded { revealCloseControl() }
        )
        .simultaneousGesture(dismissDragGesture)
        .accessibilityAction(named: PresentationCopy.dismissAccessibilityLabel, onDismiss)
        .onAppear { startHintCountdown() }
        .onDisappear { cancelOverlayTasks() }
    }
}

// MARK: - Content

private extension PresentationCanvas {
    @ViewBuilder
    var canvasContent: some View {
        switch subject {
        case .seatingChart(let viewData):
            PresentationSeatingChartView(viewData: viewData, isScrollAtTop: $isScrollAtTop)
        case .numberedList(let viewData):
            PresentationNumberedListView(viewData: viewData, isScrollAtTop: $isScrollAtTop)
        }
    }
}

// MARK: - Chrome

private extension PresentationCanvas {
    var chromeOverlay: some View {
        VStack {
            HStack {
                Spacer()
                closeControl
            }
            Spacer()
            if showsHint {
                Text(PresentationCopy.tapToDismissHint)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 28)
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .allowsHitTesting(showsCloseControl)
    }

    var closeControl: some View {
        Button(action: onDismiss) {
            Label(PresentationCopy.dismissTitle, systemImage: "xmark")
                .font(.subheadline.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(minWidth: AppSpacing.minTapTarget, minHeight: AppSpacing.minTapTarget)
                .background(.ultraThinMaterial, in: Capsule())
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(showsCloseControl ? 1 : 0)
        .allowsHitTesting(showsCloseControl)
        .accessibilityLabel(PresentationCopy.dismissAccessibilityLabel)
        .accessibilityHidden(false)
    }

    var dismissDragGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                guard PresentationDismissGesture.shouldDismiss(
                    translation: value.translation,
                    startLocation: value.startLocation,
                    isScrollAtTop: isScrollAtTop
                ) else { return }
                onDismiss()
            }
    }

    func startHintCountdown() {
        showsHint = true
        showsCloseControl = false
        hintTask?.cancel()
        hintTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                showsHint = false
            }
        }
    }

    func revealCloseControl() {
        withAnimation(.easeOut(duration: 0.15)) {
            showsHint = false
            showsCloseControl = true
        }
        closeTask?.cancel()
        closeTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                showsCloseControl = false
            }
        }
    }

    func cancelOverlayTasks() {
        hintTask?.cancel()
        closeTask?.cancel()
        hintTask = nil
        closeTask = nil
    }
}

// MARK: - 座席表（読み取り専用）

private struct PresentationSeatingChartView: View {
    let viewData: SeatingChartViewData
    @Binding var isScrollAtTop: Bool

    var body: some View {
        let rows = SeatingChartViewDataBuilder.tableOnlyRows(from: viewData)
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .center, spacing: 20) {
                ForEach(rows) { row in
                    HStack(alignment: .top, spacing: 20) {
                        ForEach(row.items) { item in
                            if case .table(let table) = item {
                                SeatingTableView(table: table, chrome: .presentation)
                                    .frame(minWidth: 180)
                                    .frame(maxWidth: .infinity, alignment: .top)
                            }
                        }
                        ForEach(0..<row.trailingFillerCount, id: \.self) { _ in
                            Color.clear
                                .frame(minWidth: 180)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(24)
            .frame(minWidth: viewData.minGridWidth)
            .frame(maxWidth: .infinity)
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            PresentationDismissGesture.isScrollAtTop(
                offsetY: geometry.contentOffset.y,
                insetTop: geometry.contentInsets.top
            )
        } action: { _, atTop in
            isScrollAtTop = atTop
        }
        .accessibilityLabel(String(localized: "座席表"))
    }
}

// MARK: - 番号札（大きなカードグリッド）

private struct PresentationNumberedListView: View {
    let viewData: SimpleShuffleViewData
    @Binding var isScrollAtTop: Bool

    var body: some View {
        GeometryReader { proxy in
            let columnCount = PresentationNumberedLayout.columnCount(
                rowCount: viewData.rows.count,
                containerWidth: proxy.size.width
            )
            let columns = Array(
                repeating: GridItem(.flexible(), spacing: 16),
                count: columnCount
            )
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewData.rows) { row in
                        VStack(spacing: 10) {
                            Text("\(row.number)")
                                .font(.system(.largeTitle, design: .rounded).weight(.bold))
                                .foregroundStyle(Color.sakuttoBlueStart)
                            Text(row.name)
                                .font(.title2.weight(.semibold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity, minHeight: 140)
                        .padding(.vertical, 20)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(
                            NumberedPersonCopy.accessibilityLabel(
                                number: row.number,
                                name: row.name,
                                accessory: SimpleShuffleCopy.accessory
                            )
                        )
                    }
                }
                .padding(24)
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                PresentationDismissGesture.isScrollAtTop(
                    offsetY: geometry.contentOffset.y,
                    insetTop: geometry.contentInsets.top
                )
            } action: { _, atTop in
                isScrollAtTop = atTop
            }
        }
    }
}

#if DEBUG
#Preview("座席表の発表") {
    PresentationCanvas(
        subject: .seatingChart(
            SeatingChartViewDataBuilder.build(
                tables: [
                    SeatingTable(
                        name: "テーブルA",
                        capacity: 4,
                        columnCount: 2,
                        layoutDirection: .top,
                        layoutText: "ステージ側",
                        assignedMembers: [
                            SeatingMember(id: UUID(), name: "太郎", isLocked: true),
                            SeatingMember(id: UUID(), name: "花子", isLocked: false)
                        ]
                    )
                ],
                globalColumnCount: 2
            )
        ),
        onDismiss: {}
    )
}

#Preview("番号札の発表") {
    PresentationCanvas(
        subject: .numberedList(
            SimpleShuffleViewDataBuilder.build(seats: [
                NumberedSeat(id: UUID(), name: "太郎", number: 1),
                NumberedSeat(id: UUID(), name: "花子", number: 2),
                NumberedSeat(id: UUID(), name: "次郎", number: 3)
            ])
        ),
        onDismiss: {}
    )
}
#endif
