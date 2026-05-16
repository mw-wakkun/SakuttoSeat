# サクッと席決め (SakuttoSeat)

![Build Status](https://github.com/mw-wakkun/SakuttoSeat/actions/workflows/swift.yml/badge.svg)
![iOS 18.0+](https://img.shields.io/badge/iOS-18.0%2B-blue.svg)
![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)
![Version 1.1.0](https://img.shields.io/badge/version-1.1.0-green.svg)

席替えを「サクッと」終わらせるための、iOS向け席決め抽選アプリです。
VIPERアーキテクチャを採用し、モダンなSwiftUIと最新のSwift Testingで構築されています。

## 特徴
- **爆速入力**: 連続して参加者をスピーディに追加できるスムーズなUI。
- **2つの抽選モード**:
    - **番号札モード**: 1人ずつ番号を割り振るシンプルなリスト表示。
    - **座席表モード(v1.1.0)**: テーブル配置を自由に変更し、実際の会場に近いイメージで座席を決定。
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
| 入力画面 | 座席表モード (v1.1.0) | 番号札モード |
| --- | --- | --- |
| <img src="https://github.com/user-attachments/assets/ff33adc0-26ee-4121-a974-1c58fff7fa89" width="300"> | <img src="https://github.com/user-attachments/assets/01368bb6-e813-4f0a-9716-d5281f2324ea" width="300"> | <img src="https://github.com/user-attachments/assets/976fcf35-3955-4760-9228-04764784d339" width="300"> |

## 開発者
- [mw-wakkun](https://github.com/mw-wakkun)

- ## 変更履歴

### [1.1.1] - 2026-05-16
- **修正**: 座席表画面の決定ボタンにグラデーションとシャドウを適用し、全体のUIデザインを統一
- **修正**: 特定の条件下で発生していた一部表示崩れの調整
- **改善**: XcodeのLocalization設定を見直し、App Storeおよびアプリ本体の日本語対応を最適化
