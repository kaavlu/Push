#!/usr/bin/env python3
"""Register Swift source files in Push.xcodeproj (objectVersion 56).

Usage:
  python3 scripts/pbxproj_add.py Data/Domain/Person.swift ...      # app target, paths relative to Push/
  python3 scripts/pbxproj_add.py --target tests DataLayerTests.swift  # test target, relative to PushTests/

IDs are deterministic (md5 of target+path) so re-running is idempotent.
"""
import hashlib
import pathlib
import re
import sys

PBXPROJ = pathlib.Path("Push.xcodeproj/project.pbxproj")


def hex_id(seed: str) -> str:
    return hashlib.md5(seed.encode()).hexdigest()[:24].upper()


def insert_after(content: str, pattern: str, addition: str) -> str:
    match = re.search(pattern, content, re.MULTILINE)
    if not match:
        sys.exit(f"anchor not found: {pattern}")
    idx = content.index("\n", match.end()) + 1
    return content[:idx] + addition + content[idx:]


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
    if "/" in rel_path:
        path_attr = f'name = {name}; path = "{rel_path}"; '
    else:
        path_attr = f"path = {name}; "
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
    args = sys.argv[1:]
    target = "app"
    if args[:1] == ["--target"]:
        target = "tests" if args[1] == "tests" else "app"
        args = args[2:]
    if not args:
        sys.exit("no files given")
    content = PBXPROJ.read_text()
    for rel in args:
        content = add_file(content, rel, target)
    PBXPROJ.write_text(content)


main()
