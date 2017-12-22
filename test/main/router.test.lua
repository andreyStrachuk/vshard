test_run = require('test_run').new()
test_run:cmd("push filter '.*/init.lua.*[0-9]+: ' to ''")
netbox = require('net.box')
fiber = require('fiber')

REPLICASET_1 = { 'storage_1_a', 'storage_1_b' }
REPLICASET_2 = { 'storage_2_a', 'storage_2_b' }

test_run:create_cluster(REPLICASET_1, 'main')
test_run:create_cluster(REPLICASET_2, 'main')
test_run:wait_fullmesh(REPLICASET_1)
test_run:wait_fullmesh(REPLICASET_2)
test_run:cmd("create server router_1 with script='main/router_1.lua'")
test_run:cmd("start server router_1")

replicaset1_uuid = test_run:eval('storage_1_a', 'box.info.cluster.uuid')[1]
replicaset2_uuid = test_run:eval('storage_2_a', 'box.info.cluster.uuid')[1]
test_run:cmd("push filter '"..replicaset1_uuid.."' to '<replicaset_1>'")
test_run:cmd("push filter '"..replicaset2_uuid.."' to '<replicaset_2>'")

_ = test_run:cmd("switch router_1")
-- gh-46: Ensure a cfg is not destroyed after router.cfg().
cfg.sharding ~= nil

-- gh-24: log all connnect/disconnect events.
test_run:grep_log('router_1', 'connected to ')

--
-- Initial distribution
--
replicaset, err = vshard.router.bucket_discovery(1); return err == nil or err
vshard.router.bootstrap()
replicaset, err = vshard.router.bucket_discovery(1); return err == nil or err
replicaset, err = vshard.router.bucket_discovery(2); return err == nil or err

--
-- Function call
--

bucket_id = 1
test_run:cmd("setopt delimiter ';'")

customer = {
    customer_id = 1,
    name = "Customer 1",
    bucket_id = bucket_id,
    accounts = {
        {
            account_id = 10,
            name = "Credit Card",
            balance = 100,
        },
        {
            account_id = 11,
            name = "Debit Card",
            balance = 50,
        },
    }
}
test_run:cmd("setopt delimiter ''");

vshard.router.call(bucket_id, 'write', 'customer_add', {customer})
vshard.router.call(bucket_id, 'read', 'customer_lookup', {1})
vshard.router.call(bucket_id + 1, 'read', 'customer_lookup', {1}) -- nothing

--
-- Monitoring
--

vshard.router.info().replicasets[1].master.state
vshard.router.info().replicasets[2].master.state

--
-- Configuration: inconsistency master=true on storage and routers
--
-- This test case flips masters in replicasets without changing
-- configuration on router and tests NON_MASTER response
--

-- Test the WRITE request
vshard.router.call(1, 'write', 'echo', { 'hello world' })

-- Shuffle masters
util = require('util')
util.shuffle_masters(cfg)

-- Reconfigure storages
test_run:cmd("switch storage_1_a")
cfg.sharding = test_run:eval('router_1', 'return cfg.sharding')[1]
vshard.storage.cfg(cfg, names['storage_1_a'])

test_run:cmd("switch storage_1_b")
cfg.sharding = test_run:eval('router_1', 'return cfg.sharding')[1]
vshard.storage.cfg(cfg, names['storage_1_b'])

test_run:cmd("switch storage_2_a")
cfg.sharding = test_run:eval('router_1', 'return cfg.sharding')[1]
vshard.storage.cfg(cfg, names['storage_2_a'])

test_run:cmd("switch storage_2_b")
cfg.sharding = test_run:eval('router_1', 'return cfg.sharding')[1]
vshard.storage.cfg(cfg, names['storage_2_b'])

-- Test that the WRITE request doesn't work
test_run:cmd("switch router_1")
util.check_error(vshard.router.call, 1, 'write', 'echo', { 'hello world' })

-- Reconfigure router and test that the WRITE request does work
vshard.router.cfg(cfg)
vshard.router.call(1, 'write', 'echo', { 'hello world' })


_ = test_run:cmd("switch default")
test_run:drop_cluster(REPLICASET_2)

-- gh-24: log all connnect/disconnect events.
while test_run:grep_log('router_1', 'disconnected from ') == nil do fiber.sleep(0.1) end

test_run:cmd("stop server router_1")
test_run:cmd("cleanup server router_1")
test_run:drop_cluster(REPLICASET_1)
test_run:cmd('clear filter')