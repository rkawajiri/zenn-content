---
title: "最初の計画を立てる"
---

この章のゴール: デモデータを読み込み、最初の計画を生成して、どんな結果が出るかを眺める。

:::message
**この章で学べる計画の考え方**

- 制約なし計画は MRP に近く、すべての受注を納期どおりに満たす計画になる
- 計画基準日（計画の「今日」）が、計画の起点になる
- 実行できるかどうかは、問題（警告）として別に示される
:::

## デモデータについて

frePPLe には、いくつかのデモデータセットが同梱されています。この章では `manufacturing_demo` を使います。家具工場のモデルで、次のようなデータが入っています。

- 完成品: chair(椅子)、round table(丸テーブル)、square table(角テーブル)、varnished chair(ニス塗り椅子)
- 部品・原材料: table leg、chair leg、wooden beam、wooden panel、cushion、screws など
- リソース(能力の制約になる設備・人): saw(のこぎり)、grinder(研磨機)、assembly line(組立ライン)、operators(Philippe / Carl / Antonio)
- 拠点(location): factory、shop 1、shop 2、warehouse
- サプライヤー: wood supplier、cushion supplier、screw supplier、chair supplier
- 受注(demand): 220 件。うち 204 件は `closed`(過去の実績)で、計画の対象になる `open` は 16 件

:::message alert
このデータセットは **読み込んだ日を基準に、日付がずらされます**。計画基準日(パラメータ `currentdate`)は `today` で、「今日」になります。16 件の `open` の受注のうち 8 件(`Demand 07` 〜 `Demand 14`)は、基準日の翌日が納期です。ほかの受注は、その 1 か月後、2 か月後、3 か月後あたりに並びます。

そのため、このチュートリアルの日付は、読む日によって変わります。本文では「基準日の翌日」のように相対的に書き、日付の例は実行した日の値になります。
:::

## データを読み込む

**画面から**

1. Admin メニューの **Execute** を開きます(`/execute/`)。画面のタイトルは「Task status」です。
2. 下の「Launch tasks」から「Load a dataset(データセットをロード)」のカードを開き、`manufacturing_demo` を選びます。
3. 「Purge all data before loading(読み込み前に全データを消去)」にチェックが入っていることを確認します。
4. 「Execute plan after loading(読み込み後に計画を実行)」は、この章では計画を自分で作るので **チェックを外して** `Launch` を押します。

**コマンドラインから**(同じことです)

```bash
docker exec frepple-community-webserver frepplectl loaddata manufacturing_demo
```

:::message
Execute 画面で押したタスクは、非同期に実行されます。画面上部のステータス欄が 5 秒ごとに更新され、終わると `Done` になります。
:::

:::message alert
03 章の構成で最初に起動したときは、Docker イメージが起動時にデモデータを用意します。Execute 画面の Task status には、起動時の計画の実行や、scenario1(distribution demo)と scenario2(manufacturing demo)へのコピーが残っています。`loaddata` で読み込み直しても問題ありません。
:::

読み込みが終わったら、Sales メニューの Items / Locations / Customers や、Sales orders(受注)を開いてデータが入っていることを確認しましょう。

## 計画を生成する

同じ Execute 画面の「Create a plan(計画を作成)」カードを使います。まずは違いを体感するために、**制約なし** で実行します。

1. 「Planning steps」で「Generate supply plan(日本語表示では「サプライチェーンを生成」)」にチェックが入っていることを確認します。これがオフだと、購買オーダー(PO)などの供給計画が生成されません。(「Generate forecast」は需要予測の機能で、Enterprise Edition 限定です。オフのままにします。)
2. 「Plan type」で「Unconstrained plan」を選びます。
3. 「Constraints(制約)」の3つ(Capacity / Manufacturing lead time / Purchasing lead time)は、この章では **すべてオフ** にします。
4. `Launch`(日本語表示では「起動」)を押します。

![Execute 画面の「Create a plan」カード](/images/frepple-tutorial-ja/execute-create-plan.jpg)

計画の生成は、デモデータなら数秒で終わります。画面上部のステータス欄が `Done` になれば完了です。

### コマンドで同じことをする（Web API）

画面の代わりに、公式ドキュメントにある Web API（`POST /execute/api/runplan/`）でも、同じ計画を実行できます。

```bash
curl -u admin:admin -X POST "http://localhost:9000/execute/api/runplan/?plantype=2&constraint=0&env=supply"
# {"taskid": 6, "message": "Successfully launched task"}
```

このAPIは **非同期** で、実行を始めるとすぐに `taskid` を返します。終わったかどうかは、次で確かめます。

```bash
curl -u admin:admin "http://localhost:9000/execute/api/status/?id=6"
```

`"status": "Done"` になれば完了です。待つ処理までまとめたスクリプトを、この本のリポジトリの `examples/frepple-api/plan.sh` に置いています。以降の章では、これを使います。

```bash
./plan.sh "plantype=2&constraint=0&env=supply"
# task 6: Done (6s)
```

クエリの意味は次のとおりです。

| パラメータ | 意味 |
|---|---|
| `plantype=2` | 制約なし計画(1 なら制約あり計画) |
| `constraint=0` | 制約をすべてオフ。制約をオンにするときは `capa,mfg_lt,po_lt` のように書く |
| `env=supply` | 「Generate supply plan」に対応 |

詳細は 公式ドキュメント `command-reference` の「Generate a plan」と、`integration-guide/remote-commands` を参照してください。

:::message
`docker exec … frepplectl runplan` でも計画は実行できますが、9.17.0 では、計画が終わってもコマンドが戻ってきませんでした（計画の最後に Web サービスを起動して待ち続けるためです）。この本では使いません。
:::

## 制約なし計画とは

制約なし計画は、ERP の MRP(所要量計算)に近い計画です。

- **すべての受注が納期どおりに満たされます。**
- そのために、機械の能力を超えて仕事を詰め込んだり、過去の日付に製造・購買を計画したりします。
- 「部品が足りない」「能力が足りない」といった問題は、**問題レポート** で警告として示されます。

つまり「理想的にはこう作りたい」という計画で、実行可能かどうかは別の話です。現実に守れる計画(制約あり計画)は 06 章で作ります。

## 生成された計画の中身

計画が終わると、次のような結果が出力されます。

| 出力 | 内容 |
|---|---|
| 製造オーダー(MO) | 何を、いつからいつまで、いくつ作るか |
| 購買オーダー(PO) | 何を、どのサプライヤーから、いつ、いくつ買うか |
| 配送オーダー(DO) | 拠点間で何をいつ運ぶか(このデータセットでは主に店舗への配送) |
| 納品(DLVR) | 受注ごとの出荷 |

参考までに、デモデータで制約なし計画を実行したときの件数の目安です(`proposed` のオーダー)。

| 種類 | 件数 |
|---|---|
| 納品(DLVR) | 16 |
| 配送オーダー(DO) | 18 |
| 製造オーダー(MO) | 17 |
| 購買オーダー(PO) | 5 |
| 作業指示(WO) | 4 |

問題レポートには、`material shortage`(部品の不足)が 5 件出ます。件数は日付や frePPLe のバージョンで変わるので、目安として読んでください。

それぞれのオーダーは status を持ちます。計画エンジンが出した提案は `proposed` です。プランナーが承認したものは `approved`、実行が確定したものは `confirmed` になります。status の意味は 08 章で詳しく説明します。

まず、Manufacturing メニューの **Manufacturing orders**(製造オーダー)と、Purchasing メニューの **Purchase orders**(購買オーダー)を開いて、生成されたオーダーの一覧を眺めてみましょう。

## つまずきポイント

- `plan.sh` が `Done` にならない: Execute 画面の Task status で、そのタスクの状態とログ（View）を確認してください。
- 購買オーダーが 1 件も出ない: 「Generate supply plan」のチェックが外れていないか確認してください。
- 「Load a dataset」を実行しても画面が変わらない: 非同期タスクなので、ステータス欄が `Done` になるまで待ってください。
- 受注の納期が本文と違う: デモデータは読み込んだ日を基準にずらされます。異常ではありません。
