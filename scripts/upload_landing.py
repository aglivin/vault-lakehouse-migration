import argparse
import subprocess
import sys
from pathlib import Path

STAGE = "@VDWH_DEV.RAW.LANDING"
VOLUME = "dbfs:/Volumes/vdwh_dev/raw/landing"
SNOWFLAKE_CONNECTION = "personal"
DATABRICKS_PROFILE = "personal"


def landing_files(out: Path, load_date: str) -> list[Path]:
    return sorted(out.glob(f"*/*/{load_date}.csv"))


def build_commands(target: str, load_date: str, out: Path) -> list[list[str]]:
    commands = []
    for file in landing_files(out, load_date):
        entity_dir = file.parent
        system = entity_dir.parent.name
        if target == "snowflake":
            destination = f"{STAGE}/{system}/{entity_dir.name}/"
            commands.append(
                ["snow", "stage", "copy", str(file), destination, "--overwrite", "--connection", SNOWFLAKE_CONNECTION]
            )
        elif target == "databricks":
            directory = f"{VOLUME}/{system}/{entity_dir.name}"
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
    parser.add_argument("--load-date", required=True)
    parser.add_argument("--out", type=Path, default=Path("data/out"))
    args = parser.parse_args(argv)
    commands = build_commands(args.target, args.load_date, args.out)
    if not commands:
        print(f"no files for {args.load_date} in {args.out}", file=sys.stderr)
        return 1
    for command in commands:
        subprocess.run(command, check=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
