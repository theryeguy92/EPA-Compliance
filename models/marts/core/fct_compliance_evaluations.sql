{{
    config(
        materialized='incremental',
        incremental_strategy='merge',
        unique_key='evaluation_sk',
        on_schema_change='fail'
    )
}}

with evaluations as (
    select * from {{ ref('stg_icis_air__evaluations') }}
    {% if is_incremental() %}
        -- EPA backfills late-reported evaluations, so reprocess a lookback
        -- window behind the current high-water mark instead of only new dates.
        where evaluation_date >= (
            select max(evaluation_date) - interval {{ var('incremental_lookback_days') }} day
            from {{ this }}
        )
        or evaluation_date is null
    {% endif %}
)

select
    {{ dbt_utils.generate_surrogate_key(['facility_id', 'evaluation_id']) }} as evaluation_sk,
    {{ dbt_utils.generate_surrogate_key(['facility_id']) }} as facility_sk,
    facility_id,
    evaluation_id,
    evaluation_date,
    evaluation_category,
    monitor_type_code,
    monitor_type_desc,
    is_on_site,
    lead_agency,
    program_codes,
    evaluation_purposes,
    source_row_count
from evaluations
