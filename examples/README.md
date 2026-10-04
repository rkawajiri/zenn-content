# examples

「frePPLe ハンズオン（日本語）」で使うスクリプトです。動作確認は frePPLe Community Edition 9.17.0 で行っています。

| 場所 | 内容 | 使う章 |
|---|---|---|
| `frepple-api/plan.sh` | Web API で計画を実行し、終わるまで待つ | 5 章〜 |
| `frepple-api/setup-model.sh` | 8 章の最小モデルを REST API でまとめて登録する | 8 章 |
| `frepple-api/setup-distribution.sh` | 8 章のモデルに、倉庫と工場から倉庫への輸送、倉庫向けの受注を足す。先に `setup-model.sh` を実行しておく | 12 章 |
| `cpsat/optimize.py` | OR-Tools CP-SAT でスケジュールを最適化し、REST API で書き戻す | 15 章 |
