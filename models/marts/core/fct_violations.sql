with violations as (
    select * from {{ ref('stg_icis_air__violations') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['violation_id']) }} as violation_sk,
    {{ dbt_utils.generate_surrogate_key(['facility_id']) }} as facility_sk,
    facility_id,
    violation_id,
    compliance_determination_id,
    enforcement_response_policy,
    is_high_priority,
    lead_agency,
    program_codes,
    pollutant_descs,
    identified_date,
    hpv_day_zero_date,
    discovery_date,
    resolved_date,
    resolved_date is not null as is_resolved,
    -- identified_date is when the agency recorded the violation, so a
    -- violation can be resolved before it is formally identified (corrected
    -- before the paperwork). Those are excluded rather than given negative
    -- durations; tests/singular/warn_resolved_before_identified.sql counts them.
    case
        when resolved_date >= identified_date
            then cast(date_diff('day', identified_date, resolved_date) as integer)
    end as days_to_resolution
from violations
