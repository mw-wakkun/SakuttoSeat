# サクッと席決め (SakuttoSeat)

![Build Status](https://github.com/mw-wakkun/SakuttoSeat/actions/workflows/swift.yml/badge.svg)
![iOS 18.0+](https://img.shields.io/badge/iOS-18.0%2B-blue.svg)
![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)

席替えを「サクッと」終わらせるための、iOS向け席決め抽選アプリです。
VIPERアーキテクチャを採用し、モダンなSwiftUIと最新のSwift Testingで構築されています。

## 特徴
- **爆速入力**: 連続して参加者をスピーディに追加できるスムーズなUI。
- **安心の抽選ロジック**: 前回と同じ並び順にならないよう配慮したシャッフルアルゴリズム。
- **プロフェッショナルな設計**: VIPERアーキテクチャによる高い保守性とテストコードによる品質担保。

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
| 入力画面 | 抽選結果 |
| --- | --- |
| <img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-05-05 at 22 24 40" src="https://github.com/user-attachments/assets/634784c2-474d-47ae-aaae-5d2825b6c501" /> | <img width="1206" height="2622" alt="Simulator Screenshot - iPhone 17 Pro - 2026-05-05 at 22 25 23" src="https://github.com/user-attachments/assets/96bf2776-7c7d-4d6d-9f79-3f01f7e6c8ee" /> |

## 開発者
- mw-wakkun
