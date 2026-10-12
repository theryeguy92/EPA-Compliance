{# Decode ICIS-Air STATE_EPA_FLAG into the agency that led the activity. #}
{% macro lead_agency(column) -%}
    case upper(trim({{ column }}))
        when 'E' then 'EPA'
        when 'S' then 'State'
        when 'L' then 'Local'
    end
{%- endmacro %}
