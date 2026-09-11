# SeatingTemplate（テンプレート一覧）リファクタリング計画書（VIPER 版）

対象: `SakuttoSeat/Modules/SeatingTemplate/` を中心に、親モジュール
（`SeatingChart`）のテンプレート保存・読込、永続化（`SeatingLayoutTemplate` /
`SeatingTemplateGateway`）、双子 UI（`FavoriteGroup`）を含む。

作成日: 2026-09-11
アーキテクチャ: **VIPER**（View / Interactor / Presenter / Entity / Router）
前提: `refactor_seating.md` Phase 0〜5、`refactor_AttendeeList.md` Phase 0〜6、
`refactor_favorite.md` Phase 0〜6 は完了済み。
本計画はそこで止まった **AttendeeList Phase 5d**（`SeatingTemplateListView` の
Gateway 化 / 子 VIPER 化）を、FavoriteGroup の完成形に揃えて実施する。

**本ファイルは計画書である。未着手フェーズの実装は、そのフェーズに入ってから行う。**

### 進捗

| Phase | 内容 | 状態 |
| --- | --- | --- |
| 0 | 準備と回帰テスト（ギャップ埋め） | ✅ 完了（2026-09-11） |
| 1 | デッド API・コメント偽証・規約穴埋め | ✅ 完了（2026-09-11） |
| 2 | 子 VIPER 化（ViewData.Row / Route / Entity） | ✅ 完了（2026-09-11） |
| 3 | Gateway の Snapshot 化と親 Interactor の純化 | 未着手 |
| 4 | シート identity と Router 境界の安定化 | 未着手 |
| 5 | 再利用部品の揃え（空状態・List・Copy） | 未着手 |
| 6 | 性能・A11y・i18n・編集モード UX | 未着手 |

回帰基準: 既存 `SeatingChartInteractorTests` / `SeatingChartPresenterTests` /
`SeatingChartViewDataTests` のテンプレート系 + Phase 0 で新設する
`SeatingTemplateTests` + 親 Router / Presenter の組み立てテスト。

検証端末は既存計画と同じく iPhone 17 / iOS 26.5 を使用する
（iOS 18.4 シミュレータでは MainActor / protocol existential の解放不整合で
`malloc: pointer being freed was not allocated` が再現するため）。

---

## 0. エグゼクティブサマリ

座席表のテンプレート保存は、親 `SeatingChart` が Gateway 経由で完了している。
上限判定、`LayoutTemplateSnapshot` への写像、`applyTemplate` は Interactor にある。
ここまでは `refactor_seating.md` Phase 3〜4 の成果である。

一方、**読込一覧だけが Phase 4 以前の形で取り残されている。**

> **「保存は VIPER、一覧は `@Query` 直叩き」**
> `SeatingTemplateListView` は SwiftUI の `@Query` と `ModelContext.delete` を自分で持つ。
> Router はクロージャ付きの素の View を `AnyView` で包むだけ。
> 親 Presenter の Output / `didSelectTemplate` は `@Model`（`SeatingLayoutTemplate`）を
> 受け取り、そこで初めて Snapshot に落とす。
> 双子の FavoriteGroup は既に「一覧・削除は子、保存・読込は親、View は ViewData.Row のみ」
> まで終わっている。同じシート UX が、モジュール境界では世代差になっている。

これは巨大モジュールの空洞化ではない。**親計画のオプション（5d）を後回しにしたことによる、規約の半適用**である。
対象 View は 92 行。小さいから残すと、全社規約が「FavoriteGroup だけ完成形」に分岐する。

各層の「あるべき責務」と「実際の中身」を対比すると次のとおり。

| 層 | VIPER における責務 | 現状 | 判定 |
| --- | --- | --- | --- |
| View（一覧） | 受動的な描画とイベント転送。Entity を知らない | `@Query` + `@Model` + `modelContext.delete`。空状態は自前 VStack。Copy なし | ✗ 重大 |
| Interactor（子） | 一覧・削除の唯一の窓口 | **ファイルが無い。** 削除は View、取得は `@Query` | ✗ 不在 |
| Presenter（子） | ViewData 生成と Interactor / Output への仲介 | **ファイルが無い。** 選択は View のクロージャ | ✗ 不在 |
| Entity | Interactor が扱う純粋なモデル | `LayoutTemplateSnapshot` は親 Entity に同居し、**id が無い**。`@Model` が Output を貫通 | △ 不完全 |
| Router（子） | モジュール組み立て | **ファイルが無い。** 親 Router が素の View を生成 | ✗ 不在 |
| Contracts（子） | 層間境界の明示 | 親に `TemplateListModuleOutput` だけある。入力が `@Model` | △ 親に寄生 |
| 横断（親） | 保存・読込適用は親。一覧・削除は子 | 保存は親。適用は親だが入力が `@Model`。一覧・削除は View。Gateway は親 View `onAppear` attach | ✗ 二重窓口 |
| 横断（命名） | 1 概念 1 名前 | `SeatingTemplate`（フォルダ） / `SeatingLayoutTemplate`（`@Model`） / `LayoutTemplateSnapshot` / `TemplateListModuleOutput` / 親 CTA「お気に入り」が併存 | △ 混乱 |
| 横断（UI） | FavoriteGroup と同一のシート型 | `SavedListRow` / `SheetChromeToolbar` は乗った。`EmptyStateView` / Copy / A11y / List 内空状態は未接続 | △ 半適用 |

本計画は既存の VIPER 命名と SeatingChart Phase 4〜5 の成果（親が保存・適用、
Gateway インスタンス、`TemplateListModuleOutput`、detent は Router）を**維持したまま**、
上記の継ぎ目を正しい層へ戻す。主要な作業は次の 3 本柱。

1. **子モジュールの確立**: View から `@Query` / `@Model` / `ModelContext` を排除し、FavoriteGroup と同じ 5 層にする
2. **永続化 API の Snapshot / ID 志向化**: Gateway が `@Model` を返さない。選択は ID、適用は `fetch(id:)`
3. **継ぎ接ぎの解消**: Output の `@Model` 貫通、シート再生成、空状態 / Copy / A11y を FavoriteGroup に揃える

FavoriteGroup 側で既に存在する資産（`EmptyStateView` / `SavedListRow` / `SheetChromeToolbar` /
`OptionalAccessibilityHint` / `route` + Binding / MainActor + 具象保持の deinit 回避 /
`*GatewayBase` / 親 Presenter による子 Presenter 保持）は再利用し、同じ問題を三度設計しない。

`refactor_seating.md` の当初 Contracts には既に
`applyTemplate(id:)` が書いてある。実装は `applyTemplate(_ snapshot:)` に着地し、
一覧側の ID 適用は未着手のまま残った。本計画はその未了を閉じる。

---

## 1. 本プロジェクトにおける VIPER の解釈（再掲・SeatingTemplate 向け注釈）

古典的 VIPER は UIKit + delegate 前提のため、SwiftUI に合わせて次のように読む。
**これは `refactor_seating.md` §1 と同一の全社規約**であり、本モジュールも例外にしない。

| 層 | 実装形態 | 依存してよいもの | 禁止事項 |
| --- | --- | --- | --- |
| **View** | `struct: View`。`@StateObject var presenter` を保持 | Presenter が公開する **ViewData** と **Route** のみ | Entity の直接参照、`@Query`、`ModelContext`、業務条件分岐、遷移状態の保持 |
| **Presenter** | `@MainActor final class: ObservableObject` + `PresenterProtocol` | Interactor（具象）、Router（必要なときだけ具象）、Entity → ViewData 変換、親 Output | ビジネスルールの判断、永続化、SwiftUI の描画 API、`AnyView` の工場化 |
| **Interactor** | `nonisolated final class: InteractorProtocol` | Entity、Entity Gateway（`*GatewayBase`） | `SwiftUI` / `UIKit` の import、Presenter・View への参照、`@Model` の画面向け加工 |
| **Entity** | 値型 `struct` / `enum` | `Foundation` のみ | ロジック（軽量な計算プロパティは可） |
| **Router** | `final class`。画面内遷移が無いなら Protocol は置かない | モジュール組み立て | ビジネスルール、Entity の加工、空の `RouterProtocol` |

補足（SeatingTemplate 固有）:

- **`ObservableObject` は Protocol に載せない。** SeatingChart / FavoriteGroup と同じ。
  protocol existential を MainActor クラスが保持すると deinit で malloc abort するため、
  Interactor / Gateway は**具象型（または `*GatewayBase`）で保持**する。
- **空の `RouterProtocol` は置かない。** `refactor_simple.md` Phase 1 の決定。
  子に画面内の子組み立てが無いなら、`static assemblePresenter` / `assembleView` /
  `assembleModule` だけでよい（FavoriteGroupRouter と同型）。
- **Gateway の attach は親 Interactor の責務。** 子は **assemble 時に同じインスタンスを注入済み**。
  親 SeatingChart の View `onAppear` attach は SwiftData 制約上の過渡期として残してよい
  （`refactor_AttendeeList.md` §8.4 と同じ判断）。
- **永続化モデル（`@Model`）は View / Presenter に出さない。** 現状は一覧 View も親 Presenter も
  `SeatingLayoutTemplate` を直接扱う。FavoriteGroup の `ViewData.Row` + 親の `loadFavorite(id:)`
  と同じく、表示は Row、適用は ID 経由の Snapshot にする。
- **提示は Presenter の `route` が単一の真実。** 親は既に `SeatingChartRoute.templateList`。
  子の失敗（一覧取得・削除）は子の `route = .alert`。成功時のシート閉鎖は親 route。
- **一覧・削除は子、保存・読込適用は親。** FavoriteGroup Phase 5 の判断をここでも採る。
  親 Interactor に一覧・削除 API は新設しない。
- **選択の Output は ID。** `@Model` もフル Snapshot も子から親へ渡さない。
  親が `fetch(id:)` → `applyTemplate(snapshot)` する（お気に入りの `loadFavorite(id:)` と同型）。

---

## 2. 現状の責務違反マッピング

### 2.1 View（`SeatingTemplateListView.swift` / 92 行）

FavoriteGroup Phase 5〜6 の行 UI / クロムだけ先に乗った、**永続化つき SwiftUI 画面**である。

| 箇所 | 内容 | 本来の層 / あるべき形 |
| --- | --- | --- |
| 13–17 | `@Environment(\.modelContext)` と `@Query` | **禁止。** 子 View は ModelContext を持たない（FavoriteGroup と同じ） |
| 19 | `onSelect: (SeatingLayoutTemplate) -> Void` | **Output**。Presenter が ID を渡す。View は Entity を知らない |
| 14, 46 | `dismiss()` でシートを閉じる | 選択成功は **親 Output**。閉じるボタンも Output `didCancel`（親が route を落とす） |
| 27–38 | 空状態が自前 `VStack` + SF Symbol。`EmptyStateView` 未使用 | **`EmptyStateView`**（FavoriteGroup は List 内） |
| 41–56 | `ForEach(templates)` が `@Model` を描き、`tables.count` を View で計算 | **ViewData.Row**（`id` / `name` / `tableCountLabel`） |
| 57 | `onDelete` が View 内 `deleteTemplate` | Presenter → Interactor。受け渡しの IndexSet は当面可。永続化は **ID 配列** |
| 82–90 | `modelContext.delete`。Gateway を通らない。`save()` も無い（autosave 依存） | **Gateway.delete(ids:)**。永続化経路を 1 本にする |
| 35, 63 | 空メッセージ / タイトルが生リテラル。字幕・編集・閉じるだけ `String(localized:)` | **Copy 型**（`FavoriteGroupCopy` / `BulkAddCopy` と同じ） |
| 43–47 | 編集中は選択しない（正しい）。FavoriteGroup はこれを後から真似た | **残す。** View の `EditMode` ローカル状態は未確定 UI として妥当 |
| 48–53 | `SavedListRow` に `.padding(.vertical, 4)` と `.foregroundColor(.primary)` | FavoriteGroup は素の Row。差分をやめる |
| — | List の `.listStyle` 未指定。FavoriteGroup は `.plain` | Phase 5 で揃える |
| — | 行 / 閉じる / 空状態の accessibilityHint が無い | Phase 6。FavoriteGroupCopy の対訳をテンプレ用に置く |
| — | Preview が無い | In-Memory Gateway で空 / 1 件の Preview（FavoriteGroup と同じ） |

View に残してよいもの:

| 残す | 理由 |
| --- | --- |
| `EditMode` のローカル状態 | 未確定の編集 UI。確定（削除）だけ Presenter へ |
| シート内 `NavigationStack` | FavoriteGroup と同じ。detent は Router 組み立て側 |
| 編集中選択の無効化 | 誤読込防止。既に正しく、FavoriteGroup の正本になった |

### 2.2 子 Presenter / Interactor / Router / Contracts

**存在しない。** 親側の代替が次のとおり歪んでいる。

| 現状の代替 | 問題 |
| --- | --- |
| View の `onSelect` クロージャ | Output Protocol を View が直接満たす形にならない。テストが View に依存する |
| `SeatingChartRouter.makeTemplateListModule` が素の View を生成 | TableEdit / VenueSettings / FavoriteGroup と組み立て規約が違う。Gateway を渡せない |
| `TemplateListModuleOutput.templateListDidSelect(template:)` | `@Model` がモジュール境界を越える。In-Memory テスト以外でシートを再現できない |
| `templateListDidCancel()` | **本番から呼ばれない。** 閉じるは `dismiss()`、スワイプは親の `sheetRouteBinding` → `dismissRoute()`。Output の cancel は死に API |
| 親 `didSelectTemplate(_ template: SeatingLayoutTemplate)` | PresenterProtocol が SwiftData モデルを公開する |
| 親 `applyTemplate(_ template: SeatingLayoutTemplate)` | Interactor は既に Snapshot を受け取る。Presenter が `@Model` → Snapshot の変換器になっている |

### 2.3 Entity / 命名 / 配置

| 現状 | 問題 |
| --- | --- |
| `LayoutTemplateSnapshot` が `SeatingChartEntity.swift` にあり、`id` が無い | 子が親 Entity に寄生。選択を ID にできない。Equatable / `nonisolated` も未付与（兄弟型と不揃い） |
| `TemplateSaveAvailability` / `TemplateSaveError` も親 Entity | 保存は親の責務なので親に残してよい。ただし `notFound` が無い。ID 読込失敗を表せない |
| `TableTemplate` が `@Model` ファイルに Codable マイグレーション付きで同居 | 値型としては正当。所在は永続化側でよい。子 Entity が `TableTemplate` に依存するのは許容 |
| `Modules/SeatingTemplate/` に View と `@Model` が同居 | 画面と永続化の境界がフォルダでも無い。FavoriteGroup は画面フォルダと `@Model` フォルダを分けた |
| `TemplateListModuleOutput` という名前 | 子モジュール型名と不一致。フォルダは `SeatingTemplate` |
| 親 CTA が「お気に入り」+ `star.fill`、シートタイトルが「テンプレート読込」 | プロダクト文言の分裂。本計画では **文言自体は変えない**（§9） |

`SeatingLayoutTemplate` フォルダ / 型名のリネームは SwiftData のユニーク制約・既存ストアに触るため
**本計画では行わない。** 文書とコメントで「画面 = SeatingTemplate、永続化 = SeatingLayoutTemplate」と固定する。

### 2.4 Router / 親との接続

`makeTemplateListModule` の detent 位置は正しい（FavoriteGroup Phase 4 がここを正本にした）。
問題は組み立てと寿命である。

| 箇所 | 内容 | 問題 |
| --- | --- | --- |
| `SeatingChartRouter.swift:46-52` | 素の `SeatingTemplateListView` + 選択クロージャ | Gateway を注入できない。子 Presenter が無いので identity も無い |
| `SeatingChartPresenter.makeRouteSheet` | `.templateList` のたびに `makeTemplateListModule` | `.sheet(item:)` の content 再評価で **View（将来は Presenter）が再生成**され、編集中状態 / 子 alert が消える |
| `SeatingChartView.onAppear` | `attachTemplateGateway(SwiftData…)` | 過渡期としては親と同じ。子シートは親の現行 Gateway を使う必要があり、今は使っていない（`@Query` が別経路） |
| 親 Interactor | 一覧・削除 API が無い | 正しい（子が持つべき）。ただし View が直削除するので Gateway の `delete(id:)` は保存以外から呼ばれない |
| 親 Presenter | `currentTemplateGateway()` が無い | FavoriteGroup は `gatewayHolder` 経由。テンプレ子を assemble する口が親に無い |

### 2.5 Gateway（`SeatingTemplateGateway.swift`）

FavoriteGroup Phase 3 より一段古い API。削除は既に ID だが、戻り値が `@Model` のまま。

| 箇所 | 内容 | 問題 |
| --- | --- | --- |
| `fetchAll() -> [SeatingLayoutTemplate]` | Interactor / テスト / 将来の子が `@Model` に結合 | Snapshot を返す |
| `insert(_ template: SeatingLayoutTemplate)` | 親 Interactor が `@Model` を new している | `insert(name:tables:globalColumnCount:)` または Snapshot 受け |
| `delete(id: UUID)` | 1 件ずつ。View の複数行削除は `IndexSet` + `modelContext` | `delete(ids:)` に揃える（FavoriteGroup と同じ） |
| `fetch(id:)` が無い | 親の読込適用が `@Model` 手渡し前提 | 追加する。当初の seating 計画の `applyTemplate(id:)` をここで支える |
| `SeatingTemplateGatewayBase` の空実装 | 未 override が成功扱いで黙る | 既存規約（deinit 回避）なので維持 |
| `InMemorySeatingTemplateGateway.templates` | `[SeatingLayoutTemplate]` を公開 | テストが `@Model` に依存。Snapshot 化後は `fetchAll()` で断言する |

`*GatewayBase` 継承は **deinit 回避のためのプロジェクト規約**である。
Protocol existential 保持に戻さない。

### 2.6 親 Presenter / Interactor のテンプレ経路

保存側は概ね正しい。読込側だけ層が逆転している。

| 箇所 | 内容 | あるべき形 |
| --- | --- | --- |
| Interactor `saveCurrentLayoutAsTemplate` | Snapshot を作り `@Model` を insert | insert API が Snapshot / フィールド受けになれば `@Model` が親から消える |
| Interactor `applyTemplate(_ snapshot:)` | レイアウト復元。ID 継承・既定値更新 | **残す。** 入口を `loadAndApplyTemplate(id:)` で包む |
| Interactor `templateSaveAvailability` | `fetchCount()`。失敗は `try?` で 0 | 本計画の範囲外（保存側）。触らない |
| Presenter `didSelectTemplate(@Model)` | Snapshot に手で写して apply | `templateListDidSelect(id:)` → Interactor が fetch + apply |
| Presenter `applyTemplate(@Model)` | テストから直接呼ばれている | テストは Snapshot または ID に移す。公開面から `@Model` を消す |
| `TemplateSaveError` | `notFound` が無い | ID 読込用に追加。見つからなければシートを閉じず / 静かに return するかは §9 |

---

## 3. 目標とするモジュール境界

FavoriteGroup と同じ完成形。親の役割は「保存」と「ID 指定の適用」だけ。

```
SeatingChart（親）
  ├─ 保存: templateSaveAvailability / saveCurrentLayoutAsTemplate
  ├─ 読込適用: loadAndApplyTemplate(id:) → fetch(id:) + applyTemplate(snapshot)
  ├─ Gateway 所有: attach は親 View onAppear（過渡期）
  └─ Output 受信: templateListDidSelect(id:) / templateListDidCancel()
        │
        │ assemble 時に同じ Gateway インスタンスを渡す
        ▼
SeatingTemplate（子）
  ├─ 一覧: allTemplates() throws
  ├─ 削除: deleteTemplates(ids:)
  ├─ ViewData.Row のみ描画
  └─ 失敗は route = .alert
```

### 3.1 目標ディレクトリ

```
SakuttoSeat/
├── Core/
│   └── Gateways/
│       └── SeatingTemplateGateway.swift   // Snapshot 戻り / fetch(id:) / delete(ids:) / insert(fields)
├── Modules/
│   ├── SeatingTemplate/
│   │   ├── SeatingTemplateContracts.swift
│   │   ├── SeatingTemplateEntity.swift    // ★ ID / Snapshot の所在（適用に必要な tables を含む）
│   │   ├── SeatingTemplateInteractor.swift
│   │   ├── SeatingTemplatePresenter.swift
│   │   ├── SeatingTemplateRouter.swift
│   │   ├── SeatingTemplateViewData.swift  // ★ Row + Builder + Copy
│   │   ├── SeatingTemplateRoute.swift     // ★ 子の alert
│   │   └── SeatingTemplateView.swift      // 旧 SeatingTemplateListView を置換
│   │   └── SeatingLayoutTemplate.swift    // @Model + TableTemplate（永続化。画面型は同居させない）
│   └── SeatingChart/
│       └── SeatingChartEntity.swift       // TemplateSave* は親に残す。Snapshot は移設
└── Components/
    ├── EmptyStateView.swift               // 既存。空状態で使用
    ├── SavedListRow.swift                 // 既存。余分な padding をやめる
    └── SheetChromeToolbar.swift           // 既存。A11y 引数を FavoriteGroup と同様に渡す
```

`SeatingLayoutTemplate` を `Modules/SeatingTemplate/` に残すのは、FavoriteGroup が
`GroupFavorite/` を分けたのに対し、テンプレの `@Model` 利用者が親と Gateway しか居ないため。
別フォルダへの移動は Xcode / インポートのノイズだけで得が少ない。**本計画ではファイル移動しない。**
コメントで「永続化モデル。画面型は `SeatingTemplate*`」と固定する。

### 3.2 目標 Contracts（骨子）

```swift
// View <- Presenter
@MainActor
protocol SeatingTemplatePresenterProtocol: AnyObject {
    var viewData: SeatingTemplateViewData { get }
    var route: SeatingTemplateRoute? { get set }

    func onAppear()
    func didSelectTemplate(id: SeatingTemplateID)
    func didDeleteTemplates(at offsets: IndexSet)
    func didTapClose()
    func dismissRoute()
}

// Presenter -> Interactor
nonisolated protocol SeatingTemplateInteractorProtocol: AnyObject {
    func allTemplates() throws -> [LayoutTemplateSnapshot]
    func deleteTemplates(ids: [SeatingTemplateID]) throws
}

// Presenter -> 親
protocol SeatingTemplateModuleOutput: AnyObject {
    func templateListDidSelect(id: SeatingTemplateID)
    func templateListDidCancel()
}
```

既存の `TemplateListModuleOutput` は `SeatingTemplateModuleOutput` にリネームし、
引数を `@Model` から ID にする。親 Router Protocol の
`makeTemplateListModule(output:)` は、FavoriteGroup に合わせて

```swift
@MainActor func makeTemplateListPresenter(
    gatewayHolder: SeatingChartInteractor,
    output: (any SeatingTemplateModuleOutput)?
) -> SeatingTemplatePresenter

@MainActor func makeTemplateListSheet(presenter: SeatingTemplatePresenter) -> AnyView
```

に分割する（assemble とシート View を分ける。Phase 4 の identity 用）。

ViewData:

```swift
struct SeatingTemplateViewData: Equatable {
    struct Row: Identifiable, Equatable {
        let id: SeatingTemplateID
        let name: String
        let tableCountLabel: String
    }
    let rows: [Row]
    var isEmpty: Bool { rows.isEmpty }
    static let empty = SeatingTemplateViewData(rows: [])
}
```

`tables` 配列は Entity（Snapshot）に残し、ViewData には載せない。
一覧描画に不要なレイアウト実体を View に渡さない。

Route:

```swift
enum SeatingTemplateRoute: Identifiable, Equatable {
    case alert(SeatingTemplateAlert)
}

enum SeatingTemplateAlert: Equatable, Identifiable {
    case deleteFailed(message: String)
    case loadFailed(message: String)
}
```

親の `SeatingChartInteractorProtocol` から消すもの: なし（一覧・削除は元々無い）。
追加するもの: `loadAndApplyTemplate(id:) throws -> [SeatingTable]`（または既存
`applyTemplate` を内部利用する薄いラッパ）。
`didSelectTemplate(_ template: SeatingLayoutTemplate)` と
`applyTemplate(_ template: SeatingLayoutTemplate)` は Presenter 公開面から消す。

`currentTemplateGateway()` は Router 組み立て用に Interactor が返す。
Presenter の公開面からは Gateway 型を出さない（FavoriteGroup の `gatewayHolder` と同型）。

### 3.3 Gateway 目標 API

```swift
protocol SeatingTemplateGateway: AnyObject {
    func fetchCount() throws -> Int
    func fetchAll() throws -> [LayoutTemplateSnapshot]
    func fetch(id: SeatingTemplateID) throws -> LayoutTemplateSnapshot?
    func insert(name: String, tables: [TableTemplate], globalColumnCount: Int) throws
    func delete(ids: [SeatingTemplateID]) throws
}
```

`*GatewayBase` 継承は維持する。`insert` が `SeatingLayoutTemplate` を受け取らないようにすると、
親 Interactor からも `@Model` が消える。

Snapshot:

```swift
typealias SeatingTemplateID = UUID

nonisolated struct LayoutTemplateSnapshot: Identifiable, Equatable {
    let id: SeatingTemplateID
    let name: String
    let tables: [TableTemplate]
    let globalColumnCount: Int
}
```

`id` を足す。保存直後に親が Snapshot を保持する必要は無い（一覧は子が fetchAll）。
`makeLayoutTemplate(named:)` は適用前の未永続化 Snapshot なので、id は `UUID()` で埋めてよい。
永続化後の id は Gateway が `@Model.id` から写す。

互換の進め方:

1. 既存メソッドを残したまま `fetch(id:)` / `delete(ids:)` / Snapshot 戻り / フィールド insert を追加
2. 呼び出し側を移す
3. `delete(id:)` 単数、`insert(_ template:)`、`fetchAll() -> [SeatingLayoutTemplate]` を削除

一度に差し替えると InMemory / SwiftData / 親の保存テスト / ViewData テストが同時に割れる。

`TemplateSaveError.notFound` を追加し、`loadAndApplyTemplate` が見つからない ID を表す。

---

## 4. 再利用性

### 4.1 今すぐ SeatingTemplate 内で揃えるもの

| 部品 | 現状の分裂 | 寄せ先 |
| --- | --- | --- |
| 空状態 | 自前 VStack。FavoriteGroup は `EmptyStateView` + List 内 | `EmptyStateView`。アイコンは `square.grid.2x2` のまま（用途差） |
| 行 | `SavedListRow` 使用済み。余分な padding / foregroundColor | 素の `SavedListRow`（FavoriteGroup と同じ呼び出し） |
| クロム | `SheetChromeToolbar` 使用済み。A11y 引数未接続 | FavoriteGroup と同じ引数セット |
| 文言 | 生リテラルと `String(localized:)` の混在 | `SeatingTemplateCopy` |
| 失敗 Gateway | 子テストが無い | テスト用 `FailingSeatingTemplateGateway` をテストターゲットへ |
| List スタイル | デフォルト vs FavoriteGroup `.plain` | `.plain` に揃える |
| Preview | 無し | In-Memory で空 / 1 件 |

### 4.2 FavoriteGroup との共通化（これ以上の新規部品は作らない）

`refactor_favorite.md` Phase 5 が先に切り出した部品を**使う側**として完成させる。
新しい共有コンポーネントは作らない。

| 既存部品 | テンプレ側の使い残し |
| --- | --- |
| `SavedListRow` | 呼び出しの修飾をやめる |
| `SheetChromeToolbar` | A11y Label / Hint を渡す |
| `EmptyStateView` | 空状態を置換。Hint は Copy |
| `OptionalAccessibilityHint` | クロムと空状態経由で使う。直接は触らない |

「保存済み一覧シート」の第三実装は作らない。FavoriteGroupView を汎用化して
テンプレをパラメータ化することも **しない**。ドメイン（グループ vs レイアウト）と
親 Output が違う。揃えるのは部品と層の形だけ。

### 4.3 親との型共有

`SeatingTemplateID` / `LayoutTemplateSnapshot` は **SeatingTemplate（子）の所有**にする。
SeatingChart はそれを import して保存・適用に使う。
依存の向きを「子が親 Entity を借りる」から「親が子（共有）Entity を使う」へ逆転させる
（FavoriteGroupEntity と同じ判断）。

`TemplateSaveAvailability` / `TemplateSaveError` は保存の話なので **親に残す。**
`notFound` だけ親の `TemplateSaveError` に足す。
`SaveAvailability` 共通化は `refactor_AttendeeList.md` §8.3 の未決のまま **触らない。**

`TableTemplate` は Codable マイグレーションを含むため
`SeatingLayoutTemplate.swift` に残す。Snapshot が参照する永続化ペイロード、という位置づけ。

---

## 5. パフォーマンス

無料枠は 3 件（`FeatureLimit.freeTemplateCount`）なので、一覧の描画コストは実害になりにくい。
直す価値があるのは **誤った複雑度の API** と **シート再生成** と **永続化の二重経路** である。
有料で件数制限が外れたときに、`@Query` + `@Model.tables` の全件実体化がそのまま残るのを防ぐ。

| # | 現状 | 影響 | 対策 | Phase |
| --- | --- | --- | --- | --- |
| 1 | 一覧 View が `@Query` で `@Model` を購読し、字幕で `tables.count` | 行表示のために tables 配列を fault する。Gateway の `fetchAll` と二重ソース | 子は Gateway。ViewData は count ラベルのみ | 2–3 |
| 2 | 削除が View の `modelContext.delete`、保存が Gateway `insert` + `save` | autosave 依存と明示 save が混在。失敗がユーザーに見えない | 削除も Gateway。失敗は route | 2–3 |
| 3 | 選択が `@Model` 手渡し | シートを閉じたあと親がモデルを読む。context 外アクセスになりうる | `fetch(id:)` → Snapshot（値型） | 3 |
| 4 | `makeRouteSheet` が毎回素の View を生成 | 親再評価で編集モード / 将来の子 alert が消える | 親が子 Presenter を route 期間中保持 | 4 |
| 5 | `LayoutTemplateSnapshot` に id が無く、適用が手渡し | 一覧と適用で同じ実体を 2 回運ぶ | ID 選択 + fetch | 3 |
| 6 | Gateway `fetchAll` がフル `@Model` | 一覧に不要な tables 実体を親保存テスト以外にも配る | Snapshot 化。ViewData は count のみ。フル tables は Entity に残す | 3 |
| 7 | 一覧取得失敗を `@Query` が隠す（空 or crash） | ユーザーは「0 件」と誤認しうる | `throws` + route（FavoriteGroup Phase 2 と同じ） | 2 |
| 8 | 字幕の `String(localized: "テーブル数: \(count)")` を毎行 | 3 件では無視できる | Builder 側でよく、先行最適化しない | — |

やらないこと:

- 一覧の差分更新 / ページング（件数が桁違いになるまで不要）
- 一覧用の軽量 DTO と適用用 Snapshot の二系統（3 件 + tables はレイアウト定義のみ。早すぎる分割）
- `@Query` の子モジュール内再導入（VIPER に戻る）
- Gateway のプロトコル existential 化（deinit 事故）
- `SaveAvailability` のテンプレ / お気に入り統合

---

## 6. 実行計画（フェーズ分割）

各フェーズは独立してマージ可能。
**「安全網 → 嘘を消す → 子の契約を立てる → 永続化 API → シート安定 → 再利用 → 仕上げ」** の順。
挙動を変えない整理を先に済ませる。FavoriteGroup と同じ。

FavoriteGroup と違う点は、**子の 5 層がまだ無い**こと。Phase 2 で箱ごと作る。
Phase 2 の時点では Gateway 旧 API を Interactor 内で Snapshot に写してもよい。
Phase 3 で写像を Gateway に移し、旧 API を削除する。

### Phase 0: 準備と回帰テスト（0.5 日）

現状の挙動を固定する characterization を足す。子モジュールはまだ無いので、
Gateway と親のテンプレ経路を厚くする。

最低限追加する仕様:

- Gateway: `fetchAll` は `createdAt` の新しい順
- Gateway: `delete(id:)` で 1 件消える。存在しない ID は無視（現行の fetch + ループ）
- Gateway: `insert` 後に count が増える
- 親: `didSelectTemplate(@Model)` で会場列数が ViewData に入り route が nil（既存。残す）
- 親: `applyTemplate(@Model)` の ID 継承 / スクロール（既存。残す）
- 親: `makeTemplateListModule` が `SeatingTemplateListView` を返すこと（Router テスト新設）
- 親: `templateListDidCancel` が route を nil にすること（現行は実装あり、呼び出し元なし。挙動は固定）
- `_既知の課題`: 一覧削除は View の `ModelContext` であり Gateway を通らない（コメントで固定。テストは書ける範囲で Gateway 側のみ）

完了条件: 見た目を変えずにテスト green。以降の回帰基準とする。
リスク: 低。

実装時の決定（2026-09-11）:

- 新設: `SeatingTemplateTests`（In-Memory と SwiftData In-Memory の両方で新しい順 / insert / ID 削除 / 欠損 ID 無視）。
- 新設: `SeatingChartRouterTests`（`makeTemplateListModule` が `SeatingTemplateListView` を包む。Gateway は渡せず fetch しない）。
- 親 Presenter: `didTapLoadTemplate` / Output 選択 / Output cancel / `makeRouteSheet(.templateList)`。
- 親 Interactor: `attachTemplateGateway` の差し替え。
- 子 VIPER / Protocol は未作成。`TemplateListModuleOutput` は現状の `@Model` 受けのまま固定する。
- プロダクト差分は既知課題のコメントのみ。挙動は変えていない。

### Phase 1: デッド API・コメント偽証・規約穴埋め（0.5 日）

挙動を変えない範囲で継ぎ目を消す。VIPER ファイルはまだ増やさない。

- `SeatingTemplateListView` / `SeatingChartRouter` ヘッダを、
  **「一覧は未 VIPER。FavoriteGroup 完成形へ移す対象」** と明記する（本計画へのポインタ）。
- `templateListDidCancel` が本番未接続であることを親 Presenter に 1 行で書く。
  消さず、Phase 2 で閉じるボタンから呼ぶ。
- `LayoutTemplateSnapshot` に `id` を **オプショナルではなく必須で足す**と呼び出しが全部割れるので、
  Phase 1 では足さない。コメントで「id は Phase 3」と固定してよい。
- 親 CTA「お気に入り」は変えない（§9）。
- 完了条件: ビルド成功、Phase 0 green、差分がコメントに限定。
- リスク: 低。

Phase 1 で Copy / EmptyStateView を旧 View に入れない。
入れても Phase 2 で View を置き換えるため二重作業になる。

実装時の決定（2026-09-11）:

- `SeatingTemplateListView` / `SeatingChartRouter` ヘッダに「一覧は未 VIPER。FavoriteGroup 完成形へ移す対象」を明記。
- 空状態の「お気に入り画面と同様」コメントは偽証だったため、自前 VStack / EmptyStateView は Phase 2 と書き直した（UI は未変更）。
- `templateListDidCancel` は Presenter / Contracts に本番未接続と書いた。実装は残した。
- `LayoutTemplateSnapshot.id` は足していない。コメントで Phase 3 と固定。
- `SeatingLayoutTemplate` に「永続化モデル。画面型は `SeatingTemplate*`」を固定。型名はリネームしていない。
- 親 CTA「お気に入り」は変えていない。Copy / EmptyStateView / 子 VIPER ファイルは未導入。

### Phase 2: 子 VIPER 化（ViewData.Row / Route / Entity）（1.5 日）

**本計画の中核。View から `@Query` / `@Model` / `ModelContext` を排除する。**

- `SeatingTemplate` に Contracts / Interactor / Presenter / Router / ViewData / Route / Entity / View を新設。
  `SeatingTemplateListView.swift` は新しい `SeatingTemplateView` に置換して削除。
- `SeatingTemplateEntity`: `SeatingTemplateID`。この時点の Snapshot は、Gateway がまだ `@Model` を返すなら
  Interactor が `LayoutTemplateSnapshot` へ写す（id は `template.id`）。
  親の `LayoutTemplateSnapshot` に暫定で `id: UUID = UUID()` を足し、既存の `makeLayoutTemplate` を壊さない。
- View は `viewData.rows` のみ。`EmptyStateView` + `SavedListRow` + `SheetChromeToolbar`。
  編集中は選択しない。全削除後に `editMode = .inactive`。
- 閉じるは `presenter.didTapClose()` → Output `templateListDidCancel()`。`dismiss()` に頼らない
  （親の sheet Binding が route を落とす経路と二重にならないよう、FavoriteGroup と同じく Output だけ）。
- 選択は `didSelectTemplate(id:)` → Output。親は暫定で `fetchAll` + `first(where:)` でもよいが、
  **推奨は Phase 2 のうちに Gateway `fetch(id:)` を加法的に足し、親を ID 適用にする。**
  `fetch(id:)` を Phase 3 に残すと Output を二度変える。
- 取得 / 削除失敗は `route = .alert`。Binding は FavoriteGroup の `alertIsPresentedBinding` を踏襲。
- `SeatingTemplateCopy` を置き、View の文言 API を揃える（文言自体は変えない）。
- 子 Presenter に `nonisolated deinit {}`（FavoriteGroup / AttendeeList と同じ）。
- 親 Router は `SeatingTemplateRouter.assembleModule(gateway:output:)` に委譲。
  この時点では毎回 assemble でよい（identity は Phase 4）。
- Preview は In-Memory Gateway。
- 完了条件: プロダクトの View に `@Query` / `ModelContext` / `SeatingLayoutTemplate` が無い。
  `SeatingTemplateTests` が一覧・削除・Output・取得失敗をカバー。親の `didSelectTemplate(@Model)` が消える。
- リスク: 中（シート UX を FavoriteGroup に寄せる。空状態が List 内になる等の見た目差）。

実装時に決めること（Phase 2）:

- 親 PresenterProtocol から `@Model` を出した瞬間に
  `SeatingChartPresenterTests` / `ViewDataTests` の `SeatingLayoutTemplate(...)` 生成を
  ID または Snapshot に移す。Phase 0 の characterization をここで更新する。
- Output プロトコル名を `SeatingTemplateModuleOutput` にリネームするなら、
  親 Contracts / Presenter extension を同コミットで置換する。typealias 残しは移行コミットだけ許容。

実装時の決定（2026-09-11）:

- 子 5 層を FavoriteGroup と同型で新設。`SeatingTemplateListView` は `SeatingTemplateView` に置換して削除。
- View から `@Query` / `ModelContext` / `SeatingLayoutTemplate` を排除。空状態は List 内 `EmptyStateView`。
- Output は `SeatingTemplateModuleOutput` にリネームし、引数を ID にした。`templateListDidCancel` は閉じるボタンから接続。
- Gateway に `fetch(id:)` を加法。親 Interactor に `loadAndApplyTemplate(id:)`。見つからない ID は `TemplateSaveError.notFound` でシートを閉じない。
- `LayoutTemplateSnapshot.id` は必須（未永続化は `UUID()`）。所在の移設は Phase 3。Interactor から生成できるよう `nonisolated` を付与した。
- 親 Router は `SeatingTemplateRouter.assembleModule(gateway:output:)` に委譲。毎回 assemble（identity は Phase 4）。
- 削除は子 Interactor が旧 `delete(id:)` を回す。`delete(ids:)` / Snapshot 戻りは Phase 3。
- Copy は既存 Catalog キーのまま。A11y Hint は Phase 6。

### Phase 3: Gateway の Snapshot 化と親 Interactor の純化（1.0 日）

Phase 2 で先行済みのため、ここでは触らない:
`loadAndApplyTemplate(id:)`、`TemplateSaveError.notFound`（見つからない ID はシートを閉じない）。

- Gateway の戻りを Snapshot にし、`insert(name:tables:globalColumnCount:)` /
  `delete(ids:)` に切り替え、旧 API を削除。
- 親 `saveCurrentLayoutAsTemplate` から `SeatingLayoutTemplate(...)` の new を消す。
- 親 `loadAndApplyTemplate(id:)` を Interactor の正式入口にする。
  Presenter は ID を渡すだけ。`@Model` 型名が親 Presenter / Interactor から消える。
- `LayoutTemplateSnapshot` を `SeatingTemplateEntity.swift` へ移設。
  親 Entity からは削除（typealias 残しは移行コミットだけ）。
- 見つからない ID は親がシートを閉じない（Phase 2 で `notFound` 済み。アラートは persistence 失敗だけ）。
- `InMemorySeatingTemplateGateway.templates` の `@Model` 公開をやめる。
  テストは `fetchAll()` で断言。
- `@Model.makeSnapshot()` 相当は Gateway プライベート。
- 親 Presenter の `makeRouteSheet` から Gateway 型を消す。
  `router.makeTemplateListPresenter(gatewayHolder: interactor, output:)`。
- 完了条件: 子・親 Interactor / Presenter に `SeatingLayoutTemplate` 型名が無い
  （残ってよいのは Gateway ファイルと `@Model` 定義）。
  `insert(_ template:)` / `delete(id:)` 単数がプロダクトコードから消える。
- リスク: 中。Gateway 実装 2 系統 + 親テストを同時に更新する。

### Phase 4: シート identity と Router 境界（0.5 日）

- `.sheet(item:)` の content 再評価で子が再生成されないようにする。
  推奨: 親 Presenter が `.templateList` をセットするとき 1 度だけ assemble し、
  `makeRouteSheet` はそのインスタンスを返す。`setRoute` で `.templateList` 以外へ移ったら破棄。
  AttendeeList の `favoriteGroupPresenter` と同型。
- detent は既に Router 側。子 View には付けない（現状維持）。
- 空の `SeatingTemplateRouterProtocol` は作らない。
- Router / 親 Presenter テストで「シート期間中は同一 Presenter」「閉じたら破棄」
  「親と同じ Gateway インスタンス」を断言する（`AttendeeListPresenterTests` /
  `AttendeeListRouterTests` を正本にする）。
- 完了条件: 削除アラート表示中に親が再描画されてもアラートが消えない
  （手動 QA + Presenter 保持のユニットテスト）。
- リスク: 中（シート寿命）。保持し続けると Gateway 差し替え後に古い子が残るので、
  `didTapLoadTemplate` のたびに新規 assemble、閉じたら破棄、のルールをテストで固定する。

### Phase 5: 再利用部品の揃え（0.5 日）

Phase 2 で部品接続済みなら、残差だけ。

- 空状態を List 内 `EmptyStateView` に統一（Phase 2 で未了ならここで必須）。
- `SavedListRow` の余分な padding / foregroundColor をやめる。
- `.listStyle(.plain)`。
- FavoriteGroup とのスクリーンショット比較（空 / 1 件 / 3 件 / 編集モード）。
- 完了条件: 行・クロム・空状態の実装がコンポーネント経由。差分が主に呼び出し。
- リスク: 低。見た目を変えるならスクリーンショット比較。

### Phase 6: 性能・A11y・i18n・編集モード UX（0.5 日）

- 閉じる / 編集 / 空状態 / 行の accessibilityHint を FavoriteGroup と対になる文言にする。
  例: 「保存済みテンプレートの一覧を閉じます」 /
  「このテンプレートを座席表に読み込みます」 /
  「編集中は読み込みできません」（既存キー再利用可） /
  「閉じるボタンで座席表に戻ります」。
- VoiceOver: 一覧 → 選択でシートが閉じ、テーブル構成が置換されること。
- 削除失敗 / 読込失敗のタイトルは Catalog キー。SwiftUI `.alert` が読み上げる。
- Catalog は翻訳値を増やさない（ja のみ）方針を維持。キーを `String(localized:)` に揃えた漏れを埋める。
- 親 CTA「お気に入り」の A11y は本計画の範囲外（座席表本体は `refactor_seating.md` Phase 6）。
- `Self._printChanges()` は任意。Phase 4 の Presenter 保持テストで代替してよい。
- 完了条件: 編集中に誤って読み込まない（Phase 2 済みなら確認のみ）。空状態と 1 件状態で VoiceOver が辿れる。
- リスク: 低。

---

## 7. 見込み効果

| 指標 | 現状 | 目標 |
| --- | --- | --- |
| 一覧 View の `@Query` / `ModelContext` | あり | なし |
| View が Entity / `@Model` を直接参照 | あり（`SeatingLayoutTemplate`） | なし（`ViewData.Row` のみ） |
| 子の 5 層 | View 1 ファイル | FavoriteGroup と同型 |
| 親 Presenter の `@Model` 露出 | `didSelectTemplate` / `applyTemplate` | なし（ID のみ） |
| Output の入力 | `@Model` | `SeatingTemplateID` |
| `templateListDidCancel` | 死に API | 閉じるボタンから接続 |
| Snapshot の id | 無し | 必須 |
| 削除 API | View の IndexSet + `modelContext` | Gateway `delete(ids:)` |
| 読込 API | `@Model` 手渡し | `fetch(id:)` |
| 取得失敗 UX | `@Query` 任せ | アラート |
| シート中の子 Presenter | 毎回素の View | route 期間中は同一インスタンス |
| `@Model` が親 Interactor に出現 | insert 時に new | Gateway 内に閉じる |
| 空状態実装 | 自前 VStack | `EmptyStateView` |
| 行 UI の修飾差（お気に入り / テンプレ） | padding 差 | なし |
| SeatingTemplate ユニットテスト | 0 | 一覧 / 削除 / Output / 取得失敗 / シート identity |

---

## 8. 検証戦略

1. **層ごとのユニットテスト**
   - **子 Interactor**: In-Memory Gateway で新しい順、ID 削除、複数削除、取得失敗の throws。
   - **子 Presenter**: 意図メソッド → 期待する ViewData / Route。削除失敗で alert route。
     選択は Output のみ。Gateway 型を Presenter テストが組み立てに使ってもよいが、
     Protocol 経由の attach は無い。
   - **子 Router**: `assemblePresenter` が Gateway を Interactor に渡すこと。
   - **親 Interactor**: 保存・上限・`loadAndApplyTemplate(id:)`・`notFound`。
     適用の ID 継承・既定値更新は既存ケースを Snapshot / ID 入口に移して維持。
   - **親 Presenter**: Output 選択で適用 + シート閉鎖 + 子 Presenter 破棄。
     cancel でシート閉鎖。シート期間中の同一インスタンス。
   - **親 Router**: `makeTemplateListPresenter` が子 Router に委譲し、親と同じ Gateway を渡すこと。
2. **回帰基準**: Phase 0 のテストを全フェーズで維持。`@Model` 入口のケースは Phase 2 で ID / Snapshot に更新。
3. **既存 FavoriteGroup / AttendeeList / SimpleShuffle / Share スイートを壊さないこと。**
   Snapshot 移設で import が足りないとコンパイルが落ちるだけなので、移設は Phase 3 に閉じる。
4. **手動 QA（テンプレート導線）**
   - 空状態でシートを開く → 空メッセージ → 閉じる → 座席表に戻る
   - レイアウトを保存（上限未満）→ 一覧に名前とテーブル数が出る → 選択で構成が置換される
   - 別レイアウトを保存 → 新しい順（上）に出る
   - スワイプ削除 / 編集モード削除
   - 最後の 1 件を消したあと空状態になり、編集モードが解除される
   - 編集モード中に行をタップしても読み込まれない
   - 上限 3 で保存ボタンがアラート。削除後に再保存できる
   - シートを下へスワイプして閉じても、閉じるボタンと同じく親 route が nil になる
   - 参加者リストへ pop しても、保存済みテンプレートは残る
   - 列数 3 以上を含むテンプレートを、未解放セッションで読んでも構成は復元される
     （適用は保存済み値の復元であり、VenueSettings の広告ゲートを再発火させないこと。既存仕様の確認）
5. **再描画**: シート表示中に親キャンバスが不要に再構築されないこと。
   削除アラート表示中に親が `objectWillChange` しても子状態が消えないこと（Phase 4）。
6. **スクリーンショット**: 空 / 1 件 / 3 件、編集モード、ダークモード、Dynamic Type 最大。
   FavoriteGroup シートと並置してクロム・行・空状態の揃えを見る。

---

## 9. 実装前に決めるべきこと（要判断）

1. **`SeatingLayoutTemplate` フォルダ / 型名のリネーム**
   画面と `@Model` の語を揃えると分かりやすいが、SwiftData のユニーク制約・既存ストアに触る。
   **推奨: 本計画ではリネームしない。** コメントで役割を固定する。
2. **子モジュールの型名（`SeatingTemplate*` vs `TemplateList*`）**
   フォルダは `SeatingTemplate`。既存 Output は `TemplateList`。
   **推奨: `SeatingTemplate*` に揃える。** Output は `SeatingTemplateModuleOutput` にリネームし、
   親 Router メソッド `makeTemplateList*` は「一覧シート」という意味で残してよい
   （FavoriteGroup も画面名と `makeFavoriteGroup*` が一致している。こちらは
   `makeTemplateList*` のままの方が親 Route `.templateList` と近い）。
3. **共有型の置き場（SeatingTemplate vs Core）**
   Snapshot は子モジュール所有が VIPER 的に綺麗。親と Gateway の両方から見える。
   **推奨: まず `SeatingTemplateEntity.swift`。** 早すぎる Core 化はしない。
4. **Output を ID にするか Snapshot にするか**
   Snapshot 渡しなら `fetch(id:)` が無くても親 apply できる。ただし一覧取得で配った実体を
   選択時に再送する形になり、FavoriteGroup と契約が分岐する。
   **推奨: ID。** Phase 2 で `fetch(id:)` を加法的に入れ、Output を一度だけ変える。
5. **親 Presenter からの Gateway 型排除の方法**
   FavoriteGroup の (B): `router.makeTemplateListPresenter(gatewayHolder: interactor, output:)`。
   **推奨: 同じ。** Presenter は具象 Interactor を渡し、Gateway 型を言及しない。
6. **シート identity の持ち方**
   **推奨: 親 Presenter が保持。** Router キャッシュは dismiss 漏れで stale Gateway になりやすい。
   AttendeeList の `favoriteGroupPresenter` をコピーする。
7. **取得失敗をアラートにするか**
   `@Query` は失敗を空に見せることがある。
   **推奨: アラート。** Phase 0 で現状（テスト可能な範囲）を固定し、Phase 2 で変える。
8. **`notFound` の UX**
   通常は子一覧にある ID しか渡らない。
   **推奨: お気に入りと同じくシートを閉じず return。** アラートは persistence 失敗だけ。
9. **親 CTA「お気に入り」を「テンプレート」に改名するか**
   シートタイトル・上限アラートは「テンプレート」。ボタンだけ「お気に入り」。
   **推奨: 本計画では変えない。** プロダクト文言であり、VIPER 化と混ぜない。
   直すなら `refactor_seating.md` Phase 6（座席表本体の i18n）へ回す。
10. **`SaveAvailability` 共通化**
    AttendeeList §8.3 の未決。本計画では **触らない。**
11. **`AnyView` の許容範囲**
    Router の戻り値は現状どおり `AnyView`（SeatingChart と同じ）。View 内では禁止。
12. **削除確認ダイアログ**
    現状は即削除（スワイプ / 編集）。確認を足すと UX 変更になる。
    **推奨: 本計画では足さない。** 誤選択防止（編集中）は既にある。
13. **一覧用軽量 DTO と適用用 Snapshot の分割**
    **推奨: しない。** 1 つの `LayoutTemplateSnapshot`。ViewData.Row だけ薄くする。
14. **親 View の `onAppear` attach を assemble 時注入に前倒しするか**
    SwiftData の `ModelContext` は View ツリーに乗ってから安定する、という既存判断。
    **推奨: 親は現状維持。** 子だけ assemble 時注入（親の現行 Gateway を渡す）。

---

## 10. 想定工数

| Phase | 内容 | 工数 | VIPER 上の意義 |
| --- | --- | --- | --- |
| 0 | 準備・回帰テスト整備 | 0.5 日 | 移送の安全網。Gateway / 親 apply の固定 |
| 1 | コメント・死に API の明示 | 0.5 日 | 継ぎ目の嘘を消す。旧 View への Cop 先行はしない |
| 2 | 子 VIPER + ViewData.Row / Route / Entity | 1.5 日 | **層間境界の確立**（View から `@Query` を排除） |
| 3 | Gateway Snapshot 化・親から `@Model` 削除 | 1.0 日 | **永続化の単一窓口化** |
| 4 | シート identity | 0.5 日 | 子モジュール寿命を Router/Presenter が握る |
| 5 | 空状態・List・Row 呼び出しの揃え | 0.5 日 | FavoriteGroup との見た目契約 |
| 6 | A11y・i18n | 0.5 日 | 品質仕上げ |
| | **合計** | **5.0 日** | |

FavoriteGroup（4.5 日）より 0.5 日多い理由は、**5 層を新設する**ため。
逆に部品（Row / クロム / EmptyState / A11y modifier）は既にあるので Phase 5〜6 は薄い。

**推奨する区切り:**

- **第一弾（Phase 0〜2、2.5 日）**: 「View が `@Query` を知らない」「選択は ID」「提示は子 route」。
  体感負債の大半（SwiftData 直叩き、`@Model` Output、死んだ cancel、空状態の分裂）がここで消える。
- **第二弾（Phase 3〜4、1.5 日）**: 永続化 API とシート寿命を FavoriteGroup と同じ完成形にする。
- **第三弾（Phase 5〜6、1.0 日）**: 見た目の揃えと A11y。Phase 2 で部品接続済みなら短縮してよい。

Phase 2 を先に置く理由は FavoriteGroup と同じで、
契約と ViewData を先に作ると Phase 3 の Gateway 差し替えで **View を触らずに済む**ため。
ただし Output を二度変えないよう、`fetch(id:)` の **加法** は Phase 2 に含める。

---

## 11. 着手時に触るファイル（目安）

変更予定（実装はまだ行わない）:

第一弾:

- `SakuttoSeat/Modules/SeatingTemplate/*`（View 置換、5 層新設）
- `SakuttoSeat/Modules/SeatingChart/SeatingChartContracts.swift`（Output / Presenter API）
- `SakuttoSeat/Modules/SeatingChart/SeatingChartPresenter.swift`
- `SakuttoSeat/Modules/SeatingChart/SeatingChartRouter.swift`
- `SakuttoSeat/Modules/SeatingChart/SeatingChartInteractor.swift`（`loadAndApplyTemplate` / `fetch(id:)` 利用）
- `SakuttoSeat/Core/Gateways/SeatingTemplateGateway.swift`（`fetch(id:)` 加法）
- `SakuttoSeatTests/SeatingTemplateTests.swift`（新設）
- `SakuttoSeatTests/SeatingChartPresenterTests.swift`
- `SakuttoSeatTests/SeatingChartViewDataTests.swift`
- `SakuttoSeat/Localizable.xcstrings`（キー揃え。翻訳追加は原則なし）

第二弾:

- `SakuttoSeat/Core/Gateways/SeatingTemplateGateway.swift`（Snapshot 化、旧 API 削除）
- `SakuttoSeat/Modules/SeatingTemplate/SeatingLayoutTemplate.swift`（`makeSnapshot` の所在）
- `SakuttoSeat/Modules/SeatingChart/SeatingChartEntity.swift`（Snapshot 移設、`notFound`）
- `SakuttoSeat/Modules/SeatingChart/SeatingChartInteractor.swift`
- `SakuttoSeat/Modules/SeatingChart/SeatingChartPresenter.swift`
- `SakuttoSeatTests/SeatingChartInteractorTests.swift`
- `SakuttoSeatTests/SeatingChartPresenterTests.swift`

第三弾:

- `SakuttoSeat/Modules/SeatingTemplate/SeatingTemplateView.swift`
- `SakuttoSeat/Modules/SeatingTemplate/SeatingTemplateViewData.swift`（Copy / A11y）
- `SakuttoSeat/Localizable.xcstrings`

参照のみ（規約の正本）:

- `refactor_seating.md` §1 / 当初の `applyTemplate(id:)`
- `refactor_AttendeeList.md` Phase 5d（本計画の由来）
- `refactor_favorite.md` 全体（双子モジュールの完成形）
- `SakuttoSeat/Modules/FavoriteGroup/*`（コピー元）
- `SakuttoSeat/Modules/AttendeeList/AttendeeListPresenter.swift`（子 Presenter 保持）
- `SakuttoSeat/Modules/AttendeeList/AttendeeListRouter.swift`（`gatewayHolder`）
- `SakuttoSeatTests/FavoriteGroupTests.swift`
- `SakuttoSeatTests/AttendeeListPresenterTests.swift`（シート identity）

---

## 12. 分析時点のファイル実態（参照）

| ファイル | 行数目安 | 役割 |
| --- | --- | --- |
| `SeatingTemplateListView.swift` | 92 | `@Query` + 削除 + 選択クロージャ。Row / クロムだけ FavoriteGroup 製 |
| `SeatingLayoutTemplate.swift` | 111 | `@Model` + `TableTemplate` の Codable マイグレーション |
| `SeatingTemplateGateway.swift` | 80 | Base + SwiftData + InMemory。戻りは `@Model`。`fetch(id:)` なし |
| `SeatingChartContracts.swift` | Output 部 | `TemplateListModuleOutput` が `@Model` を受ける |
| `SeatingChartRouter.swift` | 54 | `makeTemplateListModule` が素の View を包む。detent 位置は正しい |
| `SeatingChartPresenter.swift` | 196 | `didSelectTemplate(@Model)`。cancel は未接続。シート identity なし |
| `SeatingChartInteractor.swift` | テンプレ部 | 保存と Snapshot 適用。一覧・削除なし。insert 時に `@Model` を new |
| `SeatingChartEntity.swift` | Snapshot 部 | `LayoutTemplateSnapshot` に id なし。`TemplateSaveError` に `notFound` なし |
| `SeatingChartView.swift` | onAppear / sheet | Gateway attach は親の過渡期。sheet Binding が dismiss を route に返す |
| `FavoriteGroupView.swift` 他 | 完成形 | 本計画のコピー元。行 / クロム / EmptyState / route / identity |
| `SeatingTemplate` テスト | 不在 | Phase 0 で Gateway / 親、Phase 2 で子を新設 |

以上を、テンプレート一覧を「小さいから `@Query` のまま」にせず、
FavoriteGroup と同じ二次 VIPER 化の対象として扱うための計画とする。
