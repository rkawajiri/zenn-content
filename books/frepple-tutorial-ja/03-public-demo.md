---
title: "公開デモで完成形を見る"
---

この章のゴール: インストールなしで、公開されている frePPLe のデモを開き、「計画が出来上がった状態」を先に見ておく。

:::message
**この章で学べる計画の考え方**

- 計画システムの出力は、リソースごとの時間軸（ガント）と、受注ごとの遅れで見る
- 「計画が完成した状態」を先に見ておくと、以降の章で何を作るのかが分かる
:::

## 公開デモとは

frePPLe の開発元は、ブラウザだけで触れるデモ環境を公開しています。

- https://demo.frepple.com/

開くと、ログインの画面は出ず、そのまま管理者（Admin）としてホーム画面が表示されました（2026-09-30 に確認）。

:::message alert
公開デモは **誰でも使える共有の環境** です。ほかの人も同じデータを見ています。この本では、データを変えたり計画を実行したりせず、**見るだけ** にとどめます。データの変更や計画の実行が許されているか、どのくらいの頻度で元に戻るのかは、確認していません。
:::

:::message
公開デモは、この本で使う Community Edition ではなく、**Enterprise Edition 相当** の画面です。在庫計画や、対話的なガント（Plan editor）など、Community にない機能が入っています（需要予測の Forecast は、Community にもあります。14 章）。4 章以降で自分の手元に立てる環境とは、画面や機能が少し違います。
:::

## デモの構成を見る

画面の右上に、シナリオを選ぶドロップダウンがあります（最初は「Manufacturing」）。開くと、次のようなシナリオが並びます。

- **Manufacturing**: 家具工場のデータ。リソースの名前（assembly line、grinder、saw、Carl、Antonio）が、この本で使うデモデータと同じです。
- **Distribution**: 名前からすると、拠点間の配送を含むデータです（中身までは見ていません）。
- **Example …**: 機能ごとの小さな例。25 個以上あります。たとえば、代替材料、稼働カレンダー、需要の優先度（demand priorities）、make to order、リソースの代替・スキル・段取り、工程の種類（alternate、routing）、需要予測のいくつかの方法、などです。

「シナリオ」は、データベースを丸ごとコピーした独立したデータセットです（11 章で詳しく扱います）。

## 見てみよう 1: ガントチャート（Plan editor）

次の URL を開きます。

- https://demo.frepple.com/planningboard/

![公開デモの Plan editor（Manufacturing シナリオ）。行がリソース、横軸が時間、四角が製造オーダー](/images/frepple-tutorial-ja/demo-plan-editor.jpg)

- 行はリソース（assembly line、grinder、saw、Carl、Antonio）、横軸は時間、四角いバーは製造オーダーです。
- バーの色は遅れの大きさを表します。既定は「Color By Delay」で、メニューには feasibility、criticality、due date、priority などもあります。
- 灰色の帯は、稼働しない時間（週末など）とみられます。

Enterprise 版では、このバーをドラッグして計画を動かせます。共有環境なので、この本では試しません。Community Edition にはこの画面がなく、10 章で扱う閲覧専用のガントチャートを使います。

## 見てみよう 2: 優先度の例

ドロップダウンの「Example demand priorities」に相当する URL を開きます。

- https://demo.frepple.com/demand-priorities/data/input/demand/

![公開デモの Example demand priorities。優先度 1〜3 の受注が 12 件並び、Delay 列に遅れが色で出る](/images/frepple-tutorial-ja/demo-demand-priorities.jpg)

- 「Sales orders」の一覧に、優先度（Priority）が 1〜3 の受注が 12 件あります。
- 「Delay」の列に、納期に対する遅れが赤やオレンジのセルで出ています。
- 資源が足りないとき、優先度の高い受注ほど先に割り当てられます（9 章で自分の手元で試します）。

この日付の書式は、デモでは「日-月-年」（例: 04-12-2019）です。この本の手元の環境（4 章以降）は「年-月-日」なので、見え方が少し違います。

## ほかにも見てみよう

同じ形の URL で、ほかのシナリオも開けます。たとえば、次のようにシナリオ名が URL の先頭に入ります。

| 見たいもの | URL の例 |
|---|---|
| 優先度の例の受注 | `https://demo.frepple.com/demand-priorities/data/input/demand/` |
| 工程の例（後処理時間） | `https://demo.frepple.com/operation-posttime/data/input/operation/` |
| リソースの例（代替） | `https://demo.frepple.com/resource-alternate/data/input/resource/` |

これらの URL は、frePPLe の公式ドキュメント（`doc/examples/`）に載っているものです。

## 公開デモでできないこと

自分でデータを一から作ったり、条件を変えて何度も計画をやり直したりするには、共有のデモは向きません。次の章から、Docker で自分の手元に frePPLe を立てて、それを行います。

## つまずきポイント

- 画面が開かない・遅い: 共有の環境です。時間をおいて開き直してください。
- 数字や日付が本文と違う: デモのデータは、時期によって変わる可能性があります。
- 画面の表記が英語: デモの言語設定は英語でした。
