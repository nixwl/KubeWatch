# == Envirment Variables ==================================================================================
# BLADE_NAME: the name of the ChaosBlade instance
# HIGH: the high CPU usage threshold
# LOW: the low CPU usage threshold
# CYCLES: the number of ramp cycles
# HOLD_SECONDS: the duration to hold the CPU usage
# RAMP_SECONDS: the duration to ramp up the CPU usage
HELPER_DIR="/data/nfs-conf/chaosblade/shell/helper"
BLADE_NAME="chaosblade-singlenode-cpu-ramp-payload"
HIGH="95"
LOW="80"
CYCLES="5"
HOLD_SECONDS="70"
RAMP_SECONDS="20"
TARGET_NODE="emanage1"
CLEANUP="true"
TOTAL_SECONDS=$(( CYCLES * (HOLD_SECONDS + RAMP_SECONDS) + 60 ))
CRON_SCHEDULE="30 */4 * * *"  # Run at minute 30 every 4 hours

# install resource configmap
bash $HELPER_DIR/node_cpu_ramp_helper.sh install

# set envs configmap
# HELP: bash node_cpu_ramp_helper.sh show
bash $HELPER_DIR/node_cpu_ramp_helper.sh set BLADE_NAME=$BLADE_NAME \
     HIGH=$HIGH \
     LOW=$LOW \
     CYCLES=$CYCLES \
     HOLD_SECONDS=$HOLD_SECONDS \
     RAMP_SECONDS=$RAMP_SECONDS \
     TARGET_NODE=$TARGET_NODE \
     CLEANUP=$CLEANUP

# install cron's configmap
bash $HELPER_DIR/node_cpu_ramp_helper.sh install cron 

# Set cron parameters to adapt to the calculated duration
bash $HELPER_DIR/node_cpu_ramp_helper.sh cron set activeDeadlineSeconds=$TOTAL_SECONDS
bash $HELPER_DIR/node_cpu_ramp_helper.sh cron set schedule="$CRON_SCHEDULE"
# OR
# bash $HELPER_DIR/node_cpu_ramp_helper.sh cron schedule "$CRON_SCHEDULE"

# Run cron job
# HELP: bash node_cpu_ramp_helper.sh cron --help
bash $HELPER_DIR/node_cpu_ramp_helper.sh cron enable