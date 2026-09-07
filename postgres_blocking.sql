SELECT
    blocked.pid                         AS blocked_pid,
    blocked.usename                     AS blocked_user,
    blocked.client_addr                 AS blocked_client_ip,
    blocked.application_name            AS blocked_application,
    now() - blocked.query_start         AS blocked_for,
    blocked.query                       AS blocked_sql,

    blocker.pid                         AS blocking_pid,
    blocker.usename                     AS blocking_user,
    blocker.client_addr                 AS blocking_client_ip,
    blocker.application_name            AS blocking_application,
    blocker.state                       AS blocking_state,
    now() - blocker.backend_start       AS blocking_session_age,
    now() - blocker.query_start         AS blocking_sql_runtime,
    blocker.query                       AS blocking_sql

FROM pg_stat_activity blocked

CROSS JOIN LATERAL
    unnest(pg_blocking_pids(blocked.pid)) AS bp(blocking_pid)

JOIN pg_stat_activity blocker
    ON blocker.pid = bp.blocking_pid

ORDER BY
    blocked.query_start;