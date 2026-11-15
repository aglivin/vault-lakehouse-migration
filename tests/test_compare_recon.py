import json

import pytest

from scripts import compare_recon

ROW = {
    "table_name": "hub_customer",
    "row_count": 10,
    "distinct_keys": 10,
    "key_min": "AA",
    "key_max": "FF",
    "key_checksum": "123",
    "measure_sums": None,
    "min_load_date": "2026-01-01",
    "max_load_date": "2026-01-05",
}


def write(tmp_path, name, rows):
    path = tmp_path / name
    path.write_text(json.dumps({"show": rows}))
    return str(path)


def run(tmp_path, left_rows, right_rows):
    left = write(tmp_path, "left.json", left_rows)
    right = write(tmp_path, "right.json", right_rows)
    return compare_recon.main(["compare_recon", left, right])


def test_match_ignores_column_case_and_number_format(tmp_path, capsys):
    upper = {name.upper(): value for name, value in ROW.items()}
    assert run(tmp_path, [upper], [{**ROW, "row_count": "10.0"}]) == 0
    assert "0 differences" in capsys.readouterr().out


def test_count_mismatch(tmp_path, capsys):
    assert run(tmp_path, [ROW], [{**ROW, "row_count": 11}]) == 1
    assert "| hub_customer | row_count | 10 | 11 |" in capsys.readouterr().out


def test_hash_mismatch(tmp_path, capsys):
    assert run(tmp_path, [ROW], [{**ROW, "key_max": "FE"}]) == 1
    assert "| hub_customer | key_max | FF | FE |" in capsys.readouterr().out


def test_table_missing_on_one_side(tmp_path, capsys):
    other = {**ROW, "table_name": "hub_meter"}
    assert run(tmp_path, [ROW, other], [ROW]) == 1
    assert "| hub_meter | table | present | missing |" in capsys.readouterr().out


def test_parses_json_after_log_lines():
    text = "12:00:00 Running\n" + json.dumps({"show": [ROW]}, indent=2) + "\n12:00:01 Done\n"
    assert compare_recon.parse_show_output(text) == [ROW]


def test_no_rows_raises():
    with pytest.raises(ValueError):
        compare_recon.parse_show_output("nothing")
