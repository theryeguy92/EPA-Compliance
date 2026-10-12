-- Type 2 history of facility status, from the snapshot. One row per facility
-- per period in which its operating and compliance status held.
select
    {{ dbt_utils.generate_surrogate_key(['facility_id']) }} as facility_sk,
    facility_id,
    operating_status_code,
    operating_status_desc,
    compliance_status,
    pollutant_class_code,
    dbt_valid_from as valid_from,
    dbt_valid_to as valid_to,
    dbt_valid_to is null as is_current
from {{ ref('snap_facility_compliance_status') }}
