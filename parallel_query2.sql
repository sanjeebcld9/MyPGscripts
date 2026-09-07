SELECT 
    pid,
    COALESCE(leader_pid, pid) AS effective_leader_id,
    CASE 
        WHEN leader_pid IS NULL THEN 'Leader'
        ELSE 'Parallel Worker'
    END AS process_role,
    state,
    age(clock_timestamp(), query_start) AS duration,
    query
FROM pg_stat_activity
WHERE state != 'idle'
  AND (leader_pid IS NOT NULL OR pid IN (SELECT leader_pid FROM pg_stat_activity WHERE leader_pid IS NOT NULL))
ORDER BY effective_leader_id, leader_pid NULLS FIRST;