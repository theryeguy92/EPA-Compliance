{{ config(severity='warn') }}
-- Counts source dates that parsed but fell outside the plausible window and
-- were nulled in staging (typos such as years 0001, 0218, 8888). Warn-only:
-- the build continues, but the count shows up in every run.
{% set checks = [
    ('icis_air_evaluations', 'actual_end_date'),
    ('icis_air_violations', 'earliest_frv_determ_date'),
    ('icis_air_violations', 'hpv_dayzero_date'),
    ('icis_air_violations', 'hpv_resolved_date'),
    ('icis_air_formal_actions', 'settlement_entered_date'),
    ('icis_air_informal_actions', 'achieved_date'),
    ('icis_air_programs', 'begin_date'),
] %}

with counts as (
    {% for table, column in checks %}
        select
            '{{ table }}.{{ column }}' as source_column,
            count(*) as nulled_dates
        from {{ source('icis_air', table) }}
        where
            {{ parse_epa_date_raw(column) }} is not null  -- noqa: LT02
            and {{ parse_epa_date(column) }} is null
        {% if not loop.last %}union all{% endif %}
    {% endfor %}
)

select * from counts
where nulled_dates > 0
