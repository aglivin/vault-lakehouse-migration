from pathlib import Path
from types import SimpleNamespace

import pytest
from airflow.models import DagBag

from include.vdwh_alerts import failure_message, notify_failure
from include.vdwh_assets import RAW_LANDED, single_load_date

DAGS_DIR = Path(__file__).resolve().parents[1] / "dags"
DAG_IDS = ["vdwh_ingest", "vdwh_transform"]


@pytest.fixture(scope="module")
def dag_bag():
    return DagBag(dag_folder=str(DAGS_DIR), include_examples=False)


def test_dag_bag_has_both_dags_without_errors(dag_bag):
    assert dag_bag.import_errors == {}
    assert set(DAG_IDS) <= set(dag_bag.dag_ids)


@pytest.mark.parametrize("dag_id", DAG_IDS)
def test_dag_is_acyclic_and_retries(dag_bag, dag_id):
    dag = dag_bag.dags[dag_id]
    dag.topological_sort()
    assert all(task.retries >= 2 for task in dag.tasks)


@pytest.mark.parametrize("dag_id", DAG_IDS)
def test_every_task_alerts_on_failure(dag_bag, dag_id):
    tasks = dag_bag.dags[dag_id].tasks
    assert all(notify_failure in (task.on_failure_callback or []) for task in tasks)


@pytest.mark.parametrize("dag_id", DAG_IDS)
def test_dag_has_deadline_alert(dag_bag, dag_id):
    assert dag_bag.dags[dag_id].deadline


def test_ingest_publishes_raw_landed_after_load_raw(dag_bag):
    dag = dag_bag.dags["vdwh_ingest"]
    publisher = dag.get_task("publish_raw_landed")
    assert publisher.outlets == [RAW_LANDED]
    assert publisher.upstream_task_ids == {"load_raw"}
    assert [task.task_id for task in dag.tasks if task.outlets] == ["publish_raw_landed"]


def test_transform_is_scheduled_on_raw_landed(dag_bag):
    dag = dag_bag.dags["vdwh_transform"]
    assert dag.timetable.asset_condition.objects == (RAW_LANDED,)
    assert "load_raw" not in dag.task_ids


def test_transform_starts_by_resolving_load_date(dag_bag):
    dag = dag_bag.dags["vdwh_transform"]
    roots = [task.task_id for task in dag.tasks if not task.upstream_task_ids]
    assert roots == ["resolve_load_date"]


def event(extra):
    return SimpleNamespace(extra=extra)


def test_single_load_date_reads_event_extra():
    assert single_load_date({RAW_LANDED: [event({"load_date": "2026-01-02"})]}) == "2026-01-02"


def test_single_load_date_accepts_duplicate_events_for_same_date():
    events = [event({"load_date": "2026-01-02"}), event({"load_date": "2026-01-02"})]
    assert single_load_date({RAW_LANDED: events}) == "2026-01-02"


@pytest.mark.parametrize(
    "events",
    [
        {},
        {RAW_LANDED: []},
        {RAW_LANDED: [event({})]},
        {RAW_LANDED: [event({"load_date": "2026-01-02"}), event({"load_date": "2026-01-03"})]},
    ],
)
def test_single_load_date_refuses_to_guess(events):
    with pytest.raises(ValueError):
        single_load_date(events)


def test_failure_message_names_dag_task_and_run():
    ti = SimpleNamespace(dag_id="vdwh_ingest", task_id="load_raw", run_id="r1", try_number=3)
    message = failure_message({"ti": ti, "exception": RuntimeError("boom")})
    assert "dag_id=vdwh_ingest" in message
    assert "task_id=load_raw" in message
    assert "run_id=r1" in message
    assert "boom" in message
