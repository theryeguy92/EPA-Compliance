with facilities as (
    select * from {{ ref('stg_icis_air__facilities') }}
)

select
    {{ dbt_utils.generate_surrogate_key(['facility_id']) }} as facility_sk,
    facility_id,
    frs_registry_id,
    facility_name,
    street_address,
    city,
    county_name,
    state_code,
    zip_code,
    epa_region,
    sic_codes,
    naics_codes,
    facility_type_code,
    pollutant_class_code,
    pollutant_class_desc,
    operating_status_code,
    operating_status_desc,
    compliance_status,
    -- EPA's "Unaddressed-<agency>" statuses: a violation with no enforcement response yet.
    coalesce(compliance_status like 'Unaddressed-%', false) as has_unaddressed_violation,
    local_control_region_name
from facilities
