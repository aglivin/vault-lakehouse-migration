with operators as (
    select
        operator_type,
        execution_time_breakdown:overall_percentage::float as time_share,
        operator_statistics:input_rows::number as input_rows,
        operator_statistics:pruning:partitions_scanned::number as partitions_scanned,
        operator_statistics:pruning:partitions_total::number as partitions_total
    from table(get_query_operator_stats('{{ var("perf_query_id", "") }}'))
)

select
    operator_type,
    count(*) as operators,
    round(sum(time_share) * 100, 1) as time_share_pct,
    sum(input_rows) as input_rows,
    sum(partitions_scanned) as partitions_scanned,
    sum(partitions_total) as partitions_total
from operators
group by operator_type
order by time_share_pct desc
