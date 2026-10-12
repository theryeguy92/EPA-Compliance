with actions as (
    select * from {{ ref('int_enforcement_actions__unioned') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['facility_id', 'action_id', 'action_category']) }} as enforcement_action_sk,
    {{ dbt_utils.generate_surrogate_key(['facility_id']) }} as facility_sk,
    facility_id,
    action_id,
    action_category,
    case_number,
    activity_type_desc,
    enforcement_type_code,
    enforcement_type_desc,
    lead_agency,
    action_date,
    penalty_amount,
    has_conflicting_penalty_records,
    is_official
from actions
