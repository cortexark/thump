#!/usr/bin/env python3
"""Analyze subreddit crawl outputs and generate trend tables + markdown report."""

from __future__ import annotations

import argparse
import csv
import json
import math
import os
import re
import statistics
import subprocess
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Dict, Iterable, List, Optional, Tuple

TOPICS = [
    "HR accuracy",
    "Zones confusion",
    "VO2 trend",
    "HRV interpretation",
    "Recovery HR",
    "RHR change",
    "Stress/fatigue",
    "Breathing/sleep",
    "Training plan",
    "Device/setup issue",
    "Medical concern",
]

INTENTS = [
    "Question",
    "Progress update",
    "Troubleshooting",
    "Comparison",
    "Advice",
    "Warning",
]

SENTIMENTS = ["Positive", "Neutral", "Concerned", "Frustrated", "Reassured"]

RISKS = [
    "General fitness",
    "Potential overreaching",
    "Potential arrhythmia concern",
    "Potential respiratory concern",
    "Needs clinical follow-up language",
]

POSITIVE_WORDS = {
    "great",
    "good",
    "improved",
    "improvement",
    "better",
    "best",
    "awesome",
    "happy",
    "strong",
    "success",
    "progress",
    "win",
}
NEGATIVE_WORDS = {
    "bad",
    "worse",
    "worst",
    "issue",
    "problem",
    "broken",
    "frustrated",
    "anxious",
    "worried",
    "scared",
    "pain",
    "failed",
    "failure",
}

TOPIC_PATTERNS = {
    "HR accuracy": [r"\bheart rate\b", r"\bhr\b", r"\baccuracy\b", r"\bppg\b", r"\bsensor\b"],
    "Zones confusion": [r"\bzone\b", r"\bzones\b", r"\bzone\s*[1-5]\b"],
    "VO2 trend": [r"\bvo2\b", r"cardio fitness", r"ml/kg/min", r"aerobic"],
    "HRV interpretation": [r"\bhrv\b", r"sdnn", r"rmssd", r"variability"],
    "Recovery HR": [r"recovery\s*hr", r"heart\s*rate\s*recovery", r"hr\s*drop", r"1\s*min"],
    "RHR change": [r"resting heart rate", r"\brhr\b", r"baseline hr"],
    "Stress/fatigue": [r"stress", r"fatigue", r"overtrain", r"burnout", r"readiness"],
    "Breathing/sleep": [r"sleep", r"breath", r"respirat", r"apnea", r"snore"],
    "Training plan": [r"workout", r"training", r"run", r"cycle", r"plan", r"interval"],
    "Device/setup issue": [r"not working", r"won't", r"cant", r"can't", r"pair", r"sync", r"setup", r"battery"],
    "Medical concern": [r"afib", r"arrhythmia", r"tachy", r"brady", r"chest pain", r"doctor", r"hospital", r"diagnos"],
}

INTENT_PATTERNS = {
    "Question": [r"\?$", r"^how\b", r"^why\b", r"^what\b", r"anyone", r"does anyone"],
    "Troubleshooting": [r"not working", r"issue", r"problem", r"error", r"fix", r"broken"],
    "Progress update": [r"update", r"progress", r"today", r"week", r"month", r"improved", r"down to", r"up to"],
    "Comparison": [r"\bvs\b", r"compared", r"comparison", r"better than"],
    "Advice": [r"advice", r"recommend", r"should i", r"tips"],
    "Warning": [r"warning", r"beware", r"danger", r"alert", r"urgent"],
}

RISK_PATTERNS = {
    "Potential arrhythmia concern": [r"afib", r"arrhythmia", r"palpitation", r"irregular"],
    "Potential respiratory concern": [r"apnea", r"shortness of breath", r"breathing", r"oxygen", r"spo2"],
    "Potential overreaching": [r"overtrain", r"fatigue", r"exhausted", r"recovery", r"very sore"],
    "Needs clinical follow-up language": [r"doctor", r"er", r"emergency", r"hospital", r"medical advice"],
}


@dataclass
class LabelResult:
    topic_labels: List[str]
    intent_label: str
    sentiment: str
    risk_label: str
    confidence: float


def load_jsonl(path: str) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            rows.append(json.loads(line))
    return rows


def write_csv(path: str, rows: List[Dict[str, Any]]) -> None:
    if not rows:
        with open(path, "w", encoding="utf-8", newline="") as f:
            f.write("")
        return
    fieldnames = list(rows[0].keys())
    with open(path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def normalize_text(*parts: Optional[str]) -> str:
    joined = " ".join((p or "") for p in parts)
    txt = joined.lower()
    txt = re.sub(r"\s+", " ", txt).strip()
    return txt


def count_matches(text: str, patterns: Iterable[str]) -> int:
    c = 0
    for pat in patterns:
        if re.search(pat, text, flags=re.IGNORECASE):
            c += 1
    return c


def label_text(text: str) -> LabelResult:
    topic_scores: Dict[str, int] = {}
    for topic, pats in TOPIC_PATTERNS.items():
        s = count_matches(text, pats)
        if s > 0:
            topic_scores[topic] = s

    if topic_scores:
        max_score = max(topic_scores.values())
        topics = sorted([t for t, s in topic_scores.items() if s == max_score])
        # Keep also secondary topics with near-max support.
        secondary = sorted([t for t, s in topic_scores.items() if s == max_score - 1 and s > 0])
        topic_labels = list(dict.fromkeys(topics + secondary))[:3]
    else:
        topic_labels = ["Training plan"]

    intent_scores: Dict[str, int] = {intent: count_matches(text, pats) for intent, pats in INTENT_PATTERNS.items()}
    intent_label = max(intent_scores.items(), key=lambda kv: kv[1])[0]
    if intent_scores[intent_label] == 0:
        intent_label = "Question" if "?" in text else "Advice"

    words = re.findall(r"[a-z']+", text)
    pos = sum(1 for w in words if w in POSITIVE_WORDS)
    neg = sum(1 for w in words if w in NEGATIVE_WORDS)

    if neg >= pos + 2:
        sentiment = "Frustrated"
    elif neg > pos:
        sentiment = "Concerned"
    elif pos >= neg + 2:
        sentiment = "Positive"
    elif "doctor" in text or "hospital" in text or "urgent" in text:
        sentiment = "Concerned"
    else:
        sentiment = "Neutral"

    risk_scores: Dict[str, int] = {risk: count_matches(text, pats) for risk, pats in RISK_PATTERNS.items()}
    risk_label = max(risk_scores.items(), key=lambda kv: kv[1])[0]
    if risk_scores[risk_label] == 0:
        risk_label = "General fitness"

    match_count = sum(topic_scores.values()) + intent_scores.get(intent_label, 0) + risk_scores.get(risk_label, 0)
    confidence = min(0.95, 0.45 + 0.05 * max(1, match_count))

    return LabelResult(
        topic_labels=topic_labels,
        intent_label=intent_label,
        sentiment=sentiment,
        risk_label=risk_label,
        confidence=round(confidence, 3),
    )


def month_key(epoch: int) -> str:
    if not epoch:
        return "unknown"
    dt = datetime.fromtimestamp(epoch, tz=timezone.utc)
    return f"{dt.year:04d}-{dt.month:02d}"


def quarter_key(epoch: int) -> str:
    if not epoch:
        return "unknown"
    dt = datetime.fromtimestamp(epoch, tz=timezone.utc)
    q = (dt.month - 1) // 3 + 1
    return f"{dt.year:04d}-Q{q}"


def detect_spikes(series: List[Tuple[str, int]]) -> List[Dict[str, Any]]:
    values = [v for _, v in series]
    if len(values) < 6:
        return []
    mean = statistics.mean(values)
    stdev = statistics.pstdev(values)
    if stdev == 0:
        return []
    out = []
    for period, value in series:
        z = (value - mean) / stdev
        if z >= 2.0:
            out.append({"period": period, "value": value, "z": round(z, 3)})
    return out


def find_best_metric_tags(text: str) -> List[str]:
    tags = []
    if re.search(r"\b\d{2,3}\s*bpm\b", text):
        tags.append("heart_rate_bpm")
    if re.search(r"\bvo2\b|ml/kg/min", text):
        tags.append("vo2")
    if re.search(r"\bhrv\b|sdnn|rmssd", text):
        tags.append("hrv")
    if re.search(r"resting heart rate|\brhr\b", text):
        tags.append("rhr")
    if re.search(r"zone\s*[1-5]|heart rate zone", text):
        tags.append("zones")
    if re.search(r"recovery", text):
        tags.append("recovery")
    if re.search(r"sleep|breath|respirat|apnea", text):
        tags.append("breathing_sleep")
    return sorted(set(tags))


def has_tesseract() -> bool:
    return subprocess.call(["/bin/zsh", "-lc", "command -v tesseract >/dev/null 2>&1"]) == 0


def run_ocr(image_path: str) -> Tuple[str, float]:
    """Best effort OCR. Returns text and a heuristic confidence."""
    try:
        proc = subprocess.run(
            ["tesseract", image_path, "stdout", "-l", "eng", "--psm", "6"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            text=True,
        )
    except Exception:
        return "", 0.0

    text = (proc.stdout or "").strip()
    if not text:
        return "", 0.0

    alnum = sum(ch.isalnum() for ch in text)
    conf = min(0.95, 0.3 + 0.01 * alnum)
    return text[:8000], round(conf, 3)


def download_image(url: str, output_path: str) -> bool:
    import urllib.request

    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req, timeout=25) as resp:
            data = resp.read()
        if not data:
            return False
        with open(output_path, "wb") as f:
            f.write(data)
        return True
    except Exception:
        return False


def analyze(raw_dir: str, out_dir: str, docs_dir: str) -> Dict[str, Any]:
    submissions = load_jsonl(os.path.join(raw_dir, "submissions.jsonl"))
    comments = load_jsonl(os.path.join(raw_dir, "comments.jsonl"))
    screenshots = load_jsonl(os.path.join(raw_dir, "screenshots.jsonl"))

    os.makedirs(out_dir, exist_ok=True)
    os.makedirs(docs_dir, exist_ok=True)

    posts_by_id = {p["post_id"]: p for p in submissions}

    # Label posts
    post_labels: List[Dict[str, Any]] = []
    for post in submissions:
        text = normalize_text(post.get("title"), post.get("body"))
        lbl = label_text(text)
        post_labels.append(
            {
                "entity_id": post["post_id"],
                "entity_type": "post",
                "topic_labels": "|".join(lbl.topic_labels),
                "intent_label": lbl.intent_label,
                "sentiment": lbl.sentiment,
                "risk_label": lbl.risk_label,
                "confidence": lbl.confidence,
            }
        )

    # Label comments
    comment_labels: List[Dict[str, Any]] = []
    for comment in comments:
        text = normalize_text(comment.get("body"))
        lbl = label_text(text)
        comment_labels.append(
            {
                "entity_id": comment["comment_id"],
                "entity_type": "comment",
                "post_id": comment["post_id"],
                "topic_labels": "|".join(lbl.topic_labels),
                "intent_label": lbl.intent_label,
                "sentiment": lbl.sentiment,
                "risk_label": lbl.risk_label,
                "confidence": lbl.confidence,
            }
        )

    # Screenshot OCR + labels
    image_dir = os.path.join(raw_dir, "images")
    os.makedirs(image_dir, exist_ok=True)
    tesseract_ok = has_tesseract()

    screenshot_inventory: List[Dict[str, Any]] = []
    screenshot_labels: List[Dict[str, Any]] = []

    for shot in screenshots:
        asset_id = shot["asset_id"]
        post_id = shot["post_id"]
        url = shot["asset_url"]

        local_path = os.path.join(image_dir, f"{asset_id}.img")
        downloaded = download_image(url, local_path)

        ocr_text = ""
        ocr_conf = 0.0
        if downloaded and tesseract_ok:
            ocr_text, ocr_conf = run_ocr(local_path)

        post = posts_by_id.get(post_id, {})
        combined_text = normalize_text(post.get("title"), post.get("body"), ocr_text)
        tags = find_best_metric_tags(combined_text)
        lbl = label_text(combined_text)

        screenshot_inventory.append(
            {
                "asset_id": asset_id,
                "post_id": post_id,
                "asset_url": url,
                "asset_type": shot.get("asset_type", "unknown"),
                "downloaded": int(downloaded),
                "ocr_confidence": ocr_conf,
                "detected_metrics": "|".join(tags),
                "ocr_text_preview": (ocr_text[:280].replace("\n", " ") if ocr_text else ""),
            }
        )

        screenshot_labels.append(
            {
                "entity_id": asset_id,
                "entity_type": "screenshot",
                "post_id": post_id,
                "topic_labels": "|".join(lbl.topic_labels),
                "intent_label": lbl.intent_label,
                "sentiment": lbl.sentiment,
                "risk_label": lbl.risk_label,
                "confidence": max(lbl.confidence, ocr_conf),
            }
        )

    # Trend aggregates
    labels_by_post = {r["entity_id"]: r for r in post_labels}
    screenshots_by_post = Counter([r["post_id"] for r in screenshot_inventory])

    monthly_post_groups: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
    quarterly_post_groups: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
    for p in submissions:
        monthly_post_groups[month_key(p["created_utc"])].append(p)
        quarterly_post_groups[quarter_key(p["created_utc"])].append(p)

    def aggregate_period(groups: Dict[str, List[Dict[str, Any]]], period_type: str) -> List[Dict[str, Any]]:
        out_rows: List[Dict[str, Any]] = []
        prev_vol_by_topic: Dict[str, int] = defaultdict(int)

        for period in sorted(groups.keys()):
            posts = groups[period]
            total = len(posts)
            if total == 0:
                continue

            sent_counts = Counter()
            topic_counts = Counter()
            engagement_total = 0
            with_shot = 0
            for p in posts:
                pid = p["post_id"]
                engagement_total += int(p.get("score", 0)) + int(p.get("num_comments", 0))
                if screenshots_by_post.get(pid, 0) > 0:
                    with_shot += 1
                lbl = labels_by_post.get(pid)
                if not lbl:
                    continue
                sent_counts[lbl["sentiment"]] += 1
                for t in lbl["topic_labels"].split("|"):
                    if t:
                        topic_counts[t] += 1

            sentiment_balance = 0.0
            if total:
                pos = sent_counts.get("Positive", 0) + sent_counts.get("Reassured", 0)
                neg = sent_counts.get("Concerned", 0) + sent_counts.get("Frustrated", 0)
                sentiment_balance = round((pos - neg) / total, 4)

            screenshot_share = round(with_shot / total, 4)
            avg_engagement = round(engagement_total / total, 3)

            for topic in TOPICS:
                vol = int(topic_counts.get(topic, 0))
                prev = int(prev_vol_by_topic.get(topic, 0))
                if prev == 0:
                    delta = None if vol == 0 else 1.0
                else:
                    delta = round((vol - prev) / prev, 4)

                out_rows.append(
                    {
                        "period_type": period_type,
                        "period": period,
                        "topic": topic,
                        "volume": vol,
                        "engagement": avg_engagement,
                        "sentiment_balance": sentiment_balance,
                        "screenshot_share": screenshot_share,
                        "change_vs_prev_period": "" if delta is None else delta,
                    }
                )
                prev_vol_by_topic[topic] = vol
        return out_rows

    monthly_agg = aggregate_period(monthly_post_groups, "month")
    quarterly_agg = aggregate_period(quarterly_post_groups, "quarter")

    # Post appendix
    post_appendix: List[Dict[str, Any]] = []
    for p in sorted(submissions, key=lambda x: x.get("created_utc", 0)):
        pid = p["post_id"]
        lbl = labels_by_post.get(pid, {})
        post_comments_count = sum(1 for c in comments if c.get("post_id") == pid)
        post_appendix.append(
            {
                "post_id": pid,
                "created_utc": p.get("created_utc", 0),
                "title": p.get("title", "")[:240],
                "score": p.get("score", 0),
                "num_comments_reported": p.get("num_comments", 0),
                "num_comments_crawled": post_comments_count,
                "media_type": p.get("media_type", "none"),
                "screenshot_assets": screenshots_by_post.get(pid, 0),
                "topic_labels": lbl.get("topic_labels", ""),
                "intent_label": lbl.get("intent_label", ""),
                "sentiment": lbl.get("sentiment", ""),
                "risk_label": lbl.get("risk_label", ""),
                "confidence": lbl.get("confidence", ""),
            }
        )

    # Comment thread summaries
    comments_by_post: Dict[str, List[Dict[str, Any]]] = defaultdict(list)
    for c in comments:
        comments_by_post[c["post_id"]].append(c)
    comment_labels_by_id = {r["entity_id"]: r for r in comment_labels}

    thread_summary: List[Dict[str, Any]] = []
    for pid, crows in comments_by_post.items():
        topic_counts = Counter()
        sentiment_counts = Counter()
        risk_counts = Counter()

        disagreement = 0
        for c in crows:
            cid = c.get("comment_id")
            lbl = comment_labels_by_id.get(cid)
            if not lbl:
                continue
            for t in lbl["topic_labels"].split("|"):
                if t:
                    topic_counts[t] += 1
            sentiment_counts[lbl["sentiment"]] += 1
            risk_counts[lbl["risk_label"]] += 1

            txt = normalize_text(c.get("body"))
            if re.search(r"\b(disagree|not true|wrong|nope|actually)\b", txt):
                disagreement += 1

        top_topics = [t for t, _ in topic_counts.most_common(3)]
        total = len(crows)
        concern_ratio = 0.0
        if total:
            concern_ratio = round((sentiment_counts.get("Concerned", 0) + sentiment_counts.get("Frustrated", 0)) / total, 4)
        disagreement_ratio = round(disagreement / total, 4) if total else 0.0

        thread_summary.append(
            {
                "post_id": pid,
                "comments_count": total,
                "top_topics": "|".join(top_topics),
                "concern_ratio": concern_ratio,
                "disagreement_ratio": disagreement_ratio,
                "top_risk_label": risk_counts.most_common(1)[0][0] if risk_counts else "General fitness",
            }
        )

    # Cross-signal co-occurrence map from post topic labels
    cooc = Counter()
    for row in post_labels:
        topics = [t for t in row["topic_labels"].split("|") if t]
        for i in range(len(topics)):
            for j in range(i + 1, len(topics)):
                key = tuple(sorted((topics[i], topics[j])))
                cooc[key] += 1

    cooc_rows = [
        {"topic_a": a, "topic_b": b, "cooccurrence": n}
        for (a, b), n in sorted(cooc.items(), key=lambda kv: kv[1], reverse=True)
    ]

    # Spikes
    monthly_volume_series = [(period, len(posts)) for period, posts in sorted(monthly_post_groups.items())]
    spikes = detect_spikes(monthly_volume_series)

    # Persist outputs
    write_csv(os.path.join(out_dir, "trend_labels_posts.csv"), post_labels)
    write_csv(os.path.join(out_dir, "trend_labels_comments.csv"), comment_labels)
    write_csv(os.path.join(out_dir, "trend_labels_screenshots.csv"), screenshot_labels)
    write_csv(os.path.join(out_dir, "trend_aggregates_monthly.csv"), monthly_agg)
    write_csv(os.path.join(out_dir, "trend_aggregates_quarterly.csv"), quarterly_agg)
    write_csv(os.path.join(out_dir, "appendix_posts.csv"), post_appendix)
    write_csv(os.path.join(out_dir, "appendix_comment_threads.csv"), thread_summary)
    write_csv(os.path.join(out_dir, "appendix_screenshots.csv"), screenshot_inventory)
    write_csv(os.path.join(out_dir, "cross_signal_cooccurrence.csv"), cooc_rows)

    summary = {
        "analysis_timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "posts": len(submissions),
        "comments": len(comments),
        "screenshots": len(screenshot_inventory),
        "monthly_periods": len(monthly_post_groups),
        "quarterly_periods": len(quarterly_post_groups),
        "spikes": spikes,
        "tesseract_available": tesseract_ok,
        "downloaded_screenshots": sum(int(r["downloaded"]) for r in screenshot_inventory),
        "ocr_nonempty": sum(1 for r in screenshot_inventory if r["ocr_text_preview"]),
        "top_post_topics": Counter(
            t
            for row in post_labels
            for t in row["topic_labels"].split("|")
            if t
        ).most_common(10),
        "top_comment_topics": Counter(
            t
            for row in comment_labels
            for t in row["topic_labels"].split("|")
            if t
        ).most_common(10),
        "top_risk_labels_comments": Counter(r["risk_label"] for r in comment_labels).most_common(10),
    }

    with open(os.path.join(out_dir, "analysis_summary.json"), "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)

    # Build markdown document
    doc_path = os.path.join(docs_dir, "reddit_applewatchfitness_trend_report.md")

    earliest = min((p.get("created_utc", 0) for p in submissions), default=0)
    latest = max((p.get("created_utc", 0) for p in submissions), default=0)
    earliest_iso = datetime.fromtimestamp(earliest, tz=timezone.utc).isoformat() if earliest else "n/a"
    latest_iso = datetime.fromtimestamp(latest, tz=timezone.utc).isoformat() if latest else "n/a"

    def md_table(rows: List[Dict[str, Any]], cols: List[str], max_rows: int = 12) -> str:
        if not rows:
            return "(no rows)"
        head = "| " + " | ".join(cols) + " |\n"
        sep = "| " + " | ".join(["---"] * len(cols)) + " |\n"
        body = ""
        for row in rows[:max_rows]:
            body += "| " + " | ".join(str(row.get(c, "")) for c in cols) + " |\n"
        return head + sep + body

    top_post_topics = [{"topic": t, "count": c} for t, c in summary["top_post_topics"][:10]]
    top_comment_topics = [{"topic": t, "count": c} for t, c in summary["top_comment_topics"][:10]]
    top_risks = [{"risk": t, "count": c} for t, c in summary["top_risk_labels_comments"][:10]]

    top_months = sorted(
        [{"period": p, "posts": n} for p, n in monthly_volume_series],
        key=lambda x: x["posts"],
        reverse=True,
    )[:10]

    cooc_top = cooc_rows[:12]

    with open(doc_path, "w", encoding="utf-8") as f:
        f.write("# r/AppleWatchFitness All-Time Trend Report\n\n")
        f.write("## Executive Summary\n")
        f.write(
            "This report analyzes all publicly accessible subreddit history crawled at analysis time, including posts, comments, and screenshot/media metadata. "
            "It applies a fixed taxonomy for topic/intent/sentiment/risk labels and reports monthly + quarterly trends.\n\n"
        )

        f.write("## Corpus Coverage and Data Quality\n")
        f.write(f"- Crawl/analysis timestamp (UTC): {summary['analysis_timestamp_utc']}\n")
        f.write(f"- Posts: {summary['posts']}\n")
        f.write(f"- Comments: {summary['comments']}\n")
        f.write(f"- Screenshot assets indexed: {summary['screenshots']}\n")
        f.write(f"- Screenshot assets downloaded: {summary['downloaded_screenshots']}\n")
        f.write(f"- Screenshot assets with non-empty OCR text: {summary['ocr_nonempty']}\n")
        f.write(f"- Earliest post UTC: {earliest_iso}\n")
        f.write(f"- Latest post UTC: {latest_iso}\n")
        f.write(f"- OCR engine available (`tesseract`): {summary['tesseract_available']}\n")
        f.write("- Accessibility rule: includes only content publicly retrievable at crawl time; removed/deleted data may be incomplete.\n\n")

        f.write("## Trend Findings\n")
        f.write("### Top Post Topics\n")
        f.write(md_table(top_post_topics, ["topic", "count"], max_rows=10) + "\n")

        f.write("### Top Comment Topics\n")
        f.write(md_table(top_comment_topics, ["topic", "count"], max_rows=10) + "\n")

        f.write("### Top Comment Risk Labels\n")
        f.write(md_table(top_risks, ["risk", "count"], max_rows=10) + "\n")

        f.write("### Highest-Volume Months\n")
        f.write(md_table(top_months, ["period", "posts"], max_rows=10) + "\n")

        f.write("### Change-Point / Spike Periods\n")
        if spikes:
            f.write(md_table(spikes, ["period", "value", "z"], max_rows=20) + "\n")
        else:
            f.write("No significant spikes detected by z-score >= 2.0 on monthly post volume.\n\n")

        f.write("### Cross-Signal Co-occurrence (Posts)\n")
        f.write(md_table(cooc_top, ["topic_a", "topic_b", "cooccurrence"], max_rows=12) + "\n")

        f.write("## Metric-Family Chapters\n")
        metric_sections = [
            ("HR", ["HR accuracy"]),
            ("Zones", ["Zones confusion"]),
            ("VO2", ["VO2 trend"]),
            ("HRV", ["HRV interpretation", "Stress/fatigue"]),
            ("Recovery", ["Recovery HR", "Training plan"]),
            ("RHR", ["RHR change", "Stress/fatigue"]),
        ]
        topic_counter_posts = Counter(t for r in post_labels for t in r["topic_labels"].split("|") if t)
        topic_counter_comments = Counter(t for r in comment_labels for t in r["topic_labels"].split("|") if t)

        for chapter, keys in metric_sections:
            p_total = sum(topic_counter_posts.get(k, 0) for k in keys)
            c_total = sum(topic_counter_comments.get(k, 0) for k in keys)
            f.write(f"### {chapter}\n")
            f.write(f"- Post mentions (label hits): {p_total}\n")
            f.write(f"- Comment mentions (label hits): {c_total}\n")
            f.write("- Interpretation: trend volumes indicate community attention, not clinical prevalence.\n\n")

        f.write("## Screenshot Analysis\n")
        metrics_counter = Counter()
        for row in screenshot_inventory:
            for tag in (row.get("detected_metrics") or "").split("|"):
                if tag:
                    metrics_counter[tag] += 1

        metric_rows = [{"detected_metric": k, "count": v} for k, v in metrics_counter.most_common(15)]
        if metric_rows:
            f.write(md_table(metric_rows, ["detected_metric", "count"], max_rows=15) + "\n")
        else:
            f.write("No metric tags detected from screenshot text/title/body fusion.\n\n")

        f.write("## Medical Implication Chapter\n")
        f.write("- This forum trend analysis is observational and should be treated as screening/supportive insight only.\n")
        f.write("- Community claims about arrhythmia, respiratory risk, or diagnosis require clinical confirmation.\n")
        f.write("- Use evidence tiers in downstream product decisions: established, promising, exploratory.\n\n")

        f.write("## Product Implications\n")
        f.write("- Prioritize education where `Zones confusion`, `HRV interpretation`, and `Device/setup issue` are frequent.\n")
        f.write("- Add confidence UX and ‘insufficient data’ states for low-quality or sparse periods.\n")
        f.write("- Route high-risk language to conservative guidance (‘follow up with clinician’).\n\n")

        f.write("## Appendix Pointers\n")
        f.write("- Appendix A (per-post labels): `data/processed/appendix_posts.csv`\n")
        f.write("- Appendix B (comment-thread summaries): `data/processed/appendix_comment_threads.csv`\n")
        f.write("- Appendix C (screenshot inventory + OCR tags): `data/processed/appendix_screenshots.csv`\n")
        f.write("- Monthly aggregates: `data/processed/trend_aggregates_monthly.csv`\n")
        f.write("- Quarterly aggregates: `data/processed/trend_aggregates_quarterly.csv`\n")

    return {
        "summary": summary,
        "doc_path": doc_path,
        "out_dir": out_dir,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Analyze subreddit trend dataset and generate report")
    parser.add_argument("--raw-dir", default="data/raw")
    parser.add_argument("--out-dir", default="data/processed")
    parser.add_argument("--docs-dir", default="docs")
    args = parser.parse_args()

    result = analyze(args.raw_dir, args.out_dir, args.docs_dir)
    print(json.dumps(result["summary"], indent=2))
    print(f"report: {result['doc_path']}")


if __name__ == "__main__":
    main()
