import logging
import os
from datetime import timedelta

import httpx
from airflow.sdk import AsyncCallback, Connection, DeadlineAlert, DeadlineReference

log = logging.getLogger(__name__)

ALERT_CONN_ID_VARIABLE = "VDWH_ALERT_CONN_ID"


def send_to_webhook(message: str) -> None:
    conn_id = os.environ.get(ALERT_CONN_ID_VARIABLE, "")
    if not conn_id:
        return
    connection = Connection.get(conn_id)
    httpx.post(connection.host, json={"text": message}, timeout=10).raise_for_status()


def failure_message(context) -> str:
    ti = context["ti"]
    return (
        f"VDWH ALERT: task failed dag_id={ti.dag_id} task_id={ti.task_id} "
        f"run_id={ti.run_id} try_number={ti.try_number} error={context.get('exception')!r}"
    )


def notify_failure(context) -> None:
    message = failure_message(context)
    log.error(message)
    send_to_webhook(message)


async def log_missed_deadline(context=None, **kwargs) -> None:
    dag_run = (context or {}).get("dag_run", {})
    deadline = (context or {}).get("deadline", {})
    log.error(
        "VDWH ALERT: deadline missed dag_id=%s run_id=%s deadline_time=%s",
        dag_run.get("dag_id"),
        dag_run.get("dag_run_id"),
        deadline.get("deadline_time"),
    )


def run_deadline(interval: timedelta) -> DeadlineAlert:
    return DeadlineAlert(
        reference=DeadlineReference.DAGRUN_QUEUED_AT,
        interval=interval,
        callback=AsyncCallback(log_missed_deadline),
    )
