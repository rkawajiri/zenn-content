---
title: "デモデータで実規模の計画を見る"
---

この章のゴール: 同梱のデモデータ（家具工場）で、5〜7 章で学んだことを実規模のデータに当てはめる。遅れの理由をたどり、ガントチャートで 1 件の受注の供給の連鎖を見る。

:::message
**この章で学べる計画の考え方**

- 実規模のデータでも、遅れの理由は条件レポートでたどれる
- 遅れの主因は、能力ではなくリードタイムのこともある
- 受注 1 件の供給の連鎖を、時間軸で見る（購入 → 製造 → 流通 → 納品）
:::

## デモデータについて

frePPLe には、いくつかのデモデータセットが同梱されています。この章では `manufacturing_demo` を使います。家具工場のモデルで、次のようなデータが入っています。

- 完成品: chair（椅子）、round table（丸テーブル）、square table（角テーブル）、varnished chair（ニス塗り椅子）
- 部品・原材料: table leg、chair leg、wooden beam、wooden panel、cushion、screws など
- リソース: saw（のこぎり）、grinder（研磨機）、assembly line（組立ライン）、operators（Philippe / Carl / Antonio）
- 拠点: factory、shop 1、shop 2、warehouse
- 供給者: wood supplier、cushion supplier、screw supplier、chair supplier
- 受注: 220 件。うち 204 件は `closed`（過去の実績）で、計画の対象になる `open` は 16 件

:::message alert
このデータセットは **読み込んだ日を基準に、日付がずらされます**。計画基準日は `today` です。16 件の `open` の受注のうち 8 件（`Demand 07` 〜 `Demand 14`）は、基準日の翌日が納期です。ほかの受注は、その 1 か月後、2 か月後、3 か月後あたりに並びます。

本文の日付は「基準日の翌日」のように相対的に書きます。数値は、読む日によって変わる目安です。
:::

## データを読み込む

5 章のモデルが入っている場合は、消してから読み込みます。

1. 管理（Admin）メニューの **実行**（Execute）を開く。
2. 「新しいタスクを起動」（Launch tasks）から「データセットをロード」（Load a dataset）のカードを開き、`manufacturing_demo` を選ぶ。
3. 「Purge all data before loading」（読み込み前に全データを消去。英語のまま）にチェックが入っていることを確認する。
4. 「Execute plan after loading」（英語のまま）は **チェックを外して** `起動`（Launch）を押す。

:::message alert
コマンドラインの `frepplectl loaddata manufacturing_demo` は、既存のデータを **消さずに** 追加します。5 章のモデルが残ったまま実行すると、混ざります。消してから読み込みたいときは、画面を使うか、Web API で `emptybefore=true` を付けます。

```bash
curl -u admin:admin -X POST "http://localhost:9000/execute/api/loaddata/" \
  --data "fixture=manufacturing_demo&emptybefore=true&regenerateplan=false"
```
:::

読み込みが終わったら、販売メニューの販売オーダーで、`open` の受注 16 件を確認しましょう。

## 制約なし計画と制約あり計画を比べる

6 章・7 章と同じ手順で、2 つの計画を順に実行します。

```bash
./plan.sh "plantype=2&constraint=0&env=supply"
./plan.sh "plantype=1&constraint=capa,mfg_lt,po_lt&env=supply"
```

以下は、手元で実行した結果です（`open` の受注 16 件）。

| 見るところ | 制約なし計画 | 制約あり計画 |
|---|---|---|
| オーダー（`proposed`） | 納品 16、DO 18、MO 17、PO 5、WO 4 | — |
| 問題レポート | `material shortage` が 5 件 | 問題なし |
| 条件レポート | 空 | 29 行 |
| 納期に遅れる受注 | なし | 8 件（最大で約 2 か月遅れ） |

WO（作業指示）は、この本では扱いません。

## 遅れの理由を調べる

販売メニューの **条件レポート**（Constraint report。`/constraint/`）を開きます。

![条件レポート（Constraint report）。需要ごとに、遅れの理由（名前）と対象（所有者）が並ぶ](/images/frepple-tutorial-ja/constraint-report.jpg)

デモデータの制約あり計画では、次の理由が出ました。

| 理由（「名前」列） | 行数 | 意味 |
|---|---|---|
| manufacturing lead time | 10 | 製造を始めるべき日がすでに過去だった（例: `Assemble chair`、`Varnish chair`） |
| distribution lead time | 8 | 拠点間の輸送を始めるべき日がすでに過去だった |
| purchasing lead time | 1 | 購入を発注すべき日がすでに過去だった |
| await supply | 5 | すでに確定している補充（confirmed / approved）の到着を待った |
| overload | 5 | リソースの能力が足りなかった（`saw`、`assembly line`） |

先頭の 3 つがリードタイム制約です。基準日の翌日が納期の受注（`Demand 07` 〜 `Demand 14`）は、部品の調達や製造に必要な日数を考えると、間に合わせるには過去に着手していなければなりませんでした。たとえば `wooden beam` の調達リードタイムは 7 日です。

`overload` の行の「所有者」を見ると、`saw` と `assembly line` に集中しています。これがこのデータのボトルネック候補です。

### 制約を 1 つずつ外してみる

7 章の「考えてみよう」を、デモデータでやってみます。手元では次のようになりました。

| パターン | `constraint` | 結果 |
|---|---|---|
| A. 能力だけ | `capa` | 遅れる受注はなし。条件レポートも空 |
| B. リードタイムだけ | `mfg_lt,po_lt` | 遅れる受注が 9 件。条件レポートは 23 行 |
| C. 全部 | `capa,mfg_lt,po_lt` | 遅れる受注が 8 件。条件レポートは 29 行 |

このデータでは、遅れの主な原因は **リードタイム** で、能力だけでは遅れが出ませんでした。デモデータは能力に余裕があり、リソースの負荷率は制約なし計画でも 100% を超えません。能力が効いてくるのは、5 章のモデルのように余裕がないときです。

## ガントチャートで 1 件の受注を追う

受注 1 件について、その受注を満たすためのすべての活動（原材料の購入、拠点間の輸送、製造、最後の納品）を 1 つのガントチャートに並べて見られます。Community でも使える閲覧専用のレポート（Demand Gantt report。画面では「計画」タブ）です。ドラッグで計画を編集できる Plan editor は、Enterprise / Cloud のみです（3 章）。

### 開き方

1. 販売メニューの **販売オーダー**（Sales orders）を開き、受注（たとえば `Demand 07`）の詳細画面を開く。URL は `/detail/input/demand/<受注名>/` です。
2. 画面右上のタブ「編集 / 供給パス / Why short or late? / **計画** / Messages」から **計画** を選ぶ。

URL で直接開くこともできます。受注名の空白は `%20` にします。

```
http://localhost:9000/demandpegging/Demand%2007/
```

「Why short or late?」タブ（未訳で英語のまま）は、条件レポートをその受注だけに絞ったものです。「供給パス」は、その品目がどこから供給されるかを示します。

![Demand Gantt report（Demand 07 の「計画」タブ）。左の表が活動、右が時間軸](/images/frepple-tutorial-ja/demand-gantt.jpg)

- 灰色（暗い色）の縦線: 現在日（計画基準日）
- 赤い縦線: その受注の納期

納期の赤い線よりも右に納品（DLVR）のバーがあれば、その受注は **遅れて** います。

### 表の列の意味

| 列 | 意味 |
|---|---|
| 深さ（depth） | 供給経路上の深さ。0 が納品で、部品表や配送の階層が 1 つ深くなるごとに増える |
| 作業（operation） | 計画された作業 |
| 種類（type） | MO（製造）、DO（流通）、PO（購入）、STCK（在庫）、DLVR（納品） |
| 商品（item） | その作業が作る品目 |
| リソース（resource） | 使われるリソース |
| Required Quantity | この受注に割り当てられた数量 |
| Required Quantity Confirmed | すでに approved / confirmed / completed になっている数量 |
| Required Quantity Proposed | まだ proposed の数量（未着手の提案） |

### 読んでみよう

制約あり計画を実行した状態で、次の 3 件を見比べます。

1. **納期が近く、遅れそうな受注**: `Demand 07`（手元では納品が約 2 か月後に出ました）
2. **納期に余裕のある受注**: `Demand 05`（納期は約 3 か月先）
3. **工程の多い受注**: varnished chair の受注（`Demand 12`）。ニス塗り → 乾燥の工程が入ります

確認すること:
- 納品（DLVR）のバーは、赤い納期線の左か右か。
- いちばん時間がかかっているのは、購買のリードタイムか、製造か。
- 黒い線（現在日）より左にバーはないか。制約あり計画では、過去のオーダーは confirmed のものだけのはずです。

リソースの側から見たいときは、能力メニューの **Resource detail**（未訳で英語のまま）（`/data/input/operationplanresource/`）で、どのオーダーがいつ載っているかを一覧できます。

## デモデータの配送

デモデータには、配送の設定が入っています。在庫メニューの **商品流通**（Item distributions。`/data/input/itemdistribution/`）には、次の 6 行があります。

| 商品 | 地域（配送先） | 起源（出発地） | リードタイム | 最小サイズ | サイズ倍数 |
|---|---|---|---|---|---|
| chair、round table、square table、varnished chair（4 行） | warehouse | factory | 1 日 | 30 | 10 |
| All items | shop 1 | warehouse | 2 日 | 1 | なし |
| All items | shop 2 | warehouse | 1 日 | 1 | なし |

工場 → 倉庫 → 店舗の 2 段の配送網です。`All items` は「すべての品目」を表す親の品目で、1 行で全品目の輸送を表せます。DO は在庫メニューの **Distribution order summary**（未訳で英語のまま）（`/distribution/`）で一覧できます。自分で配送を設定する手順は 10 章にあります。

## つまずきポイント

- 制約あり計画にしても遅れが出ない: 制約のチェックと、「Plan type」が「Constrained plan」になっているかを確認してください。
- Gantt の URL が 404 または空: 受注名の空白を `%20` にしたか、計画を実行したかを確認してください。
- 赤い線と黒い線が出ない: 表示期間の外です。画面上部の期間を、計画基準日を含むようにしてください。
- 受注の納期や数字が本文と違う: デモデータは読み込んだ日を基準にずれます。異常ではありません。

公式ドキュメントの参照先: `user-interface/plan-analysis/demand-gantt-report`、`plan-editor`。
