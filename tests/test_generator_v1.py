import csv
from collections import defaultdict
from decimal import Decimal
from pathlib import Path

import pytest

from data_generator.render_v1 import LAYOUT, render_v1
from data_generator.totals import expected_totals, write_expected_totals
from data_generator.world import LOAD_DATES, build_world

ROOT = Path(__file__).resolve().parent.parent
DAYS = [d.isoformat() for d in LOAD_DATES]


def read_all(out: Path, entity: str) -> list[dict]:
    system = next(s for s, entities in LAYOUT.items() if entity in entities)
    rows = []
    for day in DAYS:
        with (out / system / entity / f"{day}.csv").open(newline="") as handle:
            rows += [dict(row, load_date=day) for row in csv.DictReader(handle)]
    return rows


@pytest.fixture(scope="module")
def world():
    return build_world(customers=300, seed=7)


@pytest.fixture(scope="module")
def out(world, tmp_path_factory):
    path = tmp_path_factory.mktemp("out")
    render_v1(world, path)
    return path


def test_same_seed_gives_identical_files(out, tmp_path):
    render_v1(build_world(customers=300, seed=7), tmp_path)
    for file in out.rglob("*.csv"):
        assert file.read_bytes() == (tmp_path / file.relative_to(out)).read_bytes()


@pytest.mark.parametrize(
    "entity, column, parent, parent_key",
    [
        ("customer_phones", "customer_no", "customers", "customer_no"),
        ("contacts", "customer_no", "customers", "customer_no"),
        ("contracts", "customer_no", "customers", "customer_no"),
        ("contracts", "tariff_code", "tariffs", "tariff_code"),
        ("contracts", "meter_no", "meters", "meter_no"),
        ("invoices", "contract_no", "contracts", "contract_no"),
        ("invoice_lines", "invoice_no", "invoices", "invoice_no"),
        ("invoice_lines", "tariff_code", "tariffs", "tariff_code"),
        ("payments", "invoice_no", "invoices", "invoice_no"),
    ],
)
def test_foreign_keys_exist(out, entity, column, parent, parent_key):
    parents = {r[parent_key] for r in read_all(out, parent)}
    assert {r[column] for r in read_all(out, entity)} <= parents


@pytest.mark.parametrize("day, ops", [(DAYS[0], {"I"}), (DAYS[1], {"I", "U", "D"}), (DAYS[2], {"I", "U", "D"})])
def test_contract_ops_per_load_date(out, day, ops):
    assert {r["op"] for r in read_all(out, "contracts") if r["load_date"] == day} == ops


def test_recreated_contract_is_deleted_then_inserted(world, out):
    events = [(r["load_date"], r["op"]) for r in read_all(out, "contracts") if r["contract_no"] == world.recreated_contract_no]
    assert events == [(DAYS[0], "I"), (DAYS[1], "D"), (DAYS[2], "I")]


def test_net_amount_in_files_matches_expected_totals(world, out):
    lines = read_all(out, "invoice_lines")
    totals = {(d, m): v for d, m, v in expected_totals(world)}
    for day in DAYS:
        loaded = sum(Decimal(r["net_amount"]) for r in lines if r["load_date"] <= day)
        assert loaded == totals[(day, "invoiced_net_total")]


def test_vat_line_is_twenty_percent_of_other_lines(out):
    lines = read_all(out, "invoice_lines")
    nets = defaultdict(Decimal)
    for r in lines:
        nets[r["invoice_no"]] += Decimal(r["net_amount"])
    assert {r["line_type"] for r in lines} == {"energy", "base_fee", "vat", "energy_tax"}
    for r in (r for r in lines if r["line_type"] == "vat"):
        assert Decimal(r["net_amount"]) == 0
        assert Decimal(r["tax_amount"]) == (Decimal("0.20") * nets[r["invoice_no"]]).quantize(Decimal("0.01"))


def test_committed_expected_totals_are_reproducible(tmp_path):
    target = tmp_path / "expected_totals.csv"
    write_expected_totals(build_world(customers=2000, seed=42), target)
    assert target.read_bytes() == (ROOT / "dbt/seeds/expected_totals.csv").read_bytes()
