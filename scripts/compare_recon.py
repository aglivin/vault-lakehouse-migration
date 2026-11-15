import json
import sys
from decimal import Decimal, InvalidOperation
from pathlib import Path

KEY_COLUMN = "table_name"


def parse_show_output(text: str) -> list[dict]:
    decoder = json.JSONDecoder()
    offset = 0
    for line in text.splitlines(keepends=True):
        if line.startswith("{"):
            try:
                payload, _ = decoder.raw_decode(text, offset)
            except json.JSONDecodeError:
                payload = None
            if isinstance(payload, dict) and "show" in payload:
                return payload["show"]
        offset += len(line)
    raise ValueError("no dbt show rows found")


NUMERIC_COLUMNS = {"row_count", "distinct_keys", "hashdiff_distinct"}


def normalise(column: str, value) -> str:
    if value is None:
        return ""
    text = str(value)
    if column not in NUMERIC_COLUMNS:
        return text
    try:
        number = Decimal(text)
    except InvalidOperation:
        return text
    return format(number.normalize(), "f")


def index_rows(rows: list[dict]) -> dict[str, dict[str, str]]:
    if not rows:
        raise ValueError("no rows")
    indexed = {}
    for row in rows:
        lowered = {name.lower(): normalise(name.lower(), value) for name, value in row.items()}
        table = lowered[KEY_COLUMN]
        if table in indexed:
            raise ValueError(f"duplicate table_name {table}")
        indexed[table] = lowered
    return indexed


def compare(left_rows: list[dict], right_rows: list[dict]) -> list[tuple[str, str, str, str]]:
    left = index_rows(left_rows)
    right = index_rows(right_rows)
    differences = []
    for table in sorted(left.keys() | right.keys()):
        if table not in right:
            differences.append((table, "table", "present", "missing"))
            continue
        if table not in left:
            differences.append((table, "table", "missing", "present"))
            continue
        for column in sorted(left[table].keys() | right[table].keys()):
            if column == KEY_COLUMN:
                continue
            left_value = left[table].get(column, "")
            right_value = right[table].get(column, "")
            if left_value != right_value:
                differences.append((table, column, left_value, right_value))
    return differences


def render(differences: list[tuple[str, str, str, str]], left_name: str, right_name: str) -> str:
    lines = [
        f"| table | column | {left_name} | {right_name} |",
        "|---|---|---|---|",
    ]
    lines.extend(f"| {table} | {column} | {left} | {right} |" for table, column, left, right in differences)
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    left_path, right_path = Path(argv[1]), Path(argv[2])
    try:
        left_rows = parse_show_output(left_path.read_text())
        right_rows = parse_show_output(right_path.read_text())
        differences = compare(left_rows, right_rows)
        tables = len(index_rows(left_rows).keys() | index_rows(right_rows).keys())
    except ValueError as error:
        print(f"invalid input: {error}")
        return 2
    if differences:
        print(render(differences, left_path.stem, right_path.stem))
        print(f"\n{len(differences)} differences in {tables} tables")
        return 1
    print(f"0 differences in {tables} tables")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
