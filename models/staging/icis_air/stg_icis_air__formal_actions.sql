with source as (
    select * from {{ source('icis_air', 'icis_air_formal_actions') }}
),

renamed as (
    select
        trim(pgm_sys_id) as facility_id,
        trim(activity_id) as action_id,
        nullif(trim(enf_identifier), '') as case_number,
        trim(activity_type_code) as activity_type_code,
        trim(activity_type_desc) as activity_type_desc,
        {{ lead_agency('state_epa_flag') }} as lead_agency,
        trim(enf_type_code) as enforcement_type_code,
        trim(enf_type_desc) as enforcement_type_desc,
        {{ parse_epa_date('settlement_entered_date') }} as settlement_date,
        try_cast(nullif(trim(penalty_amount), '') as decimal(18, 2)) as penalty_amount
    from source
),

-- An action can repeat with several enforcement types or with conflicting
-- penalty amounts (e.g. 2602 vs 2631). Summing would double-count, so keep
-- the largest assessed penalty and flag the conflict for review.
collapsed as (
    select
        facility_id,
        action_id,
        any_value(case_number) as case_number,
        any_value(activity_type_code) as activity_type_code,
        any_value(activity_type_desc) as activity_type_desc,
        any_value(lead_agency) as lead_agency,
        min(enforcement_type_code) as primary_enforcement_type_code,
        arg_min(enforcement_type_desc, enforcement_type_code) as primary_enforcement_type_desc,
        string_agg(distinct enforcement_type_code, '; ' order by enforcement_type_code) as enforcement_type_codes,
        max(settlement_date) as settlement_date,
        max(penalty_amount) as penalty_amount,
        count(distinct penalty_amount) > 1 as has_conflicting_penalty_records,
        count(*) as source_row_count
    from renamed
    group by facility_id, action_id
)

select * from collapsed
