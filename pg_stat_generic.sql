WITH activity AS (
    SELECT
        a.pid,
        a.datid,
        a.datname,
        a.usename,
        a.application_name,
        a.client_addr,
        a.client_hostname,
        a.client_port,
        a.backend_start,
        a.xact_start,
        a.query_start,
        a.state_change,
        a.wait_event_type,
        a.wait_event,
        a.state,
        a.backend_xid,
        a.backend_xmin,
        a.query_id,
        a.query,
        a.backend_type,

        /* Session age */
        now() - a.backend_start AS session_age,

        /* Transaction age */
        CASE
            WHEN a.xact_start IS NOT NULL
            THEN now() - a.xact_start
        END AS transaction_age,

        /* Current SQL execution time */
        CASE
            WHEN a.state = 'active'
                 AND a.query_start IS NOT NULL
            THEN now() - a.query_start
        END AS active_sql_duration,

        /* Current idle duration */
        CASE
            WHEN a.state = 'idle'
            THEN now() - a.state_change
        END AS idle_duration,

        /* Idle in transaction duration */
        CASE
            WHEN a.state IN
                 ('idle in transaction',
                  'idle in transaction (aborted)')
            THEN now() - a.state_change
        END AS idle_in_txn_duration

    FROM pg_stat_activity a
    WHERE a.backend_type = 'client backend'
),

blocking AS (
    SELECT
        blocked.pid AS blocked_pid,
        blocker.pid AS blocking_pid,
        blocker.usename AS blocking_user,
        blocker.application_name AS blocking_application,
        blocker.client_addr AS blocking_client_ip,
        blocker.state AS blocking_state,
        blocker.query AS blocking_sql,
        blocker.query_start AS blocking_query_start
    FROM pg_stat_activity blocked
    CROSS JOIN LATERAL unnest(
        pg_blocking_pids(blocked.pid)
    ) AS bp(blocking_pid)
    JOIN pg_stat_activity blocker
        ON blocker.pid = bp.blocking_pid
)

SELECT
    /* Session information */
    a.pid,
    a.usename                         AS username,
    a.datname                         AS database_name,

    /* Client information */
    a.client_addr                     AS client_ip,
    a.client_hostname,
    a.client_port,
    a.application_name                AS client_application,

    /* Session state */
    a.state,
    a.backend_type,

    /* Timing */
    a.backend_start,
    a.session_age,

    a.xact_start,
    a.transaction_age,

    a.query_start,

    a.active_sql_duration,
    a.idle_duration,
    a.idle_in_txn_duration,

    a.state_change,

    /* Wait information */
    a.wait_event_type,
    a.wait_event,

    /* Blocking information */
    b.blocking_pid,
    b.blocking_user,
    b.blocking_application,
    b.blocking_client_ip,
    b.blocking_state,
    b.blocking_query_start,
    b.blocking_sql,

    /* Connection pool indicators */
    CASE
        WHEN a.application_name ILIKE '%pgbouncer%'
            THEN 'PgBouncer'
        WHEN a.application_name ILIKE '%jdbc%'
            THEN 'JDBC'
        WHEN a.application_name ILIKE '%dbeaver%'
            THEN 'DBeaver'
        WHEN a.application_name ILIKE '%python%'
            THEN 'Python'
        WHEN a.application_name ILIKE '%psql%'
            THEN 'psql'
        WHEN a.application_name ILIKE '%odbc%'
            THEN 'ODBC'
        ELSE 'Application / Unknown'
    END AS connection_source,

    CASE
        WHEN a.state = 'active'
             AND a.query_start IS NOT NULL
        THEN 'RUNNING SQL'

        WHEN a.state = 'idle'
             AND now() - a.state_change > interval '30 minutes'
        THEN 'LONG IDLE'

        WHEN a.state IN
             ('idle in transaction',
              'idle in transaction (aborted)')
        THEN 'IDLE IN TRANSACTION'

        WHEN b.blocking_pid IS NOT NULL
        THEN 'BLOCKED'

        ELSE upper(a.state)
    END AS session_status,

    /* SQL */
    a.query_id,
    a.query

FROM activity a

LEFT JOIN blocking b
    ON b.blocked_pid = a.pid

ORDER BY
    CASE
        WHEN b.blocking_pid IS NOT NULL THEN 1
        WHEN a.state = 'active' THEN 2
        WHEN a.state IN
             ('idle in transaction',
              'idle in transaction (aborted)') THEN 3
        ELSE 4
    END,
    a.active_sql_duration DESC NULLS LAST,
    a.session_age DESC;