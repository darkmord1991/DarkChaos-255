#!/usr/bin/env python3
"""Compile the DC LabTools core files (lab probe result book, bug-report validation, rate limit and
spool writer) against a stub Define.h and run their checks.

The fork's unit_tests target does not link (see src/test/CMakeLists.txt), so this is the automated check
of that logic. Needs a C++20 g++ or clang++ on PATH (or $CXX); the worldserver build is not involved and
the binary is built in a temporary directory, so nothing lands in the tree.

    python apps/dc_labtools_check/run.py
"""
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
LABTOOLS = os.path.normpath(os.path.join(HERE, "..", "..", "src", "server", "scripts", "DC", "LabTools"))
SOURCES = [
    os.path.join(HERE, "core_test.cpp"),
    os.path.join(LABTOOLS, "dc_lab_probe_core.cpp"),
    os.path.join(LABTOOLS, "dc_bug_report_core.cpp"),
]


def main():
    compiler = os.environ.get("CXX") or shutil.which("g++") or shutil.which("clang++")
    if not compiler:
        print("dc_labtools_check: no g++ or clang++ on PATH")
        return 2

    with tempfile.TemporaryDirectory(prefix="dc_labtools_") as out:
        binary = os.path.join(out, "dc_labtools_check" + (".exe" if os.name == "nt" else ""))
        command = [compiler, "-std=c++20", "-Wall", "-Wextra", "-Werror", "-I", os.path.join(HERE, "stubs"),
                   "-I", LABTOOLS, "-o", binary] + SOURCES
        build = subprocess.run(command, capture_output=True, text=True)
        if build.returncode != 0:
            print(build.stdout + build.stderr)
            print("dc_labtools_check: build failed")
            return 1

        run = subprocess.run([binary], capture_output=True, text=True)
        print(run.stdout, end="")
        if run.stderr:
            print(run.stderr, end="")
        return run.returncode


if __name__ == "__main__":
    sys.exit(main())
