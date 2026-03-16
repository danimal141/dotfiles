#!/usr/bin/env python3
"""
extract_chapter.py - PDFから指定ページ範囲のテキストを抽出する。

使い方:
    python extract_chapter.py <pdf_path> <start_page> <end_page> [--output chapter.txt]

ページ番号は0-indexed（PDF物理ページ）。
"""

import argparse
import sys

import pdfplumber


def extract_chapter_text(pdf_path, start_page, end_page):
    """指定ページ範囲のテキストを抽出"""
    texts = []
    with pdfplumber.open(pdf_path) as pdf:
        total = len(pdf.pages)
        end_page = min(end_page, total - 1)

        for i in range(start_page, end_page + 1):
            page = pdf.pages[i]
            text = page.extract_text() or ""
            texts.append(f"--- Page {i} ---\n{text}")

    return "\n\n".join(texts)


def main():
    parser = argparse.ArgumentParser(
        description="Extract text from a page range of a PDF"
    )
    parser.add_argument("pdf_path", help="Path to the PDF file")
    parser.add_argument(
        "start_page", type=int, help="Start page (0-indexed, physical)"
    )
    parser.add_argument(
        "end_page", type=int, help="End page (0-indexed, physical, inclusive)"
    )
    parser.add_argument(
        "--output", "-o", default=None, help="Output text file path"
    )
    args = parser.parse_args()

    text = extract_chapter_text(args.pdf_path, args.start_page, args.end_page)

    if args.output:
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(text)
        print(
            f"Extracted pages {args.start_page}-{args.end_page} to {args.output}",
            file=sys.stderr,
        )
    else:
        print(text)


if __name__ == "__main__":
    main()
