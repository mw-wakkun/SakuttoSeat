//
//  SeatingTemplateView.swift
//  SakuttoSeat
//
//  refactor_templateListView.md Phase 2（テンプレート一覧の子 VIPER）
//  一覧・削除は Presenter → Interactor。選択結果は Output のみ。
//  View は ViewData.Row と route のみ。Gateway は親が assemble 時に同じインスタンスを渡す。
//  A11y Hint の対訳は Phase 6。
//

import SwiftUI

struct SeatingTemplateView: View {
    @StateObject var presenter: SeatingTemplatePresenter
    @State private var editMode: EditMode = .inactive

    var body: some View {
        NavigationStack {
            List {
                if presenter.viewData.isEmpty {
                    Section {
                        EmptyStateView(
                            systemImage: "square.grid.2x2",
                            message: SeatingTemplateCopy.emptyMessage
                        )
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .listRowInsets(EdgeInsets())
                    }
                } else {
                    Section {
                        ForEach(presenter.viewData.rows) { row in
                            Button {
                                // 編集モード中は誤操作を防ぐため読み込みを無効化
                                guard editMode == .inactive else { return }
                                presenter.didSelectTemplate(id: row.id)
                            } label: {
                                SavedListRow(title: row.name, subtitle: row.tableCountLabel)
                            }
                        }
                        .onDelete { offsets in
                            presenter.didDeleteTemplates(at: offsets)
                            if presenter.viewData.isEmpty {
                                editMode = .inactive
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, $editMode)
            .navigationTitle(SeatingTemplateCopy.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SheetChromeToolbar(
                    isEditing: editMode == .active,
                    showsEditButton: !presenter.viewData.isEmpty,
                    editTitle: SeatingTemplateCopy.edit,
                    closeTitle: SeatingTemplateCopy.close,
                    onToggleEdit: {
                        withAnimation {
                            editMode = (editMode == .active) ? .inactive : .active
                        }
                    },
                    onClose: { presenter.didTapClose() }
                )
            }
            .alert(
                alertTitle,
                isPresented: alertIsPresentedBinding,
                presenting: presentedAlert,
                actions: { _ in
                    Button(SeatingTemplateCopy.ok, role: .cancel) { presenter.dismissRoute() }
                },
                message: { alert in
                    alertMessage(for: alert)
                }
            )
        }
        .onAppear {
            presenter.onAppear()
        }
    }
}

// MARK: - Route Bindings

private extension SeatingTemplateView {
    var presentedAlert: SeatingTemplateAlert? {
        if case .alert(let alert) = presenter.route { return alert }
        return nil
    }

    var alertTitle: String {
        switch presentedAlert {
        case .deleteFailed:
            return SeatingTemplateCopy.deleteFailedTitle
        case .loadFailed:
            return SeatingTemplateCopy.loadFailedTitle
        case .none:
            return ""
        }
    }

    var alertIsPresentedBinding: Binding<Bool> {
        Binding(
            get: { presentedAlert != nil },
            set: { isPresented in
                if !isPresented, case .alert = presenter.route {
                    presenter.dismissRoute()
                }
            }
        )
    }

    func alertMessage(for alert: SeatingTemplateAlert) -> Text {
        switch alert {
        case .deleteFailed(let message), .loadFailed(let message):
            Text(message)
        }
    }
}

#if DEBUG
@MainActor
private enum SeatingTemplatePreviewFactory {
    static func makePresenter(populated: Bool) -> SeatingTemplatePresenter {
        let gateway = InMemorySeatingTemplateGateway()
        if populated {
            try? gateway.insert(
                SeatingLayoutTemplate(
                    name: "宴会場",
                    tables: [
                        TableTemplate(
                            name: "受付卓",
                            capacity: 3,
                            columnCount: 3,
                            layoutDirection: .left,
                            layoutText: "入り口側"
                        )
                    ],
                    globalColumnCount: 2
                )
            )
        }
        return SeatingTemplatePresenter(
            interactor: SeatingTemplateInteractor(templateGateway: gateway),
            output: nil
        )
    }
}

#Preview("テンプレート読込") {
    SeatingTemplateView(presenter: SeatingTemplatePreviewFactory.makePresenter(populated: true))
}

#Preview("テンプレート読込（空）") {
    SeatingTemplateView(presenter: SeatingTemplatePreviewFactory.makePresenter(populated: false))
}
#endif
