#!/usr/bin/env python3
"""Crawl subreddit submissions, comments, and media metadata from public Reddit JSON endpoints.

Usage:
  python3 scripts/crawl_reddit.py --subreddit AppleWatchFitness
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, asdict
from datetime import datetime, timezone
from typing import Any, Dict, Iterable, List, Optional, Tuple

USER_AGENT = "AppleWatchFitnessTrendResearch/1.0 (by /u/research-bot)"
DEFAULT_BASE = "https://old.reddit.com"
BASE = DEFAULT_BASE


@dataclass
class SubmissionRecord:
    post_id: str
    created_utc: int
    title: str
    body: str
    author_hash: str
    score: int
    num_comments: int
    flair: str
    url: str
    media_type: str
    is_deleted: bool
    is_removed: bool


@dataclass
class CommentRecord:
    comment_id: str
    post_id: str
    parent_id: str
    created_utc: int
    body: str
    author_hash: str
    score: int
    depth: int
    is_deleted: bool
    is_removed: bool


@dataclass
class ScreenshotRecord:
    asset_id: str
    post_id: str
    asset_url: str
    asset_type: str
    ocr_text: str
    detected_metrics: List[str]
    ocr_confidence: float


def ensure_dir(path: str) -> None:
    os.makedirs(path, exist_ok=True)


def hash_author(author: Optional[str]) -> str:
    raw = (author or "[unknown]").encode("utf-8", errors="ignore")
    return hashlib.sha256(raw).hexdigest()[:16]


def canonicalize_url(url: str) -> str:
    if not url:
        return ""
    parsed = urllib.parse.urlparse(url)
    clean = parsed._replace(query="", fragment="")
    return urllib.parse.urlunparse(clean)


def fetch_json(url: str, max_retries: int = 12) -> Any:
    headers = {"User-Agent": USER_AGENT}
    bearer = os.environ.get("REDDIT_BEARER_TOKEN", "").strip()
    if bearer:
        headers["Authorization"] = f"bearer {bearer}"
    req = urllib.request.Request(url, headers=headers)
    backoff = 1.0
    for attempt in range(max_retries):
        try:
            with urllib.request.urlopen(req, timeout=30) as resp:
                payload = resp.read()
                return json.loads(payload.decode("utf-8"))
        except urllib.error.HTTPError as err:
            if err.code in (429, 500, 502, 503, 504) and attempt < max_retries - 1:
                retry_after = 0.0
                try:
                    retry_after = float(err.headers.get("Retry-After", "0"))
                except Exception:
                    retry_after = 0.0
                sleep_for = max(retry_after, backoff)
                # Cap waits to keep crawl progressing while respecting limits.
                sleep_for = min(sleep_for, 90.0)
                print(
                    f"[retry] status={err.code} attempt={attempt + 1}/{max_retries} sleep={sleep_for:.1f}s url={url}",
                    file=sys.stderr,
                )
                time.sleep(sleep_for)
                backoff = min(backoff * 2.0, 90.0)
                continue
            raise
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError):
            if attempt < max_retries - 1:
                time.sleep(backoff)
                backoff = min(backoff * 2.0, 90.0)
                continue
            raise


def to_submission_record(post: Dict[str, Any]) -> SubmissionRecord:
    title = post.get("title") or ""
    body = post.get("selftext") or ""
    flair = post.get("link_flair_text") or ""
    url = post.get("url_overridden_by_dest") or post.get("url") or ""

    removed_by_category = post.get("removed_by_category")
    is_removed = bool(removed_by_category) or body == "[removed]"
    is_deleted = body == "[deleted]" or (post.get("author") == "[deleted]")

    media_type = "none"
    if post.get("is_gallery"):
        media_type = "gallery"
    elif post.get("post_hint") == "image":
        media_type = "image"
    elif post.get("post_hint") == "hosted:video":
        media_type = "video"
    elif post.get("preview"):
        media_type = "preview"

    return SubmissionRecord(
        post_id=post.get("id", ""),
        created_utc=int(post.get("created_utc", 0) or 0),
        title=title,
        body=body,
        author_hash=hash_author(post.get("author")),
        score=int(post.get("score", 0) or 0),
        num_comments=int(post.get("num_comments", 0) or 0),
        flair=flair,
        url=canonicalize_url(url),
        media_type=media_type,
        is_deleted=is_deleted,
        is_removed=is_removed,
    )


def extract_screenshots(post: Dict[str, Any]) -> List[Tuple[str, str]]:
    assets: List[Tuple[str, str]] = []
    url = canonicalize_url(post.get("url_overridden_by_dest") or post.get("url") or "")

    def add_asset(asset_url: str, asset_type: str) -> None:
        if not asset_url:
            return
        assets.append((canonicalize_url(asset_url), asset_type))

    if post.get("is_gallery") and post.get("media_metadata"):
        media_meta = post.get("media_metadata") or {}
        for _, item in media_meta.items():
            if not isinstance(item, dict):
                continue
            s = item.get("s") or {}
            u = s.get("u") or ""
            if u:
                add_asset(u.replace("&amp;", "&"), "gallery")

    if post.get("post_hint") == "image" and url:
        add_asset(url, "image")

    preview = post.get("preview") or {}
    images = preview.get("images") if isinstance(preview, dict) else None
    if isinstance(images, list):
        for image in images:
            source = image.get("source") if isinstance(image, dict) else None
            if isinstance(source, dict):
                u = source.get("url") or ""
                if u:
                    add_asset(u.replace("&amp;", "&"), "preview")

    # External image URL fallback
    if re.search(r"\.(png|jpg|jpeg|webp)$", url, flags=re.IGNORECASE):
        add_asset(url, "external_image")

    deduped = []
    seen = set()
    for asset_url, asset_type in assets:
        key = (asset_url, asset_type)
        if key in seen:
            continue
        seen.add(key)
        deduped.append((asset_url, asset_type))
    return deduped


def walk_comment_nodes(
    children: Iterable[Dict[str, Any]],
    post_id: str,
    depth: int,
    out_comments: List[CommentRecord],
    more_ids: List[str],
) -> None:
    for node in children:
        kind = node.get("kind")
        data = node.get("data") or {}
        if kind == "t1":
            body = data.get("body") or ""
            parent_id = data.get("parent_id") or ""
            is_deleted = body == "[deleted]" or data.get("author") == "[deleted]"
            is_removed = body == "[removed]"
            out_comments.append(
                CommentRecord(
                    comment_id=data.get("id", ""),
                    post_id=post_id,
                    parent_id=parent_id,
                    created_utc=int(data.get("created_utc", 0) or 0),
                    body=body,
                    author_hash=hash_author(data.get("author")),
                    score=int(data.get("score", 0) or 0),
                    depth=depth,
                    is_deleted=is_deleted,
                    is_removed=is_removed,
                )
            )
            replies = data.get("replies")
            if isinstance(replies, dict):
                reply_data = replies.get("data") or {}
                reply_children = reply_data.get("children") or []
                walk_comment_nodes(reply_children, post_id, depth + 1, out_comments, more_ids)
        elif kind == "more":
            children_ids = data.get("children") or []
            for cid in children_ids:
                if isinstance(cid, str):
                    more_ids.append(cid)


def fetch_more_children(post_id: str, ids: List[str], max_retries: int = 2) -> List[Dict[str, Any]]:
    """Attempt to expand 'more' comment placeholders using public endpoint.

    Returns a list of pseudo-nodes shaped like listing children.
    """
    if not ids:
        return []

    expanded: List[Dict[str, Any]] = []
    chunk_size = 50
    for idx in range(0, len(ids), chunk_size):
        chunk = ids[idx : idx + chunk_size]
        params = urllib.parse.urlencode(
            {
                "link_id": f"t3_{post_id}",
                "children": ",".join(chunk),
                "sort": "new",
                "api_type": "json",
                "raw_json": 1,
            }
        )
        url = f"{BASE}/api/morechildren.json?{params}"
        try:
            payload = fetch_json(url, max_retries=max_retries)
        except Exception:
            continue
        things = (((payload or {}).get("json") or {}).get("data") or {}).get("things") or []
        for thing in things:
            if isinstance(thing, dict):
                expanded.append(thing)
        time.sleep(0.2)
    return expanded


def fetch_comments_for_post(post_id: str, comment_retries: int = 3) -> Tuple[List[CommentRecord], int, int]:
    url = f"{BASE}/comments/{post_id}.json?limit=500&depth=10&sort=new&raw_json=1"
    payload = fetch_json(url, max_retries=comment_retries)

    if not isinstance(payload, list) or len(payload) < 2:
        return [], 0, 0

    comments_listing = payload[1]
    children = (((comments_listing or {}).get("data") or {}).get("children")) or []

    comments: List[CommentRecord] = []
    more_ids: List[str] = []
    walk_comment_nodes(children, post_id, depth=0, out_comments=comments, more_ids=more_ids)

    expanded_nodes = fetch_more_children(post_id, more_ids, max_retries=max(1, comment_retries - 1))
    if expanded_nodes:
        walk_comment_nodes(expanded_nodes, post_id, depth=0, out_comments=comments, more_ids=[])

    # Deduplicate by comment_id to avoid repeated nodes from morechildren expansion.
    dedup_map: Dict[str, CommentRecord] = {}
    for comment in comments:
        if comment.comment_id and comment.comment_id not in dedup_map:
            dedup_map[comment.comment_id] = comment
    return list(dedup_map.values()), len(more_ids), len(expanded_nodes)


def save_jsonl(path: str, rows: Iterable[Dict[str, Any]]) -> None:
    with open(path, "w", encoding="utf-8") as f:
        for row in rows:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")


def load_jsonl(path: str) -> List[Dict[str, Any]]:
    rows: List[Dict[str, Any]] = []
    if not os.path.exists(path):
        return rows
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:
                continue
    return rows


def epoch_to_iso(epoch: int) -> str:
    if not epoch:
        return ""
    return datetime.fromtimestamp(epoch, tz=timezone.utc).isoformat()


def crawl_subreddit(
    subreddit: str,
    max_posts: Optional[int],
    out_dir: str,
    request_delay: float,
    page_delay: float,
    comment_retries: int,
    resume: bool,
) -> Dict[str, Any]:
    base = os.environ.get("REDDIT_API_BASE", "").strip() or DEFAULT_BASE
    global BASE
    BASE = base
    ensure_dir(out_dir)
    subs_path = os.path.join(out_dir, "submissions.jsonl")
    comms_path = os.path.join(out_dir, "comments.jsonl")
    shots_path = os.path.join(out_dir, "screenshots.jsonl")
    stats_path = os.path.join(out_dir, "crawl_stats.json")

    submissions: List[SubmissionRecord] = []
    comments: List[CommentRecord] = []
    screenshots: List[ScreenshotRecord] = []

    after = None
    page_count = 0
    seen_posts = set()
    total_more_placeholders = 0
    total_more_expanded = 0

    if resume:
        for row in load_jsonl(subs_path):
            try:
                rec = SubmissionRecord(**row)
                submissions.append(rec)
                if rec.post_id:
                    seen_posts.add(rec.post_id)
            except TypeError:
                continue
        for row in load_jsonl(comms_path):
            try:
                comments.append(CommentRecord(**row))
            except TypeError:
                continue
        for row in load_jsonl(shots_path):
            try:
                screenshots.append(ScreenshotRecord(**row))
            except TypeError:
                continue
        if os.path.exists(stats_path):
            try:
                with open(stats_path, "r", encoding="utf-8") as f:
                    previous_stats = json.load(f)
                after = previous_stats.get("next_after")
                page_count = int(previous_stats.get("pages_fetched", 0) or 0)
            except Exception:
                pass

    while True:
        params = {"limit": 100, "raw_json": 1}
        if after:
            params["after"] = after
        query = urllib.parse.urlencode(params)
        url = f"{base}/r/{subreddit}/new.json?{query}"

        try:
            payload = fetch_json(url)
        except Exception as err:
            print(f"[warn] listing fetch failed, stopping crawl at page={page_count + 1}: {err}", file=sys.stderr)
            break
        listing_data = (payload or {}).get("data") or {}
        children = listing_data.get("children") or []
        after = listing_data.get("after")

        if not children:
            break

        for child in children:
            if child.get("kind") != "t3":
                continue
            post = child.get("data") or {}
            post_id = post.get("id")
            if not post_id or post_id in seen_posts:
                continue
            seen_posts.add(post_id)

            sub_rec = to_submission_record(post)
            submissions.append(sub_rec)

            asset_list = extract_screenshots(post)
            for idx, (asset_url, asset_type) in enumerate(asset_list):
                asset_id = f"{post_id}_{idx}_{hashlib.sha1(asset_url.encode('utf-8')).hexdigest()[:8]}"
                screenshots.append(
                    ScreenshotRecord(
                        asset_id=asset_id,
                        post_id=post_id,
                        asset_url=asset_url,
                        asset_type=asset_type,
                        ocr_text="",
                        detected_metrics=[],
                        ocr_confidence=0.0,
                    )
                )

            try:
                post_comments, more_count, expanded_count = fetch_comments_for_post(
                    post_id,
                    comment_retries=comment_retries,
                )
                comments.extend(post_comments)
                total_more_placeholders += more_count
                total_more_expanded += expanded_count
            except Exception as err:
                print(f"[warn] comments fetch failed for {post_id}: {err}", file=sys.stderr)

            if max_posts is not None and len(submissions) >= max_posts:
                after = None
                break

            time.sleep(max(0.0, request_delay))

        page_count += 1
        print(
            f"[crawl] page={page_count} posts={len(submissions)} comments={len(comments)} screenshots={len(screenshots)} after={after}",
            file=sys.stderr,
        )

        # Checkpoint after every page to avoid losing progress on rate-limit failures.
        save_jsonl(subs_path, (asdict(s) for s in submissions))
        save_jsonl(comms_path, (asdict(c) for c in comments))
        save_jsonl(shots_path, (asdict(s) for s in screenshots))
        with open(stats_path, "w", encoding="utf-8") as f:
            json.dump(
                {
                    "subreddit": subreddit,
                    "crawl_timestamp_utc": datetime.now(timezone.utc).isoformat(),
                    "posts_count": len(submissions),
                    "comments_count": len(comments),
                    "screenshots_count": len(screenshots),
                    "pages_fetched": page_count,
                    "more_placeholders": total_more_placeholders,
                    "more_expanded_nodes": total_more_expanded,
                    "next_after": after,
                },
                f,
                indent=2,
            )

        if not after:
            break
        if max_posts is not None and len(submissions) >= max_posts:
            break

        time.sleep(max(0.0, page_delay))

    # Dedupe comments across posts (defensive)
    comment_map: Dict[Tuple[str, str], CommentRecord] = {}
    for c in comments:
        key = (c.post_id, c.comment_id)
        if c.comment_id and key not in comment_map:
            comment_map[key] = c
    comments = list(comment_map.values())

    # Persist
    save_jsonl(subs_path, (asdict(s) for s in submissions))
    save_jsonl(comms_path, (asdict(c) for c in comments))
    save_jsonl(shots_path, (asdict(s) for s in screenshots))

    earliest = min((s.created_utc for s in submissions), default=0)
    latest = max((s.created_utc for s in submissions), default=0)

    stats = {
        "subreddit": subreddit,
        "api_base": base,
        "crawl_timestamp_utc": datetime.now(timezone.utc).isoformat(),
        "posts_count": len(submissions),
        "comments_count": len(comments),
        "screenshots_count": len(screenshots),
        "pages_fetched": page_count,
        "more_placeholders": total_more_placeholders,
        "more_expanded_nodes": total_more_expanded,
        "next_after": after,
        "earliest_post_utc": earliest,
        "latest_post_utc": latest,
        "earliest_post_iso": epoch_to_iso(earliest),
        "latest_post_iso": epoch_to_iso(latest),
        "paths": {
            "submissions": subs_path,
            "comments": comms_path,
            "screenshots": shots_path,
        },
    }

    with open(stats_path, "w", encoding="utf-8") as f:
        json.dump(stats, f, indent=2)

    return stats


def main() -> None:
    parser = argparse.ArgumentParser(description="Crawl a subreddit via public Reddit JSON endpoints")
    parser.add_argument("--subreddit", default="AppleWatchFitness")
    parser.add_argument("--max-posts", type=int, default=None)
    parser.add_argument("--out-dir", default="data/raw")
    parser.add_argument("--request-delay", type=float, default=0.75)
    parser.add_argument("--page-delay", type=float, default=2.0)
    parser.add_argument("--comment-retries", type=int, default=3)
    parser.add_argument("--resume", action="store_true")
    args = parser.parse_args()

    stats = crawl_subreddit(
        args.subreddit,
        args.max_posts,
        args.out_dir,
        request_delay=args.request_delay,
        page_delay=args.page_delay,
        comment_retries=max(1, args.comment_retries),
        resume=args.resume,
    )
    print(json.dumps(stats, indent=2))


if __name__ == "__main__":
    main()
