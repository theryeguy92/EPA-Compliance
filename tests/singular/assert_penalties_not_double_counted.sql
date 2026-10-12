-- Total penalties in the fact table must equal the source total taken as the
-- largest amount per action. A fan-out or a sum over duplicate source rows
-- would inflate this, and penalty totals are the number people quote.
with source_total as (
    select coalesce(sum(max_penalty), 0) as total
    from (
        select max(try_cast(nullif(trim(penalty_amount), '') as decimal(18, 2))) as max_penalty
        from {{ source('icis_air', 'icis_air_formal_actions') }}
        group by trim(pgm_sys_id), trim(activity_id)
    ) as per_action
),

fact_total as (
    select coalesce(sum(penalty_amount), 0) as total
    from {{ ref('fct_enforcement_actions') }}
)

select
    s.total as source_total,
    f.total as fact_total
from source_total as s
cross join fact_total as f
where s.total <> f.total
