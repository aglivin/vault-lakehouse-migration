import csv
from pathlib import Path

from data_generator.world import V1_DATES, World

LAYOUT = {
    "crm_v1": {
        "customers": "customer_no first_name last_name email birth_date street city postal_code segment updated_at op",
        "customer_phones": "customer_no phone_type phone_number op",
        "contacts": "contact_id customer_no contact_ts channel reason resolved_first_contact",
    },
    "billing_v1": {
        "tariffs": "tariff_code commodity name price_per_kwh base_fee_month valid_from",
        "meters": "meter_no commodity install_date",
        "contracts": "contract_no customer_no tariff_code meter_no start_date end_date status op",
        "invoices": "invoice_no contract_no invoice_date period_from period_to due_date",
        "invoice_lines": "invoice_no line_no tariff_code line_type kwh net_amount tax_rate tax_amount",
        "payments": "payment_id invoice_no payment_date amount",
    },
}


def write_csv(path: Path, columns: list[str], rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, columns, extrasaction="ignore", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def render_v1(world: World, out: Path) -> None:
    for system, entities in LAYOUT.items():
        for entity, columns in entities.items():
            for day in V1_DATES:
                rows = [r for r in getattr(world, entity) if r["_load_date"] == day]
                write_csv(out / system / entity / f"{day.isoformat()}.csv", columns.split(), rows)
