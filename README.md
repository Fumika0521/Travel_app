# TabiRoute (仮称)

写真のGPS情報から旅のルート地図を自動生成するiOSアプリ。v1 MVPは「写真選択 → GPS抽出 → 地図にルート表示」のみ。

競合調査・差別化方針・課金方針の経緯は `~/.claude/projects/-Users-fumika-develop2/memory/project_travel_app.md` を参照。

## 現在の状態

- このMacにはコマンドラインツールのみでフルのXcodeが入っていないため、`xcodebuild`でのビルド確認はまだ行っていません
- `Packages/RouteClusteringKit`(ピンのクラスタリングロジック)は純粋Swiftで、`swift build`では成功を確認済み。ただし`swift test`はXCTestがフルXcodeにしか含まれないため、この環境では実行できません

## Xcodeインストール後にやること

1. フルXcodeをインストール(App Store等から)
2. `cd /Users/fumika/develop2 && xcodegen generate`(project.ymlを編集した場合は再実行)
3. `cd Packages/RouteClusteringKit && swift test` でクラスタリングロジックの単体テストを確認
4. `open TabiRoute.xcodeproj` でXcodeを開き、シミュレータでビルド&実行
5. シミュレータの「写真」アプリに、位置情報あり/なしを混在させたテスト用写真を数枚追加して、以下を確認
   - トリップ作成 → 地図にルート(ポリライン)とピンが表示される
   - 近い場所で撮った写真がピンの密集にならずクラスタ表示(枚数バッジ)になる
   - 位置情報のない写真がある場合、件数が表示される
   - 初回、写真へのアクセス許可ダイアログが日本語の説明文で表示される

## 構成

- `TabiRoute/` — アプリ本体(SwiftUI + SwiftData + PhotoKit + MapKit)
- `Packages/RouteClusteringKit/` — ピンのクラスタリングロジック(UIKit/PhotoKit非依存、単体テスト対象)
- `project.yml` — XcodeGenのプロジェクト定義。`.xcodeproj`はこれから生成されるので直接編集しない

## スコープ外(v2/v3予定)

パッキングリスト、フォトブック/PDF出力、課金(StoreKit)、Web共有リンク、国内地名の逆ジオコーディング精度向上。
