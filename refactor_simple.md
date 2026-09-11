# SimpleShuffle モジュール リファクタリング計画書（VIPER 版）

対象: `SakuttoSeat/Modules/SimpleShuffle/` を中心に、横断依存
（`Share` / `ImageExportRenderer` / `NumberedPersonRow` / `AdBannerContainer`）と
親モジュール（`AttendeeList`）からの組み立て経路を含む。

作成日: 2026-09-11
アーキテクチャ: **VIPER**（View / Interactor / Presenter / Entity / Router）
前提: `refactor_seating.md` Phase 0〜5、`refactor_AttendeeList.md` Phase 0〜6 は完了済み。
SimpleShuffle の **5 層の箱と ViewData** は AttendeeList Phase 5 で既に置いてある。
本計画はそこで止まった「二次 VIPER 化」——規約の穴、Share 境界の非対称、
継ぎ接ぎ実装の不揃い——を SeatingChart の完成形に揃える。

### 進捗

| Phase | 内容 | 状態 |
| --- | --- | --- |
| 0 | 準備と回帰テスト | ✅ 完了（2026-09-11） |
| 1 | 規約穴埋め（Router DI / Protocol / Entity 純化） | ✅ 完了（2026-09-11） |
| 2 | Share / Snapshot を ViewData 駆動にする | ✅ 完了（2026-09-11） |
| 3 | 再利用・一貫性・i18n / A11y | ✅ 完了（2026-09-11） |
| 4 | 性能・初期表示仕様・空状態 | 未着手 |

回帰基準: 既存 `SimpleShuffleTests` + `ShareTests` の番号札ケース +
`AttendeeListRouterTests` の番号札組み立て。Phase 0 で拡充した characterization を
以降の全フェーズで維持する。

検証端末は既存計画と同じく iPhone 17 / iOS 26.5 を使用する
（iOS 18.4 シミュレータでは MainActor / protocol existential の解放不整合で
`malloc: pointer being freed was not allocated` が再現するため）。

---

## 0. エグゼクティブサマリ

番号札はアプリの 2 本柱のうち単純な方であり、ファイル構成は既に VIPER に見える。
AttendeeList Phase 5 で Contracts / Entity / Interactor / Router / ViewData が追加され、
共有は Share モジュール、行 UI は `NumberedPersonRow`、バナーは `AdBannerContainer` に寄っている。

それでも分析の結論は次の 1 点に集約される。

> **「箱は揃ったが、SeatingChart の完成形と中身がまだ噛み合っていない」**
> Router は Builder だけで Protocol も子の組み立て責任も無い。
> 画面は ViewData を消費するのに、共有と画像出力は `[String]` に落として番号を作り直す。
> View の色・文言 API・スナップショット identity が、同じ Phase で入れた部品と食い違っている。

これは巨大モジュールの空洞化ではなく、**複数計画・複数実装を継いだことによる規約の半適用**である。
行数は少ない。だからこそ、SeatingChart と同じ穴を「小さいから許す」と残すと、
全社規約がモジュールサイズで分岐する。

各層の「あるべき責務」と「実際の中身」を対比すると次のとおり。

| 層 | VIPER における責務 | 現状 | 判定 |
| --- | --- | --- | --- |
| View | 受動的な描画とイベント転送。Entity を知らない | ViewData 消費・`withAnimation` 配置は妥当。文言 API 混在、ブランド色の上書き、空状態なし | △ 軽い違反 |
| Interactor | シャッフルと番号の唯一の窓口 | 集合不変のシャッフルと 1-based 再番号は妥当。`name` が不必要な `var`。初期順は登録順のまま | ○〜△ |
| Presenter | ViewData 生成と Interactor / Share への仲介 | 薄い。ただし Share を自分で組み立て、`shuffle()` の戻りを捨てて再取得。Protocol に `share` が無い | △ 組み立て漏れ |
| Entity | Interactor が扱う純粋なモデル | `NumberedSeat` は妥当。ViewData.Row とほぼ同型（境界としては正しい） | ○ |
| Router | モジュール組み立てと子の注入 | `assembleModule` のみ。`RouterProtocol` なし。Share を知らない | ✗ 薄い |
| Contracts | 層間境界の明示 | Presenter / Interactor の 2 本だけ。Router / Share / Output が無い | △ 不完全 |
| 横断（Share） | 共有対象は呼び出し側の表示モデル | 座席表は `SeatingChartViewData`、番号札は `[String]`。Snapshot が index で番号再計算 | ✗ 非対称 |

本計画は既存の VIPER 命名と AttendeeList Phase 5 の成果を**維持したまま**、
上記の穴を正しい層へ戻す。主要な作業は次の 3 本柱。

1. **Router の実体化**: Share の組み立てを Presenter のデフォルト引数から Router へ移す
2. **Share 境界の対称化**: `ShareSubject` と Snapshot を ViewData 駆動にし、番号の再計算をやめる
3. **継ぎ接ぎの解消**: 色・文言・identity・テストの断言を SeatingChart / AttendeeList に揃える

SeatingChart 側で既に存在する資産（`Share` / `shareFlow` / `ImageExportRenderer` /
`NumberedPersonRow` / MainActor + 具象保持の deinit 回避）は再利用し、
同じ問題を三度設計しない。

---

## 1. 本プロジェクトにおける VIPER の解釈（再掲・SimpleShuffle 向け注釈）

古典的 VIPER は UIKit + delegate 前提のため、SwiftUI に合わせて次のように読む。
**これは `refactor_seating.md` §1 と同一の全社規約**であり、本モジュールも例外にしない。

| 層 | 実装形態 | 依存してよいもの | 禁止事項 |
| --- | --- | --- | --- |
| **View** | `struct: View`。`@StateObject var presenter` を保持 | Presenter が公開する **ViewData** と、Share 取り付けに必要な `share` | Entity の直接参照、番号の再計算、業務条件分岐、遷移状態の保持 |
| **Presenter** | `@MainActor final class: ObservableObject` + `PresenterProtocol` | Interactor（具象）、Share（具象）、Entity → ViewData 変換 | ビジネスルールの判断、子モジュールの自前組み立て、SwiftUI の描画 API |
| **Interactor** | `nonisolated final class: InteractorProtocol` | Entity | `SwiftUI` / `UIKit` の import、Presenter・View への参照 |
| **Entity** | 値型 `struct` / `enum` | `Foundation` のみ | ロジック（軽量な計算プロパティは可） |
| **Router** | `final class: RouterProtocol` | 子モジュールの Builder（Share）、遷移先生成 | ビジネスルール、Entity の加工 |

補足（SimpleShuffle 固有）:

- **`ObservableObject` は Protocol に載せない。** SeatingChart と同じく、
  protocol existential を MainActor クラスが保持すると deinit で malloc abort するため、
  Interactor / Router / Share は**具象型で保持**する。
- **本モジュールに独自 Route は不要。** シート／アラートは Share の `route` が単一の真実。
  `SimpleShuffleRoute` を新設して空 enum を置かない。
- **親への Output も不要。** QA 11.2 どおり、番号札の並びは参加者一覧に書き戻さない。
  一方向（親 → 子へ `[Attendee]` を渡して終わり）が正しい。
- **Entity は View に渡さない。** 現状の画面 View は満たしている。破っているのは
  Snapshot と Share であり、ここが本計画の本丸になる。
- **番号は Presenter（ViewData）が確定する。** View も Snapshot も Share のテキスト整形も
  `index + 1` を再計算してはならない。Interactor の `number` が唯一の番号ソース。

---

## 2. 現状の責務違反マッピング

起点ファイル `SimpleShuffleView.swift` は 66 行で、画面としての薄さは既に目標圏内である。
負債は View の肥大ではなく、**境界の非対称と規約の半適用**に残っている。

### 2.1 View（`SimpleShuffleView.swift` / `SimpleShuffleSnapshotView.swift`）

画面 View に残っているが、規約または再利用の観点で直すべきもの。

| 箇所 | 内容 | 本来の層 / 置き場 |
| --- | --- | --- |
| View `:14` | `@StateObject var presenter` は所有権として正しい（コメントのとおり `@ObservedObject` だと結果が消える） | 維持。`private` 化は任意 |
| View `:19-26` | `ForEach(presenter.viewData.rows)`。identity は `row.id`（Attendee.id） | **維持**。番号を id にすると移動アニメが消える |
| View `:23` | `tint: .blue`。`NumberedPersonRow` の既定は `.sakuttoBlueStart`。AttendeeList は既定のまま | **DesignSystem**。番号札だけシステムブルーに戻っている |
| View `:28, :30, :39` | `Text("…")` / `.navigationTitle` の生リテラル。A11y だけ `String(localized:)` | **i18n の API 不統一**（Catalog 抽出はされるが書き方が混在） |
| View `:33-37` | `AdBannerContainer` + `AppSpacing.bannerVerticalPadding` | 維持（AttendeeList Phase 6 済み） |
| View `:53-55` | `withAnimation` が View 側 | 維持（規約どおり） |
| View `:64` | `.shareFlow(presenter.share)` | 維持。ただし Protocol に `share` が無く、View は具象にしか結びつかない |
| Snapshot `:11` | 入力が `[String]`。ViewData を知らない | **Presenter / ShareSubject** |
| Snapshot `:27` | `ForEach(..., id: \.offset)`。静的画像でも identity 規約が画面と逆 | **ViewData.Row.id** |
| Snapshot `:29` | `number: index + 1`。Interactor が付けた番号を捨てている | **ViewData.Row.number** |
| Snapshot `:16-22` | 見出し文言が画面（「シャッフル結果」）と共有画像で不一致 | **Copy の単一定義**（意図的差分なら ViewData の title に載せる） |

View が持ってはいけないもの（Entity、`@Query`、遷移 Bool）は**既に無い**。
AttendeeList 計画時点の「Presenter 1 枚」問題は解消済み。残件は仕上げである。

### 2.2 Presenter（`SimpleShufflePresenter.swift`）

行数 41。薄いこと自体は正しい。残っているのは組み立てと契約。

| 箇所 | 内容 | 本来の層 |
| --- | --- | --- |
| `:17` | `let share: SharePresenter` を公開 | SeatingChart と同じ形。**Protocol にも載せる** |
| `:22-24` | `share: SharePresenter? = nil` のデフォルトで `ShareRouter.assemblePresenter()` | **Router.assembleModule**。Presenter は注入されたものを使うだけ |
| `:28-30` | `_ = interactor.shuffle()` のあと `allSeats()` で再取得 | 戻り値を `publishState(seats:)` に渡せば二重読みが消える |
| `:34-36` | `viewData.rows.map(\.name)` で Share に渡す | 座席表は `share.didTapShare(subject: .seatingChart(viewData))`。**番号札も ViewData を渡す** |
| Protocol | `SimpleShufflePresenterProtocol` に `share` が無い | SeatingChart は `var share: SharePresenter { get }` がある |

Presenter はビジネスルールを持っていない（判定は Interactor）。ここは維持する。

### 2.3 Interactor / Entity

`SimpleShuffleInteractor` はドメインとして妥当。

- 入力は `[Attendee]`（ID 維持）。AttendeeList 計画 §8.5 の推奨を実装済み。
- `shuffle()` は集合不変・順序変更、直後に 1-based 再番号。
- 1 人以下でも壊れない（テストあり）。

残件:

| 箇所 | 内容 |
| --- | --- |
| Entity `:15` | `var name: String`。名前は変わらない。`let` にできる |
| Interactor `:14-17` | 初期順は**登録順**。QA 9.1 は「既にシャッフルされた状態で表示」 |
| AttendeeListInteractor `:42` | `shuffle()` が番号札経路から一度も呼ばれない。親側のデッド API に近い |

初期シャッフルは仕様判断（§8.1）。Phase 0 では現状（登録順）をテストで固定し、
判断後に挙動を変える。

### 2.4 Router / Contracts

`SimpleShuffleRouter`（19 行）:

- `assembleModule(attendees:)` は親 `AttendeeListRouter.makeSimpleShuffleModule` から呼ばれており、方向は正しい。
- `RouterProtocol` が無い（BulkAdd / FavoriteGroup も同様の薄い Builder。SeatingChart / VenueSettings / Share / AttendeeList は Protocol あり）。
- インスタンスを Presenter に渡していない。Share を知らない。
- 戻り値は `AnyView`（親 Router 境界としては既存許容。§8.4）。

`SimpleShuffleContracts.swift` は Presenter / Interactor の 2 Protocol のみ。
SeatingChart の「View←Presenter / Presenter→Interactor / Presenter→Router」の 3 境界に足りない。

### 2.5 横断モジュールとの非対称（本計画の関連範囲）

**Share**（座席表との差分が負債）:

| 項目 | 座席表 | 番号札（現状） |
| --- | --- | --- |
| `ShareSubject` | `.seatingChart(SeatingChartViewData)` | `.numberedList(attendees: [String])` |
| コメント | 表示専用モデルから作る | 「登録順の一覧」（実装は**現在の並び**。コメントが嘘） |
| 画像 | `SeatingChartSnapshotView(viewData:)` | `SimpleShuffleSnapshotView(attendees:)` |
| テキスト | ViewData からテーブル構造を復元 | `enumerated()` で番号を再採番 |
| 出力幅 | Snapshot 側の `intrinsicWidth` | `ImageExportRenderer` に `400` 直書き |

Share モジュールが番号の意味を知っているのは VIPER 違反に近い。
Share は「渡された表示モデルをテキスト／画像にする」だけであるべき。

**親 AttendeeList**:

- 遷移は `didTapSimpleShuffle()` → `route = .simpleShuffle` → Router 委譲で正しい。
- 渡しているのは `interactor.allAttendees()`（登録順）。番号札側でシャッフルする設計。
- CTA は `canStartSeating`（1 名以上）で disable。空配列で assemble される経路は通常閉じているが、
  Router API 自体は空配列を拒まない。

---

## 3. 層をまたぐ課題（VIPER 是正と並行して対応）

### 3.1 再利用性

**(A) 番号付き行データ型が 2 つ**
`AttendeeListViewData.Row` と `SimpleShuffleViewData.Row` は `id` / `number` / `name` で同一。
View 部品 `NumberedPersonRow` は 1 本化済み。データ型まで Core に出すとモジュール境界が薄くなるので、
**無理に共通 Entity 化しない**（§8.3）。画面と Snapshot が同じ ViewData.Row を使うことの方が先。

**(B) スナップショット行のクロムが画面と二重**
`NumberedPersonRow` は共有済みだが、Snapshot 側だけ `.padding(12)` +
`secondarySystemGroupedBackground` + `cornerRadius(8)` をインラインで持つ。
`NumberedPersonRow.Style`（`.list` / `.snapshot`）にするか、Snapshot 専用の薄いラッパ 1 つに閉じる。

**(C) 見出し・「番席」・共有タイトルが 3 箇所**
画面ヘッダ、Snapshot 見出し、`ShareInteractor.makeNumberedListText` のプレフィックスが
それぞれ手書き。`SimpleShuffleCopy`（BulkAddCopy / NumberedPersonCopy と同型）に集約する。

**(D) 出力幅 `400` が Renderer に埋没**
座席表は SnapshotView が `intrinsicWidth` を公開し、Renderer はそれを読む。
番号札も同じ形にする（`SimpleShuffleSnapshotView.exportWidth`）。

**(E) ブランド色の揺れ**
リスト画面は `.blue`、参加者一覧は `.sakuttoBlueStart`、行コンポーネント既定も後者。
番号札だけシステムブルーなのは Phase 5 の取り残し。

### 3.2 パフォーマンス

件数の想定は教室〜小規模イベント（数十名）。アルゴリズム自体は O(n) で足りる。
残るのは SwiftUI の無効化と画像出力のメモリ。

| # | 内容 | 場所 |
| --- | --- | --- |
| 1 | **シャッフルごとに ViewData 配列を全差し替え。** 番号は全行変わるので差分スキップは限定的。identity が UUID のため **移動アニメは効く**（これは利点。壊さない） | Presenter `publishState` / View `ForEach` |
| 2 | **`withAnimation(.spring)` が List 全体に乗る。** 50 名超でレイアウトコストが跳ねやすい。件数に応じた animation 抑制は Phase 4 の任意 | View `:53-55` |
| 3 | **Snapshot が `VStack` + 全行即時。** 画像出力なので Lazy 化は不適。長い名簿は `ImageRenderer` のビットマップが大きくなる。幅トークン化と background の統一が先 | Snapshot / Renderer `:27-33` |
| 4 | **SharePresenter を画面表示時点で生成。** 共有しないセッションでも広告・Router グラフが乗る。組み立てを Router に移しても寿命は同じ。遅延生成は過度（§8.5 で見送り推奨） | Presenter `:24` |
| 5 | **`shuffle()` のあと `allSeats()` で配列コピーがもう 1 回。** 小さいが、戻り値を使うだけで消える | Presenter `:28-30` / Interactor `:24-27` |
| 6 | **`NumberedSeat` の `var name`。** `renumber` 時に struct を mut するため、名前までコピー対象になる。`let` 化は意図の明確化兼微減 | Entity `:15` |
| 7 | **バナーの `GeometryReader` + Preference。** 3 画面共通。本モジュール固有の仕事ではない（触らない） | `AdBannerContainer` |
| 8 | **List 既定スタイル未指定。** AttendeeList は `.insetGrouped`。見た目の再評価範囲は小さいが、明示した方が Recycle 挙動が読みやすい | View |

やらないこと: Interactor のシャッフルを自前アルゴリズムに置き換える、行の `Equatable` をやめて部分更新する、など。
`Array.shuffle()`（Fisher–Yates）で十分。README の「偏りのないシャッフル」と一致している。

### 3.3 正確性・保守性リスク

| # | 内容 | 場所 |
| --- | --- | --- |
| 1 | **初期表示が登録順。** QA 9.1 は「既にシャッフルされた状態」。プロダクトとテストとマニュアルが三分裂 | Interactor init / QA §9.1 |
| 2 | **共有テストが payload を見ていない。** `route == .selection` だけ。名前の順序が落ちても落ちない | `SimpleShufflePresenterTests` |
| 3 | **Share コメントが「登録順」。** 実装はタップ時点の並び（Presenter コメントは正しい） | `ShareContracts.swift:27-28` |
| 4 | **Snapshot / 共有テキストが index で再採番。** 今は number が常に位置と一致するため隠れている。番号規則を変えた瞬間に画面と共有がずれる | Snapshot / `ShareInteractor:70-75` |
| 5 | **空配列でも assemble できる。** 親 CTA は閉じているが、空 List + ヘッダだけが出る。`EmptyStateView` 未使用 | View / Router |
| 6 | **1 名でもシャッフルボタンが有効。** no-op。ViewData に `canShuffle` を載せて disable できる | View toolbar |
| 7 | **親 `AttendeeListInteractor.shuffle()` が本番経路から未使用。** 番号札と座席表はそれぞれ子がシャッフルする。デッドに近い API | AttendeeList |
| 8 | **画面と Snapshot のタイトル不一致。** 共有画像だけ「シャッフル結果（番号札）」 | Snapshot `:20` vs View `:28` |
| 9 | **A11y はツールバーのみ。** 行は `NumberedPersonRow` で足りる。シャッフル後の VoiceOver 通知（`.announcement`）が無い | View |
| 10 | **テストが XCTest。** README は Swift Testing と書いてあるが、リポジトリ全体が XCTest。本計画でフレームワークを切り替えない |
| 11 | **ファイル先頭コメントが AttendeeList Phase 番号。** モジュール固有の履歴になっていない | 各ファイル |

---

## 4. 目標構成

### 4.1 モジュール契約（Contracts）

`SimpleShuffleContracts.swift` を SeatingChart と同じ 3 境界に揃える。
独自 Route / Module Output は作らない。

```swift
// SimpleShuffleContracts.swift

// MARK: - View <- Presenter

/// `ObservableObject` は具象 Presenter 側で準拠する（SeatingChart と同じ規約）。
@MainActor
protocol SimpleShufflePresenterProtocol: AnyObject {
    var viewData: SimpleShuffleViewData { get }
    /// 共有フローは Share モジュールが担う（View はこの Presenter に `.shareFlow` を取り付ける）
    var share: SharePresenter { get }

    func didTapShuffle()
    func didTapShare()
}

// MARK: - Presenter -> Interactor

nonisolated protocol SimpleShuffleInteractorProtocol: AnyObject {
    func allSeats() -> [NumberedSeat]
    func shuffle() -> [NumberedSeat]
}

// MARK: - Presenter -> Router

/// Protocol 自体には @MainActor を付けない（存在型保持時の deinit 不整合を避ける）。
protocol SimpleShuffleRouterProtocol: AnyObject {
    // 画面内遷移は無い。組み立ては static assembleModule。
    // インスタンスメソッドを空で置かない。Share 生成は assemble 時の責務とする。
}
```

実装上の制約（SeatingChart 踏襲）:

- Protocol に `ObservableObject` を載せない。
- Presenter は Interactor / Share を**具象型**で保持する。
- `SimpleShuffleRouterProtocol` を空で残すのは禁止（§2.4 の「空 Protocol」を繰り返さない）。
  **Router の公開面は `assembleModule` に Share 注入を含めること**で実体化する。
  インスタンス Protocol が本当に空なら、ファイルに Protocol を書かず、
  「Builder は Router 型の static メソッド」という既存踏襲だけをコメントで残す。
  VenueSettings のようにインスタンスメソッド（広告提示）が無いなら、空 Protocol より
  **書かない方が規約に忠実**。

### 4.2 表示専用モデル

```swift
nonisolated struct SimpleShuffleViewData: Equatable {
    struct Row: Identifiable, Equatable {
        let id: UUID      // Attendee.id。View は index を計算しない
        let number: Int   // 1-based。Interactor が確定
        let name: String
    }

    let rows: [Row]
    let isEmpty: Bool
    let canShuffle: Bool  // 2 名以上。View は disable するだけ
    let title: String     // 画面 navigation / section 用（Copy から注入してもよい）

    static let empty = SimpleShuffleViewData(rows: [], isEmpty: true, canShuffle: false, title: "")
}

nonisolated enum SimpleShuffleViewDataBuilder {
    static func build(seats: [NumberedSeat]) -> SimpleShuffleViewData { /* 1:1 map + flags */ }
}
```

`title` を ViewData に載せるかは任意。文言を View の Catalog リテラルに残す方が
i18n ツールチェーンと相性が良いなら、ViewData は `rows` / `isEmpty` / `canShuffle` に留める（§8.2）。

### 4.3 Share 境界（対称化）

```swift
enum ShareSubject: Equatable {
    case seatingChart(SeatingChartViewData)
    case numberedList(SimpleShuffleViewData)   // [String] を廃止
}
```

- `ShareInteractor.makeNumberedListText` は `rows` の `number` と `name` を使う。`enumerated()` 禁止。
- `ImageExportRenderer.renderSimpleShuffle(viewData:)` は Snapshot に ViewData を渡す。
- Snapshot は `ForEach(viewData.rows)`。`id: \.offset` 禁止。
- 呼び出し: `share.didTapShare(subject: .numberedList(viewData))`（座席表と同じ形）。

Share が `SimpleShuffleViewData` を知るのは、既に `SeatingChartViewData` を知っていることと対称。
中立 DTO を Share 内に新設する案は、座席表側の大規模リネームが必要になるため本計画では採らない。

### 4.4 View に残してよいもの

| 残す | 理由 |
| --- | --- |
| `@StateObject var presenter` | Builder が生成し View が所有。シャッフル結果の寿命 |
| `withAnimation` | 描画の関心。Presenter に戻さない |
| `.shareFlow(presenter.share)` | SeatingChart と同じ取り付け |
| `AdBannerContainer` | 横断部品。番号札固有ロジックにしない |
| ツールバーの SF Symbol | 見た目。ラベル / hint は Copy または `String(localized:)` に統一 |

消すもの: `.blue` 上書き（既定 tint に戻す）、Snapshot の `[String]` / index 採番、
Presenter 内の Share デフォルト組み立て。

目標: `SimpleShuffleView` は **1 型 / 80 行以下**（現状 66 行。大きく増やさない）。
Snapshot は ViewData を受け取る **1 型のまま**。

### 4.5 目標ディレクトリ構成

現状の配置を維持する。新規モジュールは作らない。

```
SakuttoSeat/
├── Core/
│   ├── DesignSystem/                 // 既存。tint / exportWidth のトークンだけ追加する可能性
│   └── Presentation/
│       └── ImageExportRenderer.swift // renderSimpleShuffle(viewData:)
├── Components/
│   └── NumberedPersonRow.swift       // Style を足すならここだけ
├── Modules/
│   ├── SimpleShuffle/
│   │   ├── SimpleShuffleContracts.swift
│   │   ├── SimpleShuffleEntity.swift
│   │   ├── SimpleShuffleInteractor.swift
│   │   ├── SimpleShufflePresenter.swift
│   │   ├── SimpleShuffleRouter.swift
│   │   ├── SimpleShuffleViewData.swift
│   │   └── View/
│   │       ├── SimpleShuffleView.swift
│   │       └── SimpleShuffleSnapshotView.swift
│   ├── Share/                        // ShareSubject / Interactor / Router を番号札 ViewData 対応
│   └── AttendeeList/                 // 呼び出しシグネチャは [Attendee] のまま（変更しない）
└── SakuttoSeatTests/
    ├── SimpleShuffleTests.swift
    └── ShareTests.swift
```

`SimpleShuffleCopy` を置くなら `SimpleShuffleViewData.swift` 末尾か Contracts 先頭。
ファイルを増やしすぎない（モジュールが小さい）。

### 4.6 初期表示の目標（仕様判断後）

推奨（§8.1）: **assemble 時に 1 回 shuffle** し、画面に出た時点で抽選済みにする。
QA 9.1 と「番号札で決める」CTA の期待に揃う。登録順を見たい操作は参加者一覧で足りる。

実装 loc: `SimpleShuffleInteractor.init` の末尾、または Router が assemble 直後に
`interactor.shuffle()`。Presenter.init で `didTapShuffle()` 相当を呼ぶのは
「ユーザー意図メソッドを組み立てで使う」形になるため、**Interactor.init 側がきれい**。

テスト: 「初期状態は登録順」を「初期状態は集合不変・番号 1-based・順序は登録順と異なることがある」
に更新する。1 名以下は順序固定の既存ケースを残す。

判断が「登録順のまま」なら、QA と Share コメントだけ直して実装は触らない。

---

## 5. 実行計画（フェーズ分割）

各フェーズは独立してマージ可能。
**「テストで現状を固定 → 契約と DI を揃える → Share 境界を移す → 見た目と性能」** の順。
挙動を変える初期シャッフルは最後（判断後）。

### Phase 0: 準備と回帰テスト（0.5 日）

現状の挙動を固定する characterization を `SimpleShuffleTests` / `ShareTests` に足す。

最低限カバーする仕様:

- 初期順は**登録順**、番号は 1-based、ID は親 `Attendee.id`（既存）
- シャッフルしても ID / 名前の集合は不変、番号は常に 1...n（既存）
- 同名でも ID は一意（既存）
- 0 人 / 1 人は順序も番号も不変（既存）
- **追加:** `didTapShare` が Share に渡す名前配列が **現在の並び順**であること
  （`share.route == .selection` だけでは不十分。ShareInteractor 経由でテキスト断言するか、
  テスト用に subject を観測できる口を足す）
- **追加:** ViewDataBuilder が seats の number をそのまま載せ、index を再計算しないこと（既存に近い）
- **追加:** `ShareInteractor.makeNumberedListText` が渡した順で `1番席:` になること（既存）
- 親 Router が `SimpleShuffleRouter.assembleModule` へ委譲すること（既存 `AttendeeListRouterTests`）

完了条件: 見た目を変えずにテスト green。以降の回帰基準とする。
リスク: 低。
`_既知の課題`: 初期表示が QA と不一致、Share payload テスト不足、Snapshot が ViewData 非依存。

実装時の決定（2026-09-11）:

- 見た目・ドメイン挙動は変更していない。
- `SharePresenter.subject` を `private(set)` にし、番号札の共有 payload をテストから断言できるようにした。
- `SimpleShuffleTests` に ViewData の number 非再計算、シャッフル後共有の並び、Router assemble を追加。
- `ShareTests` に配列位置からの採番（Phase 2 で更新する既知課題）と空配列テキストを追加。
- 空の RouterProtocol は作っていない（Phase 1 の方針どおり、インスタンスメソッドが無い Protocol は置かない）。

### Phase 1: 規約穴埋め（0.5 日）

挙動を変えない組み立ての移動。

- `SimpleShuffleRouter.assembleModule` が `ShareRouter.assemblePresenter()` を生成し、
  `SimpleShufflePresenter(interactor:share:)` に**必須引数で**渡す。
  Presenter の `share: SharePresenter? = nil` を廃止（テストは `ShareRouter.assemblePresenter()` を明示注入）。
- `SimpleShufflePresenterProtocol` に `var share: SharePresenter { get }` を追加。
- `NumberedSeat.name` を `let` に。
- Presenter は `shuffle()` の戻りを `publishState` に使う（`allSeats()` の二重読みを削除）。
  初期表示はこれまでどおり `allSeats()`。
- 空の `RouterProtocol` は作らない。Router ファイル先頭に「子の組み立て（Share）が責務」と明記。
- ファイル先頭コメントの AttendeeList Phase 参照を、本計画の Phase 番号に更新してよい
  （履歴コメントの整理。ロジック変更なし）。

完了条件: ビルド成功、Phase 0 green、差分が DI・let 化・戻り値利用に限定。
リスク: 低。Preview / テストのイニシャライザ呼び出し漏れに注意。

実装時の決定（2026-09-11）:

- `SimpleShuffleRouter.assembleModule` が `ShareRouter.assemblePresenter()` を生成して注入する。
- Presenter の `share` デフォルト引数を廃止。テストは `ShareRouter.assemblePresenter()` を明示注入。
- `SimpleShufflePresenterProtocol` に `var share: SharePresenter { get }` を追加（SeatingChart と同じ）。
- `NumberedSeat.name` を `let` に。`number` はシャッフル後の付け替えのため `var` のまま。
- `didTapShuffle` は `interactor.shuffle()` の戻りで ViewData を更新。初期表示は `allSeats()`。
- 空の `SimpleShuffleRouterProtocol` は作っていない。Router ファイルに Builder 責務をコメントした。

### Phase 2: Share / Snapshot を ViewData 駆動にする（1 日）— **本計画の中核**

- `ShareSubject.numberedList` の associated value を `SimpleShuffleViewData` に変更。
- `SimpleShufflePresenter.didTapShare` は `share.didTapShare(subject: .numberedList(viewData))`。
- `ShareInteractor.makeNumberedListText` は `rows.map { "\($0.number)番席: \($0.name)" }`。
  `enumerated()` を番号札経路から削除。
- `SimpleShuffleSnapshotView` の入力を `SimpleShuffleViewData` に。
  `ForEach(viewData.rows)`。見出しは Copy または既存 Catalog キー。
- `ImageExportRenderer.renderSimpleShuffle(viewData:)`。幅は Snapshot の静的定数
  （座席表の `intrinsicWidth` と同じ責務分割）。
- `ShareRouter.makeShareImage` の switch を更新。
- コメント「登録順の一覧」を「タップ時点の並び（ViewData）」に修正。
- `ShareTests` / `SimpleShufflePresenterTests` を新シグネチャへ。
  番号が ViewData 由来であることのテストを 1 本追加
  （意図的に number が index+1 と違う seats を Builder に渡し、テキストがその number を使うこと。
   Interactor 経路では起きないが、境界の回帰として有効）。

完了条件: SimpleShuffle の View / Snapshot に `[String]` と `enumerated()` による番号計算が無い。
Share の番号札経路が座席表と同じく ViewData を受け取る。既存共有テキストの文字列が
通常データ（number == index+1）では Phase 0 と一致する。
リスク: 中（Share は座席表も使う。番号札 case 以外を壊さないこと）。

実装時の決定（2026-09-11）:

- `ShareSubject.numberedList` の associated value を `SimpleShuffleViewData` に変更。コメントは「タップ時点の並び」。
- Presenter は `.numberedList(viewData)` をそのまま渡す。名前配列への落としも番号の再計算もしない。
- `ShareInteractor.makeNumberedListText` は `row.number` / `row.name` を使う。番号札経路から `enumerated()` を削除。
- Snapshot は `SimpleShuffleViewData` を受け取り `ForEach(viewData.rows)`。見出しは既存 Catalog リテラルのまま（画面との差分は §8.8 どおり維持。Copy 集約は Phase 3）。
- 出力幅は `SimpleShuffleSnapshotView.exportWidth`（400）。Renderer はそれを読む。
- `ShareTests` に number ≠ index+1 の ViewData を渡す回帰を追加。通常データ（1-based 連番）の共有文字列は Phase 0 と一致。

### Phase 3: 再利用・一貫性・i18n / A11y（0.75 日）

- `NumberedPersonRow` の tint を番号札から外し、既定 `.sakuttoBlueStart` に揃える。
- 画面の生リテラルと `String(localized:)` をどちらか一方に揃える
  （推奨: `Text("キー")` の Catalog 抽出に統一し、A11y も `Text` と同じキーを使う。
   BulkAddCopy 方式にするなら `SimpleShuffleCopy` を 1 enum にまとめる）。
- Snapshot 行の padding / background を `NumberedPersonRow` の style、または
  `SimpleShuffleSnapshotView` 内 private に閉じる。他画面へ無理に広げない。
- ツールバーボタンに `canShuffle` で disable（2 名未満）。A11y hint を状態で変えてもよい。
- シャッフル後に `AccessibilityNotification.Announcement` で「席順を更新しました」相当を飛ばすかは任意。
  やるなら View 側（描画の関心）。
- `QA_MANUAL_TEST_CHECKLIST.md` §9.4 に画像共有（広告確認含む）を追記。
  現状はテキスト共有しか書いていないが、実装は座席表と同じ 2 種フロー。

完了条件: 番号札と参加者一覧の行の色が目視で同じ。文言 API がモジュール内で一系統。
VoiceOver で共有・シャッフル・各行を辿れる（既存行ラベルは維持）。
リスク: 低〜中（色と文言はスクリーンショット比較）。

実装時の決定（2026-09-11）:

- 番号札 View / Snapshot から `tint: .blue` を外し、`NumberedPersonRow` 既定の `.sakuttoBlueStart` に揃えた。
- 文言は `SimpleShuffleCopy` に集約（BulkAddCopy 同型）。`listHeader` と `snapshotTitle` は §8.8 どおり別文言のまま。
- Snapshot 行の padding / background は `SimpleShuffleSnapshotView` 内の private に閉じた。`NumberedPersonRow.Style` は他画面へ広げないため足していない。
- ViewData に `isEmpty` / `canShuffle`（2 名以上）を追加。シャッフルボタンを disable。A11y hint は状態で切り替え。
- シャッフル後に `AccessibilityNotification.Announcement`（「席順を更新しました」）を View 側で飛ばす。
- QA §9.2〜9.4 に色・1 名 disable・画像共有（広告確認含む）を追記。

### Phase 4: 性能・初期表示仕様・空状態（0.5 日）

- §8.1 の判断を実装する。初期シャッフルするなら Interactor.init で 1 回 `shuffle` 相当。
  Phase 0 の「初期は登録順」テストを更新。1 名以下は不変のまま。
- 空配列で開いたときに `EmptyStateView` を出す（防御。親 CTA が閉じているので到達は稀）。
  ViewData.isEmpty で分岐。List ヘッダだけを出さない。
- `List` に `.listStyle(.insetGrouped)` を明示（AttendeeList と揃える）。
- 大量行の spring が問題になる場合のみ、`n >= 40` で `animation(nil)` または短 duration に切る。
  **計測してから**入れる。先に入れない。
- 親 `AttendeeListInteractor.shuffle()` の去就は本計画の範囲外。触るなら
  「本番未使用」をコメントするか、別計画で削除。番号札の初期シャッフルを親に寄せない
  （QA 11.2: 番号札の状態は一覧に反映しない。親をシャッフルすると座席表の入力順も変わる）。

完了条件: 仕様判断がコードと QA とテストで一致。空状態が破綻しない。
Phase 0〜3 のテスト green。
リスク: 中（初期シャッフルはユーザーから見える挙動変更。判断なしでは実装しない）。

---

## 6. 見込み効果

| 指標 | 現状 | 目標 |
| --- | --- | --- |
| VIPER 5 層の箱 | あり（AttendeeList Phase 5） | 維持 |
| Router の責務 | Builder のみ。Share を知らない | assemble 時に Share を注入 |
| PresenterProtocol の `share` | なし | SeatingChart と同じ |
| View が Entity を直接参照 | なし（画面） / Snapshot は `[String]` | Snapshot も含め ViewData のみ |
| Share の番号札入力 | `[String]` + index 採番 | `SimpleShuffleViewData` |
| Snapshot の ForEach identity | `offset` | `Row.id` |
| 番号の真実の所在 | Interactor だが Share/Snapshot が再計算 | Interactor → ViewData のみ |
| 行の tint | `.blue`（番号札） vs `.sakuttoBlueStart`（一覧） | 1 トークン |
| Presenter の Share デフォルト組み立て | あり | なし（Router） |
| `shuffle` 後の配列再取得 | あり | なし |
| `NumberedSeat.name` | `var` | `let` |
| 共有テストの payload 断言 | なし（route のみ） | 並び順まで断言 |
| 初期表示 vs QA 9.1 | 不一致 | §8.1 で一致させる |
| `SimpleShuffleView` 行数 | 66 / 1 型 | 80 以下 / 1 型（増やしすぎない） |

---

## 7. 検証戦略

1. **層ごとのユニットテスト**
   - **Interactor**: 集合不変、番号 1-based、同名 ID、0/1 人、（判断後）初期シャッフル。
   - **Presenter**: 初期 ViewData、`didTapShuffle` 後の集合、`didTapShare` の subject が
     現在の ViewData であること。Share は注入。
   - **ViewDataBuilder**: number をそのまま載せる（index 再計算しない）。
   - **Share**: 番号札テキストが `row.number` を使う。座席表ケースは回帰として全件維持。
2. **回帰基準**: Phase 0 のテストを全フェーズで維持。シグネチャ変更は Phase 2 でテストも同時更新。
3. **既存 SeatingChart / AttendeeList スイートを壊さないこと。** ShareSubject の変更は
   `ShareTests` と `SeatingChartPresenterTests` の共有ケースに波及し得る。
4. **手動 QA（番号札）** — `QA_MANUAL_TEST_CHECKLIST.md` §9 を更新して実施:
   - 2 名以上で番号札へ → 初期順が仕様どおり
   - 再シャッフルで spring 移動が名前に追従する（番号の円も更新される）
   - 同名 2 名が入れ替わっても行が潰れない
   - テキスト共有が画面の並びと一致する
   - 画像共有: 選択 → 広告確認 → 出力。見出しと行が画面と対応する
   - 戻る → 一覧の順は変わらない（QA 11.2）
   - 1 名ではシャッフルが無効または no-op で壊れない
   - バナーがシャッフル再描画で点滅しない
5. **再描画**: シャッフル 1 回で `Self._printChanges()`。identity が UUID のままであることを確認。
   number を `ForEach` の id にしていないこと。
6. **スクリーンショット**: 2 名 / 20 名、ダークモード、Dynamic Type 最大。Phase 3 の色変更前後。

---

## 8. 実装前に決めるべきこと（要判断）

1. **初期表示をシャッフル済みにするか**
   QA 9.1 と CTA 文言は「決める」側。実装は登録順。
   **推奨:** Interactor.init で 1 回シャッフル。登録順の確認は一覧画面の責務。
   採用しない場合は QA を「登録順で開き、ツールバーで抽選」に直す。
2. **文言を ViewData に載せるか、View の Catalog リテラルに残すか**
   **推奨:** 画面文字列は View 側 Catalog。ViewData は `rows` / `isEmpty` / `canShuffle` のみ。
   共有テキストのプレフィックスは ShareInteractor（現状どおり）だが、番号部分だけ ViewData 由来にする。
3. **`AttendeeListViewData.Row` と番号札 Row の共通化**
   **推奨: しない。** 部品（`NumberedPersonRow`）の共有で十分。DTO を Core に上げると
   モジュール ViewData の意味が薄れる。
4. **`AnyView` の許容範囲**
   親 `AttendeeListRouter` と `SimpleShuffleRouter.assembleModule` の戻りは現状どおり `AnyView`。
   本計画でジェネリクス化しない（座席表計画 §8.6 と同じ）。
5. **SharePresenter の遅延生成**
   **推奨: しない。** 寿命の最適化より、Router 組み立ての一本化を優先。
6. **空の RouterProtocol を書くか**
   **推奨: 書かない。** インスタンスメソッドが無いのに Protocol だけ置くのは
   旧 SeatingChart の失敗パターン。assemble が Builder 責務であることはファイルコメントで足りる。
7. **親 `AttendeeListInteractor.shuffle()` の削除**
   番号札の初期シャッフルをここに寄せると、一覧順まで変わる。QA 11.2 に反する。
   **推奨:** 触らない（削除するなら AttendeeList の別計画）。
8. **Snapshot 見出しを画面ヘッダと同一にするか**
   画像だけ「（番号札）」と付けているのは共有先での文脈用かもしれない。
   **推奨:** 意図を残すなら Copy に `snapshotTitle` と `listHeader` を並べて明示する。
   勝手に同一化しない。

---

## 9. 想定工数

| Phase | 内容 | 工数 | VIPER 上の意義 |
| --- | --- | --- | --- |
| 0 | 準備・回帰テスト整備 | 0.5 日 | 移送の安全網。Share payload の固定 |
| 1 | Router DI・Protocol・Entity 純化 | 0.5 日 | **組み立てを Router に戻す** |
| 2 | Share / Snapshot の ViewData 化 | 1.0 日 | **層間境界の完成**（番号の再計算を排除） |
| 3 | 再利用・i18n / A11y・色の統一 | 0.75 日 | 継ぎ接ぎの解消 |
| 4 | 初期仕様・空状態・性能の任意 | 0.5 日 | プロダクトと QA の一致 |
| | **合計** | **3.25 日** | |

**推奨する区切り:**

- **第一弾（Phase 0〜1、1 日）**: テスト固定と DI。見た目は変わらない。
- **第二弾（Phase 2、1 日）**: Share 境界の対称化。ここが本丸。
- **第三弾（Phase 3〜4、1.25 日）**: 色・文言・仕様判断。スクリーンショット必須。

Phase 2 を契約（Phase 1）の後に置く理由は、Share の associated value を変えるとき
Presenter の呼び出しとテストを同時に閉じるため。Phase 4 の初期シャッフルを先にやると、
Share テストの「初期順」断言と衝突する。

本モジュールは小さい。フェーズを増やすために空 Protocol や共通 Row 型を足さない。

---

## 10. 着手時に触るファイル（目安）

変更予定（実装はまだ行わない）:

- `SakuttoSeat/Modules/SimpleShuffle/View/SimpleShuffleView.swift`
- `SakuttoSeat/Modules/SimpleShuffle/View/SimpleShuffleSnapshotView.swift`
- `SakuttoSeat/Modules/SimpleShuffle/SimpleShufflePresenter.swift`
- `SakuttoSeat/Modules/SimpleShuffle/SimpleShuffleInteractor.swift`
- `SakuttoSeat/Modules/SimpleShuffle/SimpleShuffleEntity.swift`
- `SakuttoSeat/Modules/SimpleShuffle/SimpleShuffleRouter.swift`
- `SakuttoSeat/Modules/SimpleShuffle/SimpleShuffleContracts.swift`
- `SakuttoSeat/Modules/SimpleShuffle/SimpleShuffleViewData.swift`
- `SakuttoSeat/Modules/Share/ShareContracts.swift`
- `SakuttoSeat/Modules/Share/ShareInteractor.swift`
- `SakuttoSeat/Modules/Share/ShareRouter.swift`
- `SakuttoSeat/Core/Presentation/ImageExportRenderer.swift`
- `SakuttoSeat/Components/NumberedPersonRow.swift`（Style を足す場合のみ）
- `SakuttoSeatTests/SimpleShuffleTests.swift`
- `SakuttoSeatTests/ShareTests.swift`
- `QA_MANUAL_TEST_CHECKLIST.md`（§9 の初期表示・画像共有）

参照のみ（規約の正本）:

- `refactor_seating.md`
- `refactor_AttendeeList.md`
- `SakuttoSeat/Modules/SeatingChart/SeatingChartContracts.swift`
- `SakuttoSeat/Modules/SeatingChart/SeatingChartPresenter.swift`（`share` 公開と `didTapShare`）
- `SakuttoSeat/Modules/SeatingChart/View/SeatingChartSnapshotView.swift`（ViewData 駆動の見本）
- `SakuttoSeat/Modules/VenueSettings/*`（薄い子モジュールの見本。空 Protocol は模倣しない）

変更しない（本計画の範囲外）:

- `AttendeeList` の遷移契約（`[Attendee]` 渡し、`didTapSimpleShuffle`）
- `AdBannerContainer` / アダプティブバナー
- SeatingChart 本体の Phase 6（バッジ統合・グリッド遅延描画）
- テストフレームワークの XCTest → Swift Testing 移行
