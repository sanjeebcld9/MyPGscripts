SELECT
    a.pid                           AS blocking_pid,
    a.usename                       AS blocking_user,
    a.datname                       AS database_name,
    a.client_addr                   AS blocking_client_ip,
    a.application_name              AS blocking_application,
    a.state                         AS blocking_state,

    now() - a.backend_start         AS blocker_session_age,
    now() - a.query_start           AS blocker_sql_age,

    COUNT(b.pid)                    AS blocked_session_count,

    a.wait_event_type,
    a.wait_event,

    a.query                          AS blocking_sql

FROM pg_stat_activity a

LEFT JOIN pg_stat_activity b
       ON a.pid = ANY(pg_blocking_pids(b.pid))

WHERE a.backend_type = 'client backend'

GROUP BY
    a.pid,
    a.usename,
    a.datname,
    a.client_addr,
    a.application_name,
    a.state,
    a.backend_start,
    a.query_start,
    a.wait_event_type,
    a.wait_event,
    a.query

HAVING COUNT(b.pid) > 0

ORDER BY
    blocked_session_count DESC,
    blocker_sql_age DESC;