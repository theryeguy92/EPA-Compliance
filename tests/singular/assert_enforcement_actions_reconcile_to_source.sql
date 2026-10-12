-- Every distinct action in the raw exports must appear exactly once in the fact
-- table: no actions dropped by deduplication, none fanned out by joins.
with source_actions as (
    select distinct
        'formal' as action_category,
        trim(pgm_sys_id) as facility_id,
        trim(activity_id) as action_id
    from {{ source('icis_air', 'icis_air_formal_actions') }}
    union all
    select distinct
        'informal' as action_category,
        trim(pgm_sys_id) as facility_id,
        trim(activity_id) as action_id
    from {{ source('icis_air', 'icis_air_informal_actions') }}
),

source_counts as (
    select
        action_category,
        count(*) as n
    from source_actions
    group by action_category
),

fact_counts as (
    select
        action_category,
        count(*) as n
    from {{ ref('fct_enforcement_actions') }}
    group by action_category
)

select
    s.action_category,
    s.n as source_actions,
    f.n as fact_actions
from source_counts as s
left join fact_counts as f on s.action_category = f.action_category
where f.n is distinct from s.n
