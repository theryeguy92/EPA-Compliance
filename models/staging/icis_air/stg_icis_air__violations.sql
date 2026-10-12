with source as (
    select * from {{ source('icis_air', 'icis_air_violations') }}
),

renamed as (
    select
        trim(activity_id) as violation_id,
        trim(pgm_sys_id) as facility_id,
        case
            when agency_type_desc = 'U.S. EPA' then 'EPA'
            when agency_type_desc in ('State', 'State Contractor', 'Other - State') then 'State'
            when agency_type_desc in ('Local', 'County') then 'Local'
            when agency_type_desc is not null then 'Other'
        end as lead_agency,
        nullif(trim(state_code), '') as state_code,
        nullif(trim(comp_determination_uid), '') as compliance_determination_id,
        upper(trim(enf_response_policy_code)) as enforcement_response_policy,
        nullif(trim(program_codes), '') as program_codes,
        nullif(trim(program_descs), '') as program_descs,
        nullif(trim(pollutant_codes), '') as pollutant_codes,
        nullif(trim(pollutant_descs), '') as pollutant_descs,
        {{ parse_epa_date('earliest_frv_determ_date') }} as frv_determination_date,
        {{ parse_epa_date('hpv_dayzero_date') }} as hpv_day_zero_date,
        {{ parse_epa_date('hpv_resolved_date') }} as resolved_date,
        {{ parse_epa_date('dscv_pathway_date') }} as discovery_date,
        {{ parse_epa_date('nftc_pathway_date') }} as notification_date
    from source
),

final as (
    select
        *,
        enforcement_response_policy = 'HPV' as is_high_priority,
        coalesce(hpv_day_zero_date, frv_determination_date, discovery_date) as identified_date
    from renamed
)

select * from final
