from pathlib import Path

import pytest
import yaml

from data_generator.render_v1 import LAYOUT as LAYOUT_V1
from data_generator.render_v2 import LAYOUT as LAYOUT_V2
from scripts.upload_landing import build_commands


@pytest.fixture(autouse=True)
def default_locations(monkeypatch):
    monkeypatch.delenv("SNOWFLAKE_DATABASE", raising=False)
    monkeypatch.delenv("DATABRICKS_CATALOG", raising=False)


def make_out(tmp_path: Path) -> Path:
    for system, entity in [("crm_v1", "customers"), ("billing_v1", "contracts")]:
        directory = tmp_path / system / entity
        directory.mkdir(parents=True)
        (directory / "2026-01-01.csv").write_text("a\n")
        (directory / "2026-01-02.csv").write_text("a\n")
    return tmp_path


def test_snowflake_commands(tmp_path):
    commands = build_commands("snowflake", "2026-01-01", make_out(tmp_path))
    assert commands == [
        [
            "snow", "stage", "copy", str(tmp_path / system / entity / "2026-01-01.csv"),
            f"@VDWH_DEV.RAW.LANDING/{system}/{entity}/", "--overwrite", "--connection", "personal",
        ]
        for system, entity in [("billing_v1", "contracts"), ("crm_v1", "customers")]
    ]


def test_databricks_commands(tmp_path):
    commands = build_commands("databricks", "2026-01-02", make_out(tmp_path))
    assert commands[0] == [
        "databricks", "fs", "mkdirs", "dbfs:/Volumes/vdwh_dev/raw/landing/billing_v1/contracts", "--profile", "personal",
    ]
    assert commands[1] == [
        "databricks", "fs", "cp", str(tmp_path / "billing_v1" / "contracts" / "2026-01-02.csv"),
        "dbfs:/Volumes/vdwh_dev/raw/landing/billing_v1/contracts/2026-01-02.csv",
        "--overwrite", "--profile", "personal",
    ]
    assert len(commands) == 4


@pytest.mark.parametrize("target", ["snowflake", "databricks"])
def test_profile_is_always_personal(tmp_path, target):
    for command in build_commands(target, "2026-01-01", make_out(tmp_path)):
        assert "personal" in command
        assert not {"DEFAULT", "PROD", "OLD"} & set(command)


def test_unknown_target_fails(tmp_path):
    with pytest.raises(ValueError):
        build_commands("oracle", "2026-01-01", make_out(tmp_path))


def test_raw_entities_match_generator_layout():
    project = yaml.safe_load((Path(__file__).resolve().parents[1] / "dbt" / "dbt_project.yml").read_text())
    expected = {
        f"{system}__{entity}": columns.split()
        for system, entities in {**LAYOUT_V1, **LAYOUT_V2}.items()
        for entity, columns in entities.items()
    }
    assert project["vars"]["raw_entities"] == expected


def test_cutover_date_var_matches_generator():
    from data_generator.world import CUTOVER_DATE

    project = yaml.safe_load((Path(__file__).resolve().parents[1] / "dbt" / "dbt_project.yml").read_text())
    assert project["vars"]["cutover_date"] == CUTOVER_DATE.isoformat()


def test_only_systems_of_the_load_date_are_uploaded(tmp_path):
    for system in ["crm_v1", "crm_v2"]:
        directory = tmp_path / system / "customers"
        directory.mkdir(parents=True)
        for day in ["2026-01-03", "2026-01-04"]:
            (directory / f"{day}.csv").write_text("a\n")
    before = build_commands("snowflake", "2026-01-03", tmp_path)
    after = build_commands("snowflake", "2026-01-04", tmp_path)
    assert [c[3] for c in before] == [str(tmp_path / "crm_v1/customers/2026-01-03.csv")]
    assert [c[3] for c in after] == [str(tmp_path / "crm_v2/customers/2026-01-04.csv")]


def test_locations_follow_environment(tmp_path, monkeypatch):
    monkeypatch.setenv("SNOWFLAKE_DATABASE", "VDWH_PROD")
    monkeypatch.setenv("DATABRICKS_CATALOG", "vdwh_prod")
    snowflake = build_commands("snowflake", "2026-01-01", make_out(tmp_path))
    databricks = build_commands("databricks", "2026-01-01", tmp_path)
    assert snowflake[0][4] == "@VDWH_PROD.RAW.LANDING/billing_v1/contracts/"
    assert databricks[0][3] == "dbfs:/Volumes/vdwh_prod/raw/landing/billing_v1/contracts"
