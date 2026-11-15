import csv
from decimal import Decimal
from pathlib import Path

import pytest

from data_generator.render_v1 import render_v1
from data_generator.totals import expected_totals, write_expected_totals
from data_generator.world import LOAD_DATES, build_world

ROOT = Path(__file__).resolve().parent.parent
DAYS = [d.isoformat() for d in LOAD_DATES]


def read_all(out: Path, system: str, entity: str) -> list[dict]:
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


def test_entity_folders(out):
    folders = [p for system in ("crm_v1", "billing_v1") for p in (out / system).iterdir()]
    assert len(folders) == 9
    assert all(len(list(p.glob("*.csv"))) == 3 for p in folders)


def test_same_seed_gives_identical_files(out, tmp_path):
    render_v1(build_world(customers=300, seed=7), tmp_path)
    for file in out.rglob("*.csv"):
        assert file.read_bytes() == (tmp_path / file.relative_to(out)).read_bytes()


def test_foreign_keys_exist(out):
    keys = {
        ("crm_v1", "customers", "customer_no"): [],
        ("billing_v1", "tariffs", "tariff_code"): [],
        ("billing_v1", "meters", "meter_no"): [],
        ("billing_v1", "contracts", "contract_no"): [],
        ("billing_v1", "invoices", "invoice_no"): [],
    }
    parents = {k: {r[k[2]] for r in read_all(out, k[0], k[1])} for k in keys}
    references = [
        ("crm_v1", "customer_phones", "customer_no", "customers"),
        ("crm_v1", "contacts", "customer_no", "customers"),
        ("billing_v1", "contracts", "customer_no", "customers"),
        ("billing_v1", "contracts", "tariff_code", "tariffs"),
        ("billing_v1", "contracts", "meter_no", "meters"),
        ("billing_v1", "invoices", "contract_no", "contracts"),
        ("billing_v1", "invoice_lines", "invoice_no", "invoices"),
        ("billing_v1", "invoice_lines", "tariff_code", "tariffs"),
        ("billing_v1", "payments", "invoice_no", "invoices"),
    ]
    by_entity = {k[1]: v for k, v in parents.items()}
    for system, entity, column, parent in references:
        children = {r[column] for r in read_all(out, system, entity)}
        assert children <= by_entity[parent], (entity, column)


def test_full_load_is_inserts_only(out):
    rows = [r for r in read_all(out, "billing_v1", "contracts") if r["load_date"] == DAYS[0]]
    assert {r["op"] for r in rows} == {"I"}


@pytest.mark.parametrize("day", DAYS[1:])
def test_delta_days_contain_insert_update_delete(out, day):
    ops = {r["op"] for r in read_all(out, "billing_v1", "contracts") if r["load_date"] == day}
    assert ops == {"I", "U", "D"}


def test_recreated_contract_is_deleted_then_inserted(world, out):
    events = [
        (r["load_date"], r["op"])
        for r in read_all(out, "billing_v1", "contracts")
        if r["contract_no"] == world.recreated_contract_no
    ]
    assert events == [(DAYS[0], "I"), (DAYS[1], "D"), (DAYS[2], "I")]


def test_net_amount_in_files_matches_expected_totals(world, out):
    lines = read_all(out, "billing_v1", "invoice_lines")
    totals = {(d, m): v for d, m, v in expected_totals(world)}
    for day in DAYS:
        loaded = sum(Decimal(r["net_amount"]) for r in lines if r["load_date"] <= day)
        assert loaded == totals[(day, "invoiced_net_total")]


def test_line_types(out):
    lines = read_all(out, "billing_v1", "invoice_lines")
    assert {r["line_type"] for r in lines} == {"energy", "base_fee", "vat", "energy_tax"}


def test_expected_totals_metrics_per_load_date(world):
    metrics = {(d, m) for d, m, _ in expected_totals(world)}
    names = {"customer_count", "active_contracts", "invoice_count", "invoiced_net_total"}
    assert metrics == {(d, m) for d in DAYS for m in names}


def test_committed_expected_totals_are_reproducible(tmp_path):
    target = tmp_path / "expected_totals.csv"
    write_expected_totals(build_world(customers=2000, seed=42), target)
    assert target.read_bytes() == (ROOT / "dbt/seeds/expected_totals.csv").read_bytes()
