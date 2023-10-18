OPS_BEDROCK_L1_IMAGE = "ops-bedrock-l1:latest"
OPS_BEDROCK_L2_IMAGE = "ops-bedrock-l2:latest"
OP_NODE_IMAGE = "ops-bedrock-op-node:latest"
OP_PROPOSER_IMAGE = "ops-bedrock-op-proposer:latest"

RPC_PORT_NUM = 8545
WS_PORT_NUM = 8546


def run(plan):
    uploaded_files = upload_config_and_genesis_files(plan)

    l1 = launch_l1(plan, uploaded_files)

    l2 = launch_l2(plan, uploaded_files)

    op_node = launch_op_node(plan, uploaded_files, l1, l2)

    op_proposer = launch_proposer(plan, uploaded_files, l1, op_node)


def launch_proposer(plan, uploaded_files, l1, op_node):
    return plan.add_service(
        name="op-proposer",
        config=ServiceConfig(
            image=OP_PROPOSER_IMAGE,
            ports={
                "pprof": PortSpec(6060),
                "rpc": PortSpec(RPC_PORT_NUM),
                "metrics": PortSpec(7300),
            },
            env_vars={
                "OP_PROPOSER_L1_ETH_RPC": "http://{0}:{0}".format(
                    l1.name, RPC_PORT_NUM
                ),
                "OP_PROPOSER_ROLLUP_RPC": "http://{0}:{0}".format(
                    op_node.name, RPC_PORT_NUM
                ),
                "OP_PROPOSER_POLL_INTERVAL": "1s",
                "OP_PROPOSER_NUM_CONFIRMATIONS": "1",
                "OP_PROPOSER_MNEMONIC": "test test test test test test test test test test test junk",
                "OP_PROPOSER_L2_OUTPUT_HD_PATH": "m/44'/60'/0'/0/1",
                "OP_PROPOSER_L2OO_ADDRESS": "${L2OO_ADDRESS}",
                "OP_PROPOSER_PPROF_ENABLED": "true",
                "OP_PROPOSER_METRICS_ENABLED": "true",
                "OP_PROPOSER_ALLOW_NON_FINALIZED": "true",
                "OP_PROPOSER_RPC_ENABLE_ADMIN": "true",
            },
        ),
    )


def launch_op_node(plan, uploaded_files, l1, l2):
    return plan.add_service(
        name="op-node",
        config=ServiceConfig(
            image=OP_NODE_IMAGE,
            cmd=[
                "op-node",
                "--l1=ws://{0}:{1}".format(l1.name, WS_PORT_NUM),
                "--l2=http://{0}:{1}".format(l2.name, RPC_PORT_NUM),
                "--l2.jwt-secret=/config/test-jwt-secret.txt",
                "--sequencer.enabled",
                "--sequencer.l1-confs=0",
                "--verifier.l1-confs=0",
                "--p2p.sequencer.key=8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba",
                "--rollup.config=/rollup/rollup.json",
                "--rpc.addr=0.0.0.0",
                "--rpc.port=8545",
                "--p2p.listen.ip=0.0.0.0",
                "--p2p.listen.tcp=9003",
                "--p2p.listen.udp=9003",
                "--p2p.scoring.peers=light",
                "--p2p.ban.peers=true",
                # slight diversion as we don't have op_log volume
                "--snapshotlog.file=/tmp/snapshot.log",
                "--p2p.priv.path=/config/p2p-node-key.txt",
                "--metrics.enabled",
                "--metrics.addr=0.0.0.0",
                "--metrics.port=7300",
                "--pprof.enabled",
                "--rpc.enable-admin",
            ],
            ports={
                "rpc": PortSpec(RPC_PORT_NUM),
                "metrics": PortSpec(7300),
                "pprof": PortSpec(6060),
                "p2p-tcp": PortSpec(9003),
                "p2p-udp": PortSpec(9003, transport_protocol="UDP"),
            },
            files={"/config/": uploaded_files.config, "/rollup": uploaded_files.rollup},
        ),
    )


def launch_l1(plan, uploaded_files):
    # To highlight - waits are automatic here
    return plan.add_service(
        name="l1",
        config=ServiceConfig(
            image=OPS_BEDROCK_L1_IMAGE,
            ports={
                "rpc": PortSpec(number=RPC_PORT_NUM),
                "ws": PortSpec(number=WS_PORT_NUM),
                "metrics": PortSpec(number=6060),
            },
            env_vars={"GENESIS_FILE_PATH": "/genesis/genesis-l1.json"},
            files={
                "/config/": uploaded_files.config,
                "/genesis/": uploaded_files.l1_genesis,
            },
        ),
    )


def launch_l2(plan, uploaded_files):
    return plan.add_service(
        name="l2",
        config=ServiceConfig(
            image=OPS_BEDROCK_L2_IMAGE,
            ports={
                "rpc": PortSpec(number=RPC_PORT_NUM),
                "metrics": PortSpec(number=6060),
            },
            env_vars={"GENESIS_FILE_PATH": "/genesis/genesis-l2.json"},
            entrypoint=[
                "/bin/sh",
                "/entrypoint.sh",
                "--authrpc.jwtsecret=/config/test-jwt-secret.txt",
            ],
            files={
                "/config/": uploaded_files.config,
                "/genesis/": uploaded_files.l2_genesis,
            },
        ),
    )


def upload_config_and_genesis_files(plan):
    # This file has been copied over from ".devnet"; its a generated file
    # TODO generate this in Kurtosis
    l1_genesis = plan.upload_files(
        src="./static_files/genesis/genesis-l1.json", name="l1-genesis"
    )

    #  This file is checked in to the repository; so is static
    config = plan.upload_files(src="./static_files/config", name="jwt-secret")

    # This file has been copied over from ".devnet"; its a generated file
    # TODO generate this in Kurtosis
    l2_genesis = plan.upload_files(
        src="./static_files/genesis/genesis-l2.json", name="l2-genesis"
    )

    rollup = plan.upload_files(src="./static_files/rollup.json", name="rollup")

    return struct(
        l1_genesis=l1_genesis,
        l2_genesis=l2_genesis,
        config=config,
        rollup=rollup,
    )
