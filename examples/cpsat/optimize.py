"""
frePPLe の製造オーダー(MO)を OR-Tools CP-SAT で再スケジュールするサンプル。

流れ:
  1. REST API から status=proposed の MO を取得する(各 MO の resources も入っている)
  2. 「リソース1台につき同時に1件だけ」(NoOverlap)という制約のもとで、
     納期遅れ(元の enddate を超えた分)の合計が最小になる順序・開始時刻を CP-SAT で求める
  3. --apply を付けた場合だけ、新しい startdate / enddate を REST API の PATCH で書き戻す

単純化していること(チュートリアル用):
  - 所要時間は (enddate - startdate) の経過時間で固定。稼働カレンダーは考慮しない。
  - MO 同士の前後関係(部品の MO → 組立 MO)は考慮しない。開始は元の startdate より前には動かさず、
    遅らせる方向にだけ動かす。さらに計画基準日(currentdate)より前にも開始しない
    (制約なし計画には基準日より前に始まる MO があるため)。
  - 1つの MO が複数リソースを使う場合、その全てを同時に占有する。
  - 段取り(setup)、スキル、代替リソースは扱わない。

使い方:
  python optimize.py --url http://localhost:9000 --user admin --password admin          # 計算のみ
  python optimize.py --url http://localhost:9000 --user admin --password admin --apply  # 書き戻す
"""

import argparse
from collections import defaultdict
from datetime import datetime, timedelta

MINUTE = 60


def parse_dt(value):
    """API の日時文字列を naive な datetime にする(タイムゾーンは無視して壁時計のまま扱う)。"""
    return datetime.fromisoformat(value.replace("Z", "+00:00")).replace(tzinfo=None)


def solve(mos, fixed=(), not_before=None, time_limit=20.0, workers=4):
    """
    mos   : dict のリスト。キーは reference, start(datetime), end(datetime), resources(名前のリスト)
    fixed : (resource, start, end) のリスト。confirmed 等で動かせない占有区間
    not_before : この日時より前には開始させない(通常は計画基準日 currentdate)
    戻り値: (status名, {reference: (新start, 新end)}, 遅れ合計[分])
    """
    from ortools.sat.python import cp_model

    if not mos:
        return "EMPTY", {}, 0

    if not_before:  # 分未満は切り上げる(基準日より前に開始させないため)
        not_before = not_before.replace(second=0, microsecond=0) + timedelta(minutes=1) if (
            not_before.second or not_before.microsecond
        ) else not_before
    origin = min(m["start"] for m in mos)
    if not_before:
        origin = min(origin, not_before)
    origin = origin.replace(second=0, microsecond=0)

    def to_min(dt):
        return int((dt - origin).total_seconds() // MINUTE)

    horizon = sum(max(1, to_min(m["end"]) - to_min(m["start"])) for m in mos)
    horizon += max(max(to_min(m["end"]) for m in mos), to_min(not_before) if not_before else 0) + 1

    model = cp_model.CpModel()
    per_resource = defaultdict(list)
    tardiness = []
    variables = {}

    for m in mos:
        due = to_min(m["end"])
        duration = max(1, due - to_min(m["start"]))
        release = to_min(max(m["start"], not_before)) if not_before else to_min(m["start"])
        start = model.NewIntVar(release, horizon, "s_" + m["reference"])
        end = model.NewIntVar(release + duration, horizon + duration, "e_" + m["reference"])
        interval = model.NewIntervalVar(start, duration, end, "i_" + m["reference"])
        variables[m["reference"]] = (start, end)
        for res in m["resources"]:
            per_resource[res].append(interval)
        late = model.NewIntVar(0, horizon, "late_" + m["reference"])
        model.Add(late >= end - due)
        tardiness.append(late)

    for res, start, end in fixed:
        s, e = to_min(start), to_min(end)
        if e > s:
            per_resource[res].append(model.NewFixedSizeIntervalVar(s, e - s, "fixed"))

    for intervals in per_resource.values():
        model.AddNoOverlap(intervals)

    model.Minimize(sum(tardiness))

    solver = cp_model.CpSolver()
    solver.parameters.max_time_in_seconds = time_limit
    solver.parameters.num_search_workers = workers
    status = solver.Solve(model)
    name = solver.StatusName(status)
    if status not in (cp_model.OPTIMAL, cp_model.FEASIBLE):
        return name, {}, 0

    result = {}
    for ref, (start, end) in variables.items():
        result[ref] = (
            origin + timedelta(minutes=solver.Value(start)),
            origin + timedelta(minutes=solver.Value(end)),
        )
    return name, result, int(solver.ObjectiveValue())


def fetch_currentdate(session, url):
    """
    計画基準日を API から取得する。取得できなければ None。
    パラメータ currentdate が 'today' や 'now' のときは、直近の計画実行で記録された
    last_currentdate を使う。
    """
    try:
        response = session.get(f"{url}/api/common/parameter/", params={"format": "json"})
        response.raise_for_status()
        data = response.json()
        rows = data.get("results", []) if isinstance(data, dict) else data
        values = {row["name"]: (row.get("value") or "").strip() for row in rows}
        for name in ("currentdate", "last_currentdate"):
            try:
                return parse_dt(values[name].replace(" ", "T"))
            except (KeyError, ValueError):
                continue
    except Exception as exc:  # noqa: BLE001 - 取得できなくても続行する
        print(f"計画基準日を取得できませんでした({exc})。--not-before で指定してください。")
    return None


def fetch_orders(session, url, status):
    """指定した status の MO を全件取得する。フィルターが効かない場合に備え、status は手元でも確認する。"""
    next_url = f"{url}/api/input/manufacturingorder/"
    params = {"format": "json", "status": status}
    rows = []
    while next_url:
        response = session.get(next_url, params=params)
        response.raise_for_status()
        data = response.json()
        if isinstance(data, dict):  # ページングされている場合
            rows.extend(data.get("results", []))
            next_url, params = data.get("next"), None
        else:
            rows.extend(data)
            next_url = None
    return [r for r in rows if r.get("status") == status and r.get("startdate") and r.get("enddate")]


def fetch_mos(session, url):
    """動かしてよい MO(proposed)。"""
    return [
        {
            "reference": str(row["reference"]),
            "start": parse_dt(row["startdate"]),
            "end": parse_dt(row["enddate"]),
            "resources": [r["resource"] for r in row.get("resources", [])],
        }
        for row in fetch_orders(session, url, "proposed")
    ]


def fetch_fixed(session, url):
    """confirmed / approved / completed の MO は動かさず、リソースの占有区間として扱う。"""
    fixed = []
    for status in ("confirmed", "approved", "completed"):
        for row in fetch_orders(session, url, status):
            for r in row.get("resources", []):
                fixed.append(
                    (r["resource"], parse_dt(row["startdate"]), parse_dt(row["enddate"]))
                )
    return fixed


def apply_result(session, url, mos, result, status="proposed"):
    """変更のあった MO だけを、製造オーダーの REST API に PATCH する。"""
    changed = 0
    for m in mos:
        new_start, new_end = result[m["reference"]]
        if (new_start, new_end) == (m["start"], m["end"]) and status == "proposed":
            continue
        response = session.patch(
            f"{url}/api/input/manufacturingorder/{m['reference']}/",
            json={
                "startdate": new_start.isoformat(),
                "enddate": new_end.isoformat(),
                "status": status,
            },
            params={"format": "json"},
        )
        response.raise_for_status()
        changed += 1
    return changed


def main():
    import requests

    parser = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    parser.add_argument("--url", default="http://localhost:9000")
    parser.add_argument("--user", default="admin")
    parser.add_argument("--password", default="admin")
    parser.add_argument(
        "--not-before",
        help="この日時より前には開始させない(例: '2021-01-01 00:00:00')。省略時は currentdate",
    )
    parser.add_argument("--time-limit", type=float, default=20.0)
    parser.add_argument("--apply", action="store_true", help="結果を frePPLe に書き戻す")
    parser.add_argument(
        "--status",
        default="proposed",
        choices=["proposed", "approved", "confirmed"],
        help="書き戻す MO の status。runplan で上書きされたくない場合は approved",
    )
    args = parser.parse_args()

    session = requests.Session()
    session.auth = (args.user, args.password)

    mos = fetch_mos(session, args.url)
    fixed = fetch_fixed(session, args.url)
    print(f"proposed MO: {len(mos)} 件, 固定の占有区間: {len(fixed)} 件")

    not_before = (
        parse_dt(args.not_before) if args.not_before else fetch_currentdate(session, args.url)
    )
    print(f"開始の下限(計画基準日): {not_before}")
    status, result, total_late = solve(
        mos, fixed, not_before=not_before, time_limit=args.time_limit
    )
    print(f"CP-SAT: {status}, 遅れ合計 {total_late} 分(元の enddate を納期とみなした値)")
    if not result:
        return

    moved = [
        (m["reference"], m["start"], result[m["reference"]][0])
        for m in mos
        if result[m["reference"]][0] != m["start"]
    ]
    print(f"開始時刻が変わる MO: {len(moved)} 件")
    for ref, old, new in moved[:10]:
        print(f"  {ref}: {old} -> {new}")

    if args.apply:
        count = apply_result(session, args.url, mos, result, status=args.status)
        print(f"{count} 件を書き戻しました(status={args.status})")
    else:
        print("--apply を付けると書き戻します")


if __name__ == "__main__":
    main()
