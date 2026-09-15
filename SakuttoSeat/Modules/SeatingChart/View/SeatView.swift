//
//  SeatView.swift
//  SakuttoSeat
//
//  refactor_seating.md Phase 1（ファイル分割）/ Phase 2（ViewData 化）
//  v2.1 Phase 3（発表はロック印なし・席名を大きく）
//  v2.1 UI/UX（発表席名は title3、人アイコンは title2）
//  v2.1 UI/UX（画面の席名は Dynamic Type。書き出しは固定 pt）
//

import SwiftUI

/// 座席カードの見た目。発表ではロック印を出さず、名前を大きくする。
enum SeatingChrome: Equatable {
    case interactive
    case presentation
    /// 画像書き出し。端末の文字サイズに依存させない。
    case snapshot
}

/// 1つ1つの「座席」
///
/// Phase 6 で `SeatCell` へ改名予定。Entity ではなく `SeatViewData` を受け取る。
struct SeatView: View {
    let seat: SeatViewData
    var chrome: SeatingChrome = .interactive

    var body: some View {
        VStack(spacing: chrome == .presentation ? 6 : 4) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: iconName)
                    .font(iconFont)
                    .foregroundColor(iconColor)

                if showsLockBadge {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                        .background(Circle().fill(.white))
                }
            }

            Text(seat.displayName)
                .font(nameFont)
                .foregroundColor(nameColor)
                .lineLimit(1)
                .minimumScaleFactor(chrome == .presentation ? 0.7 : 1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, chrome == .presentation ? 12 : 8)
        .background(
            showsLockBadge
            ? Color.red.opacity(0.1)
            : Color(.tertiarySystemGroupedBackground)
        )
        .cornerRadius(6)
    }

    private var showsLockBadge: Bool {
        chrome != .presentation && seat.isLocked
    }

    private var iconName: String {
        showsLockBadge ? "person.circle.fill" : "person.circle"
    }

    private var iconColor: Color {
        if seat.isEmpty { return .gray.opacity(0.3) }
        if showsLockBadge { return .red }
        return .blue
    }

    private var iconFont: Font {
        chrome == .presentation ? .title2 : .system(size: 24)
    }

    private var nameFont: Font {
        switch chrome {
        case .presentation:
            return .title3.weight(.semibold)
        case .interactive:
            return .caption.weight(nameWeight)
        case .snapshot:
            return .system(size: 11, weight: nameWeight)
        }
    }

    private var nameWeight: Font.Weight {
        showsLockBadge ? .bold : .medium
    }

    private var nameColor: Color {
        if seat.isEmpty { return .gray.opacity(0.5) }
        if showsLockBadge { return .red }
        return .primary
    }
}
