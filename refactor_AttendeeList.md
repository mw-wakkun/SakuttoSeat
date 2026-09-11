# AttendeeList モジュール リファクタリング計画書（VIPER 版）

対象: `SakuttoSeat/Modules/AttendeeList/` を中心に、未整備の関連モジュール
（`SimpleShuffle` / `GroupFavorite` / `SeatingTemplate` 一覧）と、
`refactor_seating.md` Phase 6 に持ち越された横断部品（DesignSystem / AdBanner）を含む。

作成日: 2026-09-11
アーキテクチャ: **VIPER**（View / Interactor / Presenter / Entity / Router）
前提: `refactor_seating.md` Phase 0〜5 は完了済み。本計画はそこで確定した
**SwiftUI 適応 VIPER 規約**を AttendeeList 系に適用する。

### 進捗

| Phase | 内容 | 状態 |
| --- | --- | --- |
| 0 | 準備と回帰テスト | ✅ 完了（2026-09-11） |
| 1 | ファイル分割・デッドコード削除・規約統一 | ✅ 完了（2026-09-11） |
| 2 | Contracts と ViewData / Route の導入 | ✅ 完了（2026-09-11） |
| 3 | Presenter → Interactor へのロジック移送・Gateway の正しい配置 | ✅ 完了（2026-09-11） |
| 4 | Router の実体化・遷移の Presenter 主導化 | 未着手 |
| 5 | 子モジュール切り出し（FavoriteGroup / BulkAdd）と SimpleShuffle の VIPER 化 | 未着手 |
| 6 | 再利用部品・パフォーマンス・A11y・i18n | 未着手 |

回帰基準: `SakuttoSeatTests` の既存スイート
（SeatingChart / Share / TableEdit / VenueSettings を含む）に加え、
Phase 0 で追加した `AttendeeListInteractorTests` / `AttendeeListPresenterTests`。
旧 `SakuttoSeatTests.swift` の 3 ケースは移設済み。以降の全フェーズでこれを維持する。

検証端末は `refactor_seating.md` と同じく iPhone 17 / iOS 26.5 を使用する
（iOS 18.4 シミュレータでは MainActor / protocol existential の解放不整合で
`malloc: pointer being freed was not allocated` が再現するため）。

---

## 0. エグゼクティブサマリ

AttendeeList はアプリのエントリ画面であり、参加者の登録・お気に入り・一括追加・
2 つの席決め画面への分岐を担う。ファイル構成は VIPER に見えるが、
**SeatingChart 系で確立した規約がここには適用されていない**。

分析の結論は次の 1 点に集約される。

> **「箱はあるが、SeatingChart の完成形と中身が噛み合っていない」**
> Interactor はメモリ内リスト操作に閉じ、永続化は Presenter が Gateway を直接握る。
> View は `@Query` / `@State` 10 個以上 / 業務分岐 / 遷移先の直接代入を持つ。
> Router は Builder と `AnyView` 工場に留まり、Presenter が `view(for:)` で遷移先を返す。
> 下流の SimpleShuffle は VIPER ですらなく、Presenter 1 枚にロジックとアニメーションが同居する。

各層の「あるべき責務」と「実際の中身」を対比すると次のとおり。

| 層 | VIPER における責務 | 現状 | 判定 |
| --- | --- | --- | --- |
| View | 受動的な描画とイベント転送のみ。Entity を知らない | `@Query` で `GroupFavorite` を直接購読、上限メッセージ生成、`presenter.destination` 直接代入、シート／アラートを `@State` で保持 | ✗ 重大 |
| Interactor | 全ビジネスロジックとデータストアへの唯一の窓口 | 参加者のメモリ操作のみ。お気に入り永続化を知らない。`SwiftUI` を import | ✗ 半空洞 |
| Presenter | ViewData 生成と Interactor / Router への仲介 | Entity を公開、Gateway を保持、`print` でエラー握り潰し、`AnyView` を返す | ✗ 過積載 |
| Entity | Interactor が扱う純粋なモデル | `Attendee` は妥当。`GroupFavorite`（SwiftData `@Model`）が View まで素通し | △ |
| Router | 画面遷移・モジュール組み立て・提示 | `assembleModule` + `AnyView` 2 本。Protocol なし。遷移状態は Presenter の公開プロパティ | ✗ 薄い |
| Contracts | 層間境界の明示 | **ファイルが存在しない** | ✗ 不在 |

本計画は `refactor_seating.md` の規約を**維持したまま**、上記の責務を正しい層へ移送する。
主要な作業は次の 4 本柱。

1. **View → Presenter**: `@State` / `@Query` / 業務分岐 / 遷移代入を剥がす
2. **Presenter → Interactor**: お気に入り永続化・一括置換・上限判定を移送する
3. **Router の実体化**: `view(for:)` と `destination` 直接代入を廃止する
4. **子モジュール化**: お気に入り一覧・一括追加を独立させ、SimpleShuffle を正式な VIPER にする

SeatingChart 側で既に存在する資産（`FeatureLimit` / `GroupFavoriteGateway` /
`Share` / `ActionButtonsView` / MainActor + 具象保持の deinit 回避）は再利用し、
同じ問題を二度設計しない。

---

## 1. 本プロジェクトにおける VIPER の解釈（再掲・AttendeeList 向け注釈）

古典的 VIPER は UIKit + delegate 前提のため、SwiftUI に合わせて次のように読む。
**これは `refactor_seating.md` §1 と同一の全社規約**であり、本モジュールも例外にしない。

| 層 | 実装形態 | 依存してよいもの | 禁止事項 |
| --- | --- | --- | --- |
| **View** | `struct: View`。`@StateObject var presenter` を保持 | Presenter が公開する **ViewData** と **Route** のみ | Entity の直接参照、`@Query`、`ModelContext`、業務条件分岐、遷移状態の保持 |
| **Presenter** | `@MainActor final class: ObservableObject` + `PresenterProtocol` | Interactor（具象）、Router（具象）、Entity → ViewData 変換 | ビジネスルールの判断、永続化、SwiftUI の描画 API、`AnyView` の工場化 |
| **Interactor** | `nonisolated final class: InteractorProtocol` | Entity、Entity Gateway（`*GatewayBase`） | `SwiftUI` / `UIKit` の import、Presenter・View への参照 |
| **Entity** | 値型 `struct` / `enum` | `Foundation` のみ | ロジック（軽量な計算プロパティは可） |
| **Router** | `final class: RouterProtocol` | 子モジュールの Builder、遷移先生成 | ビジネスルール、Entity の加工 |

補足（AttendeeList 固有）:

- **`ObservableObject` は Protocol に載せない。** SeatingChart と同じく、
  protocol existential を MainActor クラスが保持すると deinit で malloc abort するため、
  Interactor / Router / Gateway は**具象型（または `*GatewayBase`）で保持**する。
- **Gateway の attach は Interactor の責務。** 現状は Presenter が
  `attachFavoriteGateway` を持ち、View の `onAppear` で `ModelContext` を渡している。
  SeatingChart は Interactor が `attachTemplateGateway` を持つ。こちらに揃える。
- **永続化モデル（`@Model`）は View に出さない。** `@Query` で `GroupFavorite` を描画しているのは
  VIPER 違反であり、同時に Presenter 経由の Gateway と**二重の真実**になっている。
- **遷移は Presenter の `route` が単一の真実。** View が `presenter.destination = .seatingChart`
  と書き込む現状は、SeatingChart の `didTapSettings()` → `route = .venueSettings` と真逆。

---

## 2. 現状の責務違反マッピング

### 2.1 View に置かれているが View の責務でないもの

`AttendeeListView.swift`（391 行 / 3 型）の内訳。

| 行 | 内容 | 本来の層 |
| --- | --- | --- |
| 13–18, 24–29 | シート／アラート／入力の `@State` が 10 個以上 | **Presenter の Route**（入力欄のフォーカスと一時テキストのみ View に残してよい） |
| 21 | `@Environment(\.modelContext)` | View は SwiftData を知らない。assemble 時に Gateway を注入 |
| 24 | `@Query` で `GroupFavorite` を直接購読 | **Interactor + Gateway**。View は ViewData の一覧だけを描く |
| 102–104 | `onAppear` で Gateway 生成 + attach | **Router.assembleModule**（または Presenter 経由で Interactor） |
| 109–111 | `navigationDestination` が `presenter.view(for:)` を呼ぶ | **Router**。Presenter は destination をセットするだけ |
| 115–124 | `onSaveButtonTapped` が上限判定と文言組み立て | **Interactor（判定）→ Presenter（Route）** |
| 129–135 | グループ名 trim を View が再実施 | **Interactor**（二重 trim。Presenter は渡すだけ） |
| 137–174 | `bulkAddSheetView` がシート UI と Presenter 呼び出しを内包 | **子 VIPER モジュール（BulkAdd）** または Route 駆動の独立 View |
| 176–232 | `favoriteGroupSheetView` が Entity を `ForEach` し、削除も View 起点 | **子 VIPER モジュール（FavoriteGroup）** |
| 285–286, 293–294 | `presenter.destination = ...` を View が直接代入 | **Presenter**（`didTapSeatingChart()` / `didTapSimpleShuffle()`） |
| 289, 297 | `newName.isEmpty` で席決めボタンを disable | 一時入力は View でよいが、**「未確定入力がある」フラグは ViewData に寄せると一貫する** |
| 323–341 | `buttonLabel` が `AnyView` で背景を分岐 | **再利用コンポーネント**（DesignSystem） |
| 354–378 | `AttendeeRow` が同一ファイル | **Components**（番号札画面と共通化可能） |
| 380–391 | `Color.sakuttoBlueStart` 等のデザイントークン | **Core/DesignSystem**（`refactor_seating.md` Phase 6 の持ち越し） |

View が持っている提示状態の一覧（SeatingChart では `route` 1 本に集約済み）:

- `isShowingBulkAddSheet`
- `isShowingResetAlert`
- `isShowingSaveAlert`
- `isShowingLimitAlert`
- `isShowingFavoriteSheet`
- `presenter.destination`（ナビゲーション）

### 2.2 Presenter に置かれているが Interactor / Router の責務であるもの

`AttendeeListPresenter.swift`（129 行）。SeatingChart ほど肥大していないが、
**層の向きが逆**の処理が混在している。

| 行 | メソッド | 内容 | 本来の層 |
| --- | --- | --- | --- |
| 21 | `@Published var destination` が外部から set 可能 | View が遷移を駆動 | **Presenter が set、View は読むだけ** |
| 26 | `favoriteGateway` を Presenter が保持 | 永続化の窓口 | **Interactor** |
| 36–38 | `attachFavoriteGateway` | 同上 | **Interactor** |
| 48–50 | `didTapShuffleButton` | 呼び出し元が無いデッドコード | 削除、または SimpleShuffle 側へ |
| 52–56 | `didDeleteAttendee` | `offsets.forEach` の内側で同じ `IndexSet` を繰り返し `remove` | **バグ**。1 回呼べば足りる |
| 64–70 | `favoriteSaveAvailability` | Gateway の `fetchCount` と `FeatureLimit` 判定 | **Interactor** |
| 73–82 | `didTapSaveFavoriteGroup` | `GroupFavorite` 生成 + `insert` + `print` | **Interactor**。失敗は Route でユーザーへ |
| 85–94 | `didSelectFavoriteGroup` | `removeAll` + `add` のループ | **Interactor.replaceAll(names:)** |
| 96–103 | `didDeleteFavoriteGroup` | 単体削除。View から呼ばれていない | デッド、または一覧モジュールへ |
| 105–112 | `didDeleteFavoriteGroups` | Gateway から再 fetch して offset 削除 | **Interactor** |
| 116–123 | `view(for:)` が `AnyView` を返す | 遷移先の組み立て | **Router** |
| 64 | 戻り値が `TemplateSaveAvailability` | 座席テンプレート用の型をお気に入りに流用 | **共通化するか `FavoriteSaveAvailability` に改名** |

加えて Presenter 固有の問題:

- **`PresenterProtocol` が存在しない。** View が具象クラスに直依存。
- **`final` が付いていない。** SeatingChart / VenueSettings / TableEdit / Share は `final`。
- **Entity（`[Attendee]`）を View に公開している。** SeatingChart は `viewData` のみ。
- **保存失敗が `print` で消える。** SeatingChart は `route = .alert(.saveFailed)`。
- **お気に入り読込後に空配列になり得る。** `group.members` が空、または全要素が trim 後空だと
  `updatedAttendees` の初期値 `[]` のまま代入される（現状は許容でもテストで固定すべき）。

### 2.3 Interactor の半空洞化

`AttendeeListInteractor.swift` は参加者のメモリ操作としては整っている。
ユニーク名付与・一括パース・シャッフル再試行はドメインロジックとして妥当。

欠けているのは次。

- **お気に入りの永続化・上限判定・一括置換。** すべて Presenter 側。
- **API の非対称。** `add` / `shuffle` / `remove` は `[Attendee]` を返すのに
  `add(fromText:)` だけ `Void`。Presenter が直後に `allAttendees()` を呼び直している。
- **`import SwiftUI`。** `IndexSet` は Foundation。SeatingChart Interactor は `Foundation` のみ。
- **`nonisolated` / `final` が無い。** 規約不一致。
- **Protocol はあるが Presenter は具象に依存**（deinit 回避としては正しいが、
  Protocol を Contracts に移し、テストは具象 + In-Memory Gateway で書く形に揃える）。

### 2.4 Router の薄さ

`AttendeeListRouter.swift`（40 行）:

- `assembleModule` は妥当（アプリエントリ）。
- `makeSeatingChartView` は `SeatingChartRouter.assembleModule` へ委譲しており方向は正しい。
- `makeSimpleShuffleView` は **SimpleShuffle に Router が無いため、ここで Presenter を直接生成**している。
  子モジュールの Builder 規約が崩れている。
- `RouterProtocol` が無い。
- 遷移の発動は View → `presenter.destination =` であり、Router は「呼ばれたら View を返す工場」に過ぎない。

### 2.5 下流モジュールの未整備（本計画の関連範囲）

**SimpleShuffle**（Presenter + View のみ）:

| 問題 | 場所 |
| --- | --- |
| Interactor / Router / Contracts / Entity が無い | モジュール全体 |
| Presenter が `attendees.shuffle()` と `withAnimation` を同居 | `SimpleShufflePresenter.swift:24-28` |
| `ForEach(..., id: \.self)` + `firstIndex(of:)` で番号を再探索（O(n²)、同名で破綻） | `SimpleShuffleView.swift:19-25` |
| 行 UI が画面用とスナップショット用で二重 | `:20-44` と `SimpleShuffleSnapshotView:99-126` |
| 入力が `[String]`。親は `attendees.map(\.name)` で ID を捨てている | `AttendeeListRouter.swift:36` |

**SeatingTemplateListView**（お気に入りシートの双子）:

- `@Query` + `modelContext.delete` を View が直接実行（`SeatingTemplateListView.swift:94-103`）。
- SeatingChart Router がクロージャ付きの素の View を包んでいるだけ
  （`SeatingChartRouter.swift:46-53`）。
- AttendeeList のお気に入り一覧と空状態・編集・削除が構造的に同一。
  FavoriteGroup を子モジュール化するなら、テンプレート一覧も同じ型に揃える価値がある。
  （本計画の本丸は AttendeeList。テンプレート一覧は Phase 5 のオプションとする。）

---

## 3. 層をまたぐ課題（VIPER 是正と並行して対応）

### 3.1 再利用性

**(A) 番号付き行が 3 実装**
`AttendeeRow`、`SimpleShuffleView` の行、`SimpleShuffleSnapshotView` の行。
差分は「番席」ラベルと色（`sakuttoBlueStart` vs `Color.blue`）程度。

**(B) 保存済み一覧シートが 2 実装**
お気に入りグループ（AttendeeList 内）とテンプレート一覧。
空状態・List・削除・閉じるボタンがほぼ同じ。

**(C) 上限アラート文言が 2 箇所で手書き**
お気に入り（`AttendeeListView.swift:120-121`）とテンプレート
（`SeatingChartView.swift:205`）。`FeatureLimit` は単一定義済みだが、文言は分散。

**(D) プライマリ／セカンダリ CTA がインライン**
`buttonLabel`（`AttendeeListView.swift:323-341`）が `AnyView` で背景を分岐。
グラデーションボタンは他画面でも使える。

**(E) 広告バナーが 320×50 固定**
`AttendeeListView` / `SeatingChartView` / `SimpleShuffleView` の 3 箇所。
`refactor_seating.md` Phase 6 の持ち越し。

**(F) デザイントークンが AttendeeListView 末尾に同居**
`Color.sakuttoBlueStart` を App / Share / 本画面が参照。モジュール境界が壊れている。

**(G) 文字列が全てインライン日本語リテラル**
String Catalog 未導入（Phase 6 で SeatingChart と一括）。

### 3.2 パフォーマンス

| # | 内容 | 場所 |
| --- | --- | --- |
| 1 | **`@Query` がルート View を購読。** お気に入りの増減で参加者リスト全体が再評価される。シートを出していないときも無効化されない | `AttendeeListView.swift:24` |
| 2 | **お気に入りの二重ソース。** View は `@Query`、削除時は Gateway が `fetchAll` し直す。表示と削除対象がずれる余地がある | View `:24` / Presenter `:105-111` |
| 3 | **削除が offset を二重適用。** 複数行削除で 2 回目以降はずれた index を消す／クラッシュし得る | Presenter `:52-56` |
| 4 | **お気に入り読込が N 回の `add`。** 毎回ユニーク名走査（O(n²)） | Presenter `:88-91` / Interactor `:87-94` |
| 5 | **一括追加も 1 件ずつ `add`。** 大量ペーストで同じ O(n²) | Interactor `:73-77` |
| 6 | **`ForEach(Array(enumerated()), id: \.element.id)`。** identity は安定だが、番号表示のために全行が index 依存。先頭削除で全行が再描画される（番号更新としては正しいが、ViewData 側で番号を確定すれば差分は名前変更行だけにできる） | View `:268` |
| 7 | **番号札が `id: \.self` + `firstIndex(of:)`。** 同名で identity 衝突、各行が線形探索 | `SimpleShuffleView.swift:19-25` |
| 8 | **ルートに `.onTapGesture`。** リストのスワイプ削除やボタンとジェスチャが競合し得る。フォーカス解除はスクロール／ツールバー操作に寄せる | View `:106-108` |
| 9 | **ボトムバーが `Spacer().frame(height: 200/240)`。** 固定余白は Dynamic Type / 端末差で過不足。SeatingChart は `safeAreaInset` | View `:50-51` vs `SeatingChartView.swift:92-94` |
| 10 | **`buttonLabel` の `AnyView`。** 型消去で描画キャッシュが効きにくい | View `:333-335` |
| 11 | **`AdBannerView` が `makeUIView` のたび `load`。** 親の再描画でバナーが再生成され得る（`updateUIView` は空） | `AdBannerView.swift:13-33` |
| 12 | **Presenter が `[Attendee]` を丸ごと `@Published`。** 1 名追加でリスト全体が無効化。Equatable な ViewData 行にすればスキップ余地がある |

### 3.3 正確性・保守性リスク

| # | 内容 | 場所 |
| --- | --- | --- |
| 1 | **複数削除バグ**（上述） | Presenter `:52-56` |
| 2 | **未使用 API**。`didTapShuffleButton` / `didDeleteFavoriteGroup` | Presenter |
| 3 | **保存失敗がユーザーに見えない** | Presenter `:79-81` |
| 4 | **Gateway 未接続時は上限が常に available。** `fetchCount` 失敗を `?? 0` にしている | Presenter `:65` |
| 5 | **`onAppear` のたびに Gateway を作り直す。** 実害は小さいが、テストと寿命が曖昧 | View `:102` |
| 6 | **入力中は席決め不可。** 仕様としては妥当だが Presenter に意図メソッドが無く、理由が View に埋没 | View `:289` |
| 7 | **一括追加の区切りが View 文言と Interactor で微妙に不一致。** UI は「改行またはカンマ（、）」、実装は `\n\r,、`（半角カンマも可） | View `:140` / Interactor `:99` |
| 8 | **SimpleShuffle が名前だけ受け取る。** 登録順の安定 ID が落ち、共有・再シャッフルの identity が名前依存 | Router `:36` |
| 9 | **Interactor Protocol がファイル内にあり、Contracts が無い。** 他モジュールと非対称 | Interactor `:11-31` |
| 10 | **テストが 3 件。** ユニーク名、一括追加、お気に入り上限、複数削除、空名前拒否が未カバー。`testShuffleChangesOrder` は稀に失敗し得る | `SakuttoSeatTests.swift` |
| 11 | **アクセシビリティ未対応。** 追加ボタン、席決め CTA、お気に入り行に label / hint が無い | View 全体 |
| 12 | **コメント言語とエラーログが混在。** 削除失敗だけ英語 `print` | Presenter `:110` |

---

## 4. 目標構成

### 4.1 モジュール契約（Contracts）

`AttendeeListContracts.swift` を新設し、SeatingChart と同じ 4 境界（View←Presenter /
Presenter→Interactor / Presenter→Router / 子モジュール Output）を明示する。

```swift
// AttendeeListContracts.swift

// MARK: View <- Presenter

@MainActor
protocol AttendeeListPresenterProtocol: AnyObject {
    var viewData: AttendeeListViewData { get }
    var route: AttendeeListRoute? { get set }

    func onAppear()
    func didTapAdd(name: String)
    func didTapBulkAdd(text: String)
    func didDeleteAttendees(at offsets: IndexSet)
    func didTapReset()
    func didTapSaveFavorite()
    func didConfirmSaveFavorite(name: String)
    func didTapShowFavorites()
    func didTapBulkAddEntry()
    func didTapSeatingChart()
    func didTapSimpleShuffle()
    func dismissRoute()
}

// MARK: Presenter -> Interactor

nonisolated protocol AttendeeListInteractorProtocol: AnyObject {
    func allAttendees() -> [Attendee]
    func add(name: String) -> [Attendee]
    func add(fromText text: String) -> [Attendee]
    func replaceAll(names: [String]) -> [Attendee]
    func remove(atOffsets offsets: IndexSet) -> [Attendee]
    func removeAll() -> [Attendee]

    func favoriteSaveAvailability() -> FavoriteSaveAvailability
    func saveCurrentAsFavorite(named name: String) throws
    func allFavorites() -> [FavoriteGroupSnapshot]
    func deleteFavorites(at offsets: IndexSet) throws
    func loadFavorite(id: FavoriteGroupID) throws -> [Attendee]

    func attachFavoriteGateway(_ gateway: GroupFavoriteGatewayBase)
}

// MARK: Presenter -> Router

protocol AttendeeListRouterProtocol: AnyObject {
    @MainActor func makeSeatingChartModule(attendees: [Attendee]) -> AnyView
    @MainActor func makeSimpleShuffleModule(attendees: [Attendee]) -> AnyView
    @MainActor func makeFavoriteGroupModule(output: (any FavoriteGroupModuleOutput)?) -> AnyView
    @MainActor func makeBulkAddModule(output: (any BulkAddModuleOutput)?) -> AnyView
}

// MARK: 子モジュール Output

protocol FavoriteGroupModuleOutput: AnyObject {
    func favoriteGroupDidSelect(id: FavoriteGroupID)
    func favoriteGroupDidCancel()
}

protocol BulkAddModuleOutput: AnyObject {
    func bulkAddDidConfirm(text: String)
    func bulkAddDidCancel()
}
```

実装上の制約（SeatingChart 踏襲）:

- Protocol に `ObservableObject` を載せない。
- Presenter は Interactor / Router を**具象型**で保持する。
- Gateway は `GroupFavoriteGatewayBase` を Interactor が保持する（既存クラスを移動せず再利用）。

### 4.2 表示専用モデル

```swift
struct AttendeeListViewData: Equatable {
    struct Row: Identifiable, Equatable {
        let id: UUID
        let number: Int          // 1-based。View は index を計算しない
        let name: String
    }

    let rows: [Row]
    let isEmpty: Bool
    let canStartSeating: Bool    // 参加者 1 名以上
    let canSaveFavorite: Bool
    let canReset: Bool
}

enum AttendeeListRoute: Identifiable, Equatable {
    case seatingChart
    case simpleShuffle
    case favoriteList
    case bulkAdd
    case saveFavoritePrompt
    case alert(AttendeeListAlert)

    var presentsAsSheet: Bool { /* favoriteList, bulkAdd */ }
    var presentsAsNavigation: Bool { /* seatingChart, simpleShuffle */ }
    var presentsAsAlert: Bool { /* saveFavoritePrompt, alert */ }
}

enum AttendeeListAlert: Equatable {
    case confirmReset
    case favoriteLimitReached(currentCount: Int, limit: Int)
    case saveFailed(message: String)
}

/// SwiftData モデルを View / Presenter から隔離する
struct FavoriteGroupSnapshot: Identifiable, Equatable {
    let id: FavoriteGroupID
    let name: String
    let memberNames: [String]
    let memberSummary: String    // 表示用（", " 結合・行数制限は ViewData 側でも可）
}
```

`TemplateSaveAvailability` のお気に入り流用は、次のいずれかで解消する
（§8 の判断事項）。

- `SaveAvailability` に改名してテンプレートと共有する
- `FavoriteSaveAvailability` を別名で置き、中身は同じ associated value にする

### 4.3 View に残してよいもの

VIPER を徹底しても、SwiftUI の入力コンポーネントはローカル `@State` が必要。
残すのは次に限定する。

| 残す | 理由 |
| --- | --- |
| `newName` + `@FocusState` | 未確定のキー入力。確定時だけ Presenter へ |
| 保存アラートの `TextField` 用 `groupName` | SeatingChart の `templateName` と同じ |
| 一括追加を子モジュール化しない場合の `bulkInputText` | 子モジュール化するならそちらへ移す |

消すもの: シート／アラート／遷移の Bool、`@Query`、`modelContext`、上限メッセージ、
`destination` への代入、`view(for:)` 呼び出し。

目標: `AttendeeListView` は **1 型 / 200 行以下**。`@State` は 3 個以下。

### 4.4 目標ディレクトリ構成

```
SakuttoSeat/
├── Core/
│   ├── DesignSystem/
│   │   ├── AppColor.swift              // sakuttoBlueStart / Gradient（AttendeeListView 末尾から移設）
│   │   ├── AppSpacing.swift            // ボトム余白・バナーサイズ
│   │   └── AppButtonStyles.swift       // Primary / Secondary CTA（AnyView 廃止）
│   └── Gateways/
│       └── GroupFavoriteGateway.swift  // 既存。Presenter ではなく Interactor が保持
├── Modules/
│   ├── AttendeeList/
│   │   ├── AttendeeListContracts.swift
│   │   ├── AttendeeListEntity.swift    // Attendee + FavoriteGroupSnapshot
│   │   ├── AttendeeListInteractor.swift
│   │   ├── AttendeeListPresenter.swift
│   │   ├── AttendeeListRouter.swift
│   │   ├── AttendeeListViewData.swift
│   │   ├── AttendeeListRoute.swift
│   │   └── View/
│   │       └── AttendeeListView.swift
│   ├── FavoriteGroup/                  // ★ お気に入り一覧（現 favoriteGroupSheetView）
│   │   ├── FavoriteGroupContracts.swift
│   │   ├── FavoriteGroupInteractor.swift
│   │   ├── FavoriteGroupPresenter.swift
│   │   ├── FavoriteGroupRouter.swift
│   │   └── FavoriteGroupView.swift
│   ├── BulkAdd/                        // ★ 一括追加（現 bulkAddSheetView）
│   │   ├── BulkAddContracts.swift
│   │   ├── BulkAddPresenter.swift      // 入力検証が主。Interactor は薄くてよい
│   │   ├── BulkAddRouter.swift
│   │   └── BulkAddView.swift
│   └── SimpleShuffle/                  // ★ 欠層を補充
│       ├── SimpleShuffleContracts.swift
│       ├── SimpleShuffleEntity.swift   // NumberedSeat（id + name + number）
│       ├── SimpleShuffleInteractor.swift
│       ├── SimpleShufflePresenter.swift
│       ├── SimpleShuffleRouter.swift
│       ├── SimpleShuffleViewData.swift
│       └── View/
│           ├── SimpleShuffleView.swift
│           └── SimpleShuffleSnapshotView.swift
└── Components/
    ├── NumberedPersonRow.swift         // AttendeeRow と番号札行を統合
    ├── EmptyStateView.swift            // 参加者ゼロ / お気に入りゼロ
    └── AdBannerContainer.swift         // アダプティブバナー（Phase 6）
```

`GroupFavorite`（SwiftData `@Model`）は Gateway の内側に閉じ、
モジュール公開面は `FavoriteGroupSnapshot` のみとする。

### 4.5 子モジュール間の通信

SeatingChart の `TableEditModuleOutput` と同じ一方向通知。

- お気に入り選択 → `favoriteGroupDidSelect(id:)` → 親 Interactor が `loadFavorite`
- 一括追加確定 → `bulkAddDidConfirm(text:)` → 親 Interactor が `add(fromText:)`
- 親 View は子の Entity / `@Query` を見ない

テンプレート一覧（オプション）も `templateListDidSelect` は既にあるので、
削除と一覧表示を Gateway 経由に移すだけで同じ型に揃う。

### 4.6 再利用コンポーネント

**(1) 番号付き行**

```swift
struct NumberedPersonRow: View {
    let number: Int
    let name: String
    var accessory: String? = nil   // 番号札の「番席」
    var tint: Color = .sakuttoBlueStart
}
```

**(2) CTA ボタン（AnyView 廃止）**

```swift
struct SakuttoPrimaryButtonStyle: ButtonStyle { /* Gradient */ }
struct SakuttoSecondaryButtonStyle: ButtonStyle { /* tint.opacity(0.1) */ }
```

`@ViewBuilder` で背景を分岐すれば型消去は不要。

**(3) ボトムクロム**

SeatingChart の `safeAreaInset` に合わせ、固定 `Spacer(height: 200/240)` を廃止する。
バナーサイズは `AdBannerContainer` が決める。

---

## 5. 実行計画（フェーズ分割）

各フェーズは独立してマージ可能。
**「箱を揃える → 契約を入れる → 中身を移す → 子を切る」** の順。
挙動を変えない整理を先に済ませる。SeatingChart の順序と同じ。

### Phase 0: 準備と回帰テスト（0.5 日）

現状の挙動を固定する characterization test を `AttendeeListInteractorTests` /
`AttendeeListPresenterTests` に切り出す（`SakuttoSeatTests.swift` の 3 件は移設）。

最低限カバーする仕様:

- 前後空白の trim、空文字は追加しない
- 同名は `name` / `name(2)` / `name(3)`
- 一括追加: 改行・`,`・`、`、空要素スキップ
- 単一削除 / **複数削除（現バグの再現を `_既知の課題` 付きで記録）**
- 全削除
- お気に入り: 上限 3、保存、読込でリスト置換、offset 削除
- `InMemoryGroupFavoriteGateway` を使う（既存）
- シャッフルは「要素集合が変わらない」を主断言にし、順序変更は flaky にしない

完了条件: 見た目を変えずにテスト green。以降の回帰基準とする。
リスク: 低。

### Phase 1: ファイル分割・デッドコード削除・規約統一（0.5 日）

- `AttendeeRow` と `Color` 拡張をファイル分割（ロジック変更なし）。
  Color は最終的に DesignSystem へ移すが、Phase 1 ではファイル分離まででも可。
- 削除: `didTapShuffleButton`、`didDeleteFavoriteGroup`（呼び出し元なし）。
- `didDeleteAttendee` の二重 `remove` を **1 回呼び出しに修正**（バグ修正。Phase 0 の
  `_既知の課題` テストを同時に更新）。
- `final` / `@MainActor` / Interactor の `nonisolated` + `import Foundation` のみ、に揃える。
- `add(fromText:)` が `[Attendee]` を返すよう API を対称化（Presenter の二度読みを解消）。
- エラー `print` の言語を日本語に揃える（ユーザー向け Route 化は Phase 3）。
- 完了条件: ビルド成功、Phase 0 green、差分が移動・削除・バグ修正に限定。
- リスク: 低。

### Phase 2: Contracts と ViewData / Route の導入（1.5 日）

**本計画の中核。View から Entity と `@Query` を排除する。**

- `AttendeeListContracts` / `AttendeeListViewData` / `AttendeeListRoute` を新設。
- View のシート／アラート／`destination` を `presenter.route` 1 本に統合。
  バインディング分割は `SeatingChartView` の `sheetRouteBinding` /
  `savePromptBinding` を踏襲。
- `presenter.destination =` を廃止し、`didTapSeatingChart()` /
  `didTapSimpleShuffle()` に置換。
- 参加者リストは `viewData.rows` のみ。`Attendee` / `GroupFavorite` 型名が
  View に現れないこと。
- お気に入り一覧は、この Phase ではまだ同一ファイルでもよいが、
  渡すデータは `FavoriteGroupSnapshot` に限定する（`@Query` 廃止）。
  一覧の購読は Presenter が Gateway 結果を ViewData に載せるか、
  シート提示中だけ子が持つ（Phase 5 で子へ完全移譲）。
- `onSaveButtonTapped` の上限分岐を Presenter へ。View は Route を描くだけ。
- 完了条件: View に `GroupFavorite` / `Attendee` / `modelContext` / `@Query` が無い。
  `@State` が 3 個以下。Presenter テストダブルで Preview が作れる。
- リスク: 中（提示状態の総入れ替え）。→ Phase 0 の Presenter テストを先に Route 契約へ拡張。

### Phase 3: Presenter → Interactor へのロジック移送（1 日）

- Gateway 保持と `attachFavoriteGateway` を Interactor へ移動。
  View の `onAppear` attach をやめ、`assembleModule` 時点では In-Memory、
  実画面では SeatingChart と同様に初回だけ SwiftData Gateway を渡す
  （理想は Router が `modelContext` を受け取らない形。SwiftData の制約上、
  過渡期は Presenter `attach` → Interactor 委譲でもよいが、View からは消す）。
- `favoriteSaveAvailability` / `saveCurrentAsFavorite` / `allFavorites` /
  `deleteFavorites` / `loadFavorite` / `replaceAll` を Interactor へ。
- 保存失敗を `FavoriteSaveError`（または既存に近い enum）で `throws` し、
  Presenter が `route = .alert(.saveFailed)` にする。`print` をやめる。
- ユニーク名生成を一括追加・お気に入り読込で共有する内部 API にまとめ、
  名前集合を一度だけ作って O(n) に近づける（Phase 6 でも可。件数が多い一括追加だけ先に直す）。
- Presenter は `publishState()` だけが ViewData を更新する形に純化
  （`VenueSettingsPresenter` と同じ）。
- 完了条件: Presenter に Gateway / `FeatureLimit` / `GroupFavorite` 生成が無い。
  Interactor が `SwiftUI` を import していない。
- リスク: 中。お気に入り読込の置換仕様をテストで固定してから移す。

### Phase 4: Router の実体化と遷移の一本化（0.5 日）

- `AttendeeListRouterProtocol` を実装。
- Presenter の `view(for:)` を削除し、View は

  ```swift
  .navigationDestination(item: navigationRouteBinding) { route in
      presenter.makeRouteView(route)  // 内部で router に委譲
  }
  .sheet(item: sheetRouteBinding) { route in
      presenter.makeRouteSheet(route)
  }
  ```

  とする（SeatingChart の `makeRouteSheet` と同じ形）。
- SimpleShuffle の組み立てを `SimpleShuffleRouter.assembleModule(attendees:)` に委譲
  （SimpleShuffle 本体の VIPER 化は Phase 5。Phase 4 では Router の箱だけ先に作ってもよい）。
- `AnyView` は Router 境界に限定し、モジュール内のボタン背景からは排除。
- 完了条件: View が子モジュール型名を知らない。Presenter が `AnyView` を自分で組み立てない
  （委譲メソッド 1 本は SeatingChart 踏襲で許容）。
- リスク: 低〜中。

### Phase 5: 子モジュール切り出しと SimpleShuffle の VIPER 化（2 日）

**(5a) FavoriteGroup モジュール**

- `favoriteGroupSheetView` を独立させる。
- 一覧の取得・削除は `GroupFavoriteGateway` をこの Interactor が持つ
  （親と Gateway を共有するか、同じ SwiftData context から各々生成するかは §8）。
- 選択結果は `FavoriteGroupModuleOutput` のみ。
- 空状態は `EmptyStateView` をテンプレート一覧と共有できる形にする。

**(5b) BulkAdd モジュール**

- 入力・プレースホルダ・区切り説明をこの View に閉じる。
- パースは親 Interactor に残す（ドメインの単一所在）。子はテキストを返すだけ。
- 区切り文字の説明文を実装（`\n , 、`）に一致させる。

**(5c) SimpleShuffle の正式 VIPER 化**

- Interactor が `[NumberedSeat]` を保持し、`shuffle()` は集合不変・順序変更。
- Presenter は ViewData を公開。`withAnimation` は View 側
  （SeatingChart のシャッフルボタンと同じ）。
- 親からは `[Attendee]` を渡し、ID を維持する。
- `ForEach(id: \.self)` / `firstIndex` を廃止し、ViewData の `number` + 安定 `id` を使う。
- 行 UI は `NumberedPersonRow` に統合。Snapshot は style だけ変える。
- Share モジュールはそのまま使う（Phase 5 済み資産）。

**(5d オプション) SeatingTemplateListView の Gateway 化**

- お気に入りと同じ穴（`@Query` + View 削除）を塞ぐ。
- AttendeeList 完了後でも、差分が小さいうちに揃えると後の Phase 6 が楽。

完了条件: `AttendeeListView` が 200 行以下 / 1 型。シート UI が子モジュールにのみ存在する。
SimpleShuffle に Contracts がある。共有フローは引き続き Share モジュールのみ。
リスク: 中（シート UX の変化）。お気に入り読込・削除・上限の手動 QA を必須にする。

### Phase 6: 再利用部品・パフォーマンス・A11y・i18n（1.5 日）

`refactor_seating.md` Phase 6 と**同一バックログを共有**する。重複実装しない。

AttendeeList 側で必ず拾う項目:

- `Core/DesignSystem` へ色・余白・ボタンスタイルを移設
- `NumberedPersonRow` / `EmptyStateView` で重複行を削減
- ボトムバーを `safeAreaInset` 化
- `AdBannerView` のアダプティブ化と、親再描画での再 `load` 防止
  （`Coordinator` で 1 度だけ load、または表示中コンテナで保持）
- ルート `onTapGesture` をやめ、スクロール開始 / 追加確定時にフォーカスを外す
- 一括追加・お気に入り読込のユニーク名を O(n) に
- 座席・追加・CTA に `accessibilityLabel` / `accessibilityHint`
- String Catalog（SeatingChart と同時が望ましい）

完了条件: AttendeeList 系の重複行が目視で半減。バナーが再描画で点滅しない。
VoiceOver で追加〜席決めまで辿れる。
リスク: 中（レイアウト）。スクリーンショット比較を必須にする。

---

## 6. 見込み効果

| 指標 | 現状 | 目標 |
| --- | --- | --- |
| `AttendeeListView.swift` の行数 | 391 行 / 3 型 | 200 行以下 / 1 型 |
| View 内の `@State` 数 | 10 個以上 | 3 個以下 |
| View の `@Query` / `ModelContext` | あり | なし |
| View が Entity を直接参照 | あり（`Attendee` / `GroupFavorite`） | なし（ViewData のみ） |
| Presenter の Gateway 保持 | あり | なし（Interactor） |
| Presenter の `AnyView` 工場 | `view(for:)` | Router へ委譲 |
| モジュール契約 Protocol | Interactor のみ（ファイル内） | Contracts に集約 |
| 複数行削除 | バグあり | 1 回の `remove(atOffsets:)` |
| 保存失敗のユーザー通知 | `print` のみ | Route アラート |
| SimpleShuffle の層 | Presenter + View | 5 層 + ViewData |
| 番号付き行の実装数 | 3 | 1 |
| お気に入り一覧とテンプレ一覧 | 別実装 + View が SwiftData | 同じ子モジュール型（テンプレはオプション） |
| AttendeeList のユニットテスト | 3 件（1 件 flaky 余地） | 20 件以上、順序系は非 flaky |
| 広告バナーサイズのハードコード | 3 箇所 | 0（コンテナ側） |

---

## 7. 検証戦略

1. **層ごとのユニットテスト**
   - **Interactor**: In-Memory Gateway で追加規則、一括パース、置換、上限、削除。
   - **Presenter**: 意図メソッド → 期待する ViewData / Route。保存失敗で alert になること。
   - **Router**: 子モジュール生成と Output 結線（FavoriteGroup / BulkAdd / SimpleShuffle）。
2. **回帰基準**: Phase 0 のテストを全フェーズで維持。複数削除の既知バグは Phase 1 で消す。
3. **既存 SeatingChart スイートを壊さないこと。** Attendee の受け渡しシグネチャを変える場合は
   `SeatingChartInteractor` の初期化テストも確認する。
4. **手動 QA（エントリ画面）**
   - 空状態で追加 → リスト → スワイプ削除 → 全削除確認
   - 入力欄に文字が残っているとき席決め CTA が無効
   - 一括追加（改行 / 半角カンマ / 読点 / 空行混在）
   - お気に入り保存・上限 3・削除後に再保存
   - お気に入り読込で現リストが完全置換される
   - 座席表 / 番号札への遷移と pop 後のリスト保持
   - 番号札の再シャッフルと共有（Share 既存フロー）
5. **再描画**: お気に入り保存後に参加者リストが不要に再構築されないこと
   （`@Query` 排除の効果確認）。`Self._printChanges()` で Phase 2 前後を比較。
6. **スクリーンショット**: 空状態 / 1 名 / 20 名、ダークモード、Dynamic Type 最大。

---

## 8. 実装前に決めるべきこと（要判断）

1. **お気に入り一覧のモジュール粒度**
   完全な 5 層（FavoriteGroup）にするか、Presenter + View の 2 層に留めるか。
   テンプレート一覧も同時に揃えるなら 5 層を推奨。AttendeeList だけなら
   Route + Snapshot で Phase 2 まで進め、Phase 5 で切る段階方式でもよい。
2. **Gateway の所在（親 vs 子）**
   親 Interactor だけが Gateway を持ち、子はスナップショット配列を受け取るか。
   子が独自に Gateway を持つか。
   **推奨:** 一覧・削除は子、保存・読込置換は親。Gateway 実装は共有し、
   SwiftData `ModelContext` は各 assemble 時に同じ context から生成する
   （SeatingChart のテンプレートと同じ）。
3. **`TemplateSaveAvailability` の改名**
   共通 `SaveAvailability` にするか、お気に入り専用型を増やすか。
   共通化すると SeatingChart 側のリネームが発生する。
4. **`modelContext` の注入タイミング**
   SwiftUI では `@Environment(\.modelContext)` が View に来る制約がある。
   SeatingChart は View `onAppear` で attach している。
   AttendeeList も過渡期は同じでよいが、View から Entity / `@Query` は消す。
   中期的には `assembleModule` を `ModelContext` 付きにするか、
   App 層で Gateway を組み立てて渡す。
5. **SimpleShuffle に `[Attendee]` を渡すか `[String]` のままか**
   ID 維持と行の安定 identity のため **`[Attendee]` を推奨**。
   Share の `numberedList(attendees: [String])` は名前配列のままでよく、
   Presenter がマップする。
6. **入力中 CTA 無効化を ViewData に含めるか**
   未確定テキストは View の `@State` なので、disable は View 側のままでよい。
   「参加者が空」だけを ViewData の `canStartSeating` にするのが境界として綺麗。
7. **`AnyView` の許容範囲**
   Router の戻り値は現状どおり `AnyView` でよい（SeatingChart と同じ）。
   View 内のボタン背景では禁止。
8. **`refactor_seating.md` Phase 6 との分割**
   DesignSystem / アダプティブバナー / String Catalog は両計画で重複する。
   **推奨:** トークンとバナーは本計画 Phase 6 で先にやり、座席側 Phase 6 は
   バッジ統合・グリッド遅延描画に集中する。あるいは DesignSystem だけ先に
   独立コミットして両計画から参照する。

---

## 9. 想定工数

| Phase | 内容 | 工数 | VIPER 上の意義 |
| --- | --- | --- | --- |
| 0 | 準備・回帰テスト整備 | 0.5 日 | 移送の安全網。複数削除バグの固定 |
| 1 | ファイル分割・デッドコード・規約統一 | 0.5 日 | 箱を SeatingChart に揃える |
| 2 | Contracts と ViewData / Route | 1.5 日 | **層間境界の確立**（View から Entity / `@Query` を排除） |
| 3 | Presenter → Interactor 移送 | 1.0 日 | **永続化の単一窓口化** |
| 4 | Router 実体化 | 0.5 日 | 遷移の Presenter 主導化 |
| 5 | 子モジュール + SimpleShuffle VIPER 化 | 2.0 日 | モジュール分割の完成 |
| 6 | 再利用部品・パフォーマンス・A11y・i18n | 1.5 日 | 品質仕上げ（座席 Phase 6 と調整） |
| | **合計** | **7.5 日** | |

**推奨する区切り:**

- **第一弾（Phase 0〜2、2.5 日）**: バグ修正と「View が Entity を知らない」状態。
  体感負債の大半（`@Query`、`destination` 代入、上限分岐）がここで消える。
- **第二弾（Phase 3〜4、1.5 日）**: Interactor / Router を SeatingChart と同じ形にする。
- **第三弾（Phase 5〜6、3.5 日）**: シートの子モジュール化、番号札の正式 VIPER、横断熱。

Phase 2 を先に置く理由は SeatingChart と同じで、契約と ViewData を先に作ると
Phase 3 のロジック移送で **View を触らずに済む**ため。

---

## 10. 着手時に触るファイル（第一弾の目安）

変更予定（実装はまだ行わない）:

- `SakuttoSeat/Modules/AttendeeList/*`（本体）
- `SakuttoSeat/Modules/SimpleShuffle/*`（Phase 5）
- `SakuttoSeat/Modules/GroupFavorite/GroupFavorite.swift`（Gateway 内に閉じる。公開面は Snapshot）
- `SakuttoSeat/Core/Gateways/GroupFavoriteGateway.swift`（保持者を Presenter → Interactor へ）
- `SakuttoSeat/App/SakuttoSeatApp.swift`（色トークン移設時のみ）
- `SakuttoSeatTests/SakuttoSeatTests.swift` → AttendeeList 専用ファイルへ分割
- オプション: `SakuttoSeat/Modules/SeatingTemplate/SeatingTemplateListView.swift`

参照のみ（規約の正本）:

- `refactor_seating.md`
- `SakuttoSeat/Modules/SeatingChart/SeatingChartContracts.swift`
- `SakuttoSeat/Modules/VenueSettings/*`（薄い Presenter + Route の見本）
- `SakuttoSeat/Modules/Share/*`（横断フローの見本）
