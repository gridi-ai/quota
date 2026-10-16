"""Check the built site's machine-consumed discovery and local-link contracts."""

from dataclasses import dataclass
from html.parser import HTMLParser
import json
from pathlib import Path
import plistlib
import sys
from typing import Final
from urllib.parse import unquote, urljoin, urlsplit
from xml.etree import ElementTree


BASE: Final = "https://gridi-ai.github.io/quota/"
PAGES: Final = {"en": "index.html", "ko": "ko/index.html"}


@dataclass
class SiteError(Exception):
    path: Path
    reason: str

    def __str__(self) -> str:
        return f"{self.path}: {self.reason}"


class Page(HTMLParser):
    """Collect structural fields without depending on prose or a JS runtime."""

    def __init__(self, path: Path) -> None:
        super().__init__(convert_charrefs=True)
        self.path = path
        self.elements: list[tuple[str, dict[str, str | None]]] = []
        self.structured: list[str] = []
        self.in_structured = False
        self.feed(path.read_text(encoding="utf-8"))

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        values = dict(attrs)
        self.elements.append((tag, values))
        if tag == "script" and values.get("type") == "application/ld+json":
            self.in_structured = True

    def handle_endtag(self, tag: str) -> None:
        if tag == "script":
            self.in_structured = False

    def handle_data(self, data: str) -> None:
        if self.in_structured:
            self.structured.append(data)

    def require(self, condition: bool, reason: str) -> None:
        if not condition:
            raise SiteError(self.path, reason)


def main() -> None:
    root = Path(sys.argv[1]).resolve()
    repo = Path(__file__).resolve().parent.parent
    allowed = {"index.html", "ko/index.html", "assets/style.css", "assets/icon.png",
               "sitemap.xml", ".nojekyll"}
    published = {path.relative_to(root).as_posix() for path in root.rglob("*") if path.is_file()}
    if published != allowed:
        raise SiteError(root, f"publication allowlist mismatch: {published ^ allowed}")
    with (repo / "Resources/Info.plist").open("rb") as manifest:
        version = plistlib.load(manifest)["CFBundleShortVersionString"]
    expected = {"en": BASE, "ko": BASE + "ko/", "x-default": BASE}
    parsed = {language: Page(root / path) for language, path in PAGES.items()}
    for language, page in parsed.items():
        canonical = expected[language]
        metadata = {
            attrs.get("name") or attrs.get("property"): attrs.get("content")
            for tag, attrs in page.elements if tag == "meta"
        }
        page.require(any(tag == "html" and attrs.get("lang") == language
                         for tag, attrs in page.elements), "wrong document language")
        page.require(sum(tag == "title" for tag, _ in page.elements) == 1, "need one title")
        page.require(sum(tag == "h1" for tag, _ in page.elements) == 1, "need one h1")
        page.require(all(metadata.get(key) for key in (
            "description", "viewport", "og:title", "og:description", "og:image",
            "twitter:card", "twitter:title", "twitter:description", "twitter:image",
        )), "missing discovery metadata")
        page.require(metadata.get("og:url") == canonical, "Open Graph URL mismatch")
        page.require("noindex" not in (metadata.get("robots") or "").lower(), "page is noindex")
        canonicals = [attrs.get("href") for tag, attrs in page.elements
                      if tag == "link" and attrs.get("rel") == "canonical"]
        page.require(canonicals == [canonical], "canonical URL mismatch")
        alternates = {attrs.get("hreflang"): attrs.get("href") for tag, attrs in page.elements
                      if tag == "link" and attrs.get("rel") == "alternate"}
        page.require(alternates == expected, "alternate language URLs are not reciprocal")
        page.require(all(attrs.get("type") == "application/ld+json"
                         for tag, attrs in page.elements if tag == "script"), "unexpected runtime script")
        data = json.loads("".join(page.structured))
        page.require(data["@context"] == "https://schema.org"
                     and data["@type"] == "SoftwareApplication", "wrong structured data type")
        page.require(data["url"] == canonical and data["softwareVersion"] == version,
                     "schema URL/version does not match release")
        page.require(data["isAccessibleForFree"] is True
                     and data["offers"]["price"] == "0"
                     and data["offers"]["priceCurrency"] == "USD", "free price schema mismatch")
        page.require("aggregateRating" not in data and "review" not in data,
                     "unverified review/rating metadata")
        page.require(data["publisher"]["url"] == "https://github.com/gridi-ai",
                     "wrong publisher identity")
        for tag, attrs in page.elements:
            for attribute in ("href", "src"):
                target = attrs.get(attribute)
                if not target:
                    continue
                absolute = urljoin(canonical, target)
                if not absolute.startswith(BASE):
                    continue
                parts = urlsplit(absolute)
                relative = unquote(parts.path.removeprefix("/quota/"))
                destination = root / relative
                if parts.path.endswith("/"):
                    destination /= "index.html"
                page.require(destination.is_file(), f"missing local resource: {target}")
                if parts.fragment and destination.suffix == ".html":
                    linked = Page(destination)
                    page.require(any(values.get("id") == unquote(parts.fragment)
                                     for _, values in linked.elements),
                                 f"missing local anchor: {target}")
            if tag == "img":
                page.require(all(attrs.get(key) for key in ("width", "height", "alt")),
                             "image needs dimensions and alt text")
        print(f"PASS {language}: canonical, hreflang, schema, metadata, assets and anchors")
    sitemap = ElementTree.parse(root / "sitemap.xml")
    urls = {entry.text for entry in sitemap.findall(".//{http://www.sitemaps.org/schemas/sitemap/0.9}loc")}
    if urls != {BASE, BASE + "ko/"}:
        raise SiteError(root / "sitemap.xml", "sitemap coverage mismatch")
    for node in sitemap.findall(".//{http://www.sitemaps.org/schemas/sitemap/0.9}url"):
        alternatives = {entry.get("hreflang"): entry.get("href")
                        for entry in node.findall("{http://www.w3.org/1999/xhtml}link")}
        if alternatives != expected:
            raise SiteError(root / "sitemap.xml", "sitemap alternate mismatch")
    print("PASS sitemap: both canonical pages and reciprocal language alternates")


if __name__ == "__main__":
    main()
