select count(*) AS count
from {{ref('stg_ga4__events')}}
