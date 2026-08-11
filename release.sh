#!/bin/zsh

# エラーが起きたら処理を中断する
set -e

# 変数の初期化
VERSION=""
MESSAGE=""

# 引数の解析（-v: バージョン, -m: コミットメッセージ）
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -v|--version) VERSION="$2"; shift ;;
        -m|--message) MESSAGE="$2"; shift ;;
        *) echo "不明なパラメータ: $1"; exit 1 ;;
    esac
    shift
done

# 必須チェック
if [ -z "$VERSION" ]; then
    echo "エラー: バージョンを指定してください (例: -v 1.1.0)"
    exit 1
fi

if [ -z "$MESSAGE" ]; then
    echo "エラー: コミットメッセージを指定してください (例: -m \"新機能の追加\")"
    exit 1
fi

echo "🚀 リリースプロセスを開始します: v$VERSION"
echo "📝 機能変更のコミット: $MESSAGE"
echo "----------------------------------------"

# 1. 開発で修正した未コミットのコードをコミット
echo "📦 1. 変更をコミットしています..."
git add .
git commit -m "$MESSAGE"

# 2. Fastlaneの実行（レーン名: release を指定）
# ※バージョン番号の更新、ビルド、アップロード、リリース用コミット＆タグ付け、PushまでをFastlaneに任せる
echo "🍎 2. FastlaneでApp Storeへアップロード＆リリース処理を実行しています..."
bundle exec fastlane release version:"$VERSION"

echo "----------------------------------------"
echo "✅ すべての処理が完了しました！"
