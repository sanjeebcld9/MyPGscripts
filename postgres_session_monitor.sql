/* ============================================================
   PostgreSQL Session Monitor
   Oracle DBA Style
   ============================================================ */

WITH blocked AS (
    SELECT
        blocked_pid,
        blocking_pid
    FROM (
        SELECT
            a.pid AS blocked_pid,
            unnest(pg_blocking_pids(a.pid)) AS blocking_pid
        FROM pg_stat_activity a
        WHERE a.backend_type = 'client backend'
    ) x
),

blocker_count AS (
    SELECT
        blocking_pid,
        COUNT(*) AS blocked_session_count
    FROM blocked
    GROUP BY blocking_pid
)

SELECT
    /* ========================================================
       SESSION INFORMATION
       ======================================================== */

    a.pid                                           AS pid,
    a.usename                                       AS username,
    a.datname                                       AS database_name,

    /* Client / Machine */
    COALESCE(a.client_addr::text, 'LOCAL')          AS client_ip,
    a.client_hostname,
    a.client_port,

    /* Application / Program */
    COALESCE(NULLIF(a.application_name, ''), 'UNKNOWN')
                                                     AS application,

    /* ========================================================
       SESSION STATUS
       ======================================================== */

    a.state                                         AS state,

    CASE
        WHEN bl.blocking_pid IS NOT NULL
            THEN 'BLOCKED'

        WHEN a.state = 'active'
             AND a.query_start IS NOT NULL
             AND now() - a.query_start >
                 interval '5 minutes'
            THEN 'LONG RUNNING'

        WHEN a.state = 'active'
            THEN 'RUNNING'

        WHEN a.state = 'idle in transaction'
            THEN 'IDLE IN TXN'

        WHEN a.state = 'idle in transaction (aborted)'
            THEN 'IDLE IN TXN (ABORTED)'

        WHEN a.state = 'idle'
             AND now() - a.state_change >
                 interval '30 minutes'
            THEN 'LONG IDLE'

        WHEN a.state = 'idle'
            THEN 'IDLE'

        ELSE UPPER(a.state)

    END                                              AS session_status,

    /* ========================================================
       SESSION AGE
       ======================================================== */

    a.backend_start                                  AS login_time,

    now() - a.backend_start                          AS session_age,

    /* ========================================================
       TRANSACTION INFORMATION
       ======================================================== */

    a.xact_start,

    CASE
        WHEN a.xact_start IS NOT NULL
        THEN now() - a.xact_start
    END                                              AS transaction_age,

    /* ========================================================
       SQL INFORMATION
       ======================================================== */

    a.query_start,

    CASE
        WHEN a.state = 'active'
             AND a.query_start IS NOT NULL
        THEN now() - a.query_start
    END                                              AS sql_runtime,

    CASE
        WHEN a.state = 'idle'
        THEN now() - a.state_change
    END                                              AS idle_duration,

    CASE
        WHEN a.state IN
            ('idle in transaction',
             'idle in transaction (aborted)')
        THEN now() - a.state_change
    END                                              AS idle_txn_duration,

    /* ========================================================
       WAIT INFORMATION
       ======================================================== */

    a.wait_event_type                                AS wait_type,

    a.wait_event                                    AS wait_event,

    /* ========================================================
       BLOCKING INFORMATION
       ======================================================== */

    bl.blocking_pid                                  AS blocking_pid,

    ba.usename                                       AS blocking_username,

    ba.datname                                       AS blocking_database,

    COALESCE(ba.client_addr::text, 'LOCAL')
                                                     AS blocking_client_ip,

    COALESCE(NULLIF(ba.application_name, ''), 'UNKNOWN')
                                                     AS blocking_application,

    ba.state                                         AS blocking_state,

    CASE
        WHEN ba.pid IS NOT NULL
        THEN now() - ba.backend_start
    END                                              AS blocking_session_age,

    CASE
        WHEN ba.query_start IS NOT NULL
        THEN now() - ba.query_start
    END                                              AS blocking_sql_runtime,

    bc.blocked_session_count                         AS blocked_sessions,

    /* ========================================================
       BACKEND / PROCESS INFORMATION
       ======================================================== */

    a.backend_type,

    a.backend_xid,

    a.backend_xmin,

    /* ========================================================
       SQL / QUERY
       ======================================================== */

    a.query_id,

    a.query                                          AS current_sql,

    /* Blocking SQL */

    ba.query                                         AS blocking_sql

FROM pg_stat_activity a

/* Find blocking session */
LEFT JOIN blocked bl
       ON bl.blocked_pid = a.pid

/* Get blocker details */
LEFT JOIN pg_stat_activity ba
       ON ba.pid = bl.blocking_pid

/* Number of sessions blocked by this PID */
LEFT JOIN blocker_count bc
       ON bc.blocking_pid = a.pid

WHERE a.backend_type = 'client backend'

  /* Don't show your own monitoring session */
  AND a.pid <> pg_backend_pid()

ORDER BY

    /* Highest priority first */

    CASE
        WHEN bl.blocking_pid IS NOT NULL THEN 1
        WHEN a.state = 'active'
             AND now() - a.query_start >
                 interval '5 minutes' THEN 2
        WHEN a.state = 'idle in transaction' THEN 3
        WHEN a.state = 'idle in transaction (aborted)' THEN 4
        WHEN a.state = 'idle'
             AND now() - a.state_change >
                 interval '30 minutes' THEN 5
        WHEN a.state = 'active' THEN 6
        ELSE 7
    END,

    /* Longest SQL first */
    a.query_start ASC NULLS LAST;