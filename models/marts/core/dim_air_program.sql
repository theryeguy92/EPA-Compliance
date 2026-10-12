-- One row per Clean Air Act program (SIP, NSPS, NESHAP, MACT, Title V, ...).
with programs as (
    select
        program_code,
        program_desc
    from {{ ref('stg_icis_air__facility_programs') }}
    where program_code is not null
)

select
    program_code,
    -- Descriptions are repeated on every enrollment row; take the most common spelling.
    mode(program_desc) as program_desc,
    count(*) as facility_enrollment_count
from programs
group by program_code
