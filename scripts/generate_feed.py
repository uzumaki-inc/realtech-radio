#!/usr/bin/env python3
"""
Podcast RSS フィード生成スクリプト

episodes/ 配下の meta.yaml を読み取り、
Podcast 仕様の RSS 2.0 + iTunes 拡張の XML を生成する。

使い方:
    python scripts/generate_feed.py

出力:
    site/feed.xml
"""

import os
import glob
import yaml
import markdown
from xml.etree.ElementTree import Element, SubElement, ElementTree, indent, register_namespace
from datetime import datetime, timezone

# 名前空間プレフィックスを登録（ns0, ns1 ではなく itunes, content 等になる）
ITUNES_NS = "http://www.itunes.com/dtds/podcast-1.0.dtd"
CONTENT_NS = "http://purl.org/rss/1.0/modules/content/"
ATOM_NS = "http://www.w3.org/2005/Atom"

register_namespace("itunes", ITUNES_NS)
register_namespace("content", CONTENT_NS)
register_namespace("atom", ATOM_NS)


def load_yaml(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def load_text(path: str) -> str:
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            return f.read()
    return ""


def format_rfc2822(dt) -> str:
    """datetime を RFC 2822 形式に変換する（Podcast RSS で必須）"""
    if isinstance(dt, str):
        dt = datetime.fromisoformat(dt)
    if not hasattr(dt, "hour"):
        # date オブジェクトの場合、datetime に変換
        dt = datetime(dt.year, dt.month, dt.day, tzinfo=timezone.utc)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    # RFC 2822 形式: "Sat, 07 Mar 2026 00:00:00 +0000"
    return dt.strftime("%a, %d %b %Y %H:%M:%S %z")


def mime_type_for(url: str) -> str:
    if url.endswith(".m4a"):
        return "audio/x-m4a"
    return "audio/mpeg"


def build_feed(repo_root: str) -> Element:
    podcast = load_yaml(os.path.join(repo_root, "podcast.yaml"))

    rss = Element("rss", {"version": "2.0"})

    channel = SubElement(rss, "channel")

    # --- Channel メタデータ ---
    SubElement(channel, "title").text = podcast["title"]
    SubElement(channel, "link").text = podcast["link"]
    SubElement(channel, "description").text = podcast["description"]
    SubElement(channel, "language").text = podcast.get("language", "ja")
    SubElement(channel, "generator").text = "generate_feed.py"
    SubElement(channel, "lastBuildDate").text = format_rfc2822(
        datetime.now(timezone.utc)
    )

    # Atom self link（Podcast バリデーターが推奨）
    atom_link = SubElement(channel, f"{{{ATOM_NS}}}link")
    atom_link.set("href", podcast.get("feed_url", ""))
    atom_link.set("rel", "self")
    atom_link.set("type", "application/rss+xml")

    # iTunes 固有
    SubElement(channel, f"{{{ITUNES_NS}}}author").text = podcast.get("author", "")
    SubElement(channel, f"{{{ITUNES_NS}}}explicit").text = (
        "true" if podcast.get("explicit", False) else "false"
    )
    owner = SubElement(channel, f"{{{ITUNES_NS}}}owner")
    SubElement(owner, f"{{{ITUNES_NS}}}name").text = podcast.get("author", "")
    SubElement(owner, f"{{{ITUNES_NS}}}email").text = podcast.get("email", "")

    if "image" in podcast:
        img = SubElement(channel, f"{{{ITUNES_NS}}}image")
        img.set("href", podcast["image"])
        # RSS 標準の image 要素も追加
        rss_img = SubElement(channel, "image")
        SubElement(rss_img, "url").text = podcast["image"]
        SubElement(rss_img, "title").text = podcast["title"]
        SubElement(rss_img, "link").text = podcast["link"]

    if "category" in podcast:
        cat = SubElement(channel, f"{{{ITUNES_NS}}}category")
        cat.set("text", podcast["category"])

    # --- エピソード ---
    episodes_dir = os.path.join(repo_root, "episodes")
    episode_dirs = sorted(glob.glob(os.path.join(episodes_dir, "*")))

    episodes = []
    for ep_dir in episode_dirs:
        meta_path = os.path.join(ep_dir, "meta.yaml")
        if not os.path.isfile(meta_path):
            continue
        meta = load_yaml(meta_path)
        meta["_dir"] = ep_dir
        meta["_id"] = os.path.basename(ep_dir)
        episodes.append(meta)

    # 日付の降順（新しいエピソードが先）
    episodes.sort(key=lambda e: str(e.get("date", "")), reverse=True)

    for ep in episodes:
        item = SubElement(channel, "item")
        SubElement(item, "title").text = ep["title"]

        # ショーノートを HTML に変換して content:encoded に入れる
        shownotes_md = load_text(os.path.join(ep["_dir"], "shownotes.md"))
        if shownotes_md:
            # 雛形の TODO が残ったまま配信される事故を防ぐ（HTML コメントは
            # markdown 変換を素通しして Podcast アプリの説明欄にそのまま載る）
            if "TODO" in shownotes_md:
                raise SystemExit(
                    f"❌ {ep['_id']}/shownotes.md に TODO が残っています。"
                    "記入を完了してから公開してください。"
                )
            shownotes_html = markdown.markdown(shownotes_md)
            content_encoded = SubElement(
                item, f"{{{CONTENT_NS}}}encoded"
            )
            content_encoded.text = shownotes_html

        SubElement(item, "description").text = ep.get("description", "")
        SubElement(item, "pubDate").text = format_rfc2822(ep["date"])

        # GUID（エピソードの一意識別子）
        guid = SubElement(item, "guid", isPermaLink="false")
        guid.text = f"{podcast['link']}/episodes/{ep['_id']}"

        # 音声ファイル
        if "audio_url" in ep:
            enclosure = SubElement(item, "enclosure")
            enclosure.set("url", ep["audio_url"])
            enclosure.set("length", str(ep.get("file_size", 0)))
            enclosure.set("type", mime_type_for(ep["audio_url"]))

        # iTunes 固有
        if "duration" in ep:
            SubElement(item, f"{{{ITUNES_NS}}}duration").text = ep["duration"]
        SubElement(item, f"{{{ITUNES_NS}}}explicit").text = (
            "true" if ep.get("explicit", False) else "false"
        )
        if "episode_number" in ep:
            SubElement(item, f"{{{ITUNES_NS}}}episode").text = str(
                ep["episode_number"]
            )

    return rss


def main():
    # スクリプトのあるディレクトリからリポジトリルートを特定
    script_dir = os.path.dirname(os.path.abspath(__file__))
    repo_root = os.path.dirname(script_dir)

    rss = build_feed(repo_root)

    # 出力
    output_dir = os.path.join(repo_root, "site")
    os.makedirs(output_dir, exist_ok=True)
    output_path = os.path.join(output_dir, "feed.xml")

    indent(rss, space="  ")
    tree = ElementTree(rss)
    tree.write(output_path, encoding="unicode", xml_declaration=True)

    print(f"✅ Feed generated: {output_path}")
    print(f"   Episodes: {len(rss.find('channel').findall('item'))}")


if __name__ == "__main__":
    main()
