import argparse
from pathlib import Path

from data_generator.render_v1 import render_v1
from data_generator.totals import write_expected_totals
from data_generator.world import build_world


def main() -> None:
    parser = argparse.ArgumentParser(prog="data_generator")
    parser.add_argument("--customers", type=int, default=2000)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--out", type=Path, default=Path("data/out"))
    parser.add_argument("--totals", type=Path, default=Path("dbt/seeds/expected_totals.csv"))
    args = parser.parse_args()
    world = build_world(args.customers, args.seed)
    render_v1(world, args.out)
    write_expected_totals(world, args.totals)


main()
