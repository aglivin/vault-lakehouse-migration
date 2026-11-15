import random
from dataclasses import dataclass, field
from datetime import date, timedelta
from decimal import Decimal

from faker import Faker

from data_generator import cdc

CUTOVER_DATE = date(2026, 1, 4)
LOAD_DATES = (date(2026, 1, 1), date(2026, 1, 2), date(2026, 1, 3), date(2026, 1, 4), date(2026, 1, 5))
V1_DATES = tuple(d for d in LOAD_DATES if d < CUTOVER_DATE)
V2_DATES = tuple(d for d in LOAD_DATES if d >= CUTOVER_DATE)
ZERO = Decimal("0.00")
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
    seed: int = 0


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
        keys = ("tariff_code", "commodity", "name", "price_per_kwh", "base_fee_month")
        self.world.tariffs = [dict(zip(keys, t), valid_from="2025-01-01", _load_date=day) for t in TARIFFS]

    def add_customer(self, day: date) -> None:
        customer_no = self.next_no("C", 6)
        self.customers[customer_no] = self.record(self.world.customers, self.customer_fields(customer_no, day), day, "I")
        for phone_type in ("mobile", "home")[: self.rng.randint(1, 2)]:
            self.phones[(customer_no, phone_type)] = self.new_phone(customer_no, phone_type, day, "I")
        self.add_contract(customer_no, day)

    def record(self, table: list[dict], fields: dict, day: date, op: str = "") -> dict:
        row = dict(fields, _load_date=day, **({"op": op} if op else {}))
        table.append(row)
        return row

    def customer_fields(self, customer_no: str, day: date) -> dict:
        birth = date(1940, 1, 1) + timedelta(self.rng.randrange(22000))
        return {
            "customer_no": customer_no,
            "first_name": self.fake.first_name(),
            "last_name": self.fake.last_name(),
            "email": f"{customer_no.lower()}@example.org",
            "birth_date": birth.isoformat(),
            "segment": self.rng.choice(("residential", "small_business", "premium")),
            **self.address_fields(day),
        }

    def address_fields(self, day: date) -> dict:
        return {
            "street": self.fake.street_address(),
            "city": self.fake.city(),
            "postal_code": self.fake.postcode(),
            "updated_at": f"{day.isoformat()}T08:00:00",
        }

    def new_phone(self, customer_no: str, phone_type: str, day: date, op: str) -> dict:
        fields = {"customer_no": customer_no, "phone_type": phone_type, "phone_number": self.fake.phone_number()}
        return self.record(self.world.customer_phones, fields, day, op)

    def add_contract(self, customer_no: str, day: date, contract_no: str = "", meter_no: str = "") -> None:
        tariff = self.rng.choice(self.world.tariffs)
        if not meter_no:
            meter_no = self.next_no("M", 8)
            meter = {"meter_no": meter_no, "commodity": tariff["commodity"], "install_date": day.isoformat()}
            self.record(self.world.meters, meter, day)
        fields = {
            "contract_no": contract_no or self.next_no("K", 7),
            "customer_no": customer_no,
            "tariff_code": tariff["tariff_code"],
            "meter_no": meter_no,
            "start_date": day.isoformat(),
            "end_date": "",
            "status": "active",
        }
        row = self.record(self.world.contracts, fields, day, "I")
        self.contracts[row["contract_no"]] = row
        self.add_invoice(row, day)

    def add_invoice(self, contract: dict, day: date) -> None:
        tariff = next(t for t in self.world.tariffs if t["tariff_code"] == contract["tariff_code"])
        invoice_no = self.next_no("INV", 8)
        iso = day.isoformat()
        invoice = {
            "invoice_no": invoice_no,
            "contract_no": contract["contract_no"],
            "invoice_date": iso,
            "period_from": (day - timedelta(30)).isoformat(),
            "period_to": (day - timedelta(1)).isoformat(),
            "due_date": (day + timedelta(14)).isoformat(),
        }
        self.record(self.world.invoices, invoice, day)
        lines = self.invoice_lines(invoice_no, tariff, self.rng.randint(50, 900), day)
        if self.rng.random() < 0.8:
            amount = sum((r["net_amount"] + r["tax_amount"] for r in lines), ZERO)
            payment = {"payment_id": self.next_no("P", 9), "invoice_no": invoice_no, "payment_date": iso, "amount": amount}
            self.record(self.world.payments, payment, day)

    def invoice_lines(self, invoice_no: str, tariff: dict, kwh: int, day: date) -> list[dict]:
        nets = [
            ("energy", kwh, money(kwh * Decimal(tariff["price_per_kwh"]))),
            ("base_fee", "", Decimal(tariff["base_fee_month"])),
            ("energy_tax", kwh, money(kwh * ENERGY_TAX_PER_KWH)),
        ]
        vat = money(VAT_RATE * sum((n for _, _, n in nets), ZERO))
        parts = [*nets, ("vat", "", ZERO)]
        for number, (line_type, line_kwh, net) in enumerate(parts, 1):
            is_vat = line_type == "vat"
            fields = {
                "invoice_no": invoice_no,
                "line_no": number,
                "tariff_code": tariff["tariff_code"],
                "line_type": line_type,
                "kwh": line_kwh,
                "net_amount": net,
                "tax_rate": VAT_RATE if is_vat else ZERO,
                "tax_amount": vat if is_vat else ZERO,
            }
            self.record(self.world.invoice_lines, fields, day)
        return self.world.invoice_lines[-len(parts):]

    def add_contact(self, customer_no: str, day: date) -> None:
        rng = self.rng
        fields = {
            "contact_id": self.next_no("CT", 8),
            "customer_no": customer_no,
            "contact_ts": f"{day.isoformat()}T{rng.randint(8, 17):02d}:{rng.randint(0, 59):02d}:00",
            "channel": rng.choice(("phone", "email", "chat")),
            "reason": rng.choice(("billing", "move", "tariff", "complaint")),
            "resolved_first_contact": str(rng.random() < 0.7).lower(),
        }
        self.record(self.world.contacts, fields, day)


def build_world(customers: int, seed: int) -> World:
    builder = WorldBuilder(seed)
    builder.world.seed = seed
    first_day, *delta_days = LOAD_DATES
    builder.add_tariffs(first_day)
    for _ in range(customers):
        builder.add_customer(first_day)
    cdc.add_contacts(builder, first_day, 0.3)
    for day in delta_days:
        cdc.apply_delta_day(builder, day, v2=day >= CUTOVER_DATE)
    return builder.world
