# SeatingChart モジュール リファクタリング計画書（VIPER 版）

対象: `SakuttoSeat/Modules/SeatingChart/` を中心に、共有コンポーネント（`Modules/Common/`）と
横断的に重複している `SimpleShuffle` / `AttendeeList` の該当部分を含む。

作成日: 2026-09-10
アーキテクチャ: **VIPER**（View / Interactor / Presenter / Entity / Router）

### 進捗

| Phase | 内容 | 状態 |
| --- | --- | --- |
| 0 | 準備と回帰テスト | ✅ 完了（2026-09-10） |
| 1 | ファイル分割・デッドコード削除・規約統一 | ✅ 完了（2026-09-10） |
| 2 | Contracts と ViewData の導入 | ✅ 完了（2026-09-10） |
| 3 | Presenter → Interactor へのロジック移送 | 未着手 |
| 4 | Router の実体化・Gateway 化 | 未着手 |
| 5 | 子モジュール切り出し・Share モジュール化 | 未着手 |
| 6 | 再利用部品・パフォーマンス・A11y・i18n | 未着手 |

補修（フェーズ外）: シャッフル時のアニメーション消失を修正（課題 3.2-#3-a）。
座席グリッドを `Grid`/`GridRow` のインデックス入れ子から、安定 id を持つ `SeatSlot` の
単一 `ForEach` ＋ 即時レイアウトの `SeatGridLayout` へ置き換え。
これに伴い `EmptySeatCell`（Phase 6 予定の廃止）を前倒しで削除。

回帰基準: `SakuttoSeatTests` 55 ケース（`xcodebuild test -scheme SakuttoSeat`）。
Phase 0 で追加した `SeatingChartInteractorTests` / `SeatingChartPresenterTests` は
**現状の挙動を固定した characterization test** です。`_既知の課題` が付いたケースは
是正対象の挙動を意図的に記録しているため、Phase 3 / 6 で挙動を変える際に更新します。
Phase 2 で `SeatingChartViewDataTests` を追加（ViewData 生成・Route・テンプレート ID 継承）。

---

## 0. エグゼクティブサマリ

本プロジェクトは VIPER のファイル構成（`*View` / `*Presenter` / `*Interactor` / `*Entity` /
`*Router`）を採用していますが、**実際の責務配置が VIPER の原則から大きく乖離**しています。
分析の結論は次の 1 点に集約されます。

> **「箱はあるが中身が入っていない」**
> Interactor には座席割り当ての 2 メソッドしかなく、ドメインロジックの大半は Presenter に、
> ゲーティング・永続化・画像出力・UIKit 直叩きは View に置かれている。Router は空の Protocol を
> 持つだけで、ナビゲーションは View の `@State` が握っている。

各層の「あるべき責務」と「実際の中身」を対比すると次のとおりです。

| 層 | VIPER における責務 | 現状 | 判定 |
| --- | --- | --- | --- |
| View | 受動的な描画とイベント転送のみ。Entity を知らない | 業務分岐・永続化トリガ・広告制御・`UIActivityViewController` 直叩き・Entity を直接受領 | ✗ 重大 |
| Interactor | 全ビジネスロジックとデータストアへの唯一の窓口 | 座席割り当て 2 メソッドのみ。SwiftData に触れない | ✗ 空洞 |
| Presenter | View 向けの表示データ生成と、Interactor / Router への仲介 | ドメインロジックの大半 + `ModelContext` 直操作 + `withAnimation` | ✗ 過積載 |
| Entity | Interactor が扱う純粋なモデル | ほぼ妥当だが View まで素通しされている。未使用 enum が残存 | △ |
| Router | 画面遷移・モジュール組み立て・提示 | `assembleModule` のみ。Protocol は空。遷移状態は View が保持 | ✗ 不在 |

本計画は、既存の VIPER 命名を**維持したまま**、上記の責務を正しい層へ移送します。
主要な作業は「Presenter → Interactor へのロジック移送」「View → Presenter への状態移送」
「Router の実体化」「モジュール契約（Protocol）の整備」の 4 本柱です。

---

## 1. 本プロジェクトにおける VIPER の解釈（SwiftUI 適応版）

古典的 VIPER は UIKit + delegate 前提のため、SwiftUI に合わせて次のように読み替えます。
**この解釈を全モジュールの共通規約とします。**

| 層 | 実装形態 | 依存してよいもの | 禁止事項 |
| --- | --- | --- | --- |
| **View** | `struct: View`。`@ObservedObject var presenter: SomePresenterProtocol` 相当を保持 | Presenter が公開する **表示データ（ViewData）** のみ | Entity の直接参照、`UIKit` の直接利用、`ModelContext`、業務条件分岐、遷移状態の保持 |
| **Presenter** | `@MainActor final class: ObservableObject` + `PresenterProtocol` | Interactor（Protocol）、Router（Protocol）、Entity → ViewData 変換 | ビジネスルールの判断、永続化、SwiftUI の描画 API |
| **Interactor** | `final class: InteractorProtocol` | Entity、Entity Gateway（Repository / Service の Protocol） | `SwiftUI` / `UIKit` の import、Presenter・View への参照 |
| **Entity** | 値型 `struct` / `enum` | `Foundation` のみ | ロジック（軽量な計算プロパティは可） |
| **Router** | `final class: RouterProtocol` | 子モジュールの Builder、`UIApplication`（提示のため）、SwiftUI の遷移先生成 | ビジネスルール、Entity の加工 |

補足規約:

- **Entity は View に渡さない。** Presenter が `SeatingChartViewData` 等の表示専用モデルへ変換する。
  これが VIPER と MVVM を分ける最も実務的な境界であり、現状の最大の違反箇所。
- **Interactor は「Entity Gateway」を通じてのみ外部データに触る。**
  SwiftData / `UserDefaults` / 広告 SDK の状態は Gateway Protocol の背後に隠す。
- **Router は「遷移」だけでなく「提示（presentation）」も担う。**
  `UIActivityViewController` の提示、リワード広告の提示（`UIViewController` を要求するため）は
  Router の責務。View から UIKit を排除する根拠となる。
- **Builder（`assembleModule`）は Router の static メソッドとして維持**する（既存踏襲）。

---

## 2. 現状の責務違反マッピング

### 2.1 View に置かれているが View の責務でないもの

`SeatingChartView.swift`（1,072 行 / 8 型）の内訳:

| 行 | 内容 | 本来の層 |
| --- | --- | --- |
| 12–24 | `SeatingChartGridItem`（グリッド行の構造） | **Presenter**（ViewData） |
| 44 | `globalTableColumnCount`（会場列数。テンプレート保存対象＝ドメインデータ） | **Interactor** が保持、Presenter が公開 |
| 46 | `sessionUnlockedColumns`（セッション解放フラグ） | **Interactor** + Entity Gateway |
| 53–56 | `gridMinWidth` の算出 | **Presenter**（ViewData） |
| 59–66 | `tableGridRows`（行分割ロジック） | **Presenter**（ViewData） |
| 69–100 | `shareText`（Entity → 共有テキストの整形） | **Interactor** |
| 282–288 | 保存ボタン内の `canSaveTemplate` 分岐 | **Interactor**（判断）→ Presenter（分岐） |
| 311–314 | `handleImageShareTapped`（広告要否の判断） | **Interactor** |
| 316–328 | `playRewardedAdThenShareImage`（広告制御） | **Presenter** + Router |
| 330–362 | `exportAndShareSeatingChartImage`（`ImageRenderer` / `UIScreen`） | **Router** + Service |
| 364–379 | `presentShareSheet`（`UIActivityViewController` 直叩き） | **Router** |
| 418–522 | `SettingsSheetView`。列数の課金ルール（`applySelection` 504–521）を内蔵 | **子 VIPER モジュール**（VenueSettings） |
| 741–940 | `TableEditView`。`init` で Entity を受け取り `@State` に焼き込む | **子 VIPER モジュール**（TableEdit） |
| 526–693 | `SeatingTableView`。`SeatingTable`（Entity）と `presenter` を丸ごと受領 | ViewData を受け取る**再利用コンポーネント**へ |

さらに `AttendeeListView.swift:19-20` の `isNavigateToSeatingChart` /
`isNavigateToSimpleShuffle` という **遷移状態を View が保持**しており、
遷移先の生成は `presenter.makeSeatingChartView()`（`AttendeeListPresenter.swift:124-132`）が
`AnyView` を返す形で Presenter を経由しています。VIPER では遷移は Router の責務であり、
Presenter は Router に依頼するだけであるべきです。

### 2.2 Presenter に置かれているが Interactor の責務であるもの

`SeatingChartPresenter.swift` は 313 行のうち大半がビジネスロジックです。

| 行 | メソッド | 内容 |
| --- | --- | --- |
| 31–54 | `setupInitialTables()` | 参加者数から必要テーブル数を算出（`ceil(n / capacity)`） |
| 58–66 | `addTable(capacity:columnCount:)` | 定員・列数の制約解決（`min` / `max` クランプ） |
| 69–79 | `nextTableName()` | 未使用名の払い出し |
| 82–91 | `tableName(at:)` | A→Z→AA の連番規則 |
| 109–143 | `updateTable(...)` | 定員超過席の切り離し、テーブル数の再調整 |
| 148–182 | `updateAllTables(...)` | 一括適用の全ルール |
| 185–195 | `unifyTableLayout(...)` | 全テーブルの定員・列数統一 |
| 198–214 | `ensureSufficientTables(...)` | 総座席数不足の補填 |
| 217–226 | `removeEmptyTables()` | 末尾空テーブルの削除規則 |
| 229–234 | `toggleLock(tableId:memberId:)` | ロック状態の更新 |
| 236–241 | `deleteTable(id:)` | 削除後の再割り当て |
| 246–268 | `saveLayoutAsTemplate(...)` | **`ModelContext` を直接操作**（`insert` / `save`） |
| 272–305 | `applyTemplate(_:)` | テンプレート → Entity 変換 + 既定値更新 |
| 307–312 | `canSaveTemplate(context:)` | **`fetchCount` を直接実行**。上限「3」をハードコード |

加えて Presenter 固有の問題:

- **`ModelContext` が引数で渡ってくる**（246, 307）。VIPER では永続化は Interactor が
  Entity Gateway 経由で行い、Presenter は SwiftData の存在を知らないべき。
  エラーは `print`（267）で握り潰され、ユーザーに伝わらない。
- **`withAnimation` を Presenter が呼んでいる**（95, 103, 117, 163, 296）。アニメーションは View の関心。
- **`defaultCapacity` / `defaultColumnCount`（21–22）が非公開の暗黙状態**。
  「すべてのテーブルに適用」で更新されるドメイン設定であり、Interactor が保持すべき。
- **`router` を保持しているが一度も使っていない**（18）。Router が空 Protocol のため。
- **`@MainActor` が付いていない**。`AttendeeListPresenter` / `SimpleShufflePresenter` には付与済みで規約が不統一。
- **`PresenterProtocol` が存在しない**。View が具象クラスに直接依存しており、
  VIPER のモジュール契約が成立していない（テストダブルも作れない）。

### 2.3 Interactor の空洞化

`SeatingChartInteractor.swift` は 61 行、公開メソッドは 2 つ
（`shuffleAndAssign` / `assignInRegistrationOrder`）のみで、実体は private な `assign` 1 本です。
座席割り当てアルゴリズムとしては責務が綺麗ですが、**モジュールのビジネスロジック層としては
本来持つべきものの 1 割程度**しか入っていません。

また Interactor は状態を持たない純関数として実装されているため、テーブル配列の真実の所在が
Presenter の `@Published var tables` になっています。結果として「ドメイン状態を Presenter が持ち、
Presenter がドメイン操作も行う」＝ Interactor を経由しない経路が常態化しています。

### 2.4 Router の不在

`SeatingChartRouter.swift` は 22 行:

```swift
protocol SeatingChartRouterProtocol {
    // 将来、この画面からさらに別の画面へ遷移する場合はここに定義します
}   // ← 空
```

- Builder（`assembleModule`）しか実装がなく、`AnyView` を返している。
- 本画面は実際には **4 つのシート + 5 つの alert** を提示しているが、
  そのすべてを View の `@State` が管理している（`SeatingChartView.swift:28-47` に 15 個の `@State`）。
- 共有シート・リワード広告の提示（`UIViewController` を要求する）も View が行っている。

VIPER では、これらは Router が担うか、少なくとも Presenter の公開状態を Router 相当の
ルーティング定義で駆動すべき箇所です。

---

## 3. 層をまたぐ課題（VIPER 是正と並行して対応）

### 3.1 再利用性 — 大規模なコピペ

**(A) 方向バッジが 8 箇所に重複**
`SeatingChartView.swift:532-594`（`badgeTop/Bottom/Left/Right`）と
`:1008-1070`（`...Small`）。差分は円の直径（14 vs 12）、アイコン（8 vs 7）、
オフセット（6 vs 4）のみで、**約 130 行が実質 1 コンポーネント分**。

**(B) テーブル描画が画面用と画像出力用で二重実装**
`SeatingTableView`（526–693）と `SnapshotSeatingTableView`（944–1071）で、
座席配列の組み立て・行数計算・カード装飾・バッジ配置が丸ごと重複。

**(C) 共有・画像出力フローが 2 画面で完全重複**
`SeatingChartView.swift:311-379` と `SimpleShuffleView.swift:125-173` の
`handleImageShareTapped` / `playRewardedAdThenShareImage` / `presentShareSheet` は
**ほぼ 1 文字違わず同一**。宣言側（`.sheet(onDismiss:)` + `pendingShareSelection` + alert × 2）も重複。
→ VIPER 的には、共有は**横断的な子モジュール（Share モジュール）または Router の共通機能**として
1 箇所に集約すべき。

**(D) `EmptySeatCell`（731–738）は型推論回避のためのラッパ**
`SeatView(member: nil).id(...)` を包むだけの型。ViewData 側に seat identity を持たせれば不要。

**(E) デザイントークンが存在しない**
`140` / `16` / `32` / `120` / `72` / `12` / `15` が散在し、
`SeatingChartView.swift:54-56` と `:333-349` で**同じ値を別々に再定義**している。

**(F) 文字列が全てインラインの日本語リテラル**
String Catalog 未導入。共有テキスト整形（`:69-100`）も View 内にある。

### 3.2 パフォーマンス

| # | 内容 | 場所 |
| --- | --- | --- |
| 1 | **1 席のロック切替で全テーブルが再描画**。`SeatingTableView` が `@ObservedObject var presenter` を保持し、`@Published tables` の変更が全子 View に伝播。`SeatingTable` が `Equatable` でないため差分スキップも効かない | `:528` / `SeatingChartEntity.swift:39-48` |
| 2 | **グリッド行構造を body ごとに全再構築**。`tableGridRows` は computed property | `:59-66` |
| 3 | **`ForEach` の identity が index**。`Array(...enumerated()), id: \.offset` のため、先頭挿入で以降の全行が別 View 扱いになりアニメーションが破綻 | `:116, 390, 979` |
| 3-a | ~~座席グリッドが `Grid`/`GridRow` + インデックス `ForEach` の入れ子で、シャッフル時に座席の移動を検出できずアニメーションが消える~~ → **修正済み**。`SeatSlot`（安定 id）＋ 単一 `ForEach` ＋ カスタム `SeatGridLayout` に置き換え | `SeatGridLayout.swift` / `SeatSlot.swift` |
| 4 | **座席配列を body 内で毎回生成**（`allSeats` / `rowCount` / `desiredWidth`） | `:620-629, 969-974` |
| 5 | **全件即時レイアウト**。`LazyVGrid` の高さ過小評価を避けて `VStack`/`HStack` にした形跡があり、最大 10 列 × 多数テーブルでスケールしない | `:113-114` のコメント |
| 6 | **ロック席探索が O(T·C·L)**。`lockedMembers` を `[UUID: ...]` でキーしているのに参照は常に座席位置からで、毎座席ごとに `values.first(where:)` で全走査 | `SeatingChartInteractor.swift:36-49` |
| 7 | **`UIScreen.main` 依存**。iOS 16 以降で非推奨、iPad の Split View で誤サイズ | `:333, 357` / `SimpleShuffleView.swift:152` |
| 8 | **広告バナーが 320×50 固定**。呼び出し側 3 箇所で `.frame` をハードコード | `AdBannerView.swift:14` 他 |

### 3.3 正確性・保守性リスク

| # | 内容 | 場所 |
| --- | --- | --- |
| 1 | **編集シートが index 参照**。`editingTableIndex: Int?` を保持し、シート表示中に `tables` が変化すると別テーブルを編集する／範囲外になる | `:29, 121-124, 205-209` |
| 2 | **`TableEditView` が `init` で Entity を `@State` に焼き込む**。同一 identity の View 再利用時に前回値が残る可能性 | `:754-762` |
| 3 | **到達不能な alert**。`showTemplateLimitAlert` は宣言と alert 定義があるが `true` にする箇所が存在せず、上限案内が出ない | `:33, 217-221` |
| 4 | **無料枠が広告 1 回で実質無制限**。`canSaveTemplate` が false でも広告視聴後に無条件で `isShowingSaveAlert = true` にしており、以降の保存回数に制限がかからない。同時に無関係な `sessionUnlockedColumns` も true にしている | `:252-267` |
| 5 | **`asyncAfter(0.3)` の魔法待ちが 5 箇所以上**。シート dismiss アニメーションとの競合を時間で回避しており端末速度依存 | `:226, 255, 323` / `SimpleShuffleView.swift:97, 137` / `AttendeeListView.swift:112, 132` |
| 6 | **画像出力サイズが推測値**。`tableHeight: CGFloat = 150 // Estimated` のため定員が多いテーブルで見切れる | `:344-349` |
| 7 | **`ImageRenderer` の失敗を無言で捨てる** | `:360` |
| 8 | **`SeatingTable.id` が `let id = UUID()`**。`applyTemplate` が毎回新規 id を発行するため全置換扱いになり差分アニメーションが効かない | `SeatingChartEntity.swift:40` |
| 9 | **無料枠「3」が 4 箇所に散在**。`SeatingChartPresenter.swift:311` / `AttendeeListView.swift:149, 175` / `AppStateManager.swift:18`（未参照） | 複数 |
| 10 | **デッドコード**: `SeatPosition`（`SeatingChartEntity.swift:11-16`）、`AppStateManager`、`PremiumManager`、`AttendeeListView` の `favoriteMenuButton` / `saveGroupButton` / `resetButton` | 複数 |
| 11 | **SeatingChart モジュールのテストが 0 件**。既存は `AttendeeListInteractor` の 3 ケースのみ | `SakuttoSeatTests.swift` |
| 12 | **アクセシビリティ未対応**。座席・バッジに label なし。カード全体の `onTapGesture` と内部 Button でジェスチャ責務が曖昧 | `:646-649, 675-681` |
| 13 | Router が `AnyView` を返すため型情報が消え、遷移先の静的検査ができない | `SeatingChartRouter.swift:15-21` / `AttendeeListRouter.swift:28-39` |

---

## 4. 目標構成

### 4.1 モジュール契約（Contracts）— VIPER の中核

各モジュールに `*Contracts.swift` を新設し、**5 つの Protocol で層間の境界を明示**します。
これが現状最も欠けている要素です。

```swift
// SeatingChartContracts.swift

// MARK: View <- Presenter
/// View は Presenter の公開状態のみを読む。Entity は現れない。
@MainActor
protocol SeatingChartPresenterProtocol: ObservableObject {
    var viewData: SeatingChartViewData { get }        // 表示専用モデル
    var route: SeatingChartRoute? { get set }         // 提示中のシート/アラート

    // MARK: View -> Presenter（ユーザー意図のみを表現する）
    func onAppear()
    func didTapAddTable()
    func didTapTable(id: TableID)
    func didTapSeat(tableID: TableID, memberID: MemberID)
    func didTapShuffle()
    func didTapSaveTemplate()
    func didTapLoadTemplate()
    func didTapShare()
    func didTapSettings()
}

// MARK: Presenter -> Interactor
protocol SeatingChartInteractorProtocol {
    // ドメイン状態の取得
    func currentTables() -> [SeatingTable]
    func currentVenueSettings() -> VenueSettings

    // 座席割り当て
    func buildInitialTables(for attendees: [Attendee]) -> [SeatingTable]
    func shuffleSeats() -> [SeatingTable]
    func reassignInRegistrationOrder() -> [SeatingTable]
    func toggleLock(tableID: TableID, memberID: MemberID) -> [SeatingTable]

    // テーブル構成（現状 Presenter にあるロジック群の移送先）
    func addTable() -> [SeatingTable]
    func deleteTable(id: TableID) -> [SeatingTable]
    func updateTable(_ request: TableUpdateRequest) -> [SeatingTable]
    func updateAllTables(_ request: TableUpdateRequest) -> [SeatingTable]

    // 会場設定と課金ルール（判断は Interactor、表示は Presenter）
    func columnCountChangeRequirement(for count: Int) -> UnlockRequirement
    func applyColumnCount(_ count: Int) throws -> VenueSettings
    func grantSessionUnlock()

    // テンプレート（永続化は Entity Gateway 経由）
    func templateSaveAvailability() -> TemplateSaveAvailability
    func saveCurrentLayoutAsTemplate(named name: String) throws
    func applyTemplate(id: SeatingLayoutTemplate.ID) throws -> [SeatingTable]

    // 共有ペイロード生成（Entity -> 転送用データ）
    func makeShareText() -> String
    func shareImageRequirement() -> UnlockRequirement
}

// MARK: Presenter -> Router
@MainActor
protocol SeatingChartRouterProtocol: AnyObject {
    func presentShareSheet(text: String)
    func presentShareSheet(image: UIImage)
    func presentRewardedAd() async throws            // UIViewController を要求するため Router
    func makeTableEditModule(tableID: TableID, output: TableEditModuleOutput) -> AnyView
    func makeVenueSettingsModule(output: VenueSettingsModuleOutput) -> AnyView
    func makeTemplateListModule(output: TemplateListModuleOutput) -> AnyView
}

// MARK: Interactor -> Entity Gateway
protocol SeatingTemplateGateway {
    func fetchCount() throws -> Int
    func fetchAll() throws -> [SeatingLayoutTemplate]
    func insert(_ template: SeatingLayoutTemplate) throws
    func delete(id: SeatingLayoutTemplate.ID) throws
}

protocol FeatureUnlockGateway {
    var isSessionUnlocked: Bool { get }
    func grantSessionUnlock()
}
```

### 4.2 表示専用モデル（Presenter が生成、View が消費）

Entity を View に渡さないための境界です。`Equatable` 準拠により
パフォーマンス課題 3.2-#1〜#4 も同時に解消します。

```swift
struct SeatingChartViewData: Equatable {
    struct Row: Identifiable, Equatable {
        let id: String                  // 先頭要素の安定 ID から生成（index を使わない）
        let items: [Item]
        let trailingFillerCount: Int    // 現状 View 内で計算している fillCount
    }
    enum Item: Identifiable, Equatable {
        case table(TableViewData)
        case addButton
    }
    let rows: [Row]
    let minGridWidth: CGFloat
    let isShuffleEnabled: Bool
    let isSaveEnabled: Bool
    let isShareEnabled: Bool
}

struct TableViewData: Identifiable, Equatable {
    let id: TableID
    let name: String
    let badge: LayoutDirection?
    let layoutLabel: String?
    let seats: [SeatViewData]           // 空席パディング込みで確定済み
    let columnCount: Int
    let needsHorizontalScroll: Bool     // 現状 View 内の `columnCount <= 4` 判定
    let accessibilitySummary: String
}

struct SeatViewData: Identifiable, Equatable {
    let id: String                      // memberID or "table-empty-index"
    let memberID: MemberID?
    let displayName: String             // 空席なら「空席」
    let isLocked: Bool
}
```

### 4.3 ルーティング定義（View の `@State` 15 個を置換）

```swift
enum SeatingChartRoute: Identifiable, Equatable {
    case tableEdit(TableID)
    case venueSettings
    case templateList
    case shareSelection
    case saveTemplatePrompt
    case alert(SeatingChartAlert)
}

enum SeatingChartAlert: Equatable {
    case templateLimitReached(currentCount: Int, limit: Int)
    case confirmImageShareWithAd
    case adNotReady
    case requireUnlockForColumns(requested: Int)
    case saveFailed(message: String)
    case imageExportFailed
}
```

Presenter が `route` を単一の真実として持ち、View は `.sheet(item: $presenter.route)` /
`.alert(item:)` で 1 系統に束ねます。到達不能 alert（課題 3.3-#3）や
状態フラグの組み合わせ爆発が構造的に発生しなくなります。

### 4.4 目標ディレクトリ構成

```
SakuttoSeat/
├── Core/
│   ├── DesignSystem/
│   │   ├── AppColor.swift                   // sakuttoBlueStart 等（現状 AttendeeListView 末尾）
│   │   ├── AppSpacing.swift                 // 140/16/32/120/72 のトークン化
│   │   └── AppTypography.swift
│   ├── Gateways/                            // Interactor が使う Entity Gateway
│   │   ├── SeatingTemplateGateway.swift     // Protocol
│   │   ├── SwiftDataSeatingTemplateGateway.swift
│   │   ├── GroupFavoriteGateway.swift
│   │   ├── FeatureUnlockGateway.swift       // sessionUnlockedColumns の置き場
│   │   └── FeatureLimit.swift               // 無料枠「3」の単一定義
│   ├── Presentation/                        // Router が使う提示ヘルパー
│   │   ├── ShareSheetPresenter.swift        // UIActivityViewController の唯一の窓口
│   │   ├── ImageExportRenderer.swift        // ImageRenderer ラッパ（サイズは実測）
│   │   └── RewardedAdPresenter.swift        // async/await 化した広告提示
│   └── Extensions/
│       └── UIApplication+TopViewController.swift  // 現状 RewardedAdManager.swift:93-106 に同居
├── Modules/
│   ├── SeatingChart/
│   │   ├── SeatingChartContracts.swift      // ★ 新設：5 つの Protocol
│   │   ├── SeatingChartEntity.swift         // SeatingTable / SeatingMember / LayoutDirection / VenueSettings
│   │   ├── SeatingChartInteractor.swift     // ★ ドメインロジックの集約先
│   │   ├── SeatingChartPresenter.swift      // ★ ViewData 生成と仲介に純化
│   │   ├── SeatingChartRouter.swift         // ★ 遷移・提示・子モジュール組み立て
│   │   ├── SeatingChartViewData.swift       // 表示専用モデル
│   │   ├── SeatingChartRoute.swift
│   │   └── View/
│   │       ├── SeatingChartView.swift       // 目標 150 行以下
│   │       └── SeatingChartSnapshotView.swift
│   ├── TableEdit/                           // ★ 子 VIPER モジュール（現 TableEditView 741-940）
│   │   ├── TableEditContracts.swift
│   │   ├── TableEditInteractor.swift
│   │   ├── TableEditPresenter.swift
│   │   ├── TableEditRouter.swift
│   │   └── TableEditView.swift
│   ├── VenueSettings/                       // ★ 子 VIPER モジュール（現 SettingsSheetView 418-522）
│   │   ├── VenueSettingsContracts.swift
│   │   ├── VenueSettingsInteractor.swift    // 列数の課金ルールをここへ
│   │   ├── VenueSettingsPresenter.swift
│   │   ├── VenueSettingsRouter.swift
│   │   └── VenueSettingsView.swift
│   ├── Share/                               // ★ 横断モジュール（2 画面の重複を解消）
│   │   ├── ShareContracts.swift
│   │   ├── ShareInteractor.swift            // 広告要否の判断
│   │   ├── SharePresenter.swift
│   │   ├── ShareRouter.swift                // シート提示・広告提示
│   │   └── ShareSelectionView.swift
│   └── ...
└── Components/                              // ViewData を受け取る受動的な部品のみ
    ├── SeatingTableCard.swift               // 画面用/出力用を style で共通化
    ├── SeatCell.swift                       // 旧 SeatView（EmptySeatCell 廃止）
    ├── LayoutDirectionBadge.swift           // バッジ 8 箇所を 1 つに
    └── ActionButtonsView.swift
```

### 4.5 子モジュール間の通信規約（Module Output）

`TableEditView` / `SettingsSheetView` は現在、親の `@Binding` と親 Presenter への
直接呼び出しで結果を返しています。VIPER では **Output Protocol による一方向通知**に統一します。

```swift
protocol TableEditModuleOutput: AnyObject {
    func tableEditDidCommit(_ request: TableUpdateRequest)
    func tableEditDidRequestDelete(tableID: TableID)
    func tableEditDidCancel()
}

protocol VenueSettingsModuleOutput: AnyObject {
    func venueSettingsDidApply(columnCount: Int)
    func venueSettingsDidRequestUnlock(for columnCount: Int)
}
```

親（`SeatingChartPresenter`）が Output を実装し、子 Router が生成時に注入します。
これにより `applyTemplate` が `Int` を返して View の `@State` に書き戻す
（`SeatingChartView.swift:212-213`）といった逆流経路が消えます。

### 4.6 再利用コンポーネントの設計

**(1) バッジの単一化**

```swift
struct LayoutDirectionBadge: View {
    enum Size { case regular, compact
        var diameter: CGFloat { self == .regular ? 14 : 12 }
        var iconSize: CGFloat { self == .regular ? 8 : 7 }
        var offset: CGFloat  { self == .regular ? 6 : 4 }
    }
    let direction: LayoutDirection
    let size: Size
}

extension View {
    func layoutDirectionBadges(_ direction: LayoutDirection?, size: LayoutDirectionBadge.Size) -> some View
}
```

→ 約 130 行が約 30 行に。

**(2) テーブルカードの統合**

```swift
struct SeatingTableCard: View {
    enum Style { case interactive, snapshot }   // 影の有無・バッジサイズ・スクロール可否
    let data: TableViewData                    // Entity ではなく ViewData
    let style: Style
    var onTapCard: (() -> Void)? = nil
    var onTapSeat: ((MemberID) -> Void)? = nil
}
```

`presenter` を丸ごと渡すのをやめることで、VIPER 違反（部品が Presenter を知る）と
パフォーマンス課題 3.2-#1 を同時に解消します。

---

## 5. 実行計画（フェーズ分割）

各フェーズは独立してマージ可能。**「箱を作る → 中身を移す → 契約で固める」** の順序とし、
挙動を変えない機械的整理を先に済ませます。

### Phase 0: 準備と回帰テスト（1 日）

- SeatingChart 用テストファイルを新設し、**現状の挙動を固定する回帰テスト**を作成。
  - 現 Interactor: ロック維持、定員超過、参加者 0 人、テーブル数 < 参加者数、全席ロック済み。
  - 現 Presenter（移送前の仕様スナップショット）: `tableName(at:)` の A→Z→AA、
    `addTable` の制約クランプ、`updateAllTables` の統一結果、
    `ensureSufficientTables` の補填数、`removeEmptyTables` の境界（最低 1 テーブル維持）。
- `Core/Gateways/` に In-Memory の `SeatingTemplateGateway` テストダブルを用意。
- 完了条件: 見た目・挙動を変えずにテストが green。**以降の全フェーズでこれを回帰基準とする**。
- リスク: 低。

### Phase 1: ファイル分割・デッドコード削除・規約統一（1 日）

- `SeatingChartView.swift`（1,072 行）を型ごとに分割（§4.4 の構成へ）。**ロジック変更なし**。
- 削除: `SeatPosition`、`AppStateManager`、`PremiumManager`、
  `AttendeeListView` の `favoriteMenuButton` / `saveGroupButton` / `resetButton`。
- `UIApplication.topViewController` を `RewardedAdManager.swift` から `Core/Extensions/` へ移動。
- `SeatingChartPresenter` に `@MainActor` を付与し、3 モジュールで規約を揃える。
  Presenter の所有権も `@StateObject`（Builder が生成し View が保持）に統一。
- 履歴コメント（`// Removed PRO gating` 等）を整理、コメント言語を日本語に統一。
- 完了条件: ビルド成功、Phase 0 のテスト green、差分がファイル移動と削除のみ。
- リスク: 低（`xcodeproj` の target membership 漏れに注意）。

### Phase 2: モジュール契約（Contracts）と表示専用モデルの導入（2 日）

**VIPER 化の土台。ここが本計画の中核。**

- `SeatingChartContracts.swift` を新設し、§4.1 の 5 Protocol を定義。
  View → `SeatingChartPresenterProtocol`、Presenter → `SeatingChartInteractorProtocol` /
  `SeatingChartRouterProtocol` の依存に差し替え（具象クラス直参照を廃止）。
- `SeatingChartViewData` / `TableViewData` / `SeatViewData` を導入し、
  **View から Entity（`SeatingTable` / `SeatingMember`）の参照を完全に排除**。
  - グリッド行分割（現 `:59-66`）、`gridMinWidth`（現 `:53-56`）、
    座席パディング（現 `:620-629`）、`needsHorizontalScroll`（現 `:632`）を Presenter へ移送。
  - `Row.id` を index ではなく安定 ID に変更（課題 3.2-#3 の解消）。
- `SeatingTable` / `SeatingMember` を `Equatable`（可能なら `Hashable`）に。
  `SeatingTable.id` を `let id: UUID` + イニシャライザ引数化し、テンプレート適用時に ID を引き継ぐ
  （課題 3.3-#8 の解消）。
- `SeatingChartRoute` / `SeatingChartAlert` を導入し、View の `@State` 15 個を
  Presenter の `route` 1 本に統合。到達不能 alert（課題 3.3-#3）を解消。
- `editingTableIndex: Int?` → `route: .tableEdit(TableID)` に置換（課題 3.3-#1 の解消）。
- 完了条件: `SeatingChartView` 内に `SeatingTable` / `SeatingMember` の型名が出現しない。
  View の `@State` が 3 個以下。Presenter のテストダブルで View のプレビューが作れる。
- リスク: 中〜高（状態遷移の総入れ替え）。→ Phase 0 のテストを Presenter 契約向けに拡張してから着手。

### Phase 3: Presenter → Interactor へのロジック移送（2.5 日）

- §2.2 の表に挙げた 15 メソッドを `SeatingChartInteractor` へ移送。
  - Interactor が `tables` と `VenueSettings` の**真実の所在**となり、
    操作結果として新しい `[SeatingTable]` を返す（現状の純関数スタイルを踏襲）。
  - `defaultCapacity` / `defaultColumnCount`（現 `SeatingChartPresenter.swift:21-22`）を
    `VenueSettings` Entity に統合し、Interactor が保持。
- `globalTableColumnCount`（`SeatingChartView.swift:44`）を View から剥がし `VenueSettings` へ。
  `saveLayoutAsTemplate` / `applyTemplate` から引数・戻り値を撤去。
- `sessionUnlockedColumns`（同 `:46`）を `FeatureUnlockGateway` へ。
  画面を pop しても解放が維持されるようになる。
- `withAnimation`（Presenter 5 箇所）を Presenter から View 側へ移動。
  Presenter は `viewData` の更新のみを行う。
- `scrollToTopTrigger: Int`（`SeatingChartPresenter.swift:15`）を、
  `SeatingChartRoute` と同様に意味を持つイベント型へ置換。
- 完了条件: Presenter の行数が 150 行以下、かつ `if` / `min` / `max` によるドメイン判断が
  Presenter に存在しない。Interactor が `SwiftUI` を import していない。
  Phase 0 のテストを Interactor 直接呼び出しに書き換えても green。
- リスク: 高（ドメインロジックの大移動）。→ フェーズを 3a（テーブル構成系）/
  3b（会場設定・解放系）に分割してマージすることを推奨。

### Phase 4: Router の実体化と永続化の Gateway 化（2 日）

- `SeatingChartRouterProtocol` を §4.1 の内容で実装し、Presenter の未使用 `router`（`:18`）を活かす。
  - `presentShareSheet(text:)` / `(image:)`: `UIActivityViewController` の提示を Router に集約
    （現 `SeatingChartView.swift:364-379` / `SimpleShuffleView.swift:159-173` の重複を削除）。
  - `presentRewardedAd() async throws`: 広告提示を async/await 化。
    `asyncAfter(0.3)` の魔法待ちを全廃（3 ファイル計 5 箇所以上）。
  - `makeTableEditModule` / `makeVenueSettingsModule` / `makeTemplateListModule`:
    子モジュールの組み立てを Router へ。`AnyView` の使用は境界のみに限定。
- `AttendeeListView` の `isNavigateToSeatingChart` / `isNavigateToSimpleShuffle`（`:19-20`）を
  Router 主導の遷移に置換し、`AttendeeListPresenter.makeSeatingChartView()`（`:124-132`）の
  View 生成責務を Router へ戻す。
- `SeatingTemplateGateway` / `GroupFavoriteGateway` を実装し、
  Presenter から `ModelContext` を完全排除（現 `SeatingChartPresenter.swift:246, 307`）。
  `print` によるエラー握り潰し（同 `:267`）を `throws` + `.alert(.saveFailed)` に置換。
- `FeatureLimit` に無料枠を集約し、4 箇所のハードコード（課題 3.3-#9）を差し替え。
- 課題 3.3-#4（広告 1 回で無制限）の仕様を確定し Interactor に実装。
- 完了条件: View / Presenter に `import UIKit` と `ModelContext` が存在しない。
  `asyncAfter` の grep 結果が 0 件。上限周りの Interactor テストが green。
- リスク: 高（広告 SDK の presenter 取得タイミング、多段シートの競合）。
  → 実機確認項目を `QA_MANUAL_TEST_CHECKLIST.md` に追記。

### Phase 5: 子モジュールの切り出しと共有モジュール化（2 日）

- `TableEditView`（741–940）を **TableEdit モジュール**として独立させる。
  - `init` での `@State` 焼き込み（`:754-762`）を廃止し、Presenter が編集中の ViewData を保持。
  - 20 文字制限（`:769-773, 884-888`）と定員・列数の連動（`:775-781`）を Interactor へ。
  - 結果は `TableEditModuleOutput` で親 Presenter に通知（`@Binding` 依存を撤去）。
- `SettingsSheetView`（418–522）を **VenueSettings モジュール**として独立させる。
  - `applySelection()`（`:504-521`）の課金ルールを `VenueSettingsInteractor` へ。
  - 広告視聴後の列数適用（`:480-497`）を Presenter + Router の連携に整理。
- **Share モジュール**を新設し、`SeatingChart` / `SimpleShuffle` の重複約 100 行 × 2 を削除。
  - `ShareInteractor`: 広告要否の判断と共有ペイロードの生成
    （`shareText` の整形ロジック `SeatingChartView.swift:69-100` を移送）。
  - `ShareRouter`: シート提示・広告提示。
  - 画像出力サイズを推測値（`:344-349`）から**実測**へ変更し、見切れ（課題 3.3-#6）を解消。
    `ImageRenderer` 失敗（`:360`）時は `.alert(.imageExportFailed)` を提示。
  - `UIScreen.main` 依存（`:333, 357`）を排除。
- 完了条件: `SeatingChartView` が 150 行以下 / 1 型。3 画面で共有フローが動作し、
  共有関連コードが Share モジュールにのみ存在する。
- リスク: 中〜高（子モジュール分割に伴う UI 挙動の変化）。

### Phase 6: 再利用コンポーネント・パフォーマンス・A11y・i18n（2 日）

- `LayoutDirectionBadge` + `layoutDirectionBadges` modifier で 8 箇所を置換。
- `SeatCell`（旧 `SeatView`）に seat identity を持たせ `EmptySeatCell` を削除。
- `SeatingTableCard`（`Style` 引数）に `SeatingTableView` と `SnapshotSeatingTableView` を統合。
- `Core/DesignSystem/` に `AppSpacing` / `AppColor` を作り、マジックナンバーと
  `Color.sakuttoBlueStart`（現 `AttendeeListView.swift:458-469`）を移設。
- Interactor のロック席探索を `SeatCoordinate(tableIndex:seatIndex:)` キーに変更し
  O(T·C·L) → O(T·C) に（`SeatingChartInteractor.swift:36-49`）。
  参加者 100 名 × 20 テーブルのベンチマークテストを追加。
- グリッドの遅延描画を再検討（`LazyVStack` + 行高ヒント / `Grid`）。
  ViewData が確定済みのため、行高を Presenter から供給できるようになり再挑戦の目算が立つ。
- `AdBannerView` をアダプティブバナー化し、`.frame(width: 320, height: 50)` の 3 箇所を撤去。
- アクセシビリティ: `SeatViewData.accessibilitySummary` を活用して座席・バッジに label を付与。
  カードの `onTapGesture`（`:646-649`）を `accessibilityAction` を持つ Button に置換。
- String Catalog を導入し、日本語リテラルを移設（Interactor の共有テキスト整形を含む）。
- 完了条件: 重複行数が 250 行以上削減。ベンチマークテスト green。VoiceOver で操作可能。
- リスク: 中（見た目・レイアウトのリグレッション）。→ スクリーンショット比較を必須チェックに。

---

## 6. 見込み効果

| 指標 | 現状 | 目標 |
| --- | --- | --- |
| `SeatingChartView.swift` の行数 | 1,072 行 / 8 型 | 150 行以下 / 1 型 |
| View 内の `@State` 数 | 15 個 | 3 個以下 |
| View が Entity を直接参照 | あり（`SeatingTable` / `SeatingMember`） | なし（ViewData のみ） |
| Presenter の行数 | 313 行（ドメインロジック 15 メソッド） | 150 行以下（仲介のみ） |
| Interactor の行数 | 61 行 / 公開 2 メソッド | 300 行程度 / 公開 15 メソッド |
| Router の実装 | Builder のみ・Protocol 空 | 遷移 + 提示 + 子モジュール組み立て |
| モジュール契約 Protocol | 2 個（Interactor / 空の Router） | 5 個（View / Presenter / Interactor / Router / Gateway） |
| Presenter の `ModelContext` 依存 | あり（2 箇所） | なし（Gateway 経由） |
| 重複コード（バッジ・カード・共有） | 約 350 行 | 約 80 行 |
| SeatingChart のユニットテスト | 0 件 | 25 件以上 |
| 座席ロック 1 回での再描画対象 | 全テーブル | 1 テーブル |
| ロック席探索の計算量 | O(T · C · L) | O(T · C) |
| `asyncAfter` による暗黙待ち | 5 箇所以上 | 0 |
| 無料枠「3」の定義箇所 | 4 箇所（うち 1 つは未参照） | 1 箇所 |

---

## 7. 検証戦略

1. **層ごとのユニットテスト（VIPER の最大の利点を回収する）**
   - **Interactor**: 依存が Gateway Protocol のみになるため、In-Memory ダブルで全ルールをテスト。
     割り当て、テーブル命名、定員変更に伴う増減、空テーブル削除の境界、上限判定、列数解放ルール。
   - **Presenter**: Interactor / Router のモックを注入し、
     「意図メソッド → 期待する ViewData / route」を検証。Router 呼び出し回数も検証。
   - **Router**: 子モジュール生成の型と Output 結線を検証。
2. **回帰基準**: Phase 0 で固定したテストを全フェーズで維持。
3. **スクリーンショット比較**: (a) 1 列 / 2 列 / 10 列、(b) 定員 1 / 4 / 10、
   (c) 参加者 0 / 1 / 50 名、(d) ダークモード、(e) Dynamic Type 最大 の組み合わせ。
4. **出力画像の見切れ確認**（Phase 5）: 定員 10 名 × 10 列 × 20 テーブルで下端・右端が欠けないこと。
5. **再描画計測**: `Self._printChanges()` と Instruments の SwiftUI テンプレートで Phase 2 前後を比較。
6. **手動 QA**: `QA_MANUAL_TEST_CHECKLIST.md` に広告フロー（読み込み中／視聴中断／報酬未獲得）と
   多段シート遷移の項目を追加。

---

## 8. 実装前に決めるべきこと（要判断）

1. **無料枠と広告解放の正式仕様**（課題 3.3-#3 / #4）
   広告 1 回で「無制限」か「+N 個」か。現在の実装は事実上無制限だが、
   `showTemplateLimitAlert` の存在は上限案内を出す意図を示しており、意図が食い違っている。
   → Interactor の実装内容が決まらないため、Phase 4 の前に確定が必須。
2. **`sessionUnlockedColumns` の寿命**
   セッション（アプリ寿命）か、`AppStorage` で永続化するか。`FeatureUnlockGateway` の実装が変わる。
3. **Interactor の状態保持スタイル**
   現状の「純関数 + Presenter が状態保持」を維持するか、Interactor をドメイン状態の
   単一の所在にするか。**後者を推奨**（VIPER の原則に沿い、Presenter を薄く保てる）。
4. **Interactor → Presenter の通知方式**
   同期戻り値を維持するか、古典 VIPER の `InteractorOutput` delegate、または
   `async throws` に寄せるか。**同期戻り値 + `throws`（永続化のみ async）を推奨**。
5. **子モジュール化の粒度**
   `TableEdit` / `VenueSettings` を完全な 5 層モジュールにするか、
   Presenter + View の 2 層に留めるか。前者は堅牢だがファイル数が増える。
6. **`AnyView` の許容範囲**
   Router の戻り値を `AnyView` のままにするか、ジェネリクスや
   `NavigationDestination` 型で型を保つか（課題 3.3-#13）。
7. **`AppStateManager` / `PremiumManager` の去就**
   両方デッドコード。削除するか、`FeatureLimit` / `FeatureUnlockGateway` に統合するか。

---

## 9. 想定工数

| Phase | 内容 | 工数 | VIPER 上の意義 |
| --- | --- | --- | --- |
| 0 | 準備・回帰テスト整備 | 1.0 日 | 移送の安全網 |
| 1 | ファイル分割・デッドコード削除・規約統一 | 1.0 日 | 箱の整備 |
| 2 | Contracts と ViewData の導入 | 2.0 日 | **層間境界の確立**（View から Entity を排除） |
| 3 | Presenter → Interactor へのロジック移送 | 2.5 日 | **Interactor の実体化** |
| 4 | Router の実体化・Gateway 化 | 2.0 日 | **Router の実体化**・永続化の隔離 |
| 5 | 子モジュール切り出し・Share モジュール化 | 2.0 日 | モジュール分割の完成 |
| 6 | 再利用部品・パフォーマンス・A11y・i18n | 2.0 日 | 品質仕上げ |
| | **合計** | **12.5 日** | |

**推奨する区切り:**

- **第一弾（Phase 0〜2、4 日）**: 巨大ファイルの解消と層間契約の確立。
  ここまでで「View が Entity を知らない」という VIPER の要件を満たし、体感的な負債が大きく減ります。
- **第二弾（Phase 3〜4、4.5 日）**: Interactor と Router の実体化。VIPER 化の本体。
- **第三弾（Phase 5〜6、4 日）**: モジュール分割と品質改善。

Phase 2（Contracts / ViewData）を先に置いているのは、これを済ませておくと Phase 3 の
ロジック移送で **View を一切触らずに済む**ためです。順序を入れ替えると
View と Presenter を同時に改修する必要が生じ、リグレッション範囲が広がります。
