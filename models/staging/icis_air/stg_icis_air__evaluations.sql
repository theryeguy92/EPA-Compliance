with source as (
    select * from {{ source('icis_air', 'icis_air_evaluations') }}
),

renamed as (
    select
        trim(pgm_sys_id) as facility_id,
        trim(activity_id) as evaluation_id,
        {{ lead_agency('state_epa_flag') }} as lead_agency,
        trim(comp_monitor_type_code) as monitor_type_code,
        trim(comp_monitor_type_desc) as monitor_type_desc,
        {{ parse_epa_date('actual_end_date') }} as evaluation_date,
        nullif(trim(program_codes), '') as program_codes,
        nullif(trim(activity_purpose_desc), '') as purpose
    from source
),

-- One evaluation is repeated once per stated purpose; collapse to one row per
-- evaluation and keep every purpose.
collapsed as (
    select
        facility_id,
        evaluation_id,
        any_value(lead_agency) as lead_agency,
        any_value(monitor_type_code) as monitor_type_code,
        any_value(monitor_type_desc) as monitor_type_desc,
        any_value(evaluation_date) as evaluation_date,
        any_value(program_codes) as program_codes,
        string_agg(distinct purpose, '; ' order by purpose) as evaluation_purposes,
        count(*) as source_row_count
    from renamed
    group by facility_id, evaluation_id
),

final as (
    select
        *,
        case
            when monitor_type_desc ilike 'FCE%' then 'FCE'
            when monitor_type_desc ilike 'PCE%' then 'PCE'
        end as evaluation_category,
        monitor_type_desc ilike '%on-site%' as is_on_site
    from collapsed
)

select * from final
