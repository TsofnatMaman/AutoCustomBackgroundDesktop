"""Safely synchronize fork and branch metadata into the installer files.

Never embed GitHub context expressions directly in shell or PowerShell source.
The branch name is data, even when it contains quotes or shell metacharacters.
"""

import json
import os
from pathlib import Path
import re


def powershell_literal(value: str) -> str:
    """Return a single-quoted, non-interpolating PowerShell string literal."""
    return "'" + value.replace("'", "''") + "'"


def sync_metadata(root: Path, repository: str, branch: str) -> tuple[bool, bool]:
    if repository.count("/") != 1 or not all(repository.split("/")):
        raise ValueError("GITHUB_REPOSITORY must be in owner/repository format")
    if not branch or "\n" in branch or "\r" in branch:
        raise ValueError("GITHUB_REF_NAME must be a non-empty branch name")

    owner, repo_name = repository.split("/", 1)
    config_path = root / "Src" / "config.json"
    install_path = root / "Src" / "install.ps1"

    config_before = config_path.read_text(encoding="utf-8-sig")
    config = json.loads(config_before)
    expected = {"username": owner, "repository": repo_name, "branch": branch}
    config_changed = any(config["github"].get(key) != value for key, value in expected.items())
    if config_changed:
        config["github"].update(expected)
        config_path.write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n", encoding="utf-8-sig")

    install_before = install_path.read_text(encoding="utf-8-sig")
    install_after = install_before
    assignments = {
        "$githubUsername": owner,
        "$githubRepoName": repo_name,
        "$githubBranchName": branch,
    }
    for var_name, value in assignments.items():
        pattern = re.compile(r"^" + re.escape(var_name) + r"\s*=\s*[^\r\n]*$", re.MULTILINE)
        install_after, matches = pattern.subn(lambda _: f"{var_name} = {powershell_literal(value)}", install_after)
        if matches != 1:
            raise ValueError(f"Expected one assignment for {var_name}; found {matches}")
    install_changed = install_after != install_before
    if install_changed:
        install_path.write_text(install_after, encoding="utf-8-sig")

    return config_changed, install_changed


def main() -> None:
    repo = os.environ["GITHUB_REPOSITORY"]
    branch = os.environ["GITHUB_REF_NAME"]
    config_changed, install_changed = sync_metadata(Path("."), repo, branch)
    print(f"Repository: {repo}; branch: {branch}")
    print(f"Config updated: {config_changed}; installer updated: {install_changed}")
    output_file = os.environ.get("GITHUB_OUTPUT")
    if output_file:
        with open(output_file, "a", encoding="utf-8") as output:
            output.write(f"config-updated={str(config_changed).lower()}\n")
            output.write(f"install-updated={str(install_changed).lower()}\n")


if __name__ == "__main__":
    main()
