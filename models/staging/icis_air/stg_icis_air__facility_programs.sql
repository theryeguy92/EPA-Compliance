with source as (
    select * from {{ source('icis_air', 'icis_air_programs') }}
),

renamed as (
    select
        trim(pgm_sys_id) as facility_id,
        trim(program_code) as program_code,
        nullif(trim(program_desc), '') as program_desc,
        nullif(trim(air_operating_status_code), '') as operating_status_code,
        nullif(trim(air_operating_status_desc), '') as operating_status_desc,
        {{ parse_epa_date('begin_date') }} as program_begin_date,
        {{ parse_epa_date('updated_date') }} as program_updated_date
    from source
),

-- The export carries one duplicated facility/program pair; keep the most recently updated row.
deduplicated as (
    select * from renamed
    qualify row_number() over (
        partition by facility_id, program_code
        order by program_updated_date desc nulls last, program_begin_date desc nulls last
    ) = 1
)

select * from deduplicated
