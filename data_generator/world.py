import random
from dataclasses import dataclass, field
from datetime import date, timedelta
from decimal import Decimal

from faker import Faker

from data_generator import cdc

LOAD_DATES = (date(2026, 1, 1), date(2026, 1, 2), date(2026, 1, 3))
VAT_RATE = Decimal("0.20")
ENERGY_TAX_PER_KWH = Decimal("0.0150")
TARIFFS = (
    ("EL-BASIC", "electricity", "Basic Power", "0.2850", "4.90"),
    ("EL-GREEN", "electricity", "Green Power", "0.3150", "5.90"),
    ("EL-FIX", "electricity", "Fix Power", "0.2650", "6.90"),
    ("GAS-BASIC", "gas", "Basic Gas", "0.0980", "3.90"),
    ("GAS-ECO", "gas", "Eco Gas", "0.1080", "4.90"),
    ("GAS-FIX", "gas", "Fix Gas", "0.0910", "5.90"),
)


def money(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"))


@dataclass
class World:
    customers: list[dict] = field(default_factory=list)
    customer_phones: list[dict] = field(default_factory=list)
    contacts: list[dict] = field(default_factory=list)
    tariffs: list[dict] = field(default_factory=list)
    meters: list[dict] = field(default_factory=list)
    contracts: list[dict] = field(default_factory=list)
    invoices: list[dict] = field(default_factory=list)
    invoice_lines: list[dict] = field(default_factory=list)
    payments: list[dict] = field(default_factory=list)
    recreated_contract_no: str = ""


class WorldBuilder:
    def __init__(self, seed: int):
        self.rng = random.Random(seed)
        self.fake = Faker("de_AT")
        self.fake.seed_instance(seed)
        self.world = World()
        self.counters: dict[str, int] = {}
        self.customers: dict[str, dict] = {}
        self.phones: dict[tuple[str, str], dict] = {}
        self.contracts: dict[str, dict] = {}

    def next_no(self, prefix: str, width: int) -> str:
        self.counters[prefix] = self.counters.get(prefix, 0) + 1
        return f"{prefix}{self.counters[prefix]:0{width}d}"

    def add_tariffs(self, day: date) -> None:
        for code, commodity, name, price, base_fee in TARIFFS:
            self.world.tariffs.append(
                {
                    "tariff_code": code,
                    "commodity": commodity,
                    "name": name,
                    "price_per_kwh": price,
                    "base_fee_month": base_fee,
                    "valid_from": date(2025, 1, 1).isoformat(),
                    "_load_date": day,
                }
            )

    def customer_row(self, customer_no: str, day: date, op: str) -> dict:
        return {
            "customer_no": customer_no,
            "first_name": self.fake.first_name(),
            "last_name": self.fake.last_name(),
            "email": f"{customer_no.lower()}@example.org",
            "birth_date": (date(1940, 1, 1) + timedelta(self.rng.randrange(22000))).isoformat(),
            "street": self.fake.street_address(),
            "city": self.fake.city(),
            "postal_code": self.fake.postcode(),
            "segment": self.rng.choice(("residential", "small_business", "premium")),
            "updated_at": f"{day.isoformat()}T08:00:00",
            "op": op,
            "_load_date": day,
        }

    def phone_row(self, customer_no: str, phone_type: str, day: date, op: str) -> dict:
        return {
            "customer_no": customer_no,
            "phone_type": phone_type,
            "phone_number": self.fake.phone_number(),
            "op": op,
            "_load_date": day,
        }

    def add_customer(self, day: date) -> None:
        customer_no = self.next_no("C", 6)
        row = self.customer_row(customer_no, day, "I")
        self.customers[customer_no] = row
        self.world.customers.append(row)
        for phone_type in ("mobile", "home")[: self.rng.randint(1, 2)]:
            phone = self.phone_row(customer_no, phone_type, day, "I")
            self.phones[(customer_no, phone_type)] = phone
            self.world.customer_phones.append(phone)
        self.add_contract(customer_no, day)

    def add_contract(self, customer_no: str, day: date, contract_no: str = "", meter_no: str = "") -> None:
        tariff = self.rng.choice(self.world.tariffs)
        if not meter_no:
            meter_no = self.next_no("M", 8)
            self.world.meters.append(
                {
                    "meter_no": meter_no,
                    "commodity": tariff["commodity"],
                    "install_date": day.isoformat(),
                    "_load_date": day,
                }
            )
        row = {
            "contract_no": contract_no or self.next_no("K", 7),
            "customer_no": customer_no,
            "tariff_code": tariff["tariff_code"],
            "meter_no": meter_no,
            "start_date": day.isoformat(),
            "end_date": "",
            "status": "active",
            "op": "I",
            "_load_date": day,
        }
        self.contracts[row["contract_no"]] = row
        self.world.contracts.append(row)
        self.add_invoice(row, day)

    def tariff_by_code(self, code: str) -> dict:
        return next(t for t in self.world.tariffs if t["tariff_code"] == code)

    def add_invoice(self, contract: dict, day: date) -> None:
        tariff = self.tariff_by_code(contract["tariff_code"])
        invoice_no = self.next_no("INV", 8)
        self.world.invoices.append(
            {
                "invoice_no": invoice_no,
                "contract_no": contract["contract_no"],
                "invoice_date": day.isoformat(),
                "period_from": (day - timedelta(30)).isoformat(),
                "period_to": (day - timedelta(1)).isoformat(),
                "due_date": (day + timedelta(14)).isoformat(),
                "_load_date": day,
            }
        )
        lines = self.invoice_lines(invoice_no, tariff, self.rng.randint(50, 900), day)
        self.world.invoice_lines.extend(lines)
        if self.rng.random() < 0.8:
            self.add_payment(invoice_no, lines, day)

    def invoice_lines(self, invoice_no: str, tariff: dict, kwh: int, day: date) -> list[dict]:
        parts = [
            ("energy", kwh, money(kwh * Decimal(tariff["price_per_kwh"]))),
            ("base_fee", "", Decimal(tariff["base_fee_month"])),
            ("energy_tax", kwh, money(kwh * ENERGY_TAX_PER_KWH)),
        ]
        rows = [self.line(invoice_no, tariff, t, k, n, VAT_RATE, day) for t, k, n in parts]
        vat_total = sum((Decimal(r["tax_amount"]) for r in rows), Decimal("0.00"))
        rows.append(self.line(invoice_no, tariff, "vat", "", vat_total, Decimal("0.00"), day))
        for number, row in enumerate(rows, 1):
            row["line_no"] = number
        return rows

    def line(self, invoice_no, tariff, line_type, kwh, net, rate, day) -> dict:
        return {
            "invoice_no": invoice_no,
            "line_no": 0,
            "tariff_code": tariff["tariff_code"],
            "line_type": line_type,
            "kwh": kwh,
            "net_amount": net,
            "tax_rate": rate,
            "tax_amount": money(net * rate),
            "_load_date": day,
        }

    def add_payment(self, invoice_no: str, lines: list[dict], day: date) -> None:
        total = sum((r["net_amount"] for r in lines), Decimal("0.00"))
        self.world.payments.append(
            {
                "payment_id": self.next_no("P", 9),
                "invoice_no": invoice_no,
                "payment_date": day.isoformat(),
                "amount": total,
                "_load_date": day,
            }
        )

    def add_contact(self, customer_no: str, day: date) -> None:
        stamp = f"{day.isoformat()}T{self.rng.randint(8, 17):02d}:{self.rng.randint(0, 59):02d}:00"
        self.world.contacts.append(
            {
                "contact_id": self.next_no("CT", 8),
                "customer_no": customer_no,
                "contact_ts": stamp,
                "channel": self.rng.choice(("phone", "email", "chat")),
                "reason": self.rng.choice(("billing", "move", "tariff", "complaint")),
                "resolved_first_contact": str(self.rng.random() < 0.7).lower(),
                "_load_date": day,
            }
        )


def build_world(customers: int, seed: int) -> World:
    builder = WorldBuilder(seed)
    first_day = LOAD_DATES[0]
    builder.add_tariffs(first_day)
    for _ in range(customers):
        builder.add_customer(first_day)
    cdc.add_contacts(builder, first_day, 0.3)
    for day in LOAD_DATES[1:]:
        cdc.apply_delta_day(builder, day)
    return builder.world
