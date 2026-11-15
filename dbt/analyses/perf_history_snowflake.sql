with history as (
    select
        lower(query_text) as query_text,
        warehouse_size,
        total_elapsed_time,
        execution_time,
        bytes_scanned,
        partitions_scanned,
        partitions_total,
        rows_produced
    from snowflake.account_usage.query_history
    where
        user_name = current_user()
        and execution_status = 'SUCCESS'
        and start_time >= cast('{{ var("perf_since", "2026-01-01T00:00:00Z") }}' as timestamp_tz)
        and start_time < cast('{{ var("perf_until", "2100-01-01T00:00:00Z") }}' as timestamp_tz)
        and query_text ilike '%perf%'
),

labelled as (
    select
        coalesce(
            regexp_substr(query_text, '([a-z_]+_[0-9]+). as perf_probe', 1, 1, 'e', 1),
            regexp_substr(
                query_text, 'perf_invoice_line_(merge|delete_insert|insert_overwrite|microbatch)', 1, 1, 'e', 1
            ),
            regexp_substr(query_text, '"node_id": "model[.]vdwh[.]([a-z0-9_]+)"', 1, 1, 'e', 1)
        ) as run_group,
        warehouse_size,
        total_elapsed_time,
        execution_time,
        bytes_scanned,
        partitions_scanned,
        partitions_total,
        rows_produced
    from history
)

select
    run_group,
    max(warehouse_size) as warehouse_size,
    count(*) as statements,
    sum(total_elapsed_time) as elapsed_ms,
    sum(execution_time) as execution_ms,
    sum(bytes_scanned) as bytes_scanned,
    sum(partitions_scanned) as partitions_scanned,
    sum(partitions_total) as partitions_total,
    sum(rows_produced) as rows_produced
from labelled
where run_group is not null
group by run_group
order by elapsed_ms desc
