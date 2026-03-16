#!/usr/bin/env python3
"""
extract_toc.py - PDFから目次を抽出し、物理ページ番号とのマッピングを構築する。

使い方:
    python extract_toc.py <pdf_path> [--scan-pages 30] [--output toc.json]

出力: JSON形式の目次構造
{
  "title": "書籍タイトル",
  "author": "著者名",
  "total_pages": 350,
  "page_offset": 12,  // 目次のページ番号とPDF物理ページのずれ
  "chapters": [
    {
      "number": 1,
      "title": "Introduction",
      "start_page": 1,       // 目次記載のページ番号
      "physical_page": 13,   // PDF内の物理ページ番号(0-indexed)
      "end_physical_page": 38 // 次章の開始前ページ(推定)
    },
    ...
  ]
}
"""

import argparse
import json
import re
import sys

import pdfplumber


def extract_metadata(pdf):
    """PDFメタデータからタイトルと著者を取得"""
    meta = pdf.metadata or {}
    title = meta.get("Title", "") or meta.get("title", "") or ""
    author = meta.get("Author", "") or meta.get("author", "") or ""
    return title.strip(), author.strip()


def extract_text_pages(pdf, start=0, end=30):
    """指定範囲のページからテキストを抽出"""
    pages = []
    end = min(end, len(pdf.pages))
    for i in range(start, end):
        text = pdf.pages[i].extract_text() or ""
        pages.append({"page_index": i, "text": text})
    return pages


def find_toc_pages(pages):
    """目次ページを特定する"""
    toc_keywords = [
        r"table\s+of\s+contents",
        r"contents",
        r"目次",
        r"もくじ",
    ]
    toc_pages = []
    for page in pages:
        text_lower = page["text"].lower().strip()
        # 先頭数行に目次キーワードがあるかチェック
        first_lines = "\n".join(text_lower.split("\n")[:5])
        for kw in toc_keywords:
            if re.search(kw, first_lines, re.IGNORECASE):
                toc_pages.append(page)
                break
    # 目次キーワードがない場合、ページ番号パターンが多いページを探す
    if not toc_pages:
        for page in pages:
            lines = page["text"].split("\n")
            numbered_lines = sum(
                1 for l in lines if re.search(r"\.\s*\d{1,3}\s*$", l.strip())
            )
            if numbered_lines >= 5:
                toc_pages.append(page)
    return toc_pages


def parse_toc_entries(toc_text):
    """目次テキストからエントリをパース"""
    entries = []
    lines = toc_text.split("\n")

    # 複数のパターンに対応
    patterns = [
        # "Chapter 1: Title ..... 15" or "1. Title ..... 15"
        r"(?:chapter\s+)?(\d+)[\.:\s]+(.+?)\s*[\.…·\-_\s]{2,}\s*(\d+)",
        # "第1章 Title ..... 15"
        r"第\s*(\d+)\s*章[\.:\s]*(.+?)\s*[\.…·\-_\s]{2,}\s*(\d+)",
        # "1 Title 15" (シンプルなパターン)
        r"^(\d{1,2})\s+([A-Z\u3000-\u9fff].+?)\s+(\d{1,3})\s*$",
        # "Part I: Title" パターン (ページ番号あり)
        r"(?:part\s+)?([ivxIVX\d]+)[\.:\s]+(.+?)\s*[\.…·\-_\s]{2,}\s*(\d+)",
    ]

    for line in lines:
        line = line.strip()
        if not line:
            continue
        for pattern in patterns:
            match = re.search(pattern, line, re.IGNORECASE)
            if match:
                num_str, title, page = match.groups()
                # ローマ数字をアラビア数字に変換する試み
                try:
                    num = int(num_str)
                except ValueError:
                    num = roman_to_int(num_str)
                entries.append(
                    {
                        "number": num,
                        "title": title.strip().rstrip(".…·- "),
                        "start_page": int(page),
                    }
                )
                break
    return entries


def roman_to_int(s):
    """ローマ数字を整数に変換"""
    roman = {"i": 1, "v": 5, "x": 10, "l": 50, "c": 100}
    s = s.lower()
    result = 0
    for i, c in enumerate(s):
        if c not in roman:
            return 0
        if i + 1 < len(s) and roman.get(c, 0) < roman.get(s[i + 1], 0):
            result -= roman[c]
        else:
            result += roman[c]
    return result


def estimate_page_offset(pdf, toc_entries, scan_range=50):
    """
    目次のページ番号とPDFの物理ページ番号のオフセットを推定する。

    方法: 目次の最初のいくつかのエントリについて、
    そのタイトルらしき文字列がPDF内のどの物理ページに現れるかを探す。
    """
    if not toc_entries:
        return 0

    offsets = []
    scan_end = min(scan_range, len(pdf.pages))

    for entry in toc_entries[:5]:  # 最初の5エントリで推定
        target_title = entry["title"]
        target_page = entry["start_page"]

        # タイトルの主要部分（短くする）
        title_words = target_title.split()[:4]
        search_pattern = r"\s*".join(re.escape(w) for w in title_words)

        for phys_page in range(scan_end):
            text = pdf.pages[phys_page].extract_text() or ""
            first_lines = "\n".join(text.split("\n")[:5])
            if re.search(search_pattern, first_lines, re.IGNORECASE):
                offset = phys_page - target_page
                offsets.append(offset)
                break

    if offsets:
        # 最頻値を返す
        from collections import Counter

        return Counter(offsets).most_common(1)[0][0]
    return 0


def build_toc(pdf_path, scan_pages=30):
    """メイン処理: PDFから目次を構築する"""
    with pdfplumber.open(pdf_path) as pdf:
        title, author = extract_metadata(pdf)
        total_pages = len(pdf.pages)

        # テキスト抽出
        pages = extract_text_pages(pdf, 0, scan_pages)

        # 目次ページを特定
        toc_pages = find_toc_pages(pages)

        if toc_pages:
            # 目次テキストを結合してパース
            toc_text = "\n".join(p["text"] for p in toc_pages)
            entries = parse_toc_entries(toc_text)
        else:
            # 目次が見つからない場合、全ページから章見出しをスキャン
            print(
                "Warning: TOC page not found. Scanning all pages for chapter headings...",
                file=sys.stderr,
            )
            entries = scan_chapter_headings(pdf)

        # ページオフセットを推定
        offset = estimate_page_offset(pdf, entries)

        # 物理ページ番号を付与
        for i, entry in enumerate(entries):
            entry["physical_page"] = max(0, entry["start_page"] + offset)
            if i + 1 < len(entries):
                entry["end_physical_page"] = (
                    entries[i + 1]["start_page"] + offset - 1
                )
            else:
                entry["end_physical_page"] = total_pages - 1

        # タイトルが空なら推定
        if not title and pages:
            first_text = pages[0]["text"].split("\n")
            for line in first_text:
                if len(line.strip()) > 3:
                    title = line.strip()
                    break

        return {
            "title": title,
            "author": author,
            "total_pages": total_pages,
            "page_offset": offset,
            "toc_pages_found": len(toc_pages),
            "chapters": entries,
        }


def scan_chapter_headings(pdf):
    """全ページをスキャンして章の見出しを検出"""
    entries = []
    patterns = [
        r"^(?:Chapter|CHAPTER)\s+(\d+)[\.:\s]*(.+)",
        r"^第\s*(\d+)\s*章[\.:\s]*(.+)",
        r"^(\d{1,2})\.\s+([A-Z\u3000-\u9fff].{3,})",
    ]
    for i, page in enumerate(pdf.pages):
        text = page.extract_text() or ""
        first_lines = text.split("\n")[:3]
        for line in first_lines:
            line = line.strip()
            for pattern in patterns:
                match = re.match(pattern, line)
                if match:
                    num, title = match.groups()
                    entries.append(
                        {
                            "number": int(num),
                            "title": title.strip(),
                            "start_page": i,
                            "physical_page": i,
                        }
                    )
                    break
    return entries


def main():
    parser = argparse.ArgumentParser(description="Extract TOC from a PDF")
    parser.add_argument("pdf_path", help="Path to the PDF file")
    parser.add_argument(
        "--scan-pages",
        type=int,
        default=30,
        help="Number of pages to scan for TOC (default: 30)",
    )
    parser.add_argument(
        "--output", "-o", default=None, help="Output JSON file path"
    )
    args = parser.parse_args()

    toc = build_toc(args.pdf_path, args.scan_pages)

    output = json.dumps(toc, ensure_ascii=False, indent=2)
    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(output)
        print(f"TOC saved to {args.output}", file=sys.stderr)
    else:
        print(output)


if __name__ == "__main__":
    main()
