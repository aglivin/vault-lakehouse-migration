import argparse
from pathlib import Path

from data_generator.render_v1 import render_v1
from data_generator.render_v2 import render_v2
from data_generator.totals import write_expected_totals
from data_generator.world import build_world

DEFAULT_TOTALS = Path(__file__).resolve().parents[1] / "dbt/seeds/expected_totals.csv"


def main() -> None:
    parser = argparse.ArgumentParser(prog="data_generator")
    parser.add_argument("--customers", type=int, default=2000)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--out", type=Path, default=Path("data/out"))
    parser.add_argument("--totals-out", type=Path, default=DEFAULT_TOTALS)
    args = parser.parse_args()
    world = build_world(args.customers, args.seed)
    render_v1(world, args.out)
    render_v2(world, args.out)
    write_expected_totals(world, args.totals_out)


if __name__ == "__main__":
    main()
