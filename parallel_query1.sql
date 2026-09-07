SELECT 
    pid AS worker_pid,
    leader_pid,
    application_name,
    usename,
    state,
    age(clock_timestamp(), query_start) AS duration,
    query
FROM pg_stat_activity
WHERE leader_pid IS NOT NULL
ORDER BY leader_pid, pid;