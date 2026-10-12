-- One row per facility: inspection coverage, violation history and
-- enforcement outcomes, the questions a compliance analyst asks first.
with facilities as (
    select * from {{ ref('dim_facility') }}
),

evaluations as (
    select
        facility_sk,
        count(*) as evaluation_count,
        count(*) filter (where evaluation_category = 'FCE') as full_evaluation_count,
        max(evaluation_date) as last_evaluation_date,
        max(evaluation_date) filter (where evaluation_category = 'FCE') as last_full_evaluation_date
    from {{ ref('fct_compliance_evaluations') }}
    group by facility_sk
),

violations as (
    select
        facility_sk,
        count(*) as violation_count,
        count(*) filter (where is_high_priority) as hpv_count,
        count(*) filter (where is_high_priority and not is_resolved) as open_hpv_count,
        max(identified_date) as last_violation_identified_date
    from {{ ref('fct_violations') }}
    group by facility_sk
),

enforcement as (
    select
        facility_sk,
        count(*) filter (where action_category = 'formal') as formal_action_count,
        count(*) filter (where action_category = 'informal') as informal_action_count,
        coalesce(sum(penalty_amount), 0) as total_penalties,
        max(action_date) as last_enforcement_date
    from {{ ref('fct_enforcement_actions') }}
    group by facility_sk
)

select
    f.facility_sk,
    f.facility_id,
    f.facility_name,
    f.state_code,
    f.operating_status_desc,
    f.pollutant_class_desc,
    f.compliance_status,
    coalesce(e.evaluation_count, 0) as evaluation_count,
    coalesce(e.full_evaluation_count, 0) as full_evaluation_count,
    e.last_evaluation_date,
    e.last_full_evaluation_date,
    cast(date_diff('day', e.last_full_evaluation_date, current_date) as integer) as days_since_last_full_evaluation,
    coalesce(v.violation_count, 0) as violation_count,
    coalesce(v.hpv_count, 0) as hpv_count,
    coalesce(v.open_hpv_count, 0) as open_hpv_count,
    v.last_violation_identified_date,
    coalesce(en.formal_action_count, 0) as formal_action_count,
    coalesce(en.informal_action_count, 0) as informal_action_count,
    cast(coalesce(en.total_penalties, 0) as decimal(18, 2)) as total_penalties,
    en.last_enforcement_date
from facilities as f
left join evaluations as e on f.facility_sk = e.facility_sk
left join violations as v on f.facility_sk = v.facility_sk
left join enforcement as en on f.facility_sk = en.facility_sk
