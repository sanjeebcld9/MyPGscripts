SELECT
    pid,
    usename AS username,
    datname AS database_name,
    client_addr AS client_ip,
    client_hostname,
    application_name,
    state,

    CASE
        WHEN state = 'active'
            THEN now() - query_start
        WHEN state = 'idle'
            THEN now() - state_change
        WHEN state = 'idle in transaction'
            THEN now() - state_change
        WHEN state = 'idle in transaction (aborted)'
            THEN now() - state_change
        ELSE NULL
    END AS state_duration,

    query_start,
    state_change,
    backend_start,

    wait_event_type,
    wait_event,

    query
FROM pg_stat_activity
WHERE pid <> pg_backend_pid()
ORDER BY state_duration DESC NULLS LAST;