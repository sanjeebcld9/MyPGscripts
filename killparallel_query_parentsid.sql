SELECT 
    pid AS worker_pid,
    leader_pid,
    usename,
    age(clock_timestamp(), query_start) AS duration,
    query
FROM pg_stat_activity
WHERE leader_pid IS NOT NULL;


# Gracefully Cancel the Query (Recommended)

SELECT pg_cancel_backend(<leader_pid>);


# Force-Terminate the Backend (If Cancel Fails)

SELECT pg_terminate_backend(<leader_pid>);



