# サクッと席決め (SakuttoSeat)

[![App Store](https://img.shields.io/badge/APP_STORE-DOWNLOAD-blue?style=flat-square&logo=apple)](https://apps.apple.com/jp/app/id6766817219)
![iOS CI](https://img.shields.io/badge/iOS_CI-passing-brightgreen)
![iOS](https://img.shields.io/badge/iOS-18.0+-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
[![GitHub release](https://img.shields.io/github/v/release/mw-wakkun/SakuttoSeat?label=version&color=green&style=flat-square)](https://github.com/mw-wakkun/SakuttoSeat/releases)

席替えを「サクッと」終わらせるための、iOS向け席決め抽選アプリです。
VIPERアーキテクチャを採用し、モダンなSwiftUIと最新のSwift Testingで構築されています。

## 特徴
- **爆速入力**: 連続して参加者をスピーディに追加できるスムーズなUI。
- **お気に入り機能**: よく使う参加者リストをグループとして保存・呼び出し可能。入力の手間を大幅に削減。
- **2つの抽選モード**:
    - **番号札モード**: 1人ずつ番号を割り振るシンプルなリスト表示。
    - **座席表モード**: テーブル配置を自由に変更し、実際の会場に近いイメージで座席を決定。
- **上品なアニメーション**: 抽選時のカードの入れ替えなど、触っていて心地よいUI/UXを追求。
- **安心の抽選ロジック**: 偏りのないシャッフルアルゴリズムを採用。
- **プロフェッショナルな設計**: VIPERアーキテクチャによる高い保守性と、単体テストによる品質担保。

## 技術スタック
- **Language**: Swift 6.0
- **UI Framework**: SwiftUI
- **Architecture**: **VIPER** (View, Interactor, Presenter, Entity, Router)
- **Testing**: **Swift Testing**
- **Tools**: Xcode 17+

## アーキテクチャのこだわり
各部品の役割を明確に分離することで、機能追加や変更に強い設計を目指しました。
- **Interactor**: 席決めのシャッフルロジックやデータ管理を純粋なSwiftコードで実装。
- **Presenter**: Viewの状態管理を担い、ロジックとUIを完全に切り離しています。
- **Router**: 各画面の遷移と依存注入（DI）を管理。

## 品質担保
最新の **Swift Testing** フレームワークを利用し、抽選ロジックの信頼性を確保しています。
- 参加人数の変動に対する抽選ロジックの動作検証
- シャッフル後の配列が空でないこと、要素の欠損がないことの確認
- 重複した結果が生成されないかの検証

## スクリーンショット
| 入力画面 | 座席表モード | 番号札モード |
| --- | --- | --- |
| <img src="https://github.com/user-attachments/assets/ff33adc0-26ee-4121-a974-1c58fff7fa89" width="300"> | <img src="https://github.com/user-attachments/assets/01368bb6-e813-4f0a-9716-d5281f2324ea" width="300"> | <img src="https://github.com/user-attachments/assets/976fcf35-3955-4760-9228-04764784d339" width="300"> |

## 開発者
- [mw-wakkun](https://github.com/mw-wakkun)

## 変更履歴
すべてのアップデート履歴および詳細な変更点は [Releases ページ](https://github.com/mw-wakkun/SakuttoSeat/releases) をご確認ください。

## その他
* [プライバシーポリシー](https://shore-drifter-687.notion.site/SakuttoSeat-3586b12b81ca8032b6b1ebd43c47af28)
* [ライセンス (MIT)](LICENSE)
