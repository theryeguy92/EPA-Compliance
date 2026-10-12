{#
    ICIS-Air ships dates in two formats depending on the file:
    MM-DD-YYYY (evaluations, violations) and MM/DD/YYYY (enforcement
    actions, programs). Try both, then null out implausible values
    (the source contains typos such as years 0001, 0218 and 8888).
    tests/singular/warn_implausible_source_dates.sql counts what was nulled.
#}
{% macro parse_epa_date_raw(column) -%}
    coalesce(
        try_strptime(nullif(trim({{ column }}), ''), '%m/%d/%Y'),
        try_strptime(nullif(trim({{ column }}), ''), '%m-%d-%Y')
    )::date
{%- endmacro %}

{% macro parse_epa_date(column) -%}
    case
        when {{ parse_epa_date_raw(column) }}
            between date '{{ var("plausible_date_min") }}' and current_date + interval 1 year
            then {{ parse_epa_date_raw(column) }}
    end
{%- endmacro %}
