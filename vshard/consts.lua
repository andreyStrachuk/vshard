return {
    -- Bucket FSM
    BUCKET = {
        ACTIVE = 'active',
        SENDING = 'sending',
        SENT = 'sent',
        RECEIVING = 'receiving',
        GARBAGE = 'garbage',
    },

    BUCKET_COUNT = 3000;
    BUCKET_SYNC_TIMEOUT = 0.1;
    BUCKET_SENT_GARBAGE_DELAY = 0.5;
    REBALANCER_DISBALANCE_THRESHOLD = 1;
    REBALANCER_IDLE_INTERVAL = 60 * 60;
    REBALANCER_WORK_INTERVAL = 10;
    REBALANCER_MAX_RECEIVING = 100;
    CALL_TIMEOUT = 0.1;
    SYNC_TIMEOUT = 1;
    RECONNECT_TIMEOUT = 0.5;
    GARBAGE_COLLECT_INTERVAL = 0.5;
}