import argparse
import os
import subprocess
import sys
from datetime import date
from pathlib import Path

from data_generator.world import CUTOVER_DATE

SNOWFLAKE_CONNECTION = "personal"
DATABRICKS_PROFILE = "personal"


def landing_files(out: Path, load_date: str) -> list[Path]:
    version = "v2" if date.fromisoformat(load_date) >= CUTOVER_DATE else "v1"
    return sorted(out.glob(f"*_{version}/*/{load_date}.csv"))


def stage() -> str:
    return f"@{os.environ.get('SNOWFLAKE_DATABASE', 'VDWH_DEV')}.RAW.LANDING"


def volume() -> str:
    return f"dbfs:/Volumes/{os.environ.get('DATABRICKS_CATALOG', 'vdwh_dev')}/raw/landing"


def build_commands(target: str, load_date: str, out: Path) -> list[list[str]]:
    commands = []
    for file in landing_files(out, load_date):
        entity_dir = file.parent
        system = entity_dir.parent.name
        if target == "snowflake":
            destination = f"{stage()}/{system}/{entity_dir.name}/"
            commands.append(
                ["snow", "stage", "copy", str(file), destination, "--overwrite", "--connection", SNOWFLAKE_CONNECTION]
            )
        elif target == "databricks":
            directory = f"{volume()}/{system}/{entity_dir.name}"
            destination = f"{directory}/{file.name}"
            commands.append(["databricks", "fs", "mkdirs", directory, "--profile", DATABRICKS_PROFILE])
            commands.append(
                ["databricks", "fs", "cp", str(file), destination, "--overwrite", "--profile", DATABRICKS_PROFILE]
            )
        else:
            raise ValueError(f"unknown target: {target}")
    return commands


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", choices=["snowflake", "databricks"], required=True)
    parser.add_argument("--load-date", type=date.fromisoformat, required=True)
    parser.add_argument("--out", type=Path, default=Path("data/out"))
    args = parser.parse_args(argv)
    commands = build_commands(args.target, args.load_date.isoformat(), args.out)
    if not commands:
        print(f"no files for {args.load_date} in {args.out}", file=sys.stderr)
        return 1
    for command in commands:
        subprocess.run(command, check=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
