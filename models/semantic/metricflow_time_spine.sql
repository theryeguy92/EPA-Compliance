-- Daily time spine required by the dbt Semantic Layer (MetricFlow).
select date_day
from {{ ref('dim_date') }}
