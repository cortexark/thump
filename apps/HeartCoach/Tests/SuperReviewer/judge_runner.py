#!/usr/bin/env python3
"""
judge_runner.py — Tier B/C Claude persona judge orchestrator.

Uses `claude --print` (Claude Code CLI) to evaluate Thump captures.
No ANTHROPIC_API_KEY required.

Usage:
    python3 judge_runner.py \
        --tier [tierB|tierC] \
        --capture-dir <path to TierA capture JSONs> \
        --results-dir <output path for JudgeResult JSONs> \
        --rubric <path to consolidated_rubric_v1.json> \
        --sample <int: max captures to evaluate> \
        --claude <path to claude CLI binary>
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

# ── Persona system prompts ──────────────────────────────────────────────────

SYSTEM_PROMPTS = {
    "marcus_chen": """You are Marcus Chen, 38, VP of Engineering at a Series B startup. \
You have a history of panic attacks triggered by health anxiety. You downloaded Thump for \
PATTERN detection — not moment-to-moment data. You cannot handle vague warnings or medical \
language without context.

WHAT MARCUS CATCHES: medical alerts without context, vague warnings with no action, text \
creating urgency without resolution, numbers without reference points.
WHAT MARCUS LOVES: contextual reassurance, pattern insights, clear doable actions.

Score each criterion 1-5 from Marcus's perspective. Be specific. Quote the actual text.

Return JSON only (no prose outside JSON):
{
  "persona": "marcus_chen",
  "scores": {
    "CLR-001": {"score": 4, "justification": "...", "suggestion": null}
  },
  "overall_score": 85,
  "max_possible": 100,
  "critical_issues": ["exact quotes that alarmed Marcus"],
  "top_strengths": ["exact quotes Marcus appreciated"],
  "marcus_reaction": "2-3 sentences: what would Marcus actually do after reading this?"
}""",

    "priya_okafor": """You are Priya Okafor, 29, a public school teacher. You don't know \
what HRV means. You downloaded Thump because a friend said it explains your heart in plain \
English. If it doesn't, you'll delete it.

WHAT PRIYA CATCHES: any jargon or acronym she doesn't know, text assuming fitness knowledge, \
unactionable recommendations, numbers without meaning.
WHAT PRIYA LOVES: plain English outcomes, simple actionable steps, validation her numbers \
make sense for who she is.

Return JSON only:
{
  "persona": "priya_okafor",
  "scores": {
    "CLR-001": {"score": 4, "justification": "...", "suggestion": null}
  },
  "overall_score": 85,
  "max_possible": 100,
  "critical_issues": ["exact jargon or confusing phrases Priya would not understand"],
  "top_strengths": ["exact phrases Priya would understand and appreciate"],
  "priya_reaction": "2-3 sentences: would Priya keep the app or delete it?"
}""",

    "david_nakamura": """You are David Nakamura, 34, a product designer. You closed Apple \
Watch activity rings for 200 consecutive days. You're currently overtrained. You want Thump \
to give you PERMISSION to rest. Apps usually say "you're below your move goal" which makes \
you feel guilty and go for a run at 10 PM anyway.

WHAT DAVID CATCHES: phrases implying he SHOULD have done more, guilt-inducing goal framing, \
missing permission language on rest days, inconsistency between rest mode and high goals.
WHAT DAVID LOVES: "rest day recommended — your body is doing important work," goals set low \
on rest days, explicit validation that resting is the right call.

Return JSON only:
{
  "persona": "david_nakamura",
  "scores": {
    "CLR-001": {"score": 4, "justification": "...", "suggestion": null}
  },
  "overall_score": 85,
  "max_possible": 100,
  "critical_issues": ["exact phrases that would make David feel guilty or push him to exercise"],
  "top_strengths": ["exact phrases that give David permission and validation to rest"],
  "david_reaction": "2-3 sentences: what would David do — rest or exercise?"
}""",

    "jordan_rivera": """You are Jordan Rivera, 31, a UX researcher with Generalized Anxiety \
Disorder (GAD). You track sleep obsessively because disrupted sleep is your first anxiety \
signal. You want Thump to work PASSIVELY and never say anything that would spike anxiety.

WHAT JORDAN CATCHES: any text creating urgency or suggesting something might be wrong, \
phrases like "concerning" or "elevated for X days" without resolution, missing reassurance.
WHAT JORDAN LOVES: "everything looks normal for your stress levels this week," context \
normalizing variation, calm factual tone.

Return JSON only:
{
  "persona": "jordan_rivera",
  "scores": {
    "CLR-001": {"score": 4, "justification": "...", "suggestion": null}
  },
  "overall_score": 85,
  "max_possible": 100,
  "critical_issues": ["exact phrases that would spike Jordan's anxiety"],
  "top_strengths": ["exact phrases that are calming and reassuring"],
  "jordan_reaction": "2-3 sentences: how does Jordan feel — more or less anxious?"
}""",

    "aisha_thompson": """You are Aisha Thompson, 27, a marketing director. You run 4 days \
a week, lift 3 days, and have been wearing a WHOOP for 2 years. You know exactly what HRV, \
zone 2, and recovery scores mean. If Thump is vaguer than WHOOP, you'll go back to WHOOP.

WHAT AISHA CATCHES: vague advice a fitness expert would find useless, missing specificity \
on WHY, advice that contradicts good training science, non-personalized advice.
WHAT AISHA LOVES: specific causal data-driven recommendations, trend data, zone distribution \
analysis.

Return JSON only:
{
  "persona": "aisha_thompson",
  "scores": {
    "CLR-001": {"score": 4, "justification": "...", "suggestion": null}
  },
  "overall_score": 85,
  "max_possible": 100,
  "critical_issues": ["vague or oversimplified phrases that would frustrate a trained athlete"],
  "top_strengths": ["specific, data-rich phrases Aisha would find genuinely useful"],
  "aisha_reaction": "2-3 sentences: does this compete with WHOOP or fall short?"
}""",

    "sarah_kovacs": """You are Sarah Kovacs, 41, an operations manager with two kids aged 4 \
and 7. You sleep 5-6 hours most nights — not by choice. You will only engage with the app if \
interventions take 2 minutes or less.

WHAT SARAH CATCHES: recommendations requiring time she doesn't have, blame-adjacent framing, \
long text, advice that only works for people with schedule control.
WHAT SARAH LOVES: micro-interventions (2 min), validation her situation is real, extremely \
short scannable text.

Return JSON only:
{
  "persona": "sarah_kovacs",
  "scores": {
    "CLR-001": {"score": 4, "justification": "...", "suggestion": null}
  },
  "overall_score": 85,
  "max_possible": 100,
  "critical_issues": ["recommendations she can't do, or guilt-inducing phrases"],
  "top_strengths": ["micro-interventions or validating phrases she would actually act on"],
  "sarah_reaction": "2-3 sentences: does Sarah feel seen, or not made for her?"
}""",
}

TIER_JUDGES = {
    "tierB": ["marcus_chen", "priya_okafor", "david_nakamura", "jordan_rivera"],
    "tierC": ["marcus_chen", "priya_okafor", "david_nakamura", "jordan_rivera",
              "aisha_thompson", "sarah_kovacs"],
}

JUDGE_TITLES = {
    "marcus_chen": "Stressed Professional",
    "priya_okafor": "Health-Curious Beginner",
    "david_nakamura": "Burnt-Out Ring Chaser",
    "jordan_rivera": "Anxious Millennial",
    "aisha_thompson": "Fitness Enthusiast",
    "sarah_kovacs": "Parent Running on Empty",
}

JUDGE_NAMES = {
    "marcus_chen": "Marcus Chen",
    "priya_okafor": "Priya Okafor",
    "david_nakamura": "David Nakamura",
    "jordan_rivera": "Jordan Rivera",
    "aisha_thompson": "Aisha Thompson",
    "sarah_kovacs": "Sarah Kovacs",
}


# ── JSON extraction ─────────────────────────────────────────────────────────

def extract_json(text: str) -> dict | None:
    """Extract JSON from text that may contain markdown fences."""
    # Try ```json ... ```
    match = re.search(r"```json\s*([\s\S]*?)\s*```", text)
    if match:
        try:
            return json.loads(match.group(1))
        except Exception:
            pass
    # Try ``` ... ```
    match = re.search(r"```\s*([\s\S]*?)\s*```", text)
    if match:
        try:
            return json.loads(match.group(1))
        except Exception:
            pass
    # Try first { to last }
    start = text.find("{")
    end = text.rfind("}")
    if start >= 0 and end > start:
        try:
            return json.loads(text[start : end + 1])
        except Exception:
            pass
    return None


# ── Claude CLI call ─────────────────────────────────────────────────────────

def call_claude(
    claude_bin: str,
    system_prompt: str,
    user_message: str,
    model: str = "haiku",
    timeout: int = 180,
) -> str | None:
    """Call `claude --print` with the given prompts. Returns raw text or None on error."""
    try:
        result = subprocess.run(
            [
                claude_bin,
                "--print",
                "--system-prompt", system_prompt,
                "--model", model,
                "--no-session-persistence",
            ],
            input=user_message,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        if result.returncode == 0:
            return result.stdout
        print(f"  claude CLI error (exit {result.returncode}): {result.stderr[:200]}",
              file=sys.stderr)
        return None
    except subprocess.TimeoutExpired:
        print("  Timeout calling claude CLI", file=sys.stderr)
        return None
    except Exception as e:
        print(f"  Exception calling claude CLI: {e}", file=sys.stderr)
        return None


# ── Build MultiJudgeResult JSON ─────────────────────────────────────────────

def build_multi_judge_result(
    capture_id: str,
    judge_id: str,
    response: dict,
    latency_ms: float,
) -> dict:
    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return {
        "captureID": capture_id,
        "judgeResults": [
            {
                "judgeID": judge_id,
                "judgeName": JUDGE_NAMES.get(judge_id, judge_id),
                "personaTitle": JUDGE_TITLES.get(judge_id, "Judge"),
                "captureID": capture_id,
                "response": response,
                "latencyMs": latency_ms,
                "timestamp": timestamp,
            }
        ],
        "errors": [],
    }


# ── Main ────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Super Reviewer LLM Judge Runner")
    parser.add_argument("--tier", default="tierB", choices=["tierB", "tierC"])
    parser.add_argument("--capture-dir", required=True, help="Dir with TierA capture JSONs")
    parser.add_argument("--results-dir", required=True, help="Output dir for JudgeResult JSONs")
    parser.add_argument("--rubric", required=True, help="Path to consolidated_rubric_v1.json")
    parser.add_argument("--sample", type=int, default=50, help="Max captures to evaluate")
    parser.add_argument("--claude", default="claude", help="Path to claude CLI binary")
    args = parser.parse_args()

    judges = TIER_JUDGES[args.tier]
    capture_dir = Path(args.capture_dir)
    results_dir = Path(args.results_dir)
    results_dir.mkdir(parents=True, exist_ok=True)

    rubric = "{}"
    if Path(args.rubric).exists():
        rubric = Path(args.rubric).read_text()

    # Collect individual captures from all JSON array files
    all_captures: list[tuple[str, dict]] = []  # (capture_id, capture_dict)
    for json_file in sorted(capture_dir.glob("*.json")):
        if json_file.stem == "manifest":
            continue
        try:
            data = json.loads(json_file.read_text())
            items = data if isinstance(data, list) else [data]
            for item in items:
                # Build a unique ID from capture fields
                persona = item.get("personaName", json_file.stem)
                journey = item.get("journeyID", "unknown")
                day = item.get("dayIndex", 0)
                ts = item.get("timeStampLabel", "").replace(":", "").replace(" ", "")
                cid = f"{persona}_{journey}_d{day}_{ts}"
                all_captures.append((cid, item))
        except Exception as e:
            print(f"  Warning: could not load {json_file}: {e}", file=sys.stderr)

    if not all_captures:
        print(f"ERROR: No captures found in {capture_dir}", file=sys.stderr)
        sys.exit(1)

    # Sample
    total = len(all_captures)
    if total <= args.sample:
        sampled = all_captures
    else:
        step = max(1, total // args.sample)
        sampled = all_captures[::step][: args.sample]

    print(f"Tier: {args.tier} | Captures: {len(sampled)}/{total} sampled | "
          f"Judges: {len(judges)} ({', '.join(JUDGE_NAMES.get(j, j) for j in judges)})")
    print()

    processed = 0
    errors = 0

    for capture_id, capture_dict in sampled:
        capture_json = json.dumps(capture_dict, indent=2)

        for judge_id in judges:
            safe_id = re.sub(r"[^a-zA-Z0-9_\-]", "_", capture_id)
            result_file = results_dir / f"{safe_id}_{judge_id}.json"

            # Skip already generated
            if result_file.exists():
                processed += 1
                continue

            system_prompt = SYSTEM_PROMPTS.get(judge_id, "You are a quality reviewer.")
            user_message = (
                "## App Text to Evaluate\n\n"
                "The following JSON contains every piece of user-facing text shown in "
                "Thump Heart Coach for a specific health scenario. Evaluate it as your "
                "assigned persona.\n\n"
                f"```json\n{capture_json}\n```\n\n"
                "Score the criteria most relevant to your persona (CLR-001 through "
                "CLR-010). Respond with JSON only. No prose outside the JSON object."
            )

            t0 = time.time()
            raw = call_claude(
                claude_bin=args.claude,
                system_prompt=system_prompt,
                user_message=user_message,
            )
            latency_ms = (time.time() - t0) * 1000

            if raw is None:
                print(f"  ⚠️  Failed: {capture_id} / {judge_id}")
                errors += 1
                continue

            response = extract_json(raw)
            if response is None:
                response = {
                    "persona": judge_id,
                    "scores": {},
                    "overall_score": 0,
                    "max_possible": 100,
                    "critical_issues": [f"parse_error: could not extract JSON from: {raw[:200]}"],
                    "top_strengths": [],
                }

            # Ensure required fields
            response.setdefault("overall_score", 0)
            response.setdefault("max_possible", 100)
            response.setdefault("critical_issues", [])
            response.setdefault("top_strengths", [])
            response.setdefault("scores", {})

            multi = build_multi_judge_result(capture_id, judge_id, response, latency_ms)
            result_file.write_text(json.dumps(multi, indent=2))
            processed += 1

            if processed % 5 == 0:
                print(f"  Processed {processed} / {len(sampled) * len(judges)} "
                      f"({errors} errors)...")

    print()
    print(f"Done: {processed} results saved, {errors} errors")
    print(f"Results dir: {results_dir}")

    if errors > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
