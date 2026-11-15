from pathlib import Path

import pytest
from airflow.models import DagBag

REQUIRED_RETRIES = 2
LAYERS = ["staging", "raw_vault", "business_vault", "marts"]


@pytest.fixture(scope="module")
def dag_bag():
    return DagBag(
        dag_folder=str(Path(__file__).parents[1] / "dags"), include_examples=False
    )


@pytest.fixture(scope="module")
def dag(dag_bag):
    return dag_bag.dags["vdwh_transform"]


def test_all_dags_import(dag_bag):
    assert dag_bag.import_errors == {}


def test_dag_has_no_cycles(dag):
    dag.topological_sort()


def test_every_task_retries_at_least_twice(dag):
    assert dag.tasks
    assert all(task.retries >= REQUIRED_RETRIES for task in dag.tasks)


def test_layers_depend_on_previous_layer(dag):
    for upstream, downstream in zip(LAYERS, LAYERS[1:]):
        first_tasks = [
            task for task in dag.tasks if task.task_id.startswith(f"{downstream}.")
        ]
        upstream_ids = {uid for task in first_tasks for uid in task.upstream_task_ids}
        assert any(uid.startswith(f"{upstream}.") for uid in upstream_ids)
