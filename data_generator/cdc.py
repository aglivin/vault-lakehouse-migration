from datetime import date

NEW_CUSTOMER_SHARE = 0.02
UPDATE_SHARE = 0.03
DELETE_SHARE = 0.005
INVOICE_SHARE = 0.3
CONTACT_SHARE = 0.05


def count(total: int, share: float, minimum: int = 1) -> int:
    return max(minimum, round(total * share))


def pick(builder, population: list, size: int) -> list:
    return builder.rng.sample(population, min(size, len(population)))


def add_contacts(builder, day: date, share: float) -> None:
    customers = sorted(builder.customers)
    for customer_no in pick(builder, customers, count(len(customers), share)):
        builder.add_contact(customer_no, day)


def delete_contract(builder, contract_no: str, day: date) -> None:
    row = dict(builder.contracts.pop(contract_no), op="D", _load_date=day)
    builder.world.contracts.append(row)


def recreate_contract(builder, contract_no: str, day: date) -> None:
    last = next(r for r in reversed(builder.world.contracts) if r["contract_no"] == contract_no)
    builder.add_contract(last["customer_no"], day, contract_no, last["meter_no"])


def terminate_contract(builder, contract_no: str, day: date) -> None:
    row = dict(builder.contracts[contract_no], end_date=day.isoformat(), status="terminated", op="U", _load_date=day)
    builder.contracts[contract_no] = row
    builder.world.contracts.append(row)


def update_customer(builder, customer_no: str, day: date) -> None:
    row = dict(
        builder.customers[customer_no],
        street=builder.fake.street_address(),
        city=builder.fake.city(),
        postal_code=builder.fake.postcode(),
        updated_at=f"{day.isoformat()}T08:00:00",
        op="U",
        _load_date=day,
    )
    builder.customers[customer_no] = row
    builder.world.customers.append(row)


def update_phone(builder, key: tuple[str, str], day: date) -> None:
    if key in builder.phones:
        row = builder.phone_row(key[0], key[1], day, "U")
        builder.phones[key] = row
        builder.world.customer_phones.append(row)


def delete_phones(builder, day: date) -> None:
    keys = sorted(builder.phones)
    for key in pick(builder, keys, count(len(keys), DELETE_SHARE)):
        row = dict(builder.phones.pop(key), op="D", _load_date=day)
        builder.world.customer_phones.append(row)


def churn_contracts(builder, day: date, pool: list[str]) -> None:
    deleted = pick(builder, pool, count(len(pool), DELETE_SHARE))
    for contract_no in deleted:
        delete_contract(builder, contract_no, day)
    active = [n for n in pool if n not in deleted and builder.contracts[n]["status"] == "active"]
    for contract_no in pick(builder, active, count(len(pool), UPDATE_SHARE)):
        terminate_contract(builder, contract_no, day)


def change_customers(builder, day: date) -> None:
    customers = sorted(builder.customers)
    delete_phones(builder, day)
    for customer_no in pick(builder, customers, count(len(customers), UPDATE_SHARE)):
        update_customer(builder, customer_no, day)
        update_phone(builder, (customer_no, "mobile"), day)


def handle_recreated_contract(builder, day: date) -> None:
    world = builder.world
    if not world.recreated_contract_no:
        world.recreated_contract_no = builder.rng.choice(sorted(builder.contracts))
        delete_contract(builder, world.recreated_contract_no, day)
    else:
        recreate_contract(builder, world.recreated_contract_no, day)


def apply_delta_day(builder, day: date) -> None:
    pool = sorted(builder.contracts)
    handle_recreated_contract(builder, day)
    pool = [n for n in pool if n in builder.contracts and n != builder.world.recreated_contract_no]
    churn_contracts(builder, day, pool)
    change_customers(builder, day)
    for _ in range(count(len(builder.customers), NEW_CUSTOMER_SHARE)):
        builder.add_customer(day)
    live = sorted(n for n, r in builder.contracts.items() if r["status"] == "active")
    for contract_no in pick(builder, live, count(len(live), INVOICE_SHARE)):
        builder.add_invoice(builder.contracts[contract_no], day)
    add_contacts(builder, day, CONTACT_SHARE)
