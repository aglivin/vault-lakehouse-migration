import csv
from decimal import Decimal
from pathlib import Path

import pytest

from data_generator.render_v1 import LAYOUT as LAYOUT_V1, render_v1
from data_generator.render_v2 import LAYOUT, render_v2
from data_generator.totals import expected_totals, write_expected_totals
from data_generator.world import CUTOVER_DATE, LOAD_DATES, V1_DATES, V2_DATES, build_world

ROOT = Path(__file__).resolve().parent.parent
CUTOVER = CUTOVER_DATE.isoformat()
LAST_V1 = V1_DATES[-1].isoformat()
V2_DAYS = [d.isoformat() for d in V2_DATES]


def read(out: Path, entity: str, days=None) -> list[dict]:
    system = next(s for s, entities in {**LAYOUT_V1, **LAYOUT}.items() if entity in entities)
    rows = []
    for day in days or (V2_DAYS if system.endswith("v2") else [d.isoformat() for d in V1_DATES]):
        with (out / system / entity / f"{day}.csv").open(newline="") as handle:
            rows += [dict(row, load_date=day) for row in csv.DictReader(handle)]
    return rows


def key_map(out: Path, system: str, entity: str) -> dict[str, str]:
    path = out / system / "key_map" / f"{CUTOVER}.csv"
    with path.open(newline="") as handle:
        return {r["v1_key"]: r["v2_key"] for r in csv.DictReader(handle) if r["entity"] == entity}


@pytest.fixture(scope="module")
def world():
    return build_world(customers=300, seed=7)


@pytest.fixture(scope="module")
def out(world, tmp_path_factory):
    path = tmp_path_factory.mktemp("out")
    render_v1(world, path)
    render_v2(world, path)
    return path


def live_contracts_at_cutover(out: Path) -> dict[str, dict]:
    state = {}
    for r in read(out, "contracts"):
        if r["op"] == "D":
            state.pop(r["contract_no"], None)
        else:
            state[r["contract_no"]] = r
    return state


def test_same_seed_gives_identical_v2_files(out, tmp_path):
    render_v2(build_world(customers=300, seed=7), tmp_path)
    files = list(out.glob("*_v2/*/*.csv"))
    assert len(files) == sum(len(e) for e in LAYOUT.values()) * len(V2_DAYS)
    for file in files:
        assert file.read_bytes() == (tmp_path / file.relative_to(out)).read_bytes()


def test_v1_and_v2_files_exist_only_for_their_dates(out):
    assert {p.stem for p in out.glob("*_v1/*/*.csv")} == {d.isoformat() for d in V1_DATES}
    assert {p.stem for p in out.glob("*_v2/*/*.csv")} == set(V2_DAYS)


@pytest.mark.parametrize(
    "entity, column, parent, parent_key",
    [
        ("agreements", "account_uuid", "accounts", "account_uuid"),
        ("agreements", "product_code", "products", "product_code"),
        ("agreements", "meter_point_id", "meter_points", "meter_point_id"),
        ("account_phones", "account_uuid", "accounts", "account_uuid"),
        ("interactions", "account_uuid", "accounts", "account_uuid"),
        ("documents", "agreement_id", "agreements", "agreement_id"),
        ("document_lines", "document_id", "documents", "document_id"),
        ("document_lines", "product_code", "products", "product_code"),
        ("settlements", "document_id", "documents", "document_id"),
    ],
)
def test_foreign_keys_exist_inside_v2(out, entity, column, parent, parent_key):
    assert {r[column] for r in read(out, entity)} <= {r[parent_key] for r in read(out, parent)}


def test_every_v1_customer_and_live_contract_has_one_key_map_row(out):
    customers = [r["customer_no"] for r in read(out, "customers")]
    with (out / "crm_v2/key_map" / f"{CUTOVER}.csv").open(newline="") as handle:
        rows = list(csv.DictReader(handle))
    assert sorted(r["v1_key"] for r in rows) == sorted(set(customers))
    assert {r["entity"] for r in rows} == {"customer"}
    contract_map = key_map(out, "billing_v2", "contract")
    live = live_contracts_at_cutover(out)
    assert set(contract_map) <= set(live)
    assert {live[n]["status"] for n in set(live) - set(contract_map)} == {"terminated"}
    assert len(contract_map) == len(set(contract_map.values()))


def test_non_migrated_contracts_are_about_one_percent_and_have_no_v2_key(out):
    live = live_contracts_at_cutover(out)
    contract_map = key_map(out, "billing_v2", "contract")
    skipped = set(live) - set(contract_map)
    assert 0 < len(skipped) <= max(2, round(len(live) * 0.02))
    assert {live[n]["status"] for n in skipped} == {"terminated"}
    assert {r["agreement_id"] for r in read(out, "agreements")} >= set(contract_map.values())


def test_new_customers_in_v2_are_about_one_percent_and_have_no_v1_key(out):
    mapped = set(key_map(out, "crm_v2", "customer").values())
    accounts = {r["account_uuid"] for r in read(out, "accounts")}
    fresh = accounts - mapped
    assert mapped <= accounts
    assert 0.005 <= len(fresh) / len(accounts) <= 0.03


def test_reissued_history_keeps_v1_net_total(out):
    document_map = key_map(out, "billing_v2", "invoice")
    contract_of = {r["invoice_no"]: r["contract_no"] for r in read(out, "invoices")}
    assert set(document_map) <= set(contract_of)
    v1_net = sum(
        Decimal(r["net_amount"]) for r in read(out, "invoice_lines") if r["invoice_no"] in document_map
    )
    v2_net = sum(
        Decimal(r["amount_net"])
        for r in read(out, "document_lines", [CUTOVER])
        if r["document_id"] in set(document_map.values())
    )
    assert v2_net == v1_net
    assert len(document_map) == len(set(document_map.values()))


def test_vat_stays_on_vat_line(out):
    lines = read(out, "document_lines")
    assert {r["charge_type"] for r in lines} == {"energy", "base_fee", "vat", "energy_tax"}
    assert all((Decimal(r["vat_amount"]) != 0) == (r["charge_type"] == "vat") for r in lines)


def test_key_map_only_on_cutover_day(out):
    for system in ("crm_v2", "billing_v2"):
        assert len((out / system / "key_map" / f"{V2_DAYS[1]}.csv").read_text().splitlines()) == 1


def test_expected_totals_continue_without_double_counting(world, out):
    totals = {(d, m): v for d, m, v in expected_totals(world)}
    assert {d for d, _ in totals} == {d.isoformat() for d in LOAD_DATES}
    for day in V2_DAYS:
        assert totals[(day, "customer_count")] > totals[(LAST_V1, "customer_count")]
    v1_invoices = {r["invoice_no"] for r in read(out, "invoices")}
    new_documents = [r for r in read(out, "documents") if r["load_date"] == V2_DAYS[1]]
    assert totals[(V2_DAYS[1], "invoice_count")] == len(v1_invoices) + len(
        [r for r in read(out, "documents", [CUTOVER]) if r["issued_on"] == CUTOVER]
    ) + len(new_documents)


def test_committed_expected_totals_include_v2_days(tmp_path):
    target = tmp_path / "expected_totals.csv"
    write_expected_totals(build_world(customers=2000, seed=42), target)
    assert target.read_bytes() == (ROOT / "dbt/seeds/expected_totals.csv").read_bytes()
    assert {r["load_date"] for r in csv.DictReader(target.open())} == {d.isoformat() for d in LOAD_DATES}

