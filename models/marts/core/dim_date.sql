with spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('" ~ var('date_spine_start') ~ "' as date)",
        end_date="cast('" ~ var('date_spine_end') ~ "' as date)"
    ) }}
),

final as (
    select
        cast(date_day as date) as date_day,
        cast(extract(year from date_day) as integer) as calendar_year,
        cast(extract(quarter from date_day) as integer) as calendar_quarter,
        cast(extract(month from date_day) as integer) as calendar_month,
        strftime(date_day, '%B') as month_name,
        cast(extract(isodow from date_day) as integer) as iso_day_of_week,
        extract(isodow from date_day) in (6, 7) as is_weekend,
        -- The federal fiscal year runs October through September, which is how
        -- EPA reports enforcement results.
        cast(extract(year from date_day) + case when extract(month from date_day) >= 10 then 1 else 0 end as integer)
            as federal_fiscal_year,
        cast(((extract(month from date_day) + 2) % 12) // 3 + 1 as integer) as federal_fiscal_quarter
    from spine
)

select * from final
