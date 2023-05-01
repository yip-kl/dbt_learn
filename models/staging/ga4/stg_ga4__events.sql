SELECT
  * EXCEPT (event_date)
  ,PARSE_DATE('%Y%m%d', event_date) AS event_date
FROM {{ source('ga4', 'events')}}