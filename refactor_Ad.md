# 広告基盤 リファクタリング計画書（VIPER 版）

対象: `SakuttoSeat/Modules/AdBanner/` を起点に、バナー表示
（`Components/AdBannerContainer.swift`）とリワード提示
（`Core/Presentation/RewardedAdPresenter.swift`、Share / VenueSettings の Router）
および SDK 初期化（`App/SakuttoSeatApp.swift`）を含む横断基盤。

作成日: 2026-09-11
アーキテクチャ: **VIPER**（View / Interactor / Presenter / Entity / Router）
前提: `refactor_seating.md` Phase 0〜5、`refactor_AttendeeList.md` Phase 0〜6、
`refactor_simple.md` の該当フェーズは完了済み。本計画はそこで確定した
**SwiftUI 適応 VIPER 規約**を広告基盤に適用する。
アダプティブバナー化（旧 `refactor_seating.md` Phase 6 / `refactor_AttendeeList.md` Phase 6）
は完了済みであり、本計画はその**次の負債**を対象にする。

### 進捗

| Phase | 内容 | 状態 |
| --- | --- | --- |
| 0 | 準備と回帰テスト | ✅ 完了（2026-09-11） |
| — | Phase 0 完了後の表示 hotfix（下記） | ✅ 完了（2026-09-11） |
| 1 | 配置・命名・設定の単一化（挙動は変えない） | 未着手 |
| 2 | Gateway 契約と Router 注入口 | 未着手 |
| 3 | SDK 寿命・報酬判定・バナー Coordinator の是正 | 未着手 |
| 4 | Share / VenueSettings の提示経路をテスト可能にする | 未着手 |
| 5 | バナー UI の単一窓口化・余白規約 | 未着手 |
| 6 | パフォーマンス・A11y・収益まわりの仕上げ | 未着手 |

回帰基準: `SakuttoSeatTests` の既存スイート
（SeatingChart / Share / TableEdit / VenueSettings / AttendeeList を含む）に加え、
Phase 0 で追加する `RewardedAdGateway` / `AdBannerMetrics` / 提示経路の
characterization test。以降の全フェーズでこれを維持する。

検証端末は既存計画と同じく iPhone 17 / iOS 26.5 を使用する
（iOS 18.4 シミュレータでは MainActor / protocol existential の解放不整合で
`malloc: pointer being freed was not allocated` が再現するため）。

---

## 0. エグゼクティブサマリ

機能モジュール側（Share / VenueSettings）では、リワード広告の**要否判断は Interactor、
提示は Router** に既に寄っている。一方、広告 SDK そのものは VIPER の外に
継ぎ接ぎで残っており、規約と実装が噛み合っていない。

分析の結論は次の 1 点に集約される。

> **「画面モジュールは VIPER、広告基盤はシングルトンと UIViewRepresentable」**
> バナーは `Modules/AdBanner` と `Components` に分裂し、リワードは Manager / Presenter /
> 2 つの Router が同じ SDK を三重に包む。テストも注入もできず、報酬コールバックには
> 競合バグがある。バナーを 5 層 VIPER モジュールにする必要はない。やるべきは
> **SDK を Gateway の背後に隠し、提示を Router の唯一の窓口にすること**である。

各層の「あるべき責務」と「実際の中身」を対比すると次のとおり。

| 層 | VIPER における責務（広告） | 現状 | 判定 |
| --- | --- | --- | --- |
| View | `AdBannerContainer` をクロムとして置くだけ。SDK / ユニット ID を知らない | 3 画面が直接埋め込み。`AdBannerView` が `GoogleMobileAds` と本番 ID を持つ。余白が画面ごとに違う | △ 半ば |
| Interactor | 広告要否（`UnlockRequirement`）だけを返す。SDK 状態を見ない | Share / VenueSettings は妥当。`UnlockRequirement` が `SeatingChartEntity` に居座る | △ 配置ずれ |
| Presenter | Router に提示を依頼し、結果を Route にする | Share / VenueSettings は妥当。一方 `RewardedAdPresenter` は VIPER Presenter ではなく静的ファサード | ✗ 命名衝突 |
| Entity | ユニット種別・エラー・解放条件の値型 | `RewardedAdError` が Presentation に、ID が View / Manager に散在 | ✗ 分散 |
| Router | UIKit 提示（リワード）の唯一の窓口 | Share / VenueSettings がほぼ同一の 2 行を重複。実体はシングルトン直叩き | △ 薄い |
| Gateway | 広告 SDK の唯一の窓口。load / present / isReady | **Protocol が無い。** `RewardedAdManager.shared` がグローバル状態 | ✗ 不在 |

本計画は既存の VIPER 規約を**維持したまま**、上記の責務を正しい層へ移送する。
主要な作業は次の 4 本柱。

1. **SDK → Gateway**: `RewardedAdManager` を Protocol + 具象実装に置き、シングルトン公開をやめる
2. **静的ファサードの整理**: `RewardedAdPresenter` を ShareSheet と同じ Router ヘルパに再定義するか、Router へ吸収する
3. **バナーを Components の単一窓口に**: View は `AdBannerContainer` 以外を知らない。ID と `rootViewController` 解決を View から剝がす
4. **提示経路をテスト可能にする**: Share / VenueSettings の Presenter テストが Fake Gateway を注入できる

バナー用の `AdBannerInteractor` / `AdBannerPresenter` / `AdBannerRouter` は**作らない**。
バナーは画面ではなくクロム部品であり、5 層化は箱だけ増えて規約に反する。

---

## 1. 本プロジェクトにおける VIPER の解釈（広告向け注釈）

古典的 VIPER は UIKit + delegate 前提のため、SwiftUI に合わせて次のように読む。
**これは `refactor_seating.md` §1 と同一の全社規約**であり、広告も例外にしない。

| 層 | 実装形態 | 依存してよいもの | 禁止事項 |
| --- | --- | --- | --- |
| **View** | `struct: View`。機能画面は Presenter の ViewData / Route のみ | 再利用クロム（`AdBannerContainer`） | `GoogleMobileAds`、ユニット ID、`UIApplication`、業務条件分岐 |
| **Presenter** | `@MainActor final class: ObservableObject` + `PresenterProtocol` | Interactor（具象）、Router（具象） | SDK の load / present、ユニット ID、`print` での握り潰し |
| **Interactor** | `nonisolated final class: InteractorProtocol` | Entity、Gateway（`*GatewayBase` / 具象） | `SwiftUI` / `UIKit` / `GoogleMobileAds` の import |
| **Entity** | 値型 `struct` / `enum` | `Foundation` のみ | SDK 型 |
| **Router** | `final class: RouterProtocol` | 子モジュール Builder、提示ヘルパ、Gateway 具象 | ビジネスルール（広告要否の判断） |
| **Gateway** | Protocol + 具象。Interactor / Router から具象保持 | 外部 SDK、`UserDefaults` 等 | View / Presenter からの直接参照 |

補足（広告固有）:

- **`ObservableObject` は Protocol に載せない。** 既存どおり、MainActor クラスが
  protocol existential を持つと deinit で malloc abort するため、
  Gateway / Router は**具象型で保持**する。
- **リワードの提示は Router の責務。** `UIViewController` を要求するため。
  これは `refactor_seating.md` で確定済みで、Share / VenueSettings は既に従っている。
- **バナーは Router ではなく Components。** 画面遷移でもフルスクリーン提示でもない。
  機能 View がクロムとして置いてよい唯一の広告 UI。
- **Interactor は「見る／見ない」を決めない。** 決めるのは「この操作に広告が要るか」
  （`UnlockRequirement`）。ロード済みかどうかは Gateway の状態。
- **`RewardedAdPresenter` という名前は規約違反。** プロジェクトの Presenter は
  画面モジュールの `@MainActor ObservableObject` を指す。静的 enum に同じ語を使うと
  層が読めなくなる。`ShareSheetPresenter` と同じく **Router ヘルパ**として再定義し、
  可能なら `RewardedAdPresenter` の名前を捨てる。

---

## 2. 現状の責務違反マッピング

### 2.1 ファイル配置の分裂

広告に触れるコードは 4 箇所に分かれている。

| ファイル | 行数 | 置かれている場所 | 実際の役割 |
| --- | --- | --- | --- |
| `Modules/AdBanner/AdBannerView.swift` | 71 | 機能モジュール配下 | `UIViewRepresentable` + サイズ計算 + **本番ユニット ID** |
| `Components/AdBannerContainer.swift` | 41 | 再利用部品 | 幅計測とプレースホルダ。SDK は知らない |
| `Modules/AdBanner/RewardedAdManager.swift` | 103 | 機能モジュール配下 | SDK シングルトン。`ObservableObject` だが購読者がいない |
| `Core/Presentation/RewardedAdPresenter.swift` | 30 | Core | エラー型 + `shared` への 7 行ファサード |

呼び出し側:

| 呼び出し | 内容 |
| --- | --- |
| `AttendeeListView` `:242-243` | `AdBannerContainer` + `.padding(.vertical)` |
| `SeatingChartView` `:247-248` | `AdBannerContainer` + `.padding(.bottom)` のみ |
| `SimpleShuffleView` `:26-27` | `AdBannerContainer` + `.padding(.vertical)` |
| `ShareRouter` `:36-37` | `RewardedAdPresenter.present()` |
| `VenueSettingsRouter` `:29-30` | 同上（コピー） |
| `SakuttoSeatApp` `:32-34` | `MobileAds.shared.start()`。完了待ちとバナー load の同期なし |

`Modules/AdBanner` は VIPER モジュールの体裁（Contracts / Presenter / Interactor / Router）
を持たない。名前だけモジュールに見えるため、後続 AI が「画面モジュールとして 5 層化する」
方向に流れやすい。これが負債の入口である。

### 2.2 View に置かれているが View の責務でないもの

`AdBannerView.swift` の内訳。

| 行 | 内容 | 本来の層 |
| --- | --- | --- |
| 9 | `import GoogleMobileAds` | **Gateway**（Representable は薄い UIKit ブリッジに限定） |
| 13–20 | `AdBannerMetrics` | **Components** か **Core**。テスト対象なので SDK 型を返す API は最小化する |
| 48–52 | DEBUG / RELEASE のユニット ID | **Entity / 設定**（`AdConfiguration`） |
| 53–56 | `connectedScenes.first` + `windows.first` で root VC | **既存の `UIApplication.topViewController`** に揃える |
| 60–68 | サイズ変更時の `load` | Coordinator 内でよいが、**サイズ比較と load 判断はテスト可能な純関数へ** |

`AdBannerContainer` 自体は SDK を知らず、責務は近い。残課題は
PreferenceKey による余分なレイアウトパスと、呼び出し側余白の不統一。

機能 View が `AdBannerContainer()` を直接置くこと自体は、
`EmptyStateView` と同じクロム再利用であり **VIPER 違反ではない**。
剥がすべきなのは ID と SDK と VC 探索である。

### 2.3 Presenter に置かれているが Gateway / Router の責務であるもの

`RewardedAdPresenter` は VIPER Presenter ではない。

| 行 | 内容 | 本来の層 |
| --- | --- | --- |
| 10–17 | `RewardedAdError` | **Entity**（`Core` の値型。SeatingChart 非依存） |
| 20–29 | `isAdReady` 判定 + `loadAd` + `presentAsync` | **Gateway**。判定が Manager 側と二重 |

Share / VenueSettings の画面 Presenter は概ね正しい。

| 箇所 | 内容 | 判定 |
| --- | --- | --- |
| `SharePresenter.didConfirmImageShare` | Router に提示を依頼し、`notReady` だけ Route にする | ○ |
| `VenueSettingsPresenter.didConfirmWatchAd` | 同上。成功時だけ `grantSessionUnlock` | ○ |
| 両 Presenter の `catch { }` | `notEarned` / `failed` を黙殺 | △ 仕様としては妥当だが、ログもユーザー通知も無い |
| 両 Presenter | `RewardedAdError` を直接 import して分岐 | △ Router が結果型を返せば Presenter は SDK 由来エラーを知らなくてよい |

### 2.4 Interactor / Gateway の現状

| 箇所 | 内容 | 判定 |
| --- | --- | --- |
| `ShareInteractor.imageShareRequirement` | 常に `.rewardedAd` | ○ Interactor の判断 |
| `VenueSettingsInteractor.applyRequirement` | 無料枠とセッション解放 | ○ |
| `UnlockRequirement` | `SeatingChartEntity.swift:59-62` に定義 | ✗ Share / VenueSettings が座席表 Entity に依存 |
| 広告 SDK Gateway | 存在しない | ✗ |
| `FeatureUnlockGateway` | 列数解放フラグのみ。広告ロード状態は持たない | ○ 混ぜない（解放と配信は別関心） |

### 2.5 Router の薄い重複

```swift
func presentRewardedAd() async throws {
    try await RewardedAdPresenter.present()
}
```

が `ShareRouter` と `VenueSettingsRouter` に同じ 2 行である。
Protocol 上は正しいが、Gateway を組み立てておらず、テスト時に差し替えられない。
`VenueSettingsPresenterTests` / `SharePresenterTests` は本番 `Router()` を直接生成しており、
`didConfirmWatchAd` / `didConfirmImageShare` の成功・失敗経路は**テストゼロ**。

---

## 3. 課題の詳細

### 3.1 一貫性（継ぎ接ぎ実装の痕跡）

| # | 内容 | 場所 |
| --- | --- | --- |
| 1 | **ユニット ID が 2 ファイルにハードコード。** バナーとリワードで DEBUG 分岐がコピペ | `AdBannerView.swift:48-52` / `RewardedAdManager.swift:21-27` |
| 2 | **root VC の取り方が 2 系統。** バナーは `windows.first`、リワードは `isKeyWindow` + presented 連鎖 | `AdBannerView.swift:53-56` vs `UIApplication+TopViewController.swift` |
| 3 | **バナー余白が 3 画面で不一致。** 2 画面は `.vertical`、座席表だけ `.bottom` | AttendeeList / SimpleShuffle vs SeatingChart |
| 4 | **未準備アラートのタイトルが不一致。** Share は「広告を読み込み中」、VenueSettings は「広告の準備ができていません。」。本文は同じ | `ShareFlowModifier.swift:77-78` vs `VenueSettingsView.swift:53-56` |
| 5 | **`RewardedAdManager` が `ObservableObject`。** `@Published isAdReady` を View は購読していない。Combine と async/await が混在 | Manager `:13-17` |
| 6 | **エラー出力が `print`。** 他モジュールは Route でユーザーへ返す方針に移行済み | Manager `:40, 61, 96` |
| 7 | **`Modules/AdBanner` と `Components` と `Core/Presentation` の 3 拠点。** 後続実装がどこに足すか判断できない | 配置 |
| 8 | **App の SDK start と最初のバナー load が非同期競合。** `.task { await MobileAds.shared.start() }` の完了前に Representable が `load` し得る | `SakuttoSeatApp.swift:32-34` |
| 9 | **リワードの事前ロード起点が曖昧。** Manager の `init` で `loadAd()` するが、`shared` に触れるまで init されない。初回画像共有は高確率で `notReady` | Manager `:29-32` / Presenter `:24-26` |

### 3.2 VIPER 逸脱

| # | 内容 | あるべき姿 |
| --- | --- | --- |
| 1 | View（Representable）が本番 adUnitID を持つ | `AdConfiguration`。View はサイズと BannerView の generational 更新だけ |
| 2 | SDK 状態がシングルトン | `RewardedAdGateway` を Router が具象保持。App 起動時に 1 つ組み立てて渡す |
| 3 | `RewardedAdPresenter` が VIPER Presenter を名乗る | 改名・吸収。画面 Presenter と語彙を衝突させない |
| 4 | Share / VenueSettings Router が Gateway を知らない | `presentRewardedAd` の実装が Gateway を呼ぶ。テストは Fake を注入 |
| 5 | `UnlockRequirement` が SeatingChart Entity | `Core` の共通 Entity。座席表モジュールの詳細ではない |
| 6 | バナー Coordinator が `UIApplication.shared` | 既存ヘルパに統一。可能なら `rootViewController` を外から渡す |

### 3.3 パフォーマンス

| # | 内容 | 場所 |
| --- | --- | --- |
| 1 | **`GeometryReader` + `PreferenceKey` が幅のためだけに 1 パス増える。** 3 画面共通。iOS 16+ の `onGeometryChange` で足りる | `AdBannerContainer.swift:25-30` |
| 2 | **NavigationStack 配下でバナーが複数生存する。** 参加者一覧 → 座席表で、隠れている一覧側の `BannerView` も残る。AdMob 的には画面ごとに 1 本が正だが、非表示中も refresh が走り得る | 3 View |
| 3 | **サイズ変更のたびに `banner.load(Request())`。** 回転・Split View・キーボードでアダプティブサイズが変われば正しいが、小数点の揺れで過剰 reload し得る | Coordinator `:60-68` |
| 4 | **`lastLoadedSize` が Coordinator のインスタンス状態。** SwiftUI が Representable を作り直すと再 load。identity 安定化の指針が無い | `AdBannerView` |
| 5 | **失敗時のリトライが無い。** バナーは Delegate 未実装。リワードは dismiss / fail のたびに `loadAd` するが、初回失敗は `isAdReady = false` のまま呼び出し待ち | 双方 |
| 6 | **SDK start 完了前の load。** 無効リクエストとフィルトークン低下の温床 | App vs Representable |
| 7 | **リワードを画面表示のたびに再生成しない一方、バナーは画面数だけ実体がある。** 方針自体は妥当。問題は非表示バナーを止めないこと | — |

### 3.4 正確性・保守性リスク

| # | 内容 | 場所 |
| --- | --- | --- |
| 1 | **報酬フラグの競合（バグ）。** `present` の報酬クロージャが `Task { @MainActor in hasEarnedReward = true }` で遅延する。`adDidDismissFullScreenContent` が同ターンで走ると、視聴完了なのに `notEarned` になる余地がある | `RewardedAdManager.swift:71-74, 81-92` |
| 2 | **Delegate コールバックのスレッド保証が無い。** `FullScreenContentDelegate` は `@MainActor` ではない。continuation の二重 resume もガードが `presentContinuation == nil` の代入頼み | Manager `:81-102` |
| 3 | **提示中の再入はエラーにするが、失敗後の continuation リーク検査が無い。** どちらの Delegate も来なければ `await` が戻らない | `presentAsync` |
| 4 | **バナーは load 失敗を握りつぶす。** クラッシュはしない（QA のグレースフルフェイルは満たす）が、空スペースのまま再試行しない | Coordinator |
| 5 | **`makeBanner` は load しない。** 初回 load は `updateUIView` 頼み。通常は両方呼ばれるが、将来 `updateUIView` を短絡すると広告が出なくなる | `AdBannerView.swift:30-38, 46-58` |
| 6 | **テストが SDK をモックできない。** `AdBannerMetricsTests` はサイズ計算のみ。提示・報酬・未準備は手動 QA 依存 | Tests |
| 7 | **SKAdNetwork が Google 公式 1 件のみ。** フィルトークン / 収益に影響し得る。VIPER 外だが本基盤の一部 | `Info.plist` |
| 8 | **ATT（追跡許可）ダイアログが無い。** 仕様判断が未決のまま IDFA なしで配信している | App |

`refactor_AttendeeList.md` §3.2-#11 は
「`AdBannerView` が `makeUIView` のたび `load`。`updateUIView` は空」と記録している。
**これは Phase 6 で部分修正済み**で、現行はサイズが変わったときだけ `updateUIView` から load する。
本計画ではその記録を更新済みとして扱い、残るのはサイズ揺れ・SDK start 競合・非表示時の生存である。

---

## 4. あるべき構造

### 4.1 層の境界（広告は画面モジュールにしない）

```
機能モジュール（AttendeeList / SeatingChart / SimpleShuffle / Share / VenueSettings）
  View       … AdBannerContainer をクロムとして置く。SDK を import しない
  Presenter  … router.presentRewardedAd() を待つ。結果を Route にする
  Interactor … UnlockRequirement を返すだけ
  Router     … RewardedAdGateway 具象を保持し、提示する

Core
  Entity     … UnlockRequirement / RewardedAdError / AdConfiguration
  Gateways   … RewardedAdGateway + Impl（GoogleMobileAds はここだけ）
  Ads UI     … AdBannerContainer / AdBannerRepresentable（UIKit ブリッジ）
  App        … MobileAds.start 完了後に Gateway.load() とバナー許可フラグを立てる
```

`Modules/AdBanner/` は解体する。残す名前があるなら `Core/Ads/` に寄せ、
画面モジュール配下に置かない。

### 4.2 目標ファイル構成

```
SakuttoSeat/
├── App/
│   └── SakuttoSeatApp.swift          // start 完了 → Gateway.preload()
├── Core/
│   ├── Entity/
│   │   ├── UnlockRequirement.swift   // SeatingChartEntity から移設
│   │   └── RewardedAdError.swift     // Presentation から移設
│   ├── Gateways/
│   │   ├── AdConfiguration.swift     // バナー / リワードのユニット ID
│   │   ├── RewardedAdGateway.swift   // Protocol（load / isReady / present）
│   │   └── RewardedAdGatewayImpl.swift
│   └── Extensions/
│       └── UIApplication+TopViewController.swift  // バナーもここを使う
├── Components/
│   └── AdBannerContainer.swift       // 公開 API はこれ 1 つ。Representable は fileprivate
└── Modules/
    ├── Share/ShareRouter.swift       // Gateway 具象を init 注入
    └── VenueSettings/VenueSettingsRouter.swift
```

削除または吸収:

- `Modules/AdBanner/AdBannerView.swift`
- `Modules/AdBanner/RewardedAdManager.swift`
- `Core/Presentation/RewardedAdPresenter.swift`（ヘルパに残すなら `RewardedAdPresenter` という型名は使わない）

### 4.3 Gateway 契約（案）

Presenter / Interactor が protocol existential を保持しない既存規約に合わせ、
Router は **具象 `RewardedAdGatewayImpl`（テストでは `RewardedAdGatewayFake`）** を持つ。
Protocol はテストダブルとドキュメントのために置く。

```swift
nonisolated protocol RewardedAdGateway: AnyObject {
    var isReady: Bool { get }
    func preload()
}

protocol RewardedAdPresenting: AnyObject {
    @MainActor func present() async throws
}
```

実装上は 1 クラスにまとめてよい。ポイントは次の 4 つ。

1. **報酬クロージャ内で同期的に `hasEarnedReward = true` する。** `Task { @MainActor }` を挟まない
2. **Delegate は必ず MainActor に hop してから continuation を resume する**
3. **`present` 中の再入は `failed`。未 dismiss のまま deinit したら continuation を fail する**
4. **`ObservableObject` にしない。** 準備状態が必要な画面があれば、Router / Presenter が明示的に読む

バナー側は Gateway に載せない。`BannerView` は UIView の寿命と結びつくため、
Representable の Coordinator が `AdConfiguration` と `topViewController` だけを使う。

### 4.4 機能モジュールから見た公開面

| 呼び出し元 | 触ってよいもの | 触ってはいけないもの |
| --- | --- | --- |
| 3 つのメイン View | `AdBannerContainer()` | `AdBannerView`、`GoogleMobileAds`、ユニット ID |
| Share / VenueSettings Presenter | `router.presentRewardedAd()`、`RewardedAdError`（移設後の Entity） | `RewardedAdManager`、`RewardedAdPresenter` |
| Share / VenueSettings Interactor | `UnlockRequirement` | SDK |
| App | `MobileAds.shared.start()` と Gateway.preload。start は App か Gateway のどちらが一箇所で行うかを Phase 1 で固定 | 各 View からの start |

### 4.5 バナー Representable の方針

- 公開型は `AdBannerContainer` のみ。`AdBannerView` は fileprivate
- `updateUIView` でサイズが実質同一（幅を pt 単位で丸めた値）なら load しない（現行の意図を維持）
- 初回 load は `makeUIView` か `updateUIView` の**どちらか一方に明記**し、両方から load しない
- `BannerViewDelegate` を Coordinator が持ち、失敗はログ（または将来のプレースホルダ）に留めてクラッシュしない
- `rootViewController` は `UIApplication.shared.topViewController` に統一。nil なら load を延期
- SDK start 未完了なら load しない（App 側のフラグ、または Gateway の `isSDKReady`）

### 4.6 やらないこと（スコープ外）

- バナー専用 VIPER 5 層（Contracts / Presenter / Interactor / Router / Entity）
- 3 画面で 1 つの `BannerView` を使い回す（AdMob の画面単位バナー方針に反する）
- リワードを Interactor に移動する（UIKit 提示は Router）
- `FeatureUnlockGateway` と広告 Gateway の統合（解放フラグと配信 SDK は別）
- 広告オフの課金 IAP（プロダクト未決）
- String Catalog 全体移行（他計画の Phase 6 持ち越し。本計画では広告文言の単一化まで）

---

## 5. フェーズ計画

各フェーズは独立して PR 可能な粒度にする。前フェーズのテストが落ちた状態で次に進まない。

### Phase 0: 準備と回帰テスト（0.5 日）

- 現行挙動をテストで固定する。
  - `AdBannerMetricsTests` は維持（幅 320 / 390 で高さ ≥ 50）
  - サイズ同一なら load しない判断を、Coordinator から純関数
    `shouldReloadBanner(previous:next:)` に切り出してテストした（挙動は `previous != next` のまま）
  - `RewardedAdGateway` / `RewardedAdPresenting` を `Core/Gateways` に追加。
    `RewardedAdGatewayFake` をテスト側へ置き、Share / VenueSettings の
    「未準備 → Route」「成功 → 副作用」「notEarned → 副作用なし」は
    **Router 注入（Phase 2）まで XCTSkip**
- `QA_MANUAL_TEST_CHECKLIST.md` の §10 に、回転時のバナー再 load、
  リワード視聴完了／中断、未準備アラートの文言差（現状）を追記した
- 完了条件: 既存スイート green。広告の characterization が 1 ファイル以上ある。
- リスク: 低。

### Phase 0 完了後の表示 hotfix（計画外・2026-09-11）

Phase 0 自体はテスト固定が目的で、表示バグの修正は含まない。手動 QA で発覚した
バナー表示・レイアウト崩れを、Phase 1 に進む前に直した。**Phase 0 の完了判定は維持する。**
後続フェーズはこれを壊さないこと。すでに入っている作業はやり直さない。

| 症状 | 対応 | 後続で触るなら |
| --- | --- | --- |
| 起動直後にテスト広告が出ない | `MobileAds.start()` 完了と `rootViewController` 確定後に `load`。`BannerViewDelegate` で失敗を DEBUG ログ | Phase 3（残: リワード報酬競合、Gateway 接続） |
| 広告が親を横に押し広げ、ボタンが欠ける | `sizeThatFits` と明示 `frame`。幅は親から測る | Phase 5 |
| overlay 化で広告が再消滅 | `BannerView` は通常の子 View に戻す（overlay 禁止） | Phase 5 で overlay にしない |
| バナーが高すぎる | `currentOrientationAnchoredAdaptiveBanner`（50〜90pt）。`large` は使わない | Phase 5 で large に戻さない |
| 番号札だけ広告が出ない | inset がバナーのみだと ideal 幅 0。`containerRelativeFrame(.horizontal)` | 維持 |

シミュレータで 3 画面（参加者一覧・座席表・番号札）のバナー表示とボタン列を確認済み。

### Phase 1: 配置・命名・設定の単一化（0.5〜1 日）

挙動は変えない移動と定数の集約。

- `UnlockRequirement` を `SeatingChartEntity` から `Core` へ移設
- `RewardedAdError` を Presentation から `Core` へ移設
- `AdConfiguration` を新設し、バナー / リワードの DEBUG・本番 ID を 1 箇所にする
- `AdBannerView` + `AdBannerContainer` を `Components` に同居（または Container ファイルへ内部型として統合）
- `Modules/AdBanner/` を空にしたらディレクトリごと削除
- バナーの root VC 解決を `UIApplication.topViewController` に揃える（keyWindow 化）
  → **hotfix でバナー側は実施済み。** リワード Manager 側の `topViewController` 利用は現状維持。移動時に崩さない。
- `RewardedAdManager` の `ObservableObject` / `@Published` を削除（購読者がいない）
- `print` は残してもよいが、新規追加しない
- 完了条件: ユニット ID のリテラルが `AdConfiguration` 以外に無い。
  `import GoogleMobileAds` が App / Gateway 実装 / バナー Representable 以外に無い。
- リスク: 低（移動のみ）。

### Phase 2: Gateway 契約と Router 注入口（1 日）

- `RewardedAdGateway` / `RewardedAdPresenting` は Phase 0 で追加済み。`RewardedAdGatewayImpl`（現行 Manager の移植）と Router 注入を行う
- `ShareRouter` / `VenueSettingsRouter` の `init` で具象 Gateway を受け取る。
  既定値は本番 Impl。`assemble*` が組み立てる
- `RewardedAdPresenter.present()` の静的呼び出しを削除し、Router が Gateway を呼ぶ
- 画面 Presenter のシグネチャは変えない（`router.presentRewardedAd()` のまま）
- Fake をテストターゲットへ。この時点では Impl の中身は現行ロジックの移植でよい
- 完了条件: 本番コードに `RewardedAdManager.shared` / `RewardedAdPresenter.present` が無い。
  Presenter テストが Fake を注入できる（ケース追加は Phase 4）
- リスク: 中（組み立て経路の引き回し）。App から Gateway を 1 つ作り、
  Share / VenueSettings の assemble へ渡すか、起動時 preload 用の単一エントリを残す。
  **グローバル `shared` を残すなら `SessionFeatureUnlock.shared` と同じ「セッション寿命の明示的シングルトン」に限定**し、View からは見えないようにする。

推奨: `SessionFeatureUnlock` と同様、

```swift
enum SessionRewardedAd {
    static let shared = RewardedAdGatewayImpl()
}
```

を **assemble と App の preload 専用**にする。機能 View / Presenter は触らない。
完全 DI（App から全 Router へ引数で渡す）は組み立てが長いので、本プロジェクトの
`SessionFeatureUnlock.shared` 踏襲を優先する。

### Phase 3: SDK 寿命・報酬判定・バナー Coordinator の是正（1 日）

ここが本丸。挙動が正しくなる。

- **報酬競合の修正**: user earned コールバックで同期的にフラグを立てる。
  dismiss より後にフラグが立つ経路をテスト（Fake ではなく Impl を
  コールバック順で駆動できるならユニットで、無理なら手動 QA を必須化）
- Delegate / continuation を `@MainActor` に集約。二重 resume を防ぐ
- `MobileAds.shared.start()` 完了後にだけ `preload()` とバナー load を許可する。
  App の `.task` と Gateway を接続
  → **バナー load 待ちは hotfix 済み。** 残作業は Gateway 経由の preload と App 接続、
  リワード側の報酬競合修正。バナーの `start()` 待ちを外さない。
- バナー: load の単一路、幅の丸め比較、`rootViewController == nil` なら延期、
  `BannerViewDelegate` で失敗を握りつつ再 load 方針を 1 つ決める
  （推奨: 失敗時は自動リトライしない。次のサイズ変更または画面再表示で再試行）
  → **幅丸め・VC 延期・Delegate ログは hotfix 済み。** 自動リトライは入れない方針を維持。
- 完了条件: 視聴完了 → 画像共有 / 列数解放が手元で再現する。
  視聴中断 → 副作用なし。未準備 → 既存アラート。
- リスク: 中〜高（広告フィルはネットワーク依存。DEBUG は Google サンプル ID を維持）。

### Phase 4: Share / VenueSettings の提示経路をテスト可能にする（0.5〜1 日）

- `SharePresenterTests`
  - Fake `notReady` → `route == .alert(.adNotReady)`、シェアシートは呼ばない
  - Fake 成功 → 画像出力経路へ進む（出力自体は既存の renderer テストに任せる）
  - Fake `notEarned` / `failed` → route なし、共有なし
- `VenueSettingsPresenterTests`
  - Fake 成功 → `grantSessionUnlock` + Output に列数が渡る
  - Fake `notReady` → `.adNotReady`
  - Fake `notEarned` → 未解放のまま Output なし
- Router の `presentRewardedAd` が Gateway を 1 回呼ぶことだけを検証してもよい
- 未準備アラート文言を Share / VenueSettings で揃える（コピーの単一化。タイトルは
  「広告の準備ができていません」に寄せ、QA チェックリストを更新）
- 完了条件: リワード提示の分岐がユニットテストで固定される。
  手動 QA はフィルと実 SDK の確認に縮小できる。
- リスク: 低。

### Phase 5: バナー UI の単一窓口化・余白規約（0.5 日）

- `AdBannerContainer` がパディング込みの完成形を出すか、
  `AppSpacing.bannerVerticalPadding` を Container 内部に閉じる。
  呼び出し側 3 箇所は `AdBannerContainer()` のみにする
- 座席表の `.padding(.bottom)` だけ違う問題を解消（上下とも同じトークン）
- `GeometryReader` + Preference を `onGeometryChange` に置換（deployment 18.0 以上で使用可）
  → **hotfix で `onGeometryChange` + `containerRelativeFrame` に置換済み。**
  PreferenceKey は消えている。overlay には戻さない。
  サイズ API は `currentOrientationAnchoredAdaptiveBanner`（50〜90pt）を維持し、
  `largeAnchoredAdaptiveBanner` に戻さない。
- `bannerWidth == 0` のプレースホルダ高さは `AppSpacing.bannerFallbackHeight` を維持し、
  ジャンプを避ける
- 公開 API から `AdBannerView` / `AdBannerMetrics` を隠す。テストは
  `@testable import` で Metrics または `shouldReloadBanner` を見る
- 完了条件: 3 画面のバナー呼び出しが同一。PreferenceKey 型が消える。
- リスク: 低〜中（高さジャンプ・回転時の再計測）。スクリーンショット比較を推奨。

### Phase 6: パフォーマンス・A11y・収益まわりの仕上げ（0.5〜1 日）

- 非表示時: Representable の `dismantleUIView` で参照を切る。可能なら
  画面の `onAppear` / `onDisappear` で load を抑制（やりすぎるとフィルが落ちるので、
  **ナビゲーションで隠れた一覧のバナーを止める**程度に留める）
- VoiceOver: 現行は `.accessibilityHidden(true)`（操作対象から広告を外す）。
  方針を文書化する。変更するなら「飛ばせるが存在する」に切り替え、QA を更新
- `Info.plist` の SKAdNetwork を Google 推奨リストへ更新するか、更新しない理由を README に残す
- ATT を出すかはプロダクト判断（§8）。本フェーズでは「出さない」ならその旨を計画にチェック済みと書く
- Instruments で 3 画面往復時の `BannerView` 生存数を確認
- 完了条件: 画面遷移でバナー実体が意図どおり増減する。QA §10 / リワード項目が更新済み。
- リスク: 中（収益・A11y は仕様判断を含む）。

---

## 6. 見込み効果

| 指標 | 現状 | 目標 |
| --- | --- | --- |
| 広告コードの拠点 | 3 箇所（Modules / Components / Core/Presentation） | Core Gateway + Components の 2 拠点 |
| VIPER 画面モジュールとしての AdBanner | 中途半端な `Modules/AdBanner` | 置かない（クロム + Gateway） |
| `GoogleMobileAds` の import | App / AdBannerView / RewardedAdManager | App / GatewayImpl / バナー Representable |
| ユニット ID リテラル | 4 本（バナー DEBUG/本番、リワード DEBUG/本番が 2 ファイル） | `AdConfiguration` のみ |
| root VC 解決 | 2 系統 | `UIApplication.topViewController` のみ |
| `RewardedAdManager.shared` を知る型 | Presenter ファサード + Manager | assemble / App のみ |
| リワード分岐のユニットテスト | 0（Interactor の要否だけ） | Share / VenueSettings の成功・未準備・未獲得 |
| バナー余白の書き方 | 3 画面で 2 パターン | Container 内に 1 つ |
| 報酬コールバック競合 | あり | なし |
| SDK start 前の load | あり得る | なし |
| `RewardedAdPresenter` という VIPER 外 Presenter | あり | なし |

行数は増やしてよい。目的は削減ではなく、**層の単一化とテスト可能性**である。

---

## 7. 検証戦略

1. **層ごとのユニットテスト**
   - **Gateway Fake**: `ready` / `notReady` / `notEarned` / `failed` / `alreadyPresenting`
   - **Presenter**: Share / VenueSettings が Fake の結果を Route / Output に写すこと
   - **バナー**: 幅丸め後の同一サイズは reload しない。0 幅は load しない
   - **Interactor**: 既存の `UnlockRequirement` ケースを維持（移設後もコンパイルが通ること）
2. **回帰基準**: Phase 0 で固定したテストを全フェーズで維持
3. **手動 QA**（実 SDK。DEBUG は Google サンプル ID）
   - 3 メイン画面でバナー表示、オフラインでクラッシュしない
   - 回転・Dynamic Type で高さだけ変わり、無限 reload しない
   - 画像共有: 視聴完了でシェア、中断でシェアなし、未準備でアラート
   - 列数 3 以上: 視聴完了で適用、中断で非適用、セッション中は 2 回目以降広告なし
4. **検証端末**: iPhone 17 / iOS 26.5（既存計画と同一）
5. **やってはいけない検証**: 本番ユニット ID での自動テスト、クリックの擬似生成

---

## 8. 実装前に決めるべきこと（要判断）

1. **Gateway の寿命** — 推奨: `SessionFeatureUnlock.shared` と同じセッションシングルトンを
   assemble / App 専用にする。App から全 Router へ引数で渡す完全 DI は行わない。
2. **`RewardedAdPresenter` の名前** — 推奨: 削除。残すなら `RewardedAdPresentation` など
   VIPER Presenter と衝突しない名前。本計画は削除前提。
3. **バナー失敗時のリトライ** — 推奨: 自動リトライしない。空スペースを維持し、
   次のサイズ変更または再表示で再 load。
4. **非表示バナー** — 推奨: Navigation で隠れた画面の load/refresh を止める。
   1 つの BannerView を全画面で使い回さない。
5. **VoiceOver** — 推奨: 現行どおり広告を隠し、操作対象をアプリ本体に限定する。
   変更するなら Phase 6 で明示的にひっくり返す。
6. **ATT** — 本計画のデフォルトは現状維持（出さない）。出す場合は別タスク。
7. **SKAdNetwork リスト拡充** — 推奨: Google の最新リストへ更新（コード層と独立、Phase 6）。
8. **未準備アラート文言** — 推奨: タイトル・本文を VenueSettings 側に揃え、
   Share の「広告を読み込み中」をやめる（実際は読み込み開始を投げているだけで
   プログレスでは無いため）。

---

## 9. 既存計画との関係

| 既存計画 | 本計画での扱い |
| --- | --- |
| `refactor_seating.md` Phase 4/5 | リワード提示を Router へ移した成果は維持。Gateway 化がその続き |
| `refactor_seating.md` Phase 6 のバナー項目 | アダプティブ化は完了。固定 320×50 は解消済み |
| `refactor_AttendeeList.md` Phase 6 | `AdBannerContainer` 導入済み。§3.2-#11 の「updateUIView が空」は現行コードでは解消済み |
| `refactor_simple.md` | バナーは横断部品として触らない、とある。本計画が横断側の担当 |
| `FeatureUnlockGateway` | 列数解放フラグ。広告 SDK と統合しない |

実装は本計画の承認後に Phase 0 から順に行う。本ファイルは計画のみであり、
この時点ではコードを変更しない。
