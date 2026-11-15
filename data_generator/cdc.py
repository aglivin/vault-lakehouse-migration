from datetime import date

NEW_CUSTOMER_SHARE = 0.02
UPDATE_SHARE = 0.03
DELETE_SHARE = 0.005
INVOICE_SHARE = 0.3
CONTACT_SHARE = 0.05


def pick(builder, population: list, share: float) -> list:
    size = min(len(population), max(1, round(len(population) * share)))
    return builder.rng.sample(population, size)


def add_contacts(builder, day: date, share: float) -> None:
    for customer_no in pick(builder, sorted(builder.customers), share):
        builder.add_contact(customer_no, day)


def emit(builder, table: list[dict], row: dict, day: date, op: str) -> dict:
    return builder.record(table, {k: v for k, v in row.items() if k not in ("op", "_load_date")}, day, op)


def delete_contract(builder, contract_no: str, day: date) -> None:
    emit(builder, builder.world.contracts, builder.contracts.pop(contract_no), day, "D")


def update_customer(builder, customer_no: str, day: date) -> None:
    row = dict(builder.customers[customer_no], **builder.address_fields(day))
    builder.customers[customer_no] = emit(builder, builder.world.customers, row, day, "U")
    if (customer_no, "mobile") in builder.phones:
        builder.phones[(customer_no, "mobile")] = builder.new_phone(customer_no, "mobile", day, "U")


def delete_phones(builder, day: date) -> None:
    for key in pick(builder, sorted(builder.phones), DELETE_SHARE):
        emit(builder, builder.world.customer_phones, builder.phones.pop(key), day, "D")


def churn_contracts(builder, day: date, pool: list[str]) -> None:
    deleted = pick(builder, pool, DELETE_SHARE)
    for contract_no in deleted:
        delete_contract(builder, contract_no, day)
    active = [n for n in pool if n not in deleted and builder.contracts[n]["status"] == "active"]
    for contract_no in pick(builder, active, UPDATE_SHARE):
        row = dict(builder.contracts[contract_no], end_date=day.isoformat(), status="terminated")
        builder.contracts[contract_no] = emit(builder, builder.world.contracts, row, day, "U")


def handle_recreated_contract(builder, day: date) -> None:
    world = builder.world
    if not world.recreated_contract_no:
        world.recreated_contract_no = builder.rng.choice(sorted(builder.contracts))
        delete_contract(builder, world.recreated_contract_no, day)
        return
    last = next(r for r in reversed(world.contracts) if r["contract_no"] == world.recreated_contract_no)
    builder.add_contract(last["customer_no"], day, last["contract_no"], last["meter_no"])


def apply_delta_day(builder, day: date) -> None:
    pool = sorted(builder.contracts)
    handle_recreated_contract(builder, day)
    pool = [n for n in pool if n in builder.contracts and n != builder.world.recreated_contract_no]
    churn_contracts(builder, day, pool)
    delete_phones(builder, day)
    for customer_no in pick(builder, sorted(builder.customers), UPDATE_SHARE):
        update_customer(builder, customer_no, day)
    for _ in range(max(1, round(len(builder.customers) * NEW_CUSTOMER_SHARE))):
        builder.add_customer(day)
    live = sorted(n for n, r in builder.contracts.items() if r["status"] == "active")
    for contract_no in pick(builder, live, INVOICE_SHARE):
        builder.add_invoice(builder.contracts[contract_no], day)
    add_contacts(builder, day, CONTACT_SHARE)
