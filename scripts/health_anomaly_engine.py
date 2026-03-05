#!/usr/bin/env python3
"""User-level heart-health anomaly + nudge engine (MVP, no external deps).

Input CSV (per row):
  user_id,date,rhr,hrv_sdnn,recovery_hr_1m,recovery_hr_2m,vo2max,
  zone_minutes_z1,zone_minutes_z2,zone_minutes_z3,zone_minutes_z4,zone_minutes_z5,
  steps,walk_minutes,workout_minutes,feedback

Output CSV:
  user_id,date,status,confidence,anomaly_score,regression_flag,stress_flag,
  cardio_score,daily_nudge,explanation
"""

from __future__ import annotations

import argparse
import csv
import math
import statistics
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime
from typing import Dict, List, Optional, Sequence, Tuple


NUMERIC_FIELDS = [
    "rhr",
    "hrv_sdnn",
    "recovery_hr_1m",
    "recovery_hr_2m",
    "vo2max",
    "zone_minutes_z1",
    "zone_minutes_z2",
    "zone_minutes_z3",
    "zone_minutes_z4",
    "zone_minutes_z5",
    "steps",
    "walk_minutes",
    "workout_minutes",
]

CORE_METRICS = ["rhr", "hrv_sdnn", "recovery_hr_1m", "vo2max"]

METRIC_WEIGHTS = {
    "rhr": 0.25,  # lower is better
    "hrv_sdnn": 0.25,  # higher is better
    "recovery_hr_1m": 0.20,  # higher drop is better
    "recovery_hr_2m": 0.10,  # higher drop is better
    "vo2max": 0.20,  # higher is better
}

LOWER_IS_BETTER = {"rhr"}


@dataclass
class EngineRow:
    user_id: str
    date: datetime
    raw: Dict[str, Optional[float]]
    feedback: str


def to_float(v: str) -> Optional[float]:
    v = (v or "").strip()
    if not v:
        return None
    try:
        return float(v)
    except ValueError:
        return None


def parse_date(v: str) -> datetime:
    return datetime.strptime(v.strip(), "%Y-%m-%d")


def median(values: Sequence[float]) -> Optional[float]:
    if not values:
        return None
    return statistics.median(values)


def mad(values: Sequence[float], center: Optional[float] = None) -> Optional[float]:
    if not values:
        return None
    c = center if center is not None else statistics.median(values)
    abs_dev = [abs(x - c) for x in values]
    return statistics.median(abs_dev)


def robust_z(value: Optional[float], history: Sequence[Optional[float]]) -> Optional[float]:
    if value is None:
        return None
    clean = [x for x in history if x is not None]
    if len(clean) < 5:
        return None
    c = median(clean)
    m = mad(clean, center=c)
    if c is None or m is None or m == 0:
        return None
    scale = 1.4826 * m
    if scale == 0:
        return None
    return (value - c) / scale


def linear_slope(y: Sequence[float]) -> float:
    # Simple least squares slope with x = 0..n-1
    n = len(y)
    if n < 2:
        return 0.0
    x_mean = (n - 1) / 2.0
    y_mean = sum(y) / n
    num = 0.0
    den = 0.0
    for i, yi in enumerate(y):
        dx = i - x_mean
        num += dx * (yi - y_mean)
        den += dx * dx
    if den == 0:
        return 0.0
    return num / den


def confidence_label(available_core: int, available_total: int) -> str:
    if available_core >= 3 and available_total >= 6:
        return "high"
    if available_core >= 2 and available_total >= 4:
        return "medium"
    return "low"


def metric_orientation_adjust(metric: str, z: float) -> float:
    # Normalize so positive means "worse than baseline" for all metrics.
    if metric in LOWER_IS_BETTER:
        return z
    return -z


def clipped(v: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, v))


def compute_cardio_score(
    values: Dict[str, Optional[float]],
    history_map: Dict[str, List[Optional[float]]],
) -> Optional[float]:
    acc = 0.0
    wsum = 0.0
    for metric, w in METRIC_WEIGHTS.items():
        v = values.get(metric)
        z = robust_z(v, history_map.get(metric, []))
        if z is None:
            continue
        # Convert to normalized performance [0,100], where higher is better.
        worse = metric_orientation_adjust(metric, z)
        score_piece = 50.0 - 10.0 * worse
        acc += clipped(score_piece, 0.0, 100.0) * w
        wsum += w
    if wsum == 0:
        return None
    return round(acc / wsum, 2)


def anomaly_score(values: Dict[str, Optional[float]], history_map: Dict[str, List[Optional[float]]]) -> float:
    parts: List[Tuple[float, float]] = []
    for metric, w in METRIC_WEIGHTS.items():
        z = robust_z(values.get(metric), history_map.get(metric, []))
        if z is None:
            continue
        worse = metric_orientation_adjust(metric, z)
        parts.append((abs(worse), w))
    if not parts:
        return 0.0
    num = sum(a * w for a, w in parts)
    den = sum(w for _, w in parts) or 1.0
    return round(num / den, 3)


def stress_flag(values: Dict[str, Optional[float]], history_map: Dict[str, List[Optional[float]]]) -> bool:
    z_rhr = robust_z(values.get("rhr"), history_map.get("rhr", []))
    z_hrv = robust_z(values.get("hrv_sdnn"), history_map.get("hrv_sdnn", []))
    z_rec = robust_z(values.get("recovery_hr_1m"), history_map.get("recovery_hr_1m", []))
    if z_rhr is None or z_hrv is None:
        return False
    rhr_up = z_rhr >= 1.0
    hrv_down = z_hrv <= -1.0
    rec_down = (z_rec is not None and z_rec <= -0.8)
    return bool(rhr_up and hrv_down and rec_down)


def make_nudge(
    confidence: str,
    anomaly: float,
    is_regressing: bool,
    is_stress: bool,
    feedback: str,
    values: Dict[str, Optional[float]],
) -> str:
    if is_stress:
        return "Take 2 x 10-minute easy walks today, hydrate, and keep intensity low."
    if is_regressing or anomaly >= 1.3:
        return "Do a 10-minute walk after each meal and keep workout intensity moderate today."
    if confidence == "low":
        steps = values.get("steps") or 0
        if steps < 5000:
            return "Start with one 10-minute walk today to build consistency."
        return "Keep a light 20-minute walk today and sync watch data for better insights."
    if feedback == "negative":
        return "Reduce intensity by one level and focus on 20-30 minutes of easy activity."
    return "Keep momentum: add 10-15 minutes of brisk walking today."


def make_explanation(confidence: str, anomaly: float, is_regressing: bool, is_stress: bool) -> str:
    parts = [f"confidence={confidence}", f"anomaly={anomaly:.2f}"]
    if is_regressing:
        parts.append("trend=regressing")
    if is_stress:
        parts.append("stress-pattern-detected")
    if not is_regressing and not is_stress:
        parts.append("trend=stable-or-improving")
    return "; ".join(parts)


def load_rows(path: str) -> Dict[str, List[EngineRow]]:
    grouped: Dict[str, List[EngineRow]] = defaultdict(list)
    with open(path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            user_id = (row.get("user_id") or "").strip()
            if not user_id:
                continue
            try:
                dt = parse_date(row.get("date") or "")
            except Exception:
                continue
            raw = {k: to_float(row.get(k, "")) for k in NUMERIC_FIELDS}
            feedback = (row.get("feedback") or "skipped").strip().lower()
            grouped[user_id].append(EngineRow(user_id=user_id, date=dt, raw=raw, feedback=feedback))
    for user_id in grouped:
        grouped[user_id].sort(key=lambda r: r.date)
    return grouped


def run_engine(rows_by_user: Dict[str, List[EngineRow]], lookback_days: int) -> List[Dict[str, str]]:
    out: List[Dict[str, str]] = []
    lookback_n = max(7, lookback_days)

    for user_id, rows in rows_by_user.items():
        history_map: Dict[str, List[Optional[float]]] = {k: [] for k in NUMERIC_FIELDS}
        score_history: List[float] = []

        for row in rows:
            available_core = sum(1 for m in CORE_METRICS if row.raw.get(m) is not None)
            available_total = sum(1 for m in NUMERIC_FIELDS if row.raw.get(m) is not None)
            confidence = confidence_label(available_core, available_total)

            # Build rolling history window.
            rolling_map: Dict[str, List[Optional[float]]] = {}
            for metric, values in history_map.items():
                rolling_map[metric] = values[-lookback_n:]

            score = compute_cardio_score(row.raw, rolling_map)
            a_score = anomaly_score(row.raw, rolling_map)
            s_flag = stress_flag(row.raw, rolling_map)

            # Regression from recent score trend.
            recent_scores = score_history[-14:]
            if score is not None:
                recent_scores = recent_scores + [score]
            slope14 = linear_slope(recent_scores) if len(recent_scores) >= 5 else 0.0
            regressing = slope14 < -0.6 or a_score >= 1.8

            status = "stable"
            if regressing or s_flag:
                status = "needs_attention"
            elif score is not None and slope14 > 0.4:
                status = "improving"

            nudge = make_nudge(confidence, a_score, regressing, s_flag, row.feedback, row.raw)
            explanation = make_explanation(confidence, a_score, regressing, s_flag)

            out.append(
                {
                    "user_id": user_id,
                    "date": row.date.strftime("%Y-%m-%d"),
                    "status": status,
                    "confidence": confidence,
                    "anomaly_score": f"{a_score:.3f}",
                    "regression_flag": "1" if regressing else "0",
                    "stress_flag": "1" if s_flag else "0",
                    "cardio_score": "" if score is None else f"{score:.2f}",
                    "daily_nudge": nudge,
                    "explanation": explanation,
                }
            )

            # Update history after scoring current day.
            for metric in NUMERIC_FIELDS:
                history_map[metric].append(row.raw.get(metric))
            if score is not None:
                score_history.append(score)

    return out


def write_rows(path: str, rows: List[Dict[str, str]]) -> None:
    cols = [
        "user_id",
        "date",
        "status",
        "confidence",
        "anomaly_score",
        "regression_flag",
        "stress_flag",
        "cardio_score",
        "daily_nudge",
        "explanation",
    ]
    with open(path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=cols)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def main() -> None:
    parser = argparse.ArgumentParser(description="Heart-health anomaly + nudge engine")
    parser.add_argument("--input", required=True, help="Input CSV path")
    parser.add_argument("--output", required=True, help="Output CSV path")
    parser.add_argument("--lookback-days", type=int, default=14)
    args = parser.parse_args()

    by_user = load_rows(args.input)
    rows = run_engine(by_user, lookback_days=args.lookback_days)
    write_rows(args.output, rows)
    print(f"users={len(by_user)} rows_out={len(rows)} output={args.output}")


if __name__ == "__main__":
    main()
