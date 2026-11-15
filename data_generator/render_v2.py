import random
import uuid
from datetime import timedelta
from pathlib import Path

from data_generator.render_v1 import write_csv
from data_generator.world import CUTOVER_DATE, V2_DATES, World

KEY_MAP_COLUMNS = "entity v1_key v2_key"
NON_MIGRATED_SHARE = 0.01
STATUS = {"active": "ACTIVE", "terminated": "TERMINATED"}

LAYOUT = {
    "crm_v2": {
        "accounts": "account_uuid given_name family_name email_address date_of_birth street_line town zip customer_segment changed_at op",
        "account_phones": "account_uuid phone_kind phone_value op",
        "interactions": "interaction_id account_uuid occurred_at channel topic first_contact_resolution",
        "key_map": KEY_MAP_COLUMNS,
    },
    "billing_v2": {
        "products": "product_code commodity product_name unit_price_kwh monthly_fee available_from",
        "meter_points": "meter_point_id commodity installed_on",
        "agreements": "agreement_id account_uuid product_code meter_point_id valid_from valid_to agreement_status op",
        "documents": "document_id agreement_id issued_on billing_from billing_to payable_by",
        "document_lines": "document_id position product_code charge_type quantity_kwh amount_net vat_rate vat_amount",
        "settlements": "settlement_id document_id settled_on settled_amount",
        "key_map": KEY_MAP_COLUMNS,
    },
}


def first_seen(rows: list[dict], column: str) -> dict[str, dict]:
    seen = {}
    for row in rows:
        seen.setdefault(row[column], row)
    return seen


def numbered(prefix: str, width: int, keys) -> dict[str, str]:
    return {key: f"{prefix}{number:0{width}d}" for number, key in enumerate(keys, 1)}


def latest_state(rows: list[dict], key, upto) -> list[dict]:
    state = {}
    for row in sorted((r for r in rows if r["_load_date"] <= upto), key=lambda r: r["_load_date"]):
        if row["op"] == "D":
            state.pop(key(row), None)
        else:
            state[key(row)] = dict(row, op="I")
    return list(state.values())


class Plan:
    def __init__(self, world: World):
        self.world = world
        self.before = CUTOVER_DATE - timedelta(1)
        rng = random.Random(f"v2-{world.seed}")
        customers = first_seen(world.customers, "customer_no")
        self.account = {no: str(uuid.UUID(int=rng.getrandbits(128), version=4)) for no in customers}
        live = latest_state(world.contracts, lambda r: r["contract_no"], self.before)
        self.skipped = self.pick_non_migrated(rng, live)
        alive = {r["contract_no"] for r in latest_state(world.contracts, lambda r: r["contract_no"], CUTOVER_DATE)}
        seen_before = {r["contract_no"] for r in world.contracts if r["_load_date"] <= self.before}
        dropped = self.skipped | (seen_before - alive)
        contracts = [no for no in first_seen(world.contracts, "contract_no") if no not in dropped]
        self.agreement = numbered("AGR-", 7, contracts)
        self.product = {code: f"PRD-{code}" for code in first_seen(world.tariffs, "tariff_code")}
        self.meter_point = numbered("MP-", 7, first_seen(world.meters, "meter_no"))
        invoices = [no for no, r in first_seen(world.invoices, "invoice_no").items() if r["contract_no"] in self.agreement]
        self.document = numbered("DOC-", 9, invoices)
        self.settlement = numbered("STL-", 9, (r["payment_id"] for r in world.payments if r["invoice_no"] in self.document))
        self.interaction = numbered("IA-", 8, (r["contact_id"] for r in world.contacts))

    def pick_non_migrated(self, rng: random.Random, live: list[dict]) -> set[str]:
        closed = sorted(r["contract_no"] for r in live if r["end_date"] == self.before.isoformat())
        size = min(len(closed), max(1, round(len(live) * NON_MIGRATED_SHARE)))
        return set(rng.sample(closed, size))

    def history(self, table: list[dict], day, key=None) -> list[dict]:
        if day != CUTOVER_DATE:
            return [r for r in table if r["_load_date"] == day]
        if key is None:
            return [r for r in table if r["_load_date"] <= day]
        return latest_state(table, key, day)

    def key_map(self, system: str) -> list[dict]:
        w = self.world

        def old(table: list[dict], column: str) -> set[str]:
            return {r[column] for r in table if r["_load_date"] <= self.before}

        groups = {
            "crm_v2": [("customer", old(w.customers, "customer_no"), self.account)],
            "billing_v2": [
                ("contract", old(w.contracts, "contract_no"), self.agreement),
                ("invoice", old(w.invoices, "invoice_no"), self.document),
                ("tariff", old(w.tariffs, "tariff_code"), self.product),
                ("meter", old(w.meters, "meter_no"), self.meter_point),
            ],
        }[system]
        return [
            dict(entity=entity, v1_key=key, v2_key=mapping[key])
            for entity, keys, mapping in groups
            for key in sorted(keys & mapping.keys())
        ]

    def accounts(self, day) -> list[dict]:
        return [
            {
                "account_uuid": self.account[r["customer_no"]],
                "given_name": r["first_name"],
                "family_name": r["last_name"],
                "email_address": r["email"],
                "date_of_birth": r["birth_date"],
                "street_line": r["street"],
                "town": r["city"],
                "zip": r["postal_code"],
                "customer_segment": r["segment"],
                "changed_at": r["updated_at"],
                "op": r["op"],
            }
            for r in self.history(self.world.customers, day, lambda r: r["customer_no"])
        ]

    def account_phones(self, day) -> list[dict]:
        rows = self.history(self.world.customer_phones, day, lambda r: (r["customer_no"], r["phone_type"]))
        return [
            {"account_uuid": self.account[r["customer_no"]], "phone_kind": r["phone_type"], "phone_value": r["phone_number"], "op": r["op"]}
            for r in rows
        ]

    def interactions(self, day) -> list[dict]:
        return [
            {
                "interaction_id": self.interaction[r["contact_id"]],
                "account_uuid": self.account[r["customer_no"]],
                "occurred_at": r["contact_ts"],
                "channel": r["channel"],
                "topic": r["reason"],
                "first_contact_resolution": r["resolved_first_contact"],
            }
            for r in self.history(self.world.contacts, day)
        ]

    def products(self, day) -> list[dict]:
        return [
            {
                "product_code": self.product[r["tariff_code"]],
                "commodity": r["commodity"],
                "product_name": r["name"],
                "unit_price_kwh": r["price_per_kwh"],
                "monthly_fee": r["base_fee_month"],
                "available_from": r["valid_from"],
            }
            for r in self.history(self.world.tariffs, day)
        ]

    def meter_points(self, day) -> list[dict]:
        return [
            {"meter_point_id": self.meter_point[r["meter_no"]], "commodity": r["commodity"], "installed_on": r["install_date"]}
            for r in self.history(self.world.meters, day)
        ]

    def agreements(self, day) -> list[dict]:
        rows = self.history(self.world.contracts, day, lambda r: r["contract_no"])
        return [
            {
                "agreement_id": self.agreement[r["contract_no"]],
                "account_uuid": self.account[r["customer_no"]],
                "product_code": self.product[r["tariff_code"]],
                "meter_point_id": self.meter_point[r["meter_no"]],
                "valid_from": r["start_date"],
                "valid_to": r["end_date"],
                "agreement_status": STATUS[r["status"]],
                "op": r["op"],
            }
            for r in rows
            if r["contract_no"] in self.agreement
        ]

    def documents(self, day) -> list[dict]:
        return [
            {
                "document_id": self.document[r["invoice_no"]],
                "agreement_id": self.agreement[r["contract_no"]],
                "issued_on": r["invoice_date"],
                "billing_from": r["period_from"],
                "billing_to": r["period_to"],
                "payable_by": r["due_date"],
            }
            for r in self.history(self.world.invoices, day)
            if r["invoice_no"] in self.document
        ]

    def document_lines(self, day) -> list[dict]:
        return [
            {
                "document_id": self.document[r["invoice_no"]],
                "position": r["line_no"],
                "product_code": self.product[r["tariff_code"]],
                "charge_type": r["line_type"],
                "quantity_kwh": r["kwh"],
                "amount_net": r["net_amount"],
                "vat_rate": r["tax_rate"],
                "vat_amount": r["tax_amount"],
            }
            for r in self.history(self.world.invoice_lines, day)
            if r["invoice_no"] in self.document
        ]

    def settlements(self, day) -> list[dict]:
        return [
            {
                "settlement_id": self.settlement[r["payment_id"]],
                "document_id": self.document[r["invoice_no"]],
                "settled_on": r["payment_date"],
                "settled_amount": r["amount"],
            }
            for r in self.history(self.world.payments, day)
            if r["invoice_no"] in self.document
        ]

    def rows(self, system: str, entity: str, day) -> list[dict]:
        if entity == "key_map":
            return self.key_map(system) if day == CUTOVER_DATE else []
        return getattr(self, entity)(day)


def render_v2(world: World, out: Path) -> None:
    plan = Plan(world)
    for system, entities in LAYOUT.items():
        for entity, columns in entities.items():
            for day in V2_DATES:
                write_csv(out / system / entity / f"{day.isoformat()}.csv", columns.split(), plan.rows(system, entity, day))
