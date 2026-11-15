from collections.abc import Mapping, Sequence

from airflow.sdk import Asset

RAW_LANDED = Asset("vdwh/raw_landed")
LOAD_DATE_KEY = "load_date"


def single_load_date(triggering_asset_events: Mapping[Asset, Sequence]) -> str:
    events = triggering_asset_events.get(RAW_LANDED, [])
    load_dates = {event.extra.get(LOAD_DATE_KEY) for event in events}
    if len(load_dates) != 1 or None in load_dates:
        raise ValueError(
            f"{RAW_LANDED.name}: expected exactly one {LOAD_DATE_KEY} in triggering asset events, "
            f"got {sorted(map(str, load_dates))}; trigger vdwh_ingest for the date instead"
        )
    return load_dates.pop()
