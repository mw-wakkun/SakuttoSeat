# FavoriteGroup モジュール リファクタリング計画書（VIPER 版）

対象: `SakuttoSeat/Modules/FavoriteGroup/` を中心に、親モジュール
（`AttendeeList`）のお気に入り保存・読込、永続化（`GroupFavorite` /
`GroupFavoriteGateway`）、類似 UI（`SeatingTemplateListView`）を含む。

作成日: 2026-09-11
アーキテクチャ: **VIPER**（View / Interactor / Presenter / Entity / Router）
前提: `refactor_seating.md` Phase 0〜5、`refactor_AttendeeList.md` Phase 0〜6 は完了済み。
FavoriteGroup の **5 層の箱** は AttendeeList Phase 5 で既に置いてある。
本計画はそこで止まった「二次 VIPER 化」——親からの切り出し残り、規約の半適用、
命名の分裂、性能上の無駄——を SeatingChart / AttendeeList の完成形に揃える。

**本ファイルは計画書である。この文書の作成時点ではコードを変更しない。**

### 進捗

| Phase | 内容 | 状態 |
| --- | --- | --- |
| 0 | 準備と回帰テスト（ギャップ埋め） | ✅ 完了（2026-09-11） |
| 1 | デッド API・コメント偽証・規約穴埋め | ✅ 完了（2026-09-11） |
| 2 | ViewData.Row / Route / Entity の独立 | ✅ 完了（2026-09-11） |
| 3 | Gateway API の ID 志向化と親 Interactor の純化 | ✅ 完了（2026-09-11） |
| 4 | シート identity と Router 境界の安定化 | ✅ 完了（2026-09-11） |
| 5 | 再利用部品（一覧行・シートクロム） | 未着手 |
| 6 | 性能・A11y・i18n・編集モード UX | 未着手 |

回帰基準: 既存 `FavoriteGroupTests` + `AttendeeListInteractorTests` のお気に入り系 +
`AttendeeListPresenterTests` の FavoriteGroup Output + `AttendeeListRouterTests` の組み立て。
Phase 0 で拡充した characterization を以降の全フェーズで維持する。

検証端末は既存計画と同じく iPhone 17 / iOS 26.5 を使用する
（iOS 18.4 シミュレータでは MainActor / protocol existential の解放不整合で
`malloc: pointer being freed was not allocated` が再現するため）。

---

## 0. エグゼクティブサマリ

お気に入り一覧は AttendeeList Phase 5 で子 VIPER に切り出された。
ファイル構成（Contracts / Interactor / Presenter / Router / View）は揃っており、
View は `@Query` を持たず、削除は子で完結し、選択は `FavoriteGroupModuleOutput` で親へ返す。
この切り出し自体は正しい。

それでも分析の結論は次の 1 点に集約される。

> **「箱は揃ったが、切り出し途中の継ぎ目が契約になっている」**
> View は `FavoriteGroupSnapshot`（Entity）を直接描画する。提示状態は親の `route` と
> 子の `alert` で二系統。Gateway 型が PresenterProtocol に漏れ、親 Interactor には
> 一覧・削除の複製 API が残る。Router コメントは「View onAppear で attach」と書いてあるが、
> 実装は assemble 時注入で、子の `attachFavoriteGateway` は本番経路から呼ばれない。

これは巨大モジュールの空洞化ではない。**親計画の Phase 5 を複数回の実装で継いだことによる、規約の半適用**である。
行数は少ない（View 105 行、Presenter 64 行、Interactor 42 行）。
だからこそ、SeatingChart と同じ穴を「小さいから許す」と残すと、全社規約がモジュールサイズで分岐する。

各層の「あるべき責務」と「実際の中身」を対比すると次のとおり。

| 層 | VIPER における責務 | 現状 | 判定 |
| --- | --- | --- | --- |
| View | 受動的な描画とイベント転送。Entity を知らない | ViewData を読む形は妥当。ただし中身が Entity。`alert` を独自 Binding。文言 API 混在。編集中も選択が発火する | △ 軽い〜中程度 |
| Interactor | 一覧・削除の唯一の窓口 | Gateway 経由は妥当。`try?` で取得失敗を空配列に変換。削除が `IndexSet` 依存。`@Model` を直接扱う | △ |
| Presenter | ViewData 生成と Interactor / Output への仲介 | 薄い。ただし `alert` が Route と別系統。`attachFavoriteGateway` が View 向け Protocol に残る。`nonisolated deinit` なし | △ |
| Entity | Interactor が扱う純粋なモデル | **ファイルが無い。** `FavoriteGroupSnapshot` / `FavoriteGroupID` / `FavoriteSaveError` は親 `AttendeeListEntity` に同居 | ✗ 不在 |
| Router | モジュール組み立て | `assembleModule` のみ。Protocol なしは SimpleShuffle と同じ判断で妥当。コメントが実装と矛盾。シート identity を持たない | △ 薄い |
| Contracts | 層間境界の明示 | Presenter / Interactor / Output はある。Router は不要（空 Protocol 禁止）。ViewData が Entity 配列。`alert` が `route` ではない | △ 不完全 |
| 横断（親） | 保存・読込置換は親。一覧・削除は子 | 親 Interactor に `allFavorites` / `deleteFavorites` が残存。`loadFavorite` が全件 fetch。`currentFavoriteGateway()` が Presenter を貫通 | ✗ 二重窓口 |
| 横断（命名） | 1 概念 1 名前 | `FavoriteGroup`（画面）と `GroupFavorite`（`@Model` / Gateway）が併存 | △ 混乱 |

本計画は既存の VIPER 命名と AttendeeList Phase 5 の成果（子が一覧・削除、親が保存・読込、
Gateway インスタンス共有）を**維持したまま**、上記の継ぎ目を正しい層へ戻す。
主要な作業は次の 3 本柱。

1. **契約の純化**: View から Entity を排除し、提示を `route` 1 本にする
2. **永続化 API の ID 志向化**: offset 削除と全件スキャン読込をやめ、親の複製 API を落とす
3. **継ぎ接ぎの解消**: 命名・コメント・シート identity・テンプレ一覧との UI 共通化

SeatingChart / AttendeeList 側で既に存在する資産（`EmptyStateView` / `route` + Binding /
MainActor + 具象保持の deinit 回避 / `*GatewayBase`）は再利用し、同じ問題を三度設計しない。

---

## 1. 本プロジェクトにおける VIPER の解釈（再掲・FavoriteGroup 向け注釈）

古典的 VIPER は UIKit + delegate 前提のため、SwiftUI に合わせて次のように読む。
**これは `refactor_seating.md` §1 と同一の全社規約**であり、本モジュールも例外にしない。

| 層 | 実装形態 | 依存してよいもの | 禁止事項 |
| --- | --- | --- | --- |
| **View** | `struct: View`。`@StateObject var presenter` を保持 | Presenter が公開する **ViewData** と **Route** のみ | Entity の直接参照、`@Query`、`ModelContext`、業務条件分岐、遷移状態の保持 |
| **Presenter** | `@MainActor final class: ObservableObject` + `PresenterProtocol` | Interactor（具象）、Router（必要なときだけ具象）、Entity → ViewData 変換、親 Output | ビジネスルールの判断、永続化、SwiftUI の描画 API、`AnyView` の工場化 |
| **Interactor** | `nonisolated final class: InteractorProtocol` | Entity、Entity Gateway（`*GatewayBase`） | `SwiftUI` / `UIKit` の import、Presenter・View への参照、`@Model` の画面向け加工 |
| **Entity** | 値型 `struct` / `enum` | `Foundation` のみ | ロジック（軽量な計算プロパティは可） |
| **Router** | `final class`。画面内遷移が無いなら Protocol は置かない | モジュール組み立て | ビジネスルール、Entity の加工、空の `RouterProtocol` |

補足（FavoriteGroup 固有）:

- **`ObservableObject` は Protocol に載せない。** SeatingChart / AttendeeList と同じ。
  protocol existential を MainActor クラスが保持すると deinit で malloc abort するため、
  Interactor / Gateway は**具象型（または `*GatewayBase`）で保持**する。
- **空の `RouterProtocol` は置かない。** `refactor_simple.md` Phase 1 の決定。
  FavoriteGroup に画面内の子組み立てが無いなら、`static assembleModule` だけでよい。
- **Gateway の attach は Interactor の責務。** 子モジュールでは **assemble 時に注入済み**なので、
  PresenterProtocol / View から `attachFavoriteGateway` を消す。
  親 AttendeeList の View `onAppear` attach は SwiftData 制約上の過渡期として残してよい
  （`refactor_AttendeeList.md` §8.4）。
- **永続化モデル（`@Model`）は View / Presenter に出さない。** 現状 View は `@Model` を直接は
  見ていないが、`FavoriteGroupSnapshot` を ViewData として素通ししている。
  AttendeeList の `ViewData.Row` と同じく、表示専用 Row へ写像する。
- **提示は Presenter の `route` が単一の真実。** 親は既に `AttendeeListRoute`。
  子だけ `alert: FavoriteGroupAlert?` なのは VenueSettings / AttendeeList と不揃い。
- **一覧・削除は子、保存・読込置換は親。** Phase 5 の判断は維持する。
  変えるのは「親にも一覧・削除が残っている」ことと、「読込が全件 fetch」こと。

---

## 2. 現状の責務違反マッピング

### 2.1 View（`FavoriteGroupView.swift` / 105 行）

受動描画としては概ね正しい。残っているずれは「小さいが規約違反」である。

| 箇所 | 内容 | 本来の層 / あるべき形 |
| --- | --- | --- |
| 29–45 | `ForEach(presenter.viewData.groups)` が `FavoriteGroupSnapshot` を描く | **ViewData.Row**。View に Entity 型名を出さない |
| 64–76, 84–93 | 子独自の `alert` Binding | **`route`**（AttendeeList / VenueSettings と同じ） |
| 30–32, 61, 65 | タイトル / 閉じる / アラートタイトルが生リテラル。空状態と hint だけ `String(localized:)` | **Copy 型 or 一律 `String(localized:)`**（BulkAdd の `BulkAddCopy` 型） |
| 47–49 | `onDelete` が `IndexSet` を Presenter へ渡す | 受け渡しは当面可。Interactor は **ID 配列**で消す |
| 31 | 編集モード中も `didSelectGroup` が発火する | View が `editMode` を見て選択を無効化（テンプレ一覧は既にそうしている） |
| 58 | `EditButton()`。テンプレ一覧はカスタム編集トグル | Phase 5 で共通クロムへ。空になったあと editMode が残る |
| 78 | `.presentationDetents` が View 側。テンプレは Router 組み立て時 | **Router.assembleModule**（提示の修飾は組み立て側） |
| 16 | シート内で `NavigationStack` を再生成。親も `NavigationStack` | シート内スタックは必要。親シート側で detent を付け、子は中身に専念 |

View に残してよいもの:

| 残す | 理由 |
| --- | --- |
| `EditMode` のローカル状態 | 未確定の編集 UI。確定（削除）だけ Presenter へ |
| アラート Binding の読み取り | `route` 導入後も SeatingChart と同じ分割 Binding |

### 2.2 Presenter（`FavoriteGroupPresenter.swift` / 64 行）

薄いが、親・兄弟と契約が揃っていない。

| 箇所 | 内容 | 本来の層 |
| --- | --- | --- |
| 14, 56–58 | `@Published var alert` | **`route: FavoriteGroupRoute?`** |
| 26–29 | `attachFavoriteGateway` | **assemble 済みなら削除。** Protocol からも消す |
| 31–33 | `onAppear` で再 `publishState` | init で既に公開済み。Gateway が後差しされないなら冗長 |
| 39 | 削除が `IndexSet` のまま Interactor へ | Presenter が Row ID を解決してから Interactor へ |
| 43–46 | `FavoriteSaveError` の `limitReached` / `invalidName` / `notFound` を握り潰す | 削除経路では出ない。型を削除専用にするか、明示的に無視する |
| — | `nonisolated deinit {}` が無い（親 Presenter だけある） | 子も揃えるか、親の特例理由をコメントで固定する |
| 62 | `FavoriteGroupViewData(groups: groups, isEmpty:)` | `isEmpty` は `groups.isEmpty` の重複。Row 化時に Builder へ |

### 2.3 Interactor（`FavoriteGroupInteractor.swift` / 42 行）

永続化窓口としては正しい位置。API が「画面の offset」と「SwiftData `@Model`」にべったりしている。

| 箇所 | 内容 | あるべき形 |
| --- | --- | --- |
| 23–26 | `allFavorites()` が `(try? fetchAll()) ?? []` | 失敗は `throws`。Presenter が `route = .alert(.loadFailed)` |
| 28–40 | `deleteFavorites(at: IndexSet)` が再 fetch + offset | `deleteFavorites(ids:)`。表示順と永続化順のズレで誤削除しうる |
| 25, 29 | `GroupFavorite`（`@Model`）を直接 map / 保持 | Gateway が **Snapshot（または永続化 DTO）** を返す |
| 19–21 | `attachFavoriteGateway` | テスト用差し替えとしては残してよい。Presenter 経由は不要 |

### 2.4 Entity / 命名 / 配置

| 現状 | 問題 |
| --- | --- |
| `FavoriteGroupSnapshot` / `FavoriteGroupID` / `FavoriteSaveError` / `FavoriteSaveAvailability` が `AttendeeListEntity.swift` | 子モジュールが親の Entity ファイルに依存。VIPER のモジュール境界が逆 |
| `Modules/FavoriteGroup/` と `Modules/GroupFavorite/` | 画面名と `@Model` 名が語順逆。検索・レビューで取り違える |
| `GroupFavorite.makeSnapshot()` が `@Model` 側で `memberSummary` まで作る | 表示用結合は Presenter / ViewDataBuilder の責務 |
| FavoriteGroup に `*Entity.swift` / `*ViewData.swift` / `*Route.swift` が無い | 親・SeatingChart は分割済み。小さいモジュールでも「型の所在」は揃える |

### 2.5 Router / 親との接続

`FavoriteGroupRouter.assembleModule` は Builder として妥当。問題は周辺である。

| 箇所 | 内容 | 問題 |
| --- | --- | --- |
| Router 13 行コメント | 「実画面は View 初回 onAppear で SwiftData Gateway を渡す」 | **偽証。** 子 View は `ModelContext` を持たない。親が `currentFavoriteGateway()` を assemble に渡している |
| `AttendeeListPresenter.makeRouteSheet` | シート表示のたびに `assembleModule` し直す | `.sheet(item:)` の content が再評価されると **Presenter が再生成**され、alert / 編集中状態が消える |
| `interactor.currentFavoriteGateway()` | Presenter が Gateway 型を知って Router に渡す | 親 Presenter の永続化知識。`makeFavoriteGroupModule(output:)` が Interactor から取る形へ |
| 親 Interactor `allFavorites` / `deleteFavorites` | Phase 5 以降、本番の呼び出し元は子だけ | テスト専用の死にかけ API。契約が二重 |
| 親 `loadFavorite(id:)` | `fetchAll()` して `first(where:)` | 件数は無料枠 3 でも、API として `fetch(id:)` が無い。テンプレ側も同型 |

### 2.6 Gateway（`GroupFavoriteGateway.swift`）

| 箇所 | 内容 | 問題 |
| --- | --- | --- |
| 戻り値が `[GroupFavorite]` | Interactor が `@Model` に結合 | Snapshot / ID 志向にすると View だけでなく Interactor も `@Model` から離れる |
| `delete(atOffsets:in:)` | 画面の IndexSet が永続化 API に漏れている | `delete(ids:)` または既存の `delete(_ favorite:)` を ID で呼ぶ |
| `fetch(id:)` が無い | 親の読込が全件スキャン | 追加する |
| `GroupFavoriteGatewayBase` の空実装 | 未 override が成功扱いで黙る | 既存規約（deinit 回避）なので維持。テスト用失敗 Gateway は共通化できる |

`*GatewayBase` 継承は SeatingTemplate と同じく **deinit 回避のためのプロジェクト規約**である。
Protocol existential 保持に戻さない。

---

## 3. 目標とするモジュール境界

Phase 5 の判断を維持した完成形。

```
AttendeeList（親）
  ├─ 保存: favoriteSaveAvailability / saveCurrentAsFavorite
  ├─ 読込置換: loadFavorite(id:) → replaceAll
  ├─ Gateway 所有: attach は親 View onAppear（過渡期）
  └─ Output 受信: favoriteGroupDidSelect / DidCancel
        │
        │ assemble 時に同じ Gateway インスタンスを渡す
        ▼
FavoriteGroup（子）
  ├─ 一覧: allFavorites() throws
  ├─ 削除: deleteFavorites(ids:)
  ├─ ViewData.Row のみ描画
  └─ 失敗は route = .alert
```

### 3.1 目標ディレクトリ

```
SakuttoSeat/
├── Core/
│   └── Gateways/
│       └── GroupFavoriteGateway.swift   // fetch(id:) / delete(ids:)。戻りは Snapshot
├── Modules/
│   ├── FavoriteGroup/
│   │   ├── FavoriteGroupContracts.swift
│   │   ├── FavoriteGroupEntity.swift    // ★ ID / Snapshot / Error の所在
│   │   ├── FavoriteGroupInteractor.swift
│   │   ├── FavoriteGroupPresenter.swift
│   │   ├── FavoriteGroupRouter.swift
│   │   ├── FavoriteGroupViewData.swift  // ★ Row + Builder（Contracts から分離可）
│   │   ├── FavoriteGroupRoute.swift     // ★ alert を route に置換
│   │   └── FavoriteGroupView.swift
│   ├── GroupFavorite/
│   │   └── GroupFavorite.swift          // @Model のみ。makeSnapshot は Gateway 側へ
│   └── AttendeeList/
│       └── AttendeeListEntity.swift     // Attendee のみ。Favorite* 型は移設
└── Components/
    ├── EmptyStateView.swift             // 既存
    ├── SavedListRow.swift               // ★ 名前 + キャプション（テンプレと共有）
    └── SheetChromeToolbar.swift         // ★ 編集 + 閉じる（オプション）
```

`GroupFavorite` フォルダ名のリネーム（`FavoriteGroupModel` 等）は Xcode / SwiftData
マイグレーションを巻き込むため **本計画では行わない**。文書とコメントで
「画面 = FavoriteGroup、永続化 = GroupFavorite」と固定する。リネームは別計画。

### 3.2 目標 Contracts（骨子）

```swift
// View <- Presenter
@MainActor
protocol FavoriteGroupPresenterProtocol: AnyObject {
    var viewData: FavoriteGroupViewData { get }
    var route: FavoriteGroupRoute? { get set }

    func onAppear()
    func didSelectGroup(id: FavoriteGroupID)
    func didDeleteGroups(ids: [FavoriteGroupID])
    func didTapClose()
    func dismissRoute()
}

// Presenter -> Interactor
nonisolated protocol FavoriteGroupInteractorProtocol: AnyObject {
    func allFavorites() throws -> [FavoriteGroupSnapshot]
    func deleteFavorites(ids: [FavoriteGroupID]) throws
}

// Presenter -> 親（変更なし）
protocol FavoriteGroupModuleOutput: AnyObject {
    func favoriteGroupDidSelect(id: FavoriteGroupID)
    func favoriteGroupDidCancel()
}
```

PresenterProtocol から消すもの: `attachFavoriteGateway`、`alert`、`didDeleteGroups(at: IndexSet)`。

ViewData:

```swift
struct FavoriteGroupViewData: Equatable {
    struct Row: Identifiable, Equatable {
        let id: FavoriteGroupID
        let name: String
        let memberSummary: String
    }
    let rows: [Row]
    var isEmpty: Bool { rows.isEmpty }
    static let empty = FavoriteGroupViewData(rows: [])
}
```

`memberNames` は Entity（Snapshot）に残し、ViewData には載せない。
一覧描画に不要な配列を View に渡さない。

Route:

```swift
enum FavoriteGroupRoute: Identifiable, Equatable {
    case alert(FavoriteGroupAlert)
}
```

親の `AttendeeListInteractorProtocol` から `allFavorites` / `deleteFavorites` を外す。
残すのは `favoriteSaveAvailability` / `saveCurrentAsFavorite` / `loadFavorite(id:)` /
`attachFavoriteGateway`。`currentFavoriteGateway()` は Router 組み立て用に
Interactor 内部 or Router が触る形へ閉じる（Presenter の公開面からは消す）。

### 3.3 Gateway 目標 API

```swift
protocol GroupFavoriteGateway: AnyObject {
    func fetchCount() throws -> Int
    func fetchAll() throws -> [FavoriteGroupSnapshot]
    func fetch(id: FavoriteGroupID) throws -> FavoriteGroupSnapshot?
    func insert(name: String, members: [String]) throws
    func delete(ids: [FavoriteGroupID]) throws
}
```

`insert` が `GroupFavorite` を受け取らないようにすると、親 Interactor からも `@Model` が消える。
`*GatewayBase` 継承は維持する。

互換の進め方:

1. 既存メソッドを残したまま `fetch(id:)` / `delete(ids:)` / Snapshot 戻りを追加
2. 呼び出し側を移す
3. `delete(atOffsets:in:)` と `@Model` 戻りを削除

一度に差し替えると InMemory / SwiftData / 失敗ダブル / 親テストが同時に割れる。

---

## 4. 再利用性

### 4.1 今すぐ FavoriteGroup 内で揃えるもの

| 部品 | 現状の分裂 | 寄せ先 |
| --- | --- | --- |
| 空状態 | `EmptyStateView` 利用済み。デフォルト font/color が AttendeeList と違う | 用途差なのでデフォルトのままでよい。メッセージだけ Copy に集約 |
| 文言 | `String(localized:)` と生リテラルが混在 | `FavoriteGroupCopy`（`BulkAddCopy` と同じ型） |
| 失敗 Gateway | `FavoriteGroupTests` と `AttendeeListInteractorTests` に別実装 | テスト用 `FailingGroupFavoriteGateway` をテストターゲットへ 1 つ |
| Snapshot 生成 | `@Model.makeSnapshot()` と Interactor の map | Gateway 内の 1 関数。`memberSummary` は Builder |

### 4.2 テンプレート一覧との共通化（Phase 5）

`SeatingTemplateListView` はまだ `@Query` + `@Model` の旧形（`refactor_AttendeeList.md` Phase 5d 未実施）。
見た目はほぼ同じ（名前 + キャプション、編集、閉じる、空状態、medium/large detent）。

本計画で先に切り出す再利用部品:

```swift
struct SavedListRow: View {
    let title: String
    let subtitle: String
}
```

```swift
struct SheetListChrome: ViewModifier / ToolbarContent {
    var isEditing: Bool
    var showsEditButton: Bool
    var onToggleEdit: () -> Void
    var onClose: () -> Void
}
```

テンプレ一覧の VIPER 化自体は座席側のオプション計画に残す。
部品だけ先に FavoriteGroup で作り、テンプレは「使う側」として後から乗せる。
FavoriteGroup 計画がテンプレの `@Query` 撤去まで踏み込むと範囲が爆発する。

### 4.3 親との型共有

`FavoriteGroupID` / `FavoriteGroupSnapshot` / `FavoriteSaveError` /
`FavoriteSaveAvailability` は **FavoriteGroup（または Core）の所有**にする。
AttendeeList はそれを import して保存・読込に使う。
依存の向きを「子が親 Entity を借りる」から「親が子（共有）Entity を使う」へ逆転させる。

`TemplateSaveAvailability` との統合（`SaveAvailability`）は
`refactor_AttendeeList.md` §8.3 の未決事項。本計画では **触らない**。
お気に入り側だけを FavoriteGroup 所有に移す。

---

## 5. パフォーマンス

無料枠は 3 件（`FeatureLimit.freeFavoriteGroupCount`）なので、一覧の描画コストは実害になりにくい。
直す価値があるのは **誤った複雑度の API** と **シート再生成** である。
有料で件数制限が外れたときに、offset 全件 fetch がそのまま残るのを防ぐ。

| # | 現状 | 影響 | 対策 | Phase |
| --- | --- | --- | --- | --- |
| 1 | `loadFavorite` が毎回 `fetchAll` | O(n) スキャン。SwiftData でも全件実体化 | `fetch(id:)` | 3 |
| 2 | 削除が再 `fetchAll` + IndexSet | 表示順と永続化順がずれると誤削除。二重 fetch | `delete(ids:)` | 3 |
| 3 | 一覧取得失敗を `try?` で空配列 | ユーザーは「0 件」と誤認。再描画しても復旧しない | `throws` + route | 2–3 |
| 4 | `publishState` が init と onAppear で二重 | シート表示のたびに fetch 2 回 | onAppear は「再同期が必要なときだけ」 | 1 |
| 5 | `makeRouteSheet` が毎回 assemble | 親 View 再評価で子 Presenter が死ぬ可能性 | 親が子 Presenter を route 期間中保持、または Router がキャッシュ | 4 |
| 6 | Snapshot が `memberNames` + `memberSummary` を両方持つ | 一覧は summary だけで足りる | ViewData.Row は summary のみ。読込は `fetch(id:)` の members | 2–3 |
| 7 | `@Model` を `nonisolated` Interactor から読む | SwiftData モデルは context の実行コンテキスト外アクセスになりうる | Gateway 内で Snapshot に変換してから返す | 3 |
| 8 | `memberSummary` を毎回 `joined` | 3 件では無視できる | Builder 側でよく、先行最適化しない | — |

やらないこと:

- 一覧の差分更新 / ページング（件数が桁違いになるまで不要）
- `@Query` の再導入（VIPER に戻る）
- Gateway のプロトコルexistential 化（deinit 事故）

---

## 6. 実行計画（フェーズ分割）

各フェーズは独立してマージ可能。
**「安全網 → 嘘を消す → 契約を揃える → 永続化 API → シート安定 → 再利用 → 仕上げ」** の順。
挙動を変えない整理を先に済ませる。SeatingChart / AttendeeList / SimpleShuffle と同じ。

### Phase 0: 準備と回帰テスト（0.5 日）

現状の挙動を固定する characterization を `FavoriteGroupTests` に足す。
親側のお気に入りテストは消さず、複製 API 削除（Phase 3）まで残す。

最低限追加する仕様:

- 取得失敗（`fetchAll` throws）が今は空配列になること（`_既知の課題`）
- 複数 offset 削除
- 範囲外 offset は無視されること（Gateway の `indices.contains`）
- 選択は Output だけ（親リストを子が変えない）
- `attachFavoriteGateway` の差し替え（既存）を残す
- 親: 選択 → リスト置換 → シート閉鎖（既存）
- 親: 同一 Gateway インスタンスを子 assemble に渡していること（Router テストを断言付きに）

完了条件: 見た目を変えずにテスト green。以降の回帰基準とする。
リスク: 低。

### Phase 1: デッド API・コメント偽証・規約穴埋め（0.5 日）

挙動を変えない範囲で継ぎ目を消す。

- Router / Interactor / View ヘッダの「View onAppear で attach」を、
  **「親が assemble 時に同じ Gateway を渡す」** に直す。
- 子 PresenterProtocol / Presenter から `attachFavoriteGateway` を削除。
  Interactor の attach はテスト用に残してよい。
- `FavoriteGroupCopy` を置き、View の生リテラルを `String(localized:)` に揃える
  （文言自体は変えない）。
- 子 Presenter に `nonisolated deinit {}` を親と揃える、または
  「親だけ必要」の理由を親側コメントに固定して子は付けない、のどちらか一方に決める。
- Preview は In-Memory Gateway に 1 件入れて空でない経路も見せる。
- 完了条件: ビルド成功、Phase 0 green、差分がコメント・デッド API・文言 API に限定。
- リスク: 低。

### Phase 2: ViewData.Row / Route / Entity の独立（1.0 日）

**本計画の中核。View から Entity を排除する。**

- `FavoriteGroupEntity.swift` を新設。`FavoriteGroupID` / `FavoriteGroupSnapshot` /
  `FavoriteSaveError` / `FavoriteSaveAvailability` を AttendeeList から移す。
  AttendeeList は移設先を使う（typealias 残しは移行コミットだけ許容）。
- `FavoriteGroupViewData.Row` と Builder。View の `ForEach` は `viewData.rows` のみ。
- `FavoriteGroupRoute` を導入。`alert` を `route = .alert(.deleteFailed)` に置換。
  Binding は AttendeeList の `alertIsPresentedBinding` を踏襲し `dismissRoute()` へ。
- 一覧取得を `throws` に変え、失敗は `route = .alert(.loadFailed)`。
  Phase 0 の `_既知の課題` テストを更新する（空配列誤認をやめる。挙動変更）。
- `isEmpty` プロパティの重複格納をやめる。
- 完了条件: FavoriteGroup View に `FavoriteGroupSnapshot` / `GroupFavorite` が無い。
  Presenter テストが Route 契約。親テストは移設した型名以外 green。
- リスク: 中（提示状態の名前替えと取得失敗の UX 変更）。

### Phase 3: Gateway の ID 志向化と親 Interactor の純化（1.0 日）

- Gateway に `fetch(id:)` / `delete(ids:)` / Snapshot 戻り / `insert(name:members:)` を追加し、
  呼び出し側を移してから旧 API を削除。
- 子 Interactor の削除を ID 配列に変更。Presenter が `IndexSet` → `rows[offset].id` を解決。
- 親 `loadFavorite` は `fetch(id:)`。見つからなければ `notFound`。
- 親 Interactor から `allFavorites` / `deleteFavorites` を削除。
  親テストの該当ケースは子テストへ移すか、保存結果は `gateway.fetchAll()` で断言する。
- `GroupFavorite.makeSnapshot()` は Gateway プライベートへ移動してよい。
- 親 Presenter の `makeRouteSheet` から Gateway 型を消す。
  `router.makeFavoriteGroupModule(output:)` が Interactor の現行 Gateway を読む
  （Router に Interactor を渡すか、Presenter が `interactor` 経由の組み立てメソッドを Router に委譲）。
  Presenter が `GroupFavoriteGatewayBase` を言及しないこと。
- 完了条件: 子・親 Interactor に `GroupFavorite` 型名が無い。
  `delete(atOffsets:)` がプロダクトコードから消える。親 Protocol から一覧・削除が消える。
- リスク: 中。Gateway 実装 2 系統 + テストダブルを同時に更新する。

### Phase 4: シート identity と Router 境界（0.5 日）

- `.sheet(item:)` の content 再評価で子が再生成されないようにする。
  推奨: 親 Presenter が `.favoriteList` をセットするとき 1 度だけ assemble し、
  `makeRouteSheet` はそのインスタンスを返す。`dismissRoute` で解放。
- `.presentationDetents([.medium, .large])` を View から Router 組み立てへ移す
  （`SeatingChartRouter.makeTemplateListModule` と同じ位置）。
- Router テストで「同じ output / gateway で 2 回 make しても型が FavoriteGroupView であること」以上に、
  親 Presenter がシート期間中に同一 Presenter を返すことを断言する。
- 空の `FavoriteGroupRouterProtocol` は作らない。
- 完了条件: 削除アラート表示中に親が再描画されてもアラートが消えない
  （手動 QA + 可能なら Presenter 保持のユニットテスト）。
- リスク: 中（シート寿命）。保持し続けると Gateway 差し替え後に古い子が残るので、
  `didTapShowFavorites` のたびに新規 assemble、閉じたら破棄、のルールをテストで固定する。

### Phase 5: 再利用部品（0.5 日）

- `SavedListRow` を Components へ。FavoriteGroup 行を置換。
- 編集 + 閉じるツールバーを共通化するか、FavoriteGroup 側の UX をテンプレに寄せる
  （編集中は選択しない、全削除後に editMode 解除）。
- テンプレ一覧への適用は **任意**。やるなら表示だけ。`@Query` は触らない。
- 完了条件: FavoriteGroup の行 UI がコンポーネント経由。差分が主に移動。
- リスク: 低。見た目を変えるならスクリーンショット比較。

### Phase 6: 性能・A11y・i18n・編集モード UX（0.5 日）

Phase 3–5 で残った品質項目。

- 編集中選択の無効化（Phase 5 で未了ならここで必須）。
- 閉じる / 編集 / 空状態の accessibilityHint を AttendeeList のシート導線と揃える。
- VoiceOver: 一覧 → 選択でシートが閉じ、参加者リストが置換されること。
- 削除失敗 / 読込失敗の VoiceOver アナウンス（alert タイトルが Catalog にあること）。
- Catalog は翻訳値を増やさない（ja のみ）方針を維持。キーを `String(localized:)` に揃えた漏れを埋める。
- `Self._printChanges()` でシート表示中の親再描画回数を Phase 4 前後で比較（任意）。
- 完了条件: 編集中に誤って読み込まない。空状態と 1 件状態で VoiceOver が辿れる。
- リスク: 低〜中（UX 差はテンプレ一覧との意図的統一）。

---

## 7. 見込み効果

| 指標 | 現状 | 目標 |
| --- | --- | --- |
| View が Entity を直接参照 | あり（`FavoriteGroupSnapshot`） | なし（`ViewData.Row` のみ） |
| 子の提示状態 | `alert` プロパティ | `route` 1 本 |
| PresenterProtocol の Gateway 露出 | `attachFavoriteGateway` | なし |
| 子 Entity ファイル | 不在（親に同居） | `FavoriteGroupEntity` |
| 親 Interactor の一覧・削除 | あり（本番未使用） | なし |
| 削除 API | `IndexSet` + 再 fetch | ID 配列 |
| 読込 API | `fetchAll` + 線形検索 | `fetch(id:)` |
| 取得失敗 UX | 空一覧（誤認） | アラート |
| Router コメント | 実装と矛盾 | assemble 時注入と一致 |
| シート中の子 Presenter | 再 assemble しうる | route 期間中は同一インスタンス |
| `@Model` が Interactor に出現 | あり | Gateway 内に閉じる |
| 行 UI の実装数（お気に入り / テンプレ） | 2 | 1（`SavedListRow`） |
| 編集中の誤選択 | 起きる | 起きない |
| FavoriteGroup ユニットテスト | 一覧 / 削除 / Output の基本 | 取得失敗、複数削除、シート identity、ID 削除 |

---

## 8. 検証戦略

1. **層ごとのユニットテスト**
   - **Interactor**: In-Memory Gateway で新しい順、ID 削除、複数削除、取得失敗の throws。
   - **Presenter**: 意図メソッド → 期待する ViewData / Route。削除失敗で alert route。
     選択は Output のみ。Gateway 型を Presenter テストが組み立てに使ってもよいが、
     Protocol 経由の attach は無い。
   - **Router**: 親 `makeFavoriteGroupModule` が FavoriteGroupRouter に委譲すること
     （既存）。Phase 4 で「シート期間中の同一インスタンス」を追加。
   - **親 Interactor**: 保存・上限・`loadFavorite(id:)`・attach。一覧・削除のケースは移設。
2. **回帰基準**: Phase 0 のテストを全フェーズで維持。取得失敗の既知挙動は Phase 2 で更新。
3. **既存 SeatingChart / SimpleShuffle / Share スイートを壊さないこと。**
   Entity 移設で import が足りないとコンパイルが落ちるだけなので、移設は 1 フェーズに閉じる。
4. **手動 QA（お気に入り導線）**
   - 空状態でシートを開く → 空メッセージ → 閉じる
   - 参加者を保存（上限未満）→ 一覧に出る → 選択でリストが完全置換される
   - スワイプ削除 / 編集モード削除
   - 最後の 1 件を消したあと空状態になり、編集モードが解除される
   - 編集モード中に行をタップしても読み込まれない
   - 上限 3 で保存ボタンがアラート。削除後に再保存できる
   - シートを下へスワイプして閉じても、閉じるボタンと同じく親 route が nil になる
   - 座席表 / 番号札へ進んで pop しても、保存済みグループは残る
5. **再描画**: シート表示中に親リストが不要に再構築されないこと。
   削除アラート表示中に親が `objectWillChange` しても子状態が消えないこと（Phase 4）。
6. **スクリーンショット**: 空 / 1 件 / 3 件、編集モード、ダークモード、Dynamic Type 最大。

---

## 9. 実装前に決めるべきこと（要判断）

1. **`GroupFavorite` フォルダ / 型名のリネーム**
   画面と `@Model` の語順を揃えると分かりやすいが、SwiftData のユニーク制約・既存ストアに触る。
   **推奨: 本計画ではリネームしない。** コメントで役割を固定する。
2. **共有型の置き場（FavoriteGroup vs Core）**
   Snapshot / Error は子モジュール所有が VIPER 的に綺麗。
   親と Gateway の両方から見えるので、将来件数が増えたら `Core/Entities` へ上げてよい。
   **推奨: まず `FavoriteGroupEntity.swift`。** 早すぎる Core 化はしない。
3. **親 Presenter からの Gateway 型排除の方法**
   (A) Router が親 Interactor を知る  
   (B) `makeFavoriteGroupModule(output:)` を Presenter が呼ぶとき、
       Router 実装が「Gateway は呼び出し側で既に親 Interactor にある」前提で
       Presenter から Interactor 参照を渡す  
   (C) 親 Interactor に `makeFavoriteGroupInteractor() -> FavoriteGroupInteractor` を置く  
   **推奨: (B) 相当。** `router.makeFavoriteGroupModule(gatewayHolder: interactor, output:)`
   のように Gateway 供給だけをプロトコル化し、Presenter は具象 Interactor を渡す
   （既存の具象保持規約と両立する）。
4. **シート identity の持ち方**
   親 Presenter が子 Presenter を保持するか、Router がキャッシュするか。
   **推奨: 親 Presenter が保持。** Router キャッシュは dismiss 漏れで stale Gateway になりやすい。
5. **取得失敗をアラートにするか**
   空配列のまま「グループなし」と出す今の挙動はバグに近い。
   **推奨: アラート。** Phase 0 で現状を固定し、Phase 2 で変える。
6. **編集中選択の無効化**
   テンプレ一覧は無効、お気に入りは有効。揃えない理由が無い。
   **推奨: 無効化。** Phase 5 または 6。
7. **テンプレ一覧まで同時に VIPER 化するか**
   **推奨: しない。** `SavedListRow` だけ先に出し、5d は座席計画に残す。
8. **`SaveAvailability` 共通化**
   AttendeeList §8.3 の未決。本計画では **触らない**。
9. **`AnyView` の許容範囲**
   Router の戻り値は現状どおり `AnyView`（SeatingChart と同じ）。View 内では禁止。
10. **削除確認ダイアログ**
    現状は即削除（スワイプ / 編集）。確認を足すと UX 変更になる。
    **推奨: 本計画では足さない。** 誤選択防止（編集中）だけ直す。

---

## 10. 想定工数

| Phase | 内容 | 工数 | VIPER 上の意義 |
| --- | --- | --- | --- |
| 0 | 準備・回帰テスト整備 | 0.5 日 | 移送の安全網。空配列誤認の固定 |
| 1 | デッド API・コメント・文言 API | 0.5 日 | 継ぎ目の嘘を消す |
| 2 | ViewData.Row / Route / Entity | 1.0 日 | **層間境界の確立**（View から Entity を排除） |
| 3 | Gateway ID 志向・親の複製 API 削除 | 1.0 日 | **永続化の単一窓口化** |
| 4 | シート identity / detent 位置 | 0.5 日 | 子モジュール寿命を Router/Presenter が握る |
| 5 | 再利用行・編集クロム | 0.5 日 | テンプレ一覧への布石 |
| 6 | A11y・編集中誤選択・i18n | 0.5 日 | 品質仕上げ |
| | **合計** | **4.5 日** | |

**推奨する区切り:**

- **第一弾（Phase 0〜2、2.0 日）**: 「View が Entity を知らない」「提示は route」。
  体感負債の大半（Snapshot 素通し、alert 二系統、コメント偽証、attach の死に API）がここで消える。
- **第二弾（Phase 3〜4、1.5 日）**: 永続化 API とシート寿命を親と同じ完成形にする。
- **第三弾（Phase 5〜6、1.0 日）**: 行の共通化と編集 UX / A11y。

Phase 2 を先に置く理由は SeatingChart / AttendeeList と同じで、
契約と ViewData を先に作ると Phase 3 の Gateway 差し替えで **View を触らずに済む**ため。

---

## 11. 着手時に触るファイル（目安）

変更予定（実装はまだ行わない）:

第一弾:

- `SakuttoSeat/Modules/FavoriteGroup/*`
- `SakuttoSeat/Modules/AttendeeList/AttendeeListEntity.swift`（型の移設）
- `SakuttoSeatTests/FavoriteGroupTests.swift`
- `SakuttoSeat/Localizable.xcstrings`（キー揃え。翻訳追加は原則なし）

第二弾:

- `SakuttoSeat/Core/Gateways/GroupFavoriteGateway.swift`
- `SakuttoSeat/Modules/GroupFavorite/GroupFavorite.swift`（`makeSnapshot` の所在）
- `SakuttoSeat/Modules/AttendeeList/AttendeeListInteractor.swift`
- `SakuttoSeat/Modules/AttendeeList/AttendeeListPresenter.swift`
- `SakuttoSeat/Modules/AttendeeList/AttendeeListContracts.swift`
- `SakuttoSeat/Modules/AttendeeList/AttendeeListRouter.swift`
- `SakuttoSeatTests/AttendeeListInteractorTests.swift`
- `SakuttoSeatTests/AttendeeListPresenterTests.swift`
- `SakuttoSeatTests/AttendeeListRouterTests.swift`

第三弾:

- `SakuttoSeat/Components/SavedListRow.swift`（新設）
- `SakuttoSeat/Modules/FavoriteGroup/FavoriteGroupView.swift`
- オプション: `SakuttoSeat/Modules/SeatingTemplate/SeatingTemplateListView.swift`（行だけ置換）

参照のみ（規約の正本）:

- `refactor_seating.md` §1
- `refactor_AttendeeList.md` §1 / Phase 5 実装時決定
- `refactor_simple.md`（空 RouterProtocol 禁止、二次 VIPER 化の型）
- `SakuttoSeat/Modules/VenueSettings/*`（薄い Presenter + Route の見本）
- `SakuttoSeat/Modules/BulkAdd/*`（同じ親を持つ子モジュール。Copy / Output）
- `SakuttoSeat/Modules/AttendeeList/AttendeeListViewData.swift`（Row 化の見本）

---

## 12. 分析時点のファイル実態（参照）

| ファイル | 行数目安 | 役割 |
| --- | --- | --- |
| `FavoriteGroupView.swift` | 105 | シート UI。Entity 素通し、独自 alert Binding |
| `FavoriteGroupPresenter.swift` | 64 | 薄い仲介。attach が死に、alert が route ではない |
| `FavoriteGroupInteractor.swift` | 42 | 一覧・削除。`try?` と IndexSet |
| `FavoriteGroupContracts.swift` | 60 | ViewData が Snapshot 配列。Gateway が Protocol に漏れている |
| `FavoriteGroupRouter.swift` | 23 | Builder のみ。コメントが実装と矛盾 |
| `GroupFavorite.swift` | 33 | SwiftData `@Model` + `makeSnapshot()` |
| `GroupFavoriteGateway.swift` | 85 | Base + SwiftData + InMemory。offset 削除、`fetch(id:)` なし |
| `AttendeeListInteractor.swift` | お気に入り部 | 保存・読込に加え、複製の一覧・削除 |
| `AttendeeListPresenter.swift` | Output + sheet | Gateway を取り出して毎回 assemble |
| `FavoriteGroupTests.swift` | 166 | Interactor / Presenter の基本。取得失敗の空配列は未カバー |

以上を、FavoriteGroup を「小さいから現状維持」にせず、
SeatingChart 系と同じ二次 VIPER 化の対象として扱うための計画とする。
