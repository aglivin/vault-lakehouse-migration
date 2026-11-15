from decimal import Decimal
from pathlib import Path

from data_generator.render_v1 import write_csv
from data_generator.world import LOAD_DATES, World


def active_contracts(world: World, day) -> int:
    state = {}
    for row in sorted((r for r in world.contracts if r["_load_date"] <= day), key=lambda r: r["_load_date"]):
        if row["op"] == "D":
            state.pop(row["contract_no"], None)
        else:
            state[row["contract_no"]] = row["status"]
    return sum(status == "active" for status in state.values())


def expected_totals(world: World) -> list[tuple[str, str, Decimal]]:
    result = []
    for day in LOAD_DATES:
        customers = {r["customer_no"] for r in world.customers if r["_load_date"] <= day}
        invoices = [r for r in world.invoices if r["_load_date"] <= day]
        net = sum((r["net_amount"] for r in world.invoice_lines if r["_load_date"] <= day), Decimal("0.00"))
        vat = sum(
            (r["tax_amount"] for r in world.invoice_lines if r["_load_date"] <= day and r["line_type"] == "vat"),
            Decimal("0.00"),
        )
        iso = day.isoformat()
        result += [
            (iso, "customer_count", Decimal(len(customers))),
            (iso, "active_contracts", Decimal(active_contracts(world, day))),
            (iso, "invoice_count", Decimal(len(invoices))),
            (iso, "invoiced_net_total", net),
            (iso, "vat_total", vat),
        ]
    return result


def write_expected_totals(world: World, path: Path) -> None:
    rows = [dict(load_date=d, metric=m, value=v) for d, m, v in expected_totals(world)]
    write_csv(path, ["load_date", "metric", "value"], rows)
