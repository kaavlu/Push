#!/usr/bin/env python3
"""Register Swift source files in Push.xcodeproj (objectVersion 56).

Usage:
  python3 scripts/pbxproj_add.py Data/Domain/Person.swift ...      # app target, paths relative to Push/
  python3 scripts/pbxproj_add.py --target tests DataLayerTests.swift  # test target, relative to PushTests/

IDs are deterministic (md5 of target+path) so re-running is idempotent.
"""
import hashlib
import argparse
import pathlib
import re
import sys

PBXPROJ = pathlib.Path("Push.xcodeproj/project.pbxproj")
VALID_TARGETS = {"app", "tests"}


def hex_id(seed: str) -> str:
    return hashlib.md5(seed.encode()).hexdigest()[:24].upper()


def insert_after(content: str, pattern: str, addition: str) -> str:
    match = re.search(pattern, content, re.MULTILINE)
    if not match:
        sys.exit(f"anchor not found: {pattern}")
    idx = content.index("\n", match.end()) + 1
    return content[:idx] + addition + content[idx:]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Register Swift source files in Push.xcodeproj."
    )
    parser.add_argument(
        "--target",
        choices=sorted(VALID_TARGETS),
        default="app",
        help="Target to register files with. Paths are relative to Push/ for app and PushTests/ for tests.",
    )
    parser.add_argument("files", nargs="+", help="Swift files to register.")
    return parser.parse_args()


def validate_project() -> None:
    if not PBXPROJ.exists():
        sys.exit(f"project file not found: {PBXPROJ}")


def add_file(content: str, rel_path: str, target: str) -> str:
    name = rel_path.split("/")[-1]
    file_ref = hex_id(f"{target}:{rel_path}")
    build = hex_id(f"{target}:{rel_path}:build")
    if file_ref in content:
        print(f"skip (already registered): {rel_path}")
        return content
    content = insert_after(
        content,
        r"^/\* Begin PBXBuildFile section \*/$",
        f"\t\t{build} /* {name} in Sources */ = "
        f"{{isa = PBXBuildFile; fileRef = {file_ref} /* {name} */; }};\n",
    )
    # Always quote name/path: characters like "+" are invalid unquoted in pbxproj.
    if "/" in rel_path:
        path_attr = f'name = "{name}"; path = "{rel_path}"; '
    else:
        path_attr = f'path = "{name}"; '
    content = insert_after(
        content,
        r"^/\* Begin PBXFileReference section \*/$",
        f"\t\t{file_ref} /* {name} */ = {{isa = PBXFileReference; "
        f'lastKnownFileType = sourcecode.swift; {path_attr}sourceTree = "<group>"; }};\n',
    )
    # Anchor on a file that already exists in the right group / build phase.
    group_member = "ContentView.swift" if target == "app" else "PushTests.swift"
    content = insert_after(
        content,
        rf"^\s+\w{{24}} /\* {group_member} \*/,$",
        f"\t\t\t\t{file_ref} /* {name} */,\n",
    )
    content = insert_after(
        content,
        rf"^\s+\w{{24}} /\* {group_member} in Sources \*/,$",
        f"\t\t\t\t{build} /* {name} in Sources */,\n",
    )
    print(f"registered: {rel_path} -> {target}")
    return content


def main() -> None:
    parsed = parse_args()
    validate_project()
    content = PBXPROJ.read_text()
    for rel in parsed.files:
        content = add_file(content, rel, parsed.target)
    PBXPROJ.write_text(content)


main()
