#!/usr/bin/env python3
"""Vibe pre_tool guard: block git commit/push that targets the default branch.

Reads the Vibe hook payload (JSON on stdin), inspects tool_input.command,
and answers with {"decision": "deny", "reason": ...} when the command would
commit to or push the default branch (main/master). Everything else passes
silently (exit 0, no output).

Rule of the repo: changes to the default branch only via a feature branch
and a pull request.
"""
import json
import re
import subprocess
import sys


def deny(reason: str) -> None:
    print(json.dumps({"decision": "deny", "reason": reason}))
    sys.exit(0)


def git(cwd: str, *args: str) -> str:
    try:
        r = subprocess.run(
            ["git", "-C", cwd, *args],
            capture_output=True, text=True, timeout=10,
        )
        return r.stdout.strip() if r.returncode == 0 else ""
    except Exception:
        return ""


def main() -> None:
    payload = json.load(sys.stdin)
    cmd = (payload.get("tool_input") or {}).get("command") or ""
    cwd = payload.get("cwd") or "."

    branch = git(cwd, "rev-parse", "--abbrev-ref", "HEAD") or "HEAD"
    default = git(cwd, "symbolic-ref", "--short", "refs/remotes/origin/HEAD")
    if default.startswith("origin/"):
        default = default[len("origin/"):]
    if not default:
        if git(cwd, "rev-parse", "--verify", "main"):
            default = "main"
        elif git(cwd, "rev-parse", "--verify", "master"):
            default = "master"
        else:
            default = "main"

    # Walk each segment of a compound command (&&, ||, ;, |) in order,
    # tracking the "effective branch" so that e.g.
    #   git switch -c feat/x && git commit -m x && git push
    # is judged on feat/x, not on the branch before the command ran.
    segments = re.split(r"&&|\|\||;|\|", cmd)
    eff_branch = branch
    saw_git = False
    for seg in segments:
        m = re.search(
            r"\bgit\b((?:\s+(?:-[A-Za-z-]+|--[\w-]+(?:=\S+)?))*)\s+([A-Za-z-]+)(.*)",
            seg,
        )
        if not m:
            continue
        saw_git = True
        sub, rest = m.group(2), m.group(3)
        toks = [t for t in rest.split() if t and not t.startswith("-")]

        if sub in ("switch", "checkout"):
            # target branch = last non-option token (branch name for -c/-b too)
            if toks:
                eff_branch = toks[-1]
        elif sub == "commit":
            if eff_branch == default:
                deny(
                    f"git commit on the default branch '{default}' (effective branch here: '{eff_branch}'). "
                    f"Create a feature branch first (git switch -c <topic>) and open a PR; "
                    f"'{default}' only changes via pull request."
                )
        elif sub == "push":
            if eff_branch == default:
                deny(
                    f"git push from the default branch '{default}'. "
                    f"Push a feature branch and open a PR instead."
                )
            if any(t in ("--all", "--mirror") for t in rest.split()):
                deny("git push --all/--mirror can publish the default branch; push a feature branch + PR instead.")
            for t in toks:
                if t == default or t.endswith(":" + default):
                    deny(
                        f"git push targets the default branch '{default}' ({t}). "
                        f"Push a feature branch and open a PR instead."
                    )

    if not saw_git:
        return  # not a git command


if __name__ == "__main__":
    main()
