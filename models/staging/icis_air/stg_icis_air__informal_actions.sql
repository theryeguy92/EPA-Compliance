with source as (
    select * from {{ source('icis_air', 'icis_air_informal_actions') }}
),

renamed as (
    select distinct
        trim(pgm_sys_id) as facility_id,
        trim(activity_id) as action_id,
        nullif(trim(enf_identifier), '') as case_number,
        trim(activity_type_code) as activity_type_code,
        trim(activity_type_desc) as activity_type_desc,
        {{ lead_agency('state_epa_flag') }} as lead_agency,
        trim(enf_type_code) as enforcement_type_code,
        trim(enf_type_desc) as enforcement_type_desc,
        {{ parse_epa_date('achieved_date') }} as achieved_date,
        upper(trim(official_flg)) = 'Y' as is_official
    -- About half the source rows are exact duplicates; distinct removes them.
    from source
)

select * from renamed
