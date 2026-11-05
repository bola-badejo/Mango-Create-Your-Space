#!/usr/bin/env python3
"""Mango preflight: catches common Flutter build breakers without the SDK.

Checks
  1. syntax       every Dart file parses (needs `pip install tree-sitter tree-sitter-language-pack`;
                  skipped with a note if unavailable)
  2. imports      every package:mango/ and relative import resolves, with exact
                  letter case (Linux CI and web builds are case-sensitive)
  3. platform     no browser-only library (dart:html, dart:js_interop, package:web, ...)
                  is reachable from lib/main.dart on Android/iOS without a
                  conditional import
  4. packages     every imported package is declared in pubspec.yaml
  5. assets       every asset path declared in pubspec.yaml exists
  6. tokens       every MangoPalette / MangoRadius / MangoSpace / MangoSize /
                  MangoMotionTokens member and context.colors field used exists

Usage:  python3 tool/preflight.py            (exit 1 if any error)
        python3 tool/preflight.py --strict   (warnings also fail)
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"
WEB_ONLY = (
    "dart:html", "dart:js", "dart:js_util", "dart:js_interop",
    "dart:js_interop_unsafe", "dart:ui_web", "dart:indexed_db", "dart:web_gl",
    "dart:web_audio", "dart:svg", "package:web/", "package:js/",
)
SDK_PACKAGES = {"flutter", "flutter_test", "flutter_web_plugins", "flutter_driver",
                "integration_test", "flutter_localizations", "sky_engine"}

errors: list[str] = []
warnings: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def warn(msg: str) -> None:
    warnings.append(msg)


def rel(p: Path) -> str:
    return str(p.relative_to(ROOT))


def dart_files(*dirs: str) -> list[Path]:
    out: list[Path] = []
    for d in dirs:
        base = ROOT / d
        if base.exists():
            out += sorted(p for p in base.rglob("*.dart") if ".dart_tool" not in p.parts)
    return out


def strip_comments(src: str) -> str:
    src = re.sub(r"/\*.*?\*/", lambda m: " " * len(m.group(0)), src, flags=re.S)
    return re.sub(r"//[^\n]*", "", src)


DIRECTIVE = re.compile(
    r"^\s*(import|export|part)\s+((?:'[^']*'|\"[^\"]*\")(?:\s+if\s*\([^)]*\)\s*(?:'[^']*'|\"[^\"]*\"))*)",
    re.M,
)
URI = re.compile(r"'([^']*)'|\"([^\"]*)\"")


def directives(src: str):
    """Yield (kind, default_uri, conditional_uris)."""
    for m in DIRECTIVE.finditer(strip_comments(src)):
        uris = [a or b for a, b in URI.findall(m.group(2))]
        yield m.group(1), uris[0], uris[1:]


def exists_exact_case(path: Path) -> bool:
    """True if `path` exists with exactly this letter case."""
    try:
        parts = path.resolve().relative_to(ROOT).parts
    except ValueError:
        return path.exists()
    cur = ROOT
    for part in parts:
        try:
            names = os.listdir(cur)
        except (FileNotFoundError, NotADirectoryError):
            return False
        if part not in names:
            return False
        cur = cur / part
    return True


def resolve(uri: str, src_file: Path) -> Path | None:
    if uri.startswith("package:mango/"):
        return LIB / uri[len("package:mango/"):]
    if ":" in uri:
        return None
    return (src_file.parent / uri)


def pubspec():
    text = (ROOT / "pubspec.yaml").read_text()
    try:
        import yaml  # type: ignore
        return yaml.safe_load(text)
    except ImportError:
        return None


def collect_declared_packages(spec) -> set[str]:
    """Every key that looks like a dependency anywhere under the dependency maps,
    tolerant of the mis-indented entries in this project's pubspec."""
    names: set[str] = set()

    def walk(node):
        if isinstance(node, dict):
            for k, v in node.items():
                names.add(str(k))
                walk(v)

    for key in ("dependencies", "dev_dependencies", "dependency_overrides"):
        walk((spec or {}).get(key) or {})
    return names


# 1. syntax ---------------------------------------------------------------
def check_syntax(files: list[Path]) -> None:
    try:
        from tree_sitter_language_pack import get_parser  # type: ignore
    except ImportError:
        warn("syntax: tree-sitter not installed; skipped "
             "(pip install tree-sitter tree-sitter-language-pack)")
        return
    sys.setrecursionlimit(1_000_000)
    parser = get_parser("dart")
    for f in files:
        src = f.read_bytes()
        tree = parser.parse(src)
        if not tree.root_node.has_error:
            continue
        stack = [tree.root_node]
        while stack:
            n = stack.pop()
            if n.type == "ERROR" or n.is_missing:
                line = n.start_point[0] + 1
                snippet = src.decode(errors="replace").splitlines()[line - 1].strip()[:100]
                err(f"syntax: {rel(f)}:{line}: {snippet}")
                break
            stack.extend(n.children)


# 2 + 3. imports and platform reachability ---------------------------------
def check_imports(files: list[Path]) -> None:
    graph: dict[Path, list[Path]] = {}
    web_only_direct: dict[Path, list[str]] = {}
    for f in files:
        src = f.read_text(errors="replace")
        edges: list[Path] = []
        for kind, default, conditional in directives(src):
            for uri in [default, *conditional]:
                target = resolve(uri, f)
                if target is None:
                    continue
                if not exists_exact_case(target):
                    hint = ""
                    if target.exists():
                        hint = " (exists with different letter case: fails on Linux and web builds)"
                    err(f"imports: {rel(f)}: cannot resolve '{uri}'{hint}")
            # On Android/iOS only the default URI is used.
            if any(default.startswith(w) for w in WEB_ONLY):
                web_only_direct.setdefault(f, []).append(default)
            t = resolve(default, f)
            if t is not None and t.exists() and kind != "part":
                edges.append(t.resolve())
            elif t is not None and t.exists():
                edges.append(t.resolve())
        graph[f.resolve()] = edges

    main = (LIB / "main.dart").resolve()
    seen: set[Path] = set()
    parent: dict[Path, Path] = {}
    stack = [main]
    while stack:
        n = stack.pop()
        if n in seen:
            continue
        seen.add(n)
        for m in graph.get(n, []):
            if m not in seen:
                parent.setdefault(m, n)
                stack.append(m)
    for f, libs in sorted(web_only_direct.items()):
        if f.resolve() in seen:
            chain = []
            n = f.resolve()
            while n in parent and len(chain) < 4:
                chain.append(rel(parent[n]))
                n = parent[n]
            via = " <- ".join(chain)
            err(f"platform: {rel(f)} imports {', '.join(sorted(set(libs)))} without a "
                f"conditional import; Android/iOS builds fail (reached via {via})")


# 4. packages ---------------------------------------------------------------
def check_packages(files: list[Path], spec) -> None:
    if spec is None:
        warn("packages: PyYAML not installed; skipped (pip install pyyaml)")
        return
    declared = collect_declared_packages(spec) | SDK_PACKAGES | {spec.get("name", "")}
    used: dict[str, str] = {}
    for f in files:
        for _, default, conditional in directives(f.read_text(errors="replace")):
            for uri in [default, *conditional]:
                if uri.startswith("package:"):
                    used.setdefault(uri[8:].split("/")[0], rel(f))
    lock: dict = {}
    lock_path = ROOT / "pubspec.lock"
    if lock_path.exists():
        import yaml  # type: ignore
        lock = (yaml.safe_load(lock_path.read_text()) or {}).get("packages") or {}
    for pkg, where in sorted(used.items()):
        if pkg in declared:
            continue
        if pkg in lock:
            # Resolves through another package, so it compiles; declare it to
            # stop a dependency update from silently removing it.
            warn(f"packages: '{pkg}' imported (e.g. {where}) only as a transitive "
                 f"dependency; add it to pubspec.yaml")
        else:
            err(f"packages: '{pkg}' imported (e.g. {where}) but not in pubspec.yaml "
                f"or pubspec.lock")


# 5. assets ----------------------------------------------------------------
def check_assets(spec) -> None:
    if spec is None:
        return
    flutter = spec.get("flutter") or {}
    for a in flutter.get("assets") or []:
        path = a if isinstance(a, str) else a.get("path", "")
        if not (ROOT / path).exists():
            msg = f"assets: '{path}' is declared in pubspec.yaml but missing"
            if path == ".env":
                msg += " (create it locally; CI writes one from a secret or an empty file)"
                warn(msg)
            else:
                err(msg)
    for fam in flutter.get("fonts") or []:
        for font in fam.get("fonts") or []:
            if not (ROOT / font["asset"]).exists():
                err(f"assets: font '{font['asset']}' is declared but missing")


# 6. design-system tokens ----------------------------------------------------
def members(path: Path, cls: str) -> set[str]:
    src = path.read_text()
    m = re.search(rf"class {cls}\b[^{{]*\{{(.*?)\n\}}", src, re.S)
    body = m.group(1) if m else ""
    return set(re.findall(r"static const (?:[A-Za-z<>?]+ )?(\w+)\s*=", body))


def check_tokens(files: list[Path]) -> None:
    theme = LIB / "Core" / "theme"
    known = {
        "MangoPalette": members(theme / "mango_palette.dart", "MangoPalette"),
        "MangoRadius": members(theme / "mango_tokens.dart", "MangoRadius"),
        "MangoSpace": members(theme / "mango_tokens.dart", "MangoSpace"),
        "MangoSize": members(theme / "mango_tokens.dart", "MangoSize"),
        "MangoMotionTokens": members(theme / "mango_tokens.dart", "MangoMotionTokens"),
    }
    colors = set(re.findall(r"final Color (\w+);", (theme / "mango_colors.dart").read_text()))
    for f in files:
        src = strip_comments(f.read_text(errors="replace"))
        for cls, names in known.items():
            for name in set(re.findall(rf"\b{cls}\.(\w+)", src)):
                if name not in names:
                    err(f"tokens: {rel(f)}: {cls}.{name} does not exist")
        for name in set(re.findall(r"\bcontext\.colors\.(\w+)", src)) | \
                set(re.findall(r"\bc\.(\w+)", src) if "context.colors" in src else []):
            if name not in colors and name not in {"withValues", "toARGB32"}:
                if re.search(rf"\bc\.{name}\b", src) and f"context.colors.{name}" not in src:
                    continue  # `c` may be another variable; only flag explicit uses
                err(f"tokens: {rel(f)}: context.colors.{name} does not exist")


def main() -> int:
    strict = "--strict" in sys.argv
    files = dart_files("lib", "test")
    spec = pubspec()
    check_syntax(files)
    check_imports(files)
    check_packages(files, spec)
    check_assets(spec)
    check_tokens(files)
    for w in warnings:
        print(f"WARN  {w}")
    for e in errors:
        print(f"ERROR {e}")
    print(f"\npreflight: {len(files)} files, {len(errors)} errors, {len(warnings)} warnings")
    return 1 if errors or (strict and warnings) else 0


if __name__ == "__main__":
    sys.exit(main())
