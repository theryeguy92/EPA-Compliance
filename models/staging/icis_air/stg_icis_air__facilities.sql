with source as (
    select * from {{ source('icis_air', 'icis_air_facilities') }}
),

renamed as (
    select
        trim(pgm_sys_id) as facility_id,
        nullif(trim(registry_id), '') as frs_registry_id,
        trim(facility_name) as facility_name,
        nullif(trim(street_address), '') as street_address,
        nullif(trim(city), '') as city,
        nullif(trim(county_name), '') as county_name,
        upper(nullif(trim(state), '')) as state_code,
        nullif(trim(zip_code), '') as zip_code,
        nullif(trim(epa_region), '') as epa_region,
        nullif(trim(sic_codes), '') as sic_codes,
        nullif(trim(naics_codes), '') as naics_codes,
        nullif(trim(facility_type_code), '') as facility_type_code,
        nullif(trim(air_pollutant_class_code), '') as pollutant_class_code,
        nullif(trim(air_pollutant_class_desc), '') as pollutant_class_desc,
        nullif(trim(air_operating_status_code), '') as operating_status_code,
        nullif(trim(air_operating_status_desc), '') as operating_status_desc,
        nullif(trim(current_hpv), '') as compliance_status,
        nullif(trim(local_control_region_code), '') as local_control_region_code,
        nullif(trim(local_control_region_name), '') as local_control_region_name,
        _loaded_at
    from source
)

select * from renamed
