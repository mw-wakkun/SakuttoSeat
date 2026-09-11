# GroupFavorite（永続化モデル）リファクタリング計画書

対象: `SakuttoSeat/Modules/GroupFavorite/GroupFavorite.swift` を起点に、
永続化 Gateway（`GroupFavoriteGateway`）、親の注入経路（`AttendeeList` / App）、
画面側の共有 Entity（`FavoriteGroupSnapshot`）を含む。

作成日: 2026-09-11
アーキテクチャ: **VIPER**（View / Interactor / Presenter / Entity / Router）
+ 永続化は **Gateway の内側**（`@Model` は画面モジュールではない）
前提:
- `refactor_seating.md` Phase 0〜5、`refactor_AttendeeList.md` Phase 0〜6、
  `refactor_favorite.md` Phase 0〜6、`refactor_templateListView.md` Phase 0〜6 は完了済み。
- 画面モジュール **FavoriteGroup** の 5 層（Contracts / Interactor / Presenter /
  Entity / Router / View / ViewData / Route）は既に揃っている。
- 本計画はそこで意図的に残した **永続化モデルそのもの** と、
  「View が SwiftData Gateway を new する」最後の VIPER 穴を対象にする。

**未着手フェーズの実装は、そのフェーズに入ってから行う。**

### 進捗

| Phase | 内容 | 状態 |
| --- | --- | --- |
| 0 | 準備と回帰テスト（Gateway / スキーマのギャップ埋め） | ✅ 完了（2026-09-11） |
| 1 | 配置・命名の固定（偽モジュール解消。型名は変えない） | ✅ 完了（2026-09-11） |
| 2 | Entity / `@Model` の純化（Snapshot・init・表示結合） | 未着手 |
| 3 | Gateway の性能と API 分割（一括削除・一覧/詳細） | 未着手 |
| 4 | App 注入で View から SwiftData を排除 | 未着手 |
| 5 | テストダブル共通化・デッド API・仕上げ | 未着手 |

回帰基準: 既存 `FavoriteGroupTests` + `AttendeeListInteractorTests` のお気に入り系 +
`AttendeeListPresenterTests` の FavoriteGroup Output / シート identity +
`AttendeeListRouterTests` の組み立て。Phase 0 で足す Gateway テストを以降の全フェーズで維持する。

検証端末は既存計画と同じく iPhone 17 / iOS 26.5 を使用する
（iOS 18.4 シミュレータでは MainActor / protocol existential の解放不整合で
`malloc: pointer being freed was not allocated` が再現するため）。

画面 VIPER の二次整備（ViewData.Row / route / ID 削除 / シート identity /
`SavedListRow`）は **再実施しない**。正本は `refactor_favorite.md`。
本計画が触るのは「`@Model` と Gateway と注入」に限る。画面側に入るのは、
その変更が契約をまたぐときに必要な最小差分だけである。

---

## 0. エグゼクティブサマリ

`GroupFavorite.swift` は 27 行の SwiftData `@Model` である。画面ではない。
コメントも「永続化モデル。画面モジュール名は FavoriteGroup」と正しく書いている。
それにもかかわらず、ファイルは `Modules/GroupFavorite/` に単独で置かれ、
Xcode 上は画面モジュールと並ぶ「偽 VIPER モジュール」になっている。

`refactor_favorite.md` は画面側の継ぎ目をほぼ解消した。
一覧は Snapshot、削除は ID、View は ViewData.Row、Gateway 戻りは `@Model` ではない。
残っているのは、そこで「別計画」と明示して先送りしたものと、
複数 AI が画面と永続化を別々に積んだことによる **永続化層の半適用** である。

分析の結論は次の 1 点に集約される。

> **「画面の箱は揃ったが、永続化はまだ Modules に住み、View が Gateway を new している」**
> `@Model` は `Modules/GroupFavorite`。画面は `Modules/FavoriteGroup`。
> Gateway は `Core/Gateways`。App は `.modelContainer(for: [GroupFavorite.self, …])`。
> 親 View の `onAppear` が毎回 `SwiftDataGroupFavoriteGateway(context:)` を生成する。
> Snapshot は「表示結合は Builder」と書いておきながら `memberSummary` を自分でも作る。
> 削除は ID 配列なのに、SwiftData 側は ID ごとに fetch してから delete する。

行数は少ない。だからこそ、SeatingChart 系と同じ穴を「小さいから許す」と残すと、
永続化規約がモジュールサイズで分岐する。双子の `SeatingLayoutTemplate` /
`SeatingTemplateGateway` も同型なので、ここで決めた型をテンプレ側の正本にする。

各層の「あるべき責務」と「実際の中身」を対比すると次のとおり。

| 層 | VIPER における責務 | 現状 | 判定 |
| --- | --- | --- | --- |
| `@Model`（`GroupFavorite`） | Gateway 内のストア表現。画面モジュールではない | `Modules/` に単独ファイル。`init` が id / createdAt を受け取れない（テンプレは受け取れる） | ✗ 配置が画面扱い |
| Gateway | `@Model` を閉じ、Snapshot / ID だけを返す | API 形は完成。削除が N+1。一覧がメンバー配列まで実体化。SwiftData 実装のテストが無い | △ 契約は良いが実装が粗い |
| Entity（Snapshot） | Interactor が扱う純粋なモデル。表示結合を持たない | `memberSummary` が Entity と Builder の二重。コメントと実装が矛盾 | △ 半適用 |
| 親 View | Presenter の ViewData / Route のみ。永続化型を知らない | `@Environment(\.modelContext)` + `SwiftDataGroupFavoriteGateway` を `onAppear` で new | ✗ 最後の VIPER 穴 |
| 親 Presenter / Contracts | Gateway 型を公開面に出さない | `attachFavoriteGateway(_ gateway: GroupFavoriteGatewayBase)` が PresenterProtocol にある | △ 過渡期のまま固定されていない |
| App | コンテナ所有と Gateway 組み立て | `@Model` 型を並べるだけ。Gateway は作らない | △ 半分だけ正しい |
| 命名 | 1 概念 1 名前 | 画面 `FavoriteGroup` / 永続化 `GroupFavorite` が語順逆 | △ 意図的に残置 |
| テスト | Gateway 2 系統（InMemory / SwiftData）を直接固定 | Interactor 経由の InMemory のみ。失敗ダブルが 3 ファイルに複製 | △ 穴 |

本計画は画面 VIPER の成果を**維持したまま**、永続化を Core の正しい位置へ戻す。
主要な作業は次の 3 本柱。

1. **配置の是正**: `@Model` を偽モジュールから `Core` へ移し、命名を文書で固定する（型名は変えない）
2. **永続化 API の仕上げ**: 一覧/詳細の分割、一括削除、Snapshot から表示結合を外す
3. **注入の VIPER 化**: App が Gateway を組み立て、View から `ModelContext` / Gateway 型を消す

`SeatingLayoutTemplate` のファイル移動とテンプレ View の `attachTemplateGateway` は
本計画の本丸ではない。お気に入り側で型を決め、テンプレは「同じ型に乗せる」フォローにする
（§9.7）。両方を同時に動かすと範囲が爆発する。

---

## 1. 本プロジェクトにおける VIPER の解釈（永続化向け注釈）

古典的 VIPER は UIKit + delegate 前提のため、SwiftUI に合わせて次のように読む。
**これは `refactor_seating.md` §1 と同一の全社規約**である。
`@Model` を 5 層のどれかに無理に割り当てない。永続化は **5 層の外** にある。

| 層 | 実装形態 | 依存してよいもの | 禁止事項 |
| --- | --- | --- | --- |
| **View** | `struct: View`。`@StateObject var presenter` を保持 | Presenter が公開する **ViewData** と **Route** のみ | Entity、`@Query`、`ModelContext`、`*Gateway` 型、`@Model` |
| **Presenter** | `@MainActor final class: ObservableObject` + `PresenterProtocol` | Interactor（具象）、Router（必要なときだけ具象）、Entity → ViewData | ビジネスルール、永続化、SwiftUI の描画 API、Gateway 型の公開 |
| **Interactor** | `nonisolated final class: InteractorProtocol` | Entity、Entity Gateway（`*GatewayBase`） | `SwiftUI` / `UIKit`、Presenter・View への参照、`@Model` |
| **Entity** | 値型 `struct` / `enum` | `Foundation` のみ | 表示用結合、SwiftData、ロジック（軽量な計算プロパティは可） |
| **Router** | `final class`。空 Protocol は置かない | モジュール組み立て | ビジネスルール、Entity の加工 |
| **Gateway** | `*Gateway` protocol + `*GatewayBase` + SwiftData / InMemory | `@Model`、`ModelContext`、Snapshot | View / Presenter からの参照。Protocol existential をクラスが保持すること |
| **`@Model`** | SwiftData のストア表現。**VIPER モジュールではない** | Foundation / SwiftData | `Modules/` 配下への配置、View / Presenter / Interactor からの直接参照、表示用メソッド |

補足（GroupFavorite 固有）:

- **画面名は `FavoriteGroup`、永続化名は `GroupFavorite`。** 本計画でも型名はリネームしない
  （SwiftData のユニーク制約と既存ストアに触る）。役割はコメントとディレクトリで固定する。
- **`@Model` は Gateway ファイルに閉じる、が「型が見える場所」まで閉じているわけではない。**
  現状 Interactor から型名は消えた。残っている公開面は App の `modelContainer(for:)` と
  親 View の Gateway 生成である。App がコンテナを持つのは正当。View が Gateway を new するのは違反。
- **`ObservableObject` は Protocol に載せない。** Gateway は `*GatewayBase` を具象保持。
  Protocol existential 化に戻さない。
- **Gateway の attach は Interactor の責務で、本番は assemble 時に済み、であるべき。**
  子 FavoriteGroup は既にそうなっている。親 AttendeeList だけが View `onAppear` で後差しする。
  これは `refactor_AttendeeList.md` §8.4 の過渡期として残った。本計画で終わらせる。
- **Snapshot に表示用文字列を載せない。** `LayoutTemplateSnapshot` は件数ラベルを Builder に任せている。
  `FavoriteGroupSnapshot.memberSummary` だけが例外になっている。
- **一覧 API は一覧に必要な列だけを返す。** 読込置換は `fetch(id:)` がメンバー配列を返す。
  今の `fetchAll() -> [FavoriteGroupSnapshot]` は一覧なのに `memberNames` まで載せる。

---

## 2. 現状の責務違反マッピング

### 2.1 `@Model`（`GroupFavorite.swift` / 27 行）

ファイル単体は素直である。問題は **中身の不足** と **置き場所** と **双子との非対称**。

| 箇所 | 内容 | 本来の層 / あるべき形 |
| --- | --- | --- |
| パス `Modules/GroupFavorite/` | 画面でも Interactor でもない 1 ファイルが Modules にいる | **`Core/Persistence/`**（または `Core/Models/`）。VIPER モジュールではない |
| 型名 `GroupFavorite` | 画面 `FavoriteGroup` と語順が逆 | 本計画では **リネームしない**。ディレクトリとコメントで固定 |
| `init(name:members:)` | `id` / `createdAt` を外部から渡せない | テンプレ `SeatingLayoutTemplate.init` は両方受け取れる。テスト・再 insert・写像の対称のため揃える |
| `members: [String]` | 参加者の `Attendee.id` が落ちる。読込時に親が UUID を再発行し、同名は `(2)` 付与対象になる | 現行仕様としてテストで固定。ID 維持は **本計画ではやらない**（仕様変更） |
| バリデーション無し | 空名前・空メンバーを `@Model` が拒まない | 拒むのは **親 Interactor**。Gateway は永続化だけ |
| `updatedAt` 無し | 並びは `createdAt` 降順のみ | 追加するとスキーマ変更。本計画では足さない |
| `makeSnapshot()` | Gateway 側の `fileprivate` 拡張に既に移動済み | 維持。`@Model` ファイルを再汚染しない |

View に残してよいもの、ではなく **`@Model` に残してよいもの**:

| 残す | 理由 |
| --- | --- |
| `@Attribute(.unique) var id: UUID` | 画面の `FavoriteGroupID` と同一。`PersistentIdentifier` に寄せない（テンプレと同じ） |
| `members: [String]` | 現行の保存契約。関連 `@Model` 化は件数が見えるまで不要 |
| `createdAt` | 新しい順の唯一のキー |

### 2.2 Gateway（`GroupFavoriteGateway.swift` / 121 行）

契約（Snapshot 戻り / `fetch(id:)` / `delete(ids:)` / `insert(name:members:)`）は
`refactor_favorite.md` Phase 3 で揃っている。残るのは実装の粗さである。

| 箇所 | 内容 | 問題 |
| --- | --- | --- |
| `delete(ids:)` | ID ごとに `fetchModel` → `delete` → 最後に 1 回 `save` | **N+1 クエリ。** 無料枠 3 では実害なし。有料で制限が外れたときに残る |
| `fetch(id:)` | `FetchDescriptor` + `#Predicate { $0.id == targetID }` + `.first` | unique 属性に対する定石ではある。バッチ削除と共有する `fetchModels(ids:)` が無い |
| `fetchAll()` | 全件の `members` まで実体化 | 一覧は id / name / 表示用要約だけで足りる。読込は既に `fetch(id:)` |
| `GroupFavoriteGatewayBase` の空実装 | 未 override が成功扱いで黙る | deinit 回避の規約なので **維持**。テスト用失敗 Gateway は共通化 |
| InMemory の `nextCreatedAt` | 同一瞬間の連続 insert でも新しい順を保つ | 妥当。SwiftData 側は `Date()` で衝突し得る（無料枠では無視可） |
| `FavoriteGroupSnapshot.persisted` | InMemory insert がここで UUID を切る。SwiftData は `@Model.init` が切る | ID 発行が 2 箇所。Gateway に寄せるとテストの再現が楽 |
| SwiftData 具象のユニットテスト | **ファイルが無い** | Interactor テストは InMemory だけ。ストア不整合は手動 QA 頼み |
| `nonisolated` + `ModelContext` | Interactor も `nonisolated` | 呼び出し元 Presenter が `@MainActor` なので現状は主スレッド。型はそれを強制しない |

`*GatewayBase` 継承はテンプレと同じく **deinit 回避のためのプロジェクト規約**である。
Protocol existential 保持に戻さない。

### 2.3 Entity（`FavoriteGroupEntity.swift`）

画面モジュール所有は `refactor_favorite.md` Phase 2 の決定として維持する。
永続化計画として直すのは **Snapshot の純度** だけ。

| 現状 | 問題 |
| --- | --- |
| コメント「表示用結合は ViewData Builder」 | `persisted` が `memberNames.joined` して `memberSummary` を入れる |
| Builder も `group.memberNames.joined` | **二重計算。** Snapshot の `memberSummary` は一覧テスト以外で読まれない |
| `LayoutTemplateSnapshot` は表示ラベルを持たない | お気に入りだけ例外 |
| `FavoriteSaveError` が保存・読込・削除を兼ねる | 子は `persistenceFailed` しか投げない。Presenter が他 case を握り潰す枝がある |

`FavoriteSaveAvailability` と `TemplateSaveAvailability` の統合は
`refactor_AttendeeList.md` §8.3 の未決。本計画でも **触らない**。

### 2.4 親 View / App の注入（VIPER 最後の穴）

| 箇所 | 内容 | 問題 |
| --- | --- | --- |
| `AttendeeListView` 21–23, 70–72 | `@Environment(\.modelContext)` と `onAppear` で Gateway を new | View が永続化具象を知る。画面復帰のたびに Gateway を作り直す |
| `AttendeeListPresenterProtocol.attachFavoriteGateway` | Gateway 型が View←Presenter 契約に露出 | View が `GroupFavoriteGatewayBase` を知る |
| `AttendeeListRouter.assembleModule` | 起動時は InMemory。実ストアは後差し | 初回フレームと SwiftData のあいだに理論上のレースがある（保存ボタンは `onAppear` 後なので実害は小さい） |
| `SakuttoSeatApp` 38 | `.modelContainer(for: [GroupFavorite.self, SeatingLayoutTemplate.self])` | コンテナ所有は正当。**Gateway をここで組み立てていない** |
| 子 FavoriteGroup View | `ModelContext` を持たない | 正しい。親だけが過渡期 |

座席表 View も同じ型で `attachTemplateGateway` している。本計画の必須範囲はお気に入り側。
App 注入の型を決めたら、テンプレは同じ手順で後続可能（§9.7）。

### 2.5 画面側に残っている、永続化と接続する薄い継ぎ目

画面 VIPER をやり直す対象ではない。永続化 API を変えるときに触る。

| 箇所 | 内容 | 本計画での扱い |
| --- | --- | --- |
| `FavoriteGroupPresenterProtocol.didDeleteGroups(at: IndexSet)` | View の `onDelete` 都合。Interactor は既に ID | Protocol を ID 配列にするかは Phase 5 の任意。必須ではない |
| Presenter `init` と `onAppear` の二重 `publishState` | シート表示のたびに `fetchAll` 2 回 | Phase 4 で後差しが消えたら `onAppear` の再同期は不要にできる |
| `AttendeeListRouter.makeFavoriteGroupModule` | Presenter / Sheet 分離後も結合 API が残る | テストが使っている。Phase 5 でデッドなら削除 |
| 失敗 Gateway の複製 | `FavoriteGroupTests` / `AttendeeListInteractorTests` / `AttendeeListPresenterTests` / `AttendeeListRouterTests` | Phase 5 でテストターゲットへ 1 系統 |

---

## 3. 目標とするモジュール境界

画面側の判断（一覧・削除は子、保存・読込置換は親、Gateway インスタンス共有）は維持する。
変わるのは **誰が SwiftData Gateway を new するか** と **`@Model` の住所**。

```
App
  ├─ ModelContainer 所有（GroupFavorite / SeatingLayoutTemplate）
  └─ SwiftDataGroupFavoriteGateway を assemble 時に注入
        │
        ▼
AttendeeList（親）
  ├─ 保存: favoriteSaveAvailability / saveCurrentAsFavorite
  ├─ 読込置換: loadFavorite(id:) → replaceAll
  ├─ Gateway 所有: assemble 済み。View onAppear attach は廃止
  └─ Output 受信: favoriteGroupDidSelect / DidCancel
        │
        │ 同じ Gateway インスタンスを渡す（現状どおり）
        ▼
FavoriteGroup（子・画面。本計画では再 VIPER 化しない）
  ├─ 一覧: summaries() throws
  ├─ 削除: deleteFavorites(ids:)
  └─ 失敗は route = .alert
        │
        ▼
GroupFavoriteGateway
  ├─ @Model はこのファイル群の外に出さない（App の Schema 登録を除く）
  └─ 戻りは Snapshot / Summary。入力はプリミティブ
```

### 3.1 目標ディレクトリ

```
SakuttoSeat/
├── App/
│   └── SakuttoSeatApp.swift          // Container + Gateway を組み立てて Router へ
├── Core/
│   ├── Persistence/                  // ★ @Model の住所。VIPER モジュールではない
│   │   └── GroupFavorite.swift
│   └── Gateways/
│       └── GroupFavoriteGateway.swift // fetchSummaries / fetch(id:) / delete(ids:)
├── Modules/
│   ├── FavoriteGroup/                // 画面。配置は現状維持
│   │   └── FavoriteGroupEntity.swift // Snapshot から memberSummary を削除
│   ├── GroupFavorite/                // ★ 削除（中身は Core/Persistence へ）
│   └── AttendeeList/
│       ├── AttendeeListView.swift    // modelContext / attach を削除
│       ├── AttendeeListContracts.swift
│       ├── AttendeeListPresenter.swift
│       └── AttendeeListRouter.swift  // assembleModule(favoriteGateway:)
└── SakuttoSeatTests/
    ├── GroupFavoriteGatewayTests.swift          // ★ 新設
    └── Support/GroupFavoriteTestGateways.swift  // ★ 失敗 / カウント用ダブル
```

`Modules/GroupFavorite/` を空にして残さない。
`SeatingLayoutTemplate.swift` の移動は本計画の必須範囲外（§9.7）。

### 3.2 `@Model` 目標形

スキーマ（ストアに載るプロパティ）は **変えない**。変えるのは init の対称性だけ。

```swift
@Model
final class GroupFavorite {
    @Attribute(.unique) var id: UUID
    var name: String
    var members: [String]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        members: [String],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.members = members
        self.createdAt = createdAt
    }
}
```

プロパティ追加（`updatedAt`、メンバーの `@Model` 関連、名前ユニーク）は
`VersionedSchema` が必要になるので本計画ではやらない。

### 3.3 Gateway 目標 API

```swift
nonisolated protocol GroupFavoriteGateway: AnyObject {
    func fetchCount() throws -> Int
    func fetchSummaries() throws -> [FavoriteGroupSummary]
    func fetch(id: FavoriteGroupID) throws -> FavoriteGroupSnapshot?
    func insert(name: String, members: [String]) throws
    func delete(ids: [FavoriteGroupID]) throws
}
```

```swift
nonisolated struct FavoriteGroupSummary: Identifiable, Equatable {
    let id: FavoriteGroupID
    let name: String
    let memberNames: [String]  // Builder が要約する。列を増やさず id+name だけにしてもよい
}

nonisolated struct FavoriteGroupSnapshot: Identifiable, Equatable {
    let id: FavoriteGroupID
    let name: String
    let memberNames: [String]
}
```

一覧に `memberNames` を残すか:

- **残す（推奨・第一弾）**: Builder が結合する。SwiftData は配列を読むが、API から
  `memberSummary` は消える。件数 3 では fetch 分割の効果が小さい。
- **id+name+count だけにする（Phase 3 の本丸）**: 一覧の実体化を減らす。
  字幕が「3 人」になると UX が変わるので、要約文字列が必要なら
  Gateway 内で `joined` して `memberSummary` を Summary に載せる
  （Entity ではなく Summary DTO。画面の ViewData.Row へ写す）。

推奨: Phase 2 で Snapshot から `memberSummary` を削除（挙動不変）。
Phase 3 で `fetchSummaries` を足し、`fetchAll` を削除。
Summary には一覧用の `memberSummary` を Gateway が載せてよい
（結合は Gateway or Builder の **どちらか一方**。二重は禁止）。

互換の進め方:

1. `fetchSummaries` を追加し、子 Interactor を移す
2. `fetchAll` の本番呼び出しがゼロになったら削除
3. テストの `gateway.fetchAll()` 断言は `fetchSummaries` または `fetch(id:)` へ

`insert` が `@Model` を受け取らない現状は維持する。
`*GatewayBase` 継承は維持する。

### 3.4 App 注入の目標形

```swift
@main
struct SakuttoSeatApp: App {
    private let modelContainer: ModelContainer
    private let favoriteGateway: GroupFavoriteGatewayBase

    init() {
        // 既存の appearance 設定 …
        let container = try! ModelContainer(
            for: GroupFavorite.self, SeatingLayoutTemplate.self
        )
        self.modelContainer = container
        self.favoriteGateway = SwiftDataGroupFavoriteGateway(
            context: container.mainContext
        )
    }

    var body: some Scene {
        WindowGroup {
            AttendeeListRouter.assembleModule(favoriteGateway: favoriteGateway)
            // …
        }
        .modelContainer(modelContainer)
    }
}
```

PresenterProtocol / View から消すもの: `attachFavoriteGateway`、`ModelContext`、
`SwiftDataGroupFavoriteGateway`。

Interactor の `attachFavoriteGateway` は **テスト用に残してよい**
（FavoriteGroup 子と同じ）。本番 View 経路からは呼ばない。

`mainContext` と `.modelContainer` の Environment が同一コンテナを指すことを
Phase 0 のノートと Phase 4 の手動 QA で固定する。座席表を開いたあとも
お気に入りが同じストアであること。

---

## 4. 再利用性

### 4.1 GroupFavorite 内で揃えるもの

| 部品 | 現状の分裂 | 寄せ先 |
| --- | --- | --- |
| `@Model` の住所 | `Modules/GroupFavorite` vs Gateway は `Core/Gateways` | `Core/Persistence` |
| `init` シグネチャ | テンプレは id / createdAt を受け取れる。お気に入りは不可 | テンプレに揃える |
| Snapshot の表示結合 | Entity と Builder の二重。テンプレ Snapshot は持たない | Builder（または Summary DTO）の一方 |
| 失敗 Gateway | テスト 3〜4 ファイルに別実装 | `SakuttoSeatTests/Support/GroupFavoriteTestGateways.swift` |
| ID 発行 | `@Model.init` と `Snapshot.persisted` | Gateway insert が 1 箇所で切る |

### 4.2 テンプレート永続化との共通化（やらない / やる）

`SeatingTemplateGateway` は fetchCount / fetchAll / fetch(id) / insert / delete(ids) /
Base / InMemory / SwiftData / `makeSnapshot` 拡張までほぼコピーである。

| 案 | 判断 |
| --- | --- |
| ジェネリック `SwiftDataGateway<Model, Snapshot>` | **本計画ではやらない。** Predicate / insert 引数が型ごとに違う。早すぎる抽象化 |
| `Core/Persistence` に両 `@Model` を並べる | お気に入りを先に移し、テンプレはフォロー（§9.7） |
| `SaveAvailability` 統合 | AttendeeList §8.3 の未決。**触らない** |
| テストダブルの基底 | 失敗パターンだけ共通ファイル化。プロトコル化はしない |

### 4.3 画面モジュールとの型共有

`FavoriteGroupID` / `FavoriteGroupSnapshot` / `FavoriteSaveError` /
`FavoriteSaveAvailability` は **FavoriteGroupEntity 所有のまま**。
Gateway が画面 Entity に依存する向きは現状どおり受け入れる
（`refactor_favorite.md` §9.2 の「まず FavoriteGroupEntity。早すぎる Core 化はしない」）。

Summary を足す場合も `FavoriteGroupEntity.swift` に置く。
Gateway 専用 DTO を Core に増やすと型がまた分裂する。

---

## 5. パフォーマンス

無料枠は 3 件（`FeatureLimit.freeFavoriteGroupCount`）なので、一覧の描画コストは実害になりにくい。
直す価値があるのは **誤った複雑度の API** と **View が Gateway を毎回 new すること** である。
有料で件数制限が外れたときに、N+1 削除と全件メンバー実体化がそのまま残るのを防ぐ。

| # | 現状 | 影響 | 対策 | Phase |
| --- | --- | --- | --- | --- |
| 1 | `delete(ids:)` が ID ごとに fetch | O(n) クエリ。順序ずれは ID 化で解消済み。無駄な I/O が残る | 1 fetch + メモリ filter + 一括 delete、または `delete(model:where:)` | 3 |
| 2 | `fetchAll` が `members` まで実体化 | 一覧は要約だけで足りる | `fetchSummaries`。詳細は `fetch(id:)` | 3 |
| 3 | Snapshot と Builder が両方 `joined` | 3 件では無視できるが、真実が 2 つ | `memberSummary` を Entity から削除 | 2 |
| 4 | Presenter init + onAppear で二重 fetch | シート表示のたびに 2 回 | 後差し廃止後、onAppear の再同期をやめる | 4 |
| 5 | 親 View `onAppear` のたびに Gateway 再生成 | 画面復帰のたびにオブジェクト増殖。同一 `ModelContext` なら実害は小さい | App 注入。寿命は Scene と一致 | 4 |
| 6 | assemble 中は InMemory、onAppear 後に SwiftData | 理論上の書き込み先の切り替わり | assemble 時点で SwiftData | 4 |
| 7 | `nonisolated` Gateway が `ModelContext` を保持 | オフトレッドから呼ぶと未定義 | 本番経路は MainActor Presenter のみ、をテストとコメントで固定。型で強制は Phase 5 任意 | 5 |
| 8 | InMemory `fetchAll` が毎回 sort | 3 件では無視 | 挿入時に先頭へ入れる程度でよい。先行最適化しない | — |

やらないこと:

- 一覧の差分更新 / ページング（件数が桁違いになるまで不要）
- `@Query` の再導入（VIPER に戻る）
- Gateway のプロトコル existential 化（deinit 事故）
- `members` の関連 `@Model` 化（スキーマ変更）
- 保存時に `Attendee.id` を永続化する（読込置換の仕様変更）
- SwiftData の `VersionedSchema` 導入（プロパティを足さない限り不要）

---

## 6. 実行計画（フェーズ分割）

各フェーズは独立してマージ可能。
**「安全網 → 住所を直す → 契約を純化する → I/O を減らす → 注入を VIPER 化する → 掃除」** の順。
挙動を変えない整理を先に済ませる。SeatingChart / AttendeeList / FavoriteGroup と同じ。

### Phase 0: 準備と回帰テスト（0.5 日）

現状の挙動を固定する characterization を足す。画面テストは消さない。

新設 `GroupFavoriteGatewayTests`:

- InMemory: 新しい順、`fetch(id:)`、複数 ID 削除、存在しない ID は無視、空 ids は no-op
- InMemory: 同一瞬間の連続 insert でも新しい順（既存 `nextCreatedAt` の仕様）
- SwiftData: `ModelContainer(inMemory: true)` で上記と同等
- SwiftData: unique `id` が persist / fetch で一致すること
- `GroupFavoriteGatewayBase` の未 override は成功扱いで空（既知の規約）

既存テストで不足している仕様:

- 親: 空リストでは `canSaveFavorite == false`（既存 ViewData テスト）。Interactor は空メンバー保存を拒まないこと（Gateway 経由の現状）。**拒む仕様に変えない**
- Snapshot の `memberSummary` が `", "` 結合であること（Phase 2 で削除するので、ここは現状固定）

完了条件: 見た目を変えずにテスト green。以降の回帰基準とする。
リスク: 低。SwiftData in-memory コンテナのセットアップだけ新規。

実装時の決定（2026-09-11）:

- 新設 `SakuttoSeatTests/GroupFavoriteGatewayTests.swift`。InMemory と SwiftData in-memory は
  既存 `GroupFavoriteGateway` protocol 経由の共有ケースで同一契約を断言する
  （テンプレ Gateway テストの複製を、お気に入りでは Protocol 再利用に寄せた）。
- SwiftData は `ModelContainer(isStoredInMemoryOnly: true)` + `ModelContext(container)`。
  コンテナはテストメソッド内で保持する（`SeatingTemplateTests` と同じ）。
- unique id の persist / fetch 一致は SwiftData 専用ケース。InMemory は `fetch(id:)` で同等。
- `GroupFavoriteGatewayBase` の未 override は insert / delete しても空のまま（既知の規約）。
- 空メンバー保存は Interactor が拒まない現状を `AttendeeListInteractorTests` に固定。仕様変更しない。
- `memberSummary` の `", "` 結合は Snapshot 工場と Gateway `fetchAll` の両方で固定（Phase 2 で削除）。
- 新規 Protocol は不要。`GroupFavoriteGateway` は既にある。
- 本番コード（`@Model` / Gateway 実装 / 画面）は未変更。

### Phase 1: 配置・命名の固定（0.5 日）

挙動を変えない。スキーマを変えない。

- `GroupFavorite.swift` を `Core/Persistence/GroupFavorite.swift` へ移動。
  `Modules/GroupFavorite/` を削除する。
- ヘッダコメントを次の 3 行に固定する。
  「永続化モデル（SwiftData）。VIPER 画面モジュールではない。
  画面名は FavoriteGroup。Snapshot 変換は GroupFavoriteGateway。」
- Gateway / Entity / App のコメントから「Modules/GroupFavorite」参照を更新。
- Xcode ターゲットメンバーシップとフォルダ参照を通す（ビルドが唯一の完了条件）。
- 型名 `GroupFavorite` / Gateway 名は変えない。
- 完了条件: ビルド成功、Phase 0 green、差分が移動とコメントに限定。
- リスク: 低。pbxproj / フォルダ同期だけ注意。

### Phase 2: Entity / `@Model` の純化（0.5 日）

- `GroupFavorite.init` をテンプレと同じく `id` / `createdAt` を受け取れる形にする
  （デフォルト引数で既存呼び出しは無変更）。
- `FavoriteGroupSnapshot` から `memberSummary` を削除。
  `persisted` 工場は `id` / `name` / `memberNames` のみ。
- `FavoriteGroupViewDataBuilder` だけが `joined(separator: ", ")` する。
- Interactor / Gateway テストの `snapshot.memberSummary` 断言を ViewData テストへ移す。
- 子 Presenter の `FavoriteSaveError` catch で `persistenceFailed` 以外を握り潰している枝は、
  明示 `default: break` にするか、子 Interactor の throws を
  `persistenceFailed` に限定するコメントを Contracts に書く。エラー型の分割はしない。
- 完了条件: Entity に表示用結合が無い。View の字幕は現状と同じ。
- リスク: 低〜中（テストの断言移動）。

### Phase 3: Gateway の性能と API 分割（1.0 日）

- `fetchSummaries()` を追加。子 `allFavorites()` は Summary 配列を返すか、
  Interactor 内で Snapshot 相当に写さず Builder が Summary を受ける。
- `fetchAll()` を本番から削除。親の保存確認テストは `fetchSummaries` or `fetch(id:)`。
- `delete(ids:)` を「対象を 1 回の fetch で集め、まとめて `context.delete`、`save` は 1 回」に変更。
  SwiftData の `#Predicate { ids.contains($0.id) }` が使えない場合は
  fetchAll 相当 + Set 判定でよい（件数前提をコメントする）。
- InMemory の delete は現状の Set 判定のままでよい（既に O(n) 1 パス）。
- 完了条件: 子・親の本番コードに `fetchAll` が無い。削除の save が 1 回。
  Gateway テストが「3 ID 削除で fetch が N+1 にならない」ことを
  スパイまたは in-memory SwiftData で固定できなくても、実装がループ fetch でないこと。
- リスク: 中。呼び出し側の型変更が子 Interactor / Builder に波及する。

一覧 Summary にメンバー配列を残すなら、性能効果は削除の一括化が主になる。
その場合でも `fetchAll` という「詳細の配列」名を消す意味がある。

### Phase 4: App 注入で View から SwiftData を排除（1.0 日）

**本計画の VIPER 上の本丸。**

- App が `ModelContainer` を保持し、`SwiftDataGroupFavoriteGateway` を
  `AttendeeListRouter.assembleModule(favoriteGateway:)` へ渡す。
- Preview / テストの assemble は従来どおり InMemory デフォルト引数。
- `AttendeeListView` から `import SwiftData`、`modelContext`、
  `onAppear` 内の `attachFavoriteGateway` を削除。`onAppear` はフォーカスと
  `presenter.onAppear()`（必要なら）だけ。
- PresenterProtocol から `attachFavoriteGateway` を削除。
  Interactor / Presenter の attach はテスト用に残すなら Presenter のテスト専用メソッド
  （Protocol 外）にするか、Interactor に直接差し込む。
- 子シートの Gateway 共有は現状どおり `currentFavoriteGateway()`。
- 後差しが消えたら、子 Presenter の `onAppear` 再 `publishState` をやめてよいか判断する。
  推奨: やめる（init で公開済み）。親リスト側の `onAppear` は参加者 ViewData 用に残してよい。
- 完了条件: AttendeeList View に `GroupFavorite` / `ModelContext` /
  `SwiftDataGroupFavoriteGateway` / `attachFavoriteGateway` が無い。
  実機/シミュレータで保存 → 一覧 → 選択置換 → キル後も残る。
- リスク: 中。`mainContext` と Environment のコンテナ不一致、プレビューのクラッシュ。
  座席表のテンプレ attach は残るので、App は `.modelContainer` を引き続き付ける。

### Phase 5: テストダブル共通化・デッド API・仕上げ（0.5 日）

- `FailingInsert` / `FailingFetch` / `FailingDelete` / `FetchCounting` を
  テスト Support へ 1 系統。本番コードにテスト型を置かない。
- `makeFavoriteGroupModule` が Presenter 経路から死んでいるなら Protocol と実装から削除。
  Router テストは `makeFavoriteGroupPresenter` + `makeFavoriteGroupSheet` に寄せる。
- Gateway / Interactor が MainActor からだけ呼ばれることをコメントで固定。
  型での強制（`@MainActor` Gateway）は、`nonisolated` Interactor 規約と衝突するので **しない**。
- `didDeleteGroups(at: IndexSet)` を ID 配列にするかは任意。やるなら View が
  `offsets` → `rows[offset].id` を解決して Presenter へ渡す（今の逆）。
  推奨: **本計画ではやらない。** 永続化層の成果を薄める。
- 完了条件: 失敗ダブルの定義が 1 ファイル。Phase 0〜4 green。
- リスク: 低。

---

## 7. 見込み効果

| 指標 | 現状 | 目標 |
| --- | --- | --- |
| `@Model` の住所 | `Modules/GroupFavorite/`（偽モジュール） | `Core/Persistence/` |
| 画面と永続化の型名 | 語順逆のまま（意図的） | 型名は維持。ディレクトリで区別 |
| View の `ModelContext` / Gateway new | あり（AttendeeList） | なし |
| PresenterProtocol の Gateway 露出 | `attachFavoriteGateway` | なし（テストは Interactor 直） |
| Snapshot の表示結合 | `memberSummary` あり（Builder と二重） | なし |
| `@Model.init` | name / members のみ | テンプレと同じく id / createdAt 可 |
| 一覧 API | `fetchAll` → フル Snapshot | `fetchSummaries` |
| 削除 I/O | ID ごと fetch | 1 パス + save 1 回 |
| Gateway の SwiftData テスト | 無し | in-memory コンテナで固定 |
| 失敗テストダブル | 3〜4 ファイルに複製 | Support 1 系統 |
| 起動時ストア | InMemory → onAppear で SwiftData | assemble 時点で SwiftData |
| テンプレ `@Model` の住所 | `Modules/SeatingTemplate/` | 本計画では未移動（フォロー） |

---

## 8. 検証戦略

1. **層ごとのユニットテスト**
   - **Gateway**: InMemory と SwiftData in-memory。新しい順、ID 取得、一括削除、空 ids。
   - **Interactor（既存）**: 保存上限、trim、`loadFavorite(id:)`、attach。一覧・削除は子。
   - **Presenter（既存）**: シート identity、選択は Output のみ。Phase 4 後は
     Protocol 経由 attach が無いこと。
   - **Router**: assemble が渡された Gateway を子へ共有すること（既存）。
2. **回帰基準**: Phase 0 の Gateway テスト + 既存お気に入りスイートを全フェーズで維持。
   `memberSummary` 断言は Phase 2 で ViewData 側へ更新。
3. **既存 SeatingChart / SimpleShuffle / Share / SeatingTemplate スイートを壊さないこと。**
   `@Model` 移動はコンパイルとターゲット所属だけが壊れやすい。
4. **手動 QA（お気に入り永続化）**
   - 参加者を保存（上限未満）→ アプリキル → 起動 → 一覧に残る
   - 一覧から選択 → 参加者リストが完全置換される
   - スワイプ削除 / 編集モード削除 → キル後も消えたまま
   - 上限 3 で保存ボタンがアラート。削除後に再保存できる
   - 座席表へ進んで pop しても、保存済みグループは同じストアを見ている
   - Preview が InMemory で空 / 1 件を表示できる（実 SwiftData に触れない）
5. **注入**
   - View ソースに `SwiftData` / `modelContext` / `attachFavoriteGateway` が無いこと
     （Phase 4 の完了条件。grep で固定してよい）
   - 起動直後、`onAppear` 前に保存相当の Interactor API を叩いても
     InMemory に逃げないこと（assemble 注入の効果。ユニットで固定）
6. **スクリーンショット**: 本計画は永続化が主なので必須ではない。
   Phase 2 で字幕結合を Builder へ移すときだけ、空 / 1 件 / 複数名の一覧を目視。

---

## 9. 実装前に決めるべきこと（要判断）

1. **`GroupFavorite` 型名のリネーム**
   画面と語順を揃えると分かりやすいが、SwiftData の既存ストアとユニーク制約に触る。
   **推奨: 本計画ではリネームしない。** `Core/Persistence` へ移し、コメントで役割を固定する。
2. **共有型の置き場（FavoriteGroupEntity vs Core）**
   Snapshot / Error は子モジュール所有が VIPER 的に綺麗。Gateway もそれを使う。
   **推奨: 現状維持（FavoriteGroupEntity）。** Summary を足しても同ファイル。
3. **一覧 Summary に `memberNames` を残すか**
   残すと Phase 3 の I/O 削減が削除一括化中心になる。
   落とすと字幕を「N 人」にするか、Gateway が結合済み文字列を Summary に載せる必要がある。
   **推奨: Summary に `memberSummary: String` を Gateway が載せ、`memberNames` は `fetch(id:)` だけ。**
   一覧の字幕 UX は維持し、詳細配列は読込経路専用にする。
4. **App 注入 vs View onAppear（現状維持）**
   SwiftUI は `@Environment(\.modelContext)` が View に来る。SeatingChart はまだ後差し。
   **推奨: お気に入りは App 注入に進める。** これが残っている唯一の VIPER 違反で、
   `@Model` を Core に移すだけでは画面規約が完成しない。
5. **Interactor の attach を本番から完全削除するか**
   テストの差し替えに便利。
   **推奨: Interactor には残す。PresenterProtocol / View からは消す。**
6. **空メンバーの保存を Interactor で拒むか**
   ViewData がボタンを無効化している。Gateway は拒まない。
   **推奨: 本計画では拒まない。** 仕様追加になる。characterization で現状を固定する。
7. **`SeatingLayoutTemplate` とテンプレ attach を同時にやるか**
   **推奨: しない。** お気に入りで App 注入の型を決め、テンプレは
   `refactor_templateListView.md` のフォロー（または短い後続計画）にする。
   App の `modelContainer` は両方の `@Model` を今どおり登録する。
8. **`VersionedSchema` を先に入れるか**
   プロパティを足さないなら不要。入れると移動フェーズが膨らむ。
   **推奨: 入れない。** 将来フィールドを足す計画の Phase 0 にする。
9. **`members: [String]` を関連モデルにするか**
   ID 維持・部分更新に強くなるが、マイグレーションと読込仕様が変わる。
   **推奨: しない。**
10. **ジェネリック Gateway**
    **推奨: しない。** お気に入りとテンプレのコピーは意図した対称。抽象は 3 つ目ができたとき。
11. **Presenter の IndexSet API**
    **推奨: 本計画では触らない。**

---

## 10. 想定工数

| Phase | 内容 | 工数 | VIPER 上の意義 |
| --- | --- | --- | --- |
| 0 | Gateway / スキーマの回帰テスト | 0.5 日 | ストア実装の安全網。今まで InMemory しか無い |
| 1 | `@Model` を Core/Persistence へ | 0.5 日 | 偽モジュールの解消。画面と永続化の住所を分離 |
| 2 | Snapshot / init の純化 | 0.5 日 | Entity から表示結合を排除 |
| 3 | summaries / 一括削除 | 1.0 日 | 永続化 API を一覧と詳細に分ける |
| 4 | App 注入、View から SwiftData 排除 | 1.0 日 | **View が Gateway を知らない状態** |
| 5 | テストダブル / デッド API | 0.5 日 | 継ぎ接ぎの掃除 |
| | **合計** | **4.0 日** | |

**推奨する区切り:**

- **第一弾（Phase 0〜2、1.5 日）**: 「`@Model` は Core」「Snapshot は表示を知らない」。
  体感負債の住所とコメント矛盾がここで消える。挙動はほぼ不変。
- **第二弾（Phase 3〜4、2.0 日）**: API 分割と App 注入。VIPER の完成形。
- **第三弾（Phase 5、0.5 日）**: テストの複製とデッド API。

Phase 1 を Phase 4 より先に置く理由は、View から SwiftData を剥がす作業中に
「`GroupFavorite` はどこにある型か」が Core に決まっていた方が、
App の Schema 登録と Gateway の import が一本になるため。
Phase 4 を先にやると、偽モジュールのまま注入だけ完成して規約がまた割れる。

---

## 11. 着手時に触るファイル（目安）

変更予定（実装はまだ行わない）:

第一弾:

- `SakuttoSeat/Modules/GroupFavorite/GroupFavorite.swift` → `SakuttoSeat/Core/Persistence/GroupFavorite.swift`
- `SakuttoSeat/Core/Gateways/GroupFavoriteGateway.swift`（コメント、必要なら init 呼び出し）
- `SakuttoSeat/Modules/FavoriteGroup/FavoriteGroupEntity.swift`
- `SakuttoSeat/Modules/FavoriteGroup/FavoriteGroupViewData.swift`（結合の単一化）
- `SakuttoSeatTests/GroupFavoriteGatewayTests.swift`（新設）
- `SakuttoSeatTests/FavoriteGroupTests.swift`（`memberSummary` 断言の移動）
- `SakuttoSeatTests/AttendeeListInteractorTests.swift`（同上）

第二弾:

- `SakuttoSeat/Core/Gateways/GroupFavoriteGateway.swift`
- `SakuttoSeat/Modules/FavoriteGroup/FavoriteGroupInteractor.swift`
- `SakuttoSeat/Modules/FavoriteGroup/FavoriteGroupPresenter.swift`（onAppear 再 fetch の可否）
- `SakuttoSeat/App/SakuttoSeatApp.swift`
- `SakuttoSeat/Modules/AttendeeList/AttendeeListView.swift`
- `SakuttoSeat/Modules/AttendeeList/AttendeeListContracts.swift`
- `SakuttoSeat/Modules/AttendeeList/AttendeeListPresenter.swift`
- `SakuttoSeat/Modules/AttendeeList/AttendeeListRouter.swift`
- `SakuttoSeatTests/AttendeeListPresenterTests.swift`
- `SakuttoSeatTests/AttendeeListRouterTests.swift`

第三弾:

- `SakuttoSeatTests/Support/GroupFavoriteTestGateways.swift`（新設）
- 上記テストファイルのダブル削除

参照のみ（規約の正本。本計画ではコードを変えない）:

- `refactor_favorite.md`（画面 VIPER の完成形。再実施しない）
- `refactor_AttendeeList.md` §8.4（View onAppear attach の過渡期）
- `refactor_seating.md` §1
- `SakuttoSeat/Modules/SeatingTemplate/SeatingLayoutTemplate.swift`（init の見本。移動はフォロー）
- `SakuttoSeat/Core/Gateways/SeatingTemplateGateway.swift`（Gateway の双子。抽象化しない）
- `SakuttoSeat/Modules/SeatingChart/View/SeatingChartView.swift`（同じ attach 過渡期）

---

## 12. 分析時点のファイル実態（参照）

| ファイル | 行数目安 | 役割 |
| --- | --- | --- |
| `Modules/GroupFavorite/GroupFavorite.swift` | 27 | SwiftData `@Model` のみ。偽モジュール。init が id / createdAt 不足 |
| `Core/Gateways/GroupFavoriteGateway.swift` | 121 | Base + SwiftData + InMemory。契約は完成。削除 N+1、`fetchAll` がフル Snapshot、SwiftData テスト無し |
| `FavoriteGroupEntity.swift` | 49 | ID / Snapshot / Error / Availability。`memberSummary` がコメントと矛盾 |
| `FavoriteGroupInteractor.swift` | 41 | 一覧・削除。`@Model` は既に出ない |
| `FavoriteGroupPresenter.swift` | 81 | IndexSet → ID。init と onAppear で二重 fetch |
| `AttendeeListView.swift` | `onAppear` | **View が SwiftData Gateway を new する最後の穴** |
| `AttendeeListInteractor.swift` | お気に入り部 | 保存・`fetch(id:)` 読込。一覧・削除は持たない（正しい） |
| `AttendeeListContracts.swift` | attach | PresenterProtocol に Gateway 型が残る |
| `AttendeeListRouter.swift` | assemble | デフォルト InMemory。結合 `makeFavoriteGroupModule` が残存 |
| `SakuttoSeatApp.swift` | 38 行付近 | `modelContainer(for: [GroupFavorite.self, …])`。Gateway は組み立てない |
| `FavoriteGroupTests.swift` | 325 | 画面の回帰は厚い。Gateway 直テストは無い |
| `SeatingLayoutTemplate.swift` | 対照 | 同じ偽モジュール配置。init だけこちらが完成形 |

以上を、`GroupFavorite` を「小さい `@Model` だから現状維持」にせず、
画面 FavoriteGroup と同じ完成度の **永続化境界** として扱うための計画とする。
画面 5 層の再 VIPER 化は範囲外である。
