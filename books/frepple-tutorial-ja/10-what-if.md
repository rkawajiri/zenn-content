---
title: "What-if シナリオで比べる"
---

この章のゴール: データベースを複製して安全に条件を変え、元の計画と結果を比較する。

:::message
**この章で学べる計画の考え方**

- What-if は、本番に影響を与えずに条件を変えて比べる方法
- 比較は、「遅れた受注の数」など同じ指標を並べて行う
:::

## What-if とは

What-if は英語の "What if ...?"(もし〜だったら?)です。「もし受注が増えたら?」「もし機械が 1 台増えたら?」「もしあの機械が故障したら?」を、**本番の計画に影響を与えずに** 試すための仕組みです。

frePPLe では、これを **シナリオ(scenario)** という、データベースの丸ごとのコピーで実現します (公式ドキュメント `user-interface/what-if-scenarios`)。

- シナリオの中で、データを変えたり、計画を実行しても、元のデータには影響しません。
- 気に入らなければ、シナリオを破棄(release)するだけで元どおりです。
- 気に入れば、シナリオの内容を元へ戻す(promote)こともできます。

シナリオの枠(slot)の数は管理者が決めます(公式ドキュメント `installation-guide/multi-model`)。03 章の構成で起動した Docker イメージには、`scenario1` と `scenario2` の **2 つ** の枠がありました。どちらも起動時にデモデータがコピーされていて、最初から状態が `In use`(使用中)になっています。

| シナリオ | 起動直後の中身 | データベース名 |
|---|---|---|
| Default(Production) | 本番のデータ | `frepple0` |
| Scenario1 | distribution demo | `frepple1` |
| Scenario2 | manufacturing demo | `frepple2` |

:::message alert
使用中の枠には、そのままコピーできません（`Destination scenario is not free` と表示されます）。先にその枠を **Release**(解放)するか、コピーのコマンドに `--force` を付けて上書きします。起動時のデモデータが不要なら、Release して構いません。
:::

## シナリオを作る

1. Admin メニューの **Execute** を開く。
2. 下の「Scenario management」のカードを開く。Default / Scenario1 / Scenario2 の一覧が出て、各行に **Manage** のメニュー、Status(状態)、Label(ラベル)があります。
3. コピー先にしたい行が `In use` なら、Manage のメニューから「Release: You will lose ALL data in this scenario!」を選ぶ。使用中の枠のメニューには、この項目だけが出ました。
4. `Free` になった行の Manage のメニューには「Copy from default」が出ます。これを選ぶとコピーが始まります。(この手順書では、メニュー項目の中身は画面の DOM で確認しました。項目を実際にクリックしての実行は、同じ操作を Web API `POST /execute/api/scenario_copy/?copy=1&source=default&destination=scenario1` で行って確認しています。)
5. コピーは、デモデータの規模なら数秒で終わります(手元では約 4 秒)。データ量が増えると長くなります。
6. 終わると、画面右上のドロップダウン(「Production」と表示されているもの)に新しいシナリオが現れます。表示名は、その枠の Label です（手元では「distribution demo」「manufacturing demo」）。それを選ぶ。

これ以降の操作は、すべて選んだシナリオの中で行われます。右上の表示で、今どのシナリオを見ているかをいつでも確認できます。

### Web API でする場合

公式ドキュメントの Web API（`POST /execute/api/scenario_copy/`）で、同じことができます。

```bash
# 1) 使用中の枠 scenario1 を解放する（枠の中のデータは消えます）
curl -u admin:admin -X POST "http://localhost:9000/scenario1/execute/api/scenario_copy/?release=1"

# 2) メインのデータベース(default)を scenario1 にコピーする
curl -u admin:admin -X POST "http://localhost:9000/execute/api/scenario_copy/?copy=1&source=default&destination=scenario1"
```

どちらも `taskid` を返して非同期に動きます。手元では、コピーは約 3 秒で終わりました。

## 実験してみよう

07 章のモデル(または 06 章のデモデータ)で、次の実験をしてみましょう。

**実験 A: 作業台が 2 台になったら?**

1. 元のデータベース(default)で、制約あり計画を実行しておく。
2. `scenario1` にコピーして、ドロップダウンで `scenario1` に切り替える。
3. `workbench` の `maximum` を 2 にする。
4. `scenario1` で制約あり計画を実行する。

```bash
./plan.sh "plantype=1&constraint=capa,mfg_lt,po_lt&env=supply" scenario1
```

`plan.sh` の 2 つ目の引数が、シナリオの名前です。

**実験 B: 機械が 1 週間止まったら?**

08 章の「機械が止まった」の手順で、シナリオの中で `maximum` を 0 にして再計画します。

## 結果を比べる

シナリオ同士を比べる方法は、次のとおりです。

1. Demand report など、比べたいレポートを開く。
2. ツールバーの **↓ のアイコン**(エクスポート)を押す。「Export CSV or Excel file」というダイアログが開きます。
3. 「Export format」から形式を選ぶ（Spreadsheet table / Spreadsheet list / CSV table / CSV list）。
4. 「Scenarios to export」で、比べたいシナリオを **両方** チェックする。今のシナリオ（Production）は最初からチェックされていて、外せません。ほかは Label の名前で並びます。
5. `Export` を押す。出力された Excel で、ピボットテーブルを作って比べる。

出力された Excel（`Demand report.xlsx`）には、次のような形で入りました（Spreadsheet table を選んだ場合）。

- シート名はレポート名（`Demand report`）で、1 枚だけです。
- 1 行目が見出しで、左から `Scenario`、`Item`、`Count Of Late Demands`、`Quantity Of Late Demands`、`Value Of Late Demand`、`Data field`、そのあと日付の列が並びます。
- **1 列目の `Scenario` に、シナリオの Label（`Production`、`distribution demo` など）が入ります。** 選んだシナリオが、同じシートに縦に連なります（手元では 2 シナリオで 28 行ずつ、合計 56 行）。
- `Data field` の行は `Net forecast`、`Sales orders`、`Total demand`、`Supply` などです。

そのため、`Scenario` 列をピボットテーブルの列（または行）に置けば、シナリオごとの数値を並べて比べられます。たとえば `Count Of Late Demands`（遅れた受注の件数）や `Quantity Of Late Demands`（遅れた数量）が、そのまま比較の指標になります。

比べるときの見どころ:

- demand report の、遅れた受注の数と遅れ日数
- resource report の、負荷率
- 購買オーダーの数量(部品の必要量がどう変わったか)

## シナリオを片付ける

比較が終わったら、Execute 画面の scenario management で、そのシナリオの **Release** を実行します。枠が `Free` に戻り、シナリオはドロップダウンから消えます。

:::message alert
Release すると、シナリオの中のデータは破棄されます。残したい結果は、先に Excel にエクスポートしておいてください。
:::

**Promote** は、シナリオの内容を元のデータベースに反映する操作です。元のデータを上書きするので、実行前に内容をよく確認してください。

## つまずきポイント

- コピーできない（`Destination scenario is not free`）: 使用中の枠です。先に Release するか `--force` を付けてください。
- 枠が足りない: 一覧の下に `+` / `-` のボタンがあります（枠の追加・削除用とみられますが、この手順書では試していません）。データベースの用意については 公式ドキュメント `installation-guide/multi-model` を参照してください。
- Copy に時間がかかる: データ量に比例します。デモデータなら短時間のはずです。
- シナリオでの変更が元に反映されない: 仕様どおりです。反映したいときだけ Promote を使います。
- どのシナリオにいるのか分からなくなった: 右上のドロップダウンを確認してください。
