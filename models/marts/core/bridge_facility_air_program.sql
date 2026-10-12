-- Facility-to-program enrollment (many-to-many).
select
    {{ dbt_utils.generate_surrogate_key(['facility_id']) }} as facility_sk,
    facility_id,
    program_code,
    operating_status_code,
    operating_status_desc,
    program_begin_date,
    program_updated_date
from {{ ref('stg_icis_air__facility_programs') }}
