with history as (
    select
        lower(statement_text) as statement_text,
        total_duration_ms,
        execution_duration_ms,
        read_bytes,
        read_files,
        pruned_files,
        produced_rows,
        from_result_cache
    from system.query.history
    where
        executed_by = current_user()
        and execution_status = 'FINISHED'
        and start_time >= cast('{{ var("perf_since", "2026-01-01T00:00:00Z") }}' as timestamp)
        and start_time < cast('{{ var("perf_until", "2100-01-01T00:00:00Z") }}' as timestamp)
        and statement_text ilike '%perf%'
),

labelled as (
    select
        coalesce(
            nullif(regexp_extract(statement_text, '([a-z_]+_[0-9]+). as perf_probe', 1), ''),
            nullif(
                regexp_extract(
                    statement_text, 'perf_invoice_line_(merge|delete_insert|insert_overwrite|microbatch)', 1
                ),
                ''
            ),
            nullif(regexp_extract(statement_text, '"node_id": "model[.]vdwh[.]([a-z0-9_]+)"', 1), '')
        ) as run_group,
        total_duration_ms,
        execution_duration_ms,
        read_bytes,
        read_files,
        pruned_files,
        produced_rows,
        from_result_cache
    from history
)

select
    run_group,
    count(*) as statements,
    sum(total_duration_ms) as elapsed_ms,
    sum(execution_duration_ms) as execution_ms,
    sum(read_bytes) as bytes_read,
    sum(read_files) as files_read,
    sum(pruned_files) as files_pruned,
    sum(produced_rows) as rows_produced,
    max(from_result_cache) as any_from_result_cache
from labelled
where run_group is not null
group by run_group
order by elapsed_ms desc
