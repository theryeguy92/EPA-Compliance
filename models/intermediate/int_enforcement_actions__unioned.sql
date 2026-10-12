-- Formal and informal enforcement share one fact table; action_category tells them apart.
with formal as (
    select
        facility_id,
        action_id,
        'formal' as action_category,
        case_number,
        activity_type_desc,
        primary_enforcement_type_code as enforcement_type_code,
        primary_enforcement_type_desc as enforcement_type_desc,
        lead_agency,
        settlement_date as action_date,
        penalty_amount,
        has_conflicting_penalty_records,
        true as is_official
    from {{ ref('stg_icis_air__formal_actions') }}
),

informal as (
    select
        facility_id,
        action_id,
        'informal' as action_category,
        case_number,
        activity_type_desc,
        enforcement_type_code,
        enforcement_type_desc,
        lead_agency,
        achieved_date as action_date,
        cast(null as decimal(18, 2)) as penalty_amount,
        false as has_conflicting_penalty_records,
        is_official
    from {{ ref('stg_icis_air__informal_actions') }}
)

select * from formal
union all
select * from informal
