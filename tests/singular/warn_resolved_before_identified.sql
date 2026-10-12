{{ config(severity='warn') }}
-- Violations resolved before they were formally identified. identified_date is
-- a determination date, so this is usually a violation corrected before the
-- paperwork was entered (median gap is a few weeks), not a data error. They are
-- excluded from days_to_resolution; this test keeps the count visible.
select
    violation_id,
    facility_id,
    enforcement_response_policy,
    identified_date,
    resolved_date
from {{ ref('fct_violations') }}
where resolved_date < identified_date
