#!/bin/bash
# Start Hadoop & Spark cluster with health checks
# Author: Mohamed Amine Belhassine
# Usage: ./start_cluster.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠  $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Check if running on master node
if [[ ! "$(hostname)" == "m-1" ]]; then
    print_warning "This script should be run on the master node (m-1)"
    print_info "Current hostname: $(hostname)"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

print_header "🚀 Starting Hadoop & Spark Cluster"

# Step 1: Start HDFS
print_info "Step 1/5: Starting HDFS (NameNode, DataNodes, SecondaryNameNode)..."
start-dfs.sh
sleep 5

# Verify HDFS started
if jps | grep -q "NameNode"; then
    print_success "NameNode started successfully"
else
    print_error "Failed to start NameNode"
    exit 1
fi

# Step 2: Wait for HDFS to exit safe mode
print_info "Step 2/5: Waiting for HDFS to exit safe mode..."
print_info "This may take 30-60 seconds..."

if timeout 300 hdfs dfsadmin -safemode wait; then
    print_success "HDFS exited safe mode successfully"
else
    print_error "HDFS did not exit safe mode within 5 minutes"
    print_warning "Trying to force leave safe mode..."
    hdfs dfsadmin -safemode leave
fi

# Check HDFS health
print_info "Checking HDFS health..."
LIVE_NODES=$(hdfs dfsadmin -report | grep "Live datanodes" | awk '{print $3}' | sed 's/://g')
print_info "Live DataNodes: $LIVE_NODES"

if [[ "$LIVE_NODES" -lt 2 ]]; then
    print_warning "Expected 2 DataNodes but found $LIVE_NODES"
    print_info "This may resolve itself in a minute. Continuing..."
fi

# Step 3: Start YARN
print_info "Step 3/5: Starting YARN (ResourceManager, NodeManagers)..."
start-yarn.sh
sleep 5

# Verify YARN started
if jps | grep -q "ResourceManager"; then
    print_success "ResourceManager started successfully"
else
    print_error "Failed to start ResourceManager"
    exit 1
fi

# Wait for NodeManagers to register
print_info "Waiting for NodeManagers to register (30 seconds)..."
sleep 30

# Check YARN health
print_info "Checking YARN health..."
ACTIVE_NODES=$(yarn node -list 2>/dev/null | grep "RUNNING" | wc -l)
print_info "Active YARN nodes: $ACTIVE_NODES"

if [[ "$ACTIVE_NODES" -lt 2 ]]; then
    print_warning "Expected 2 NodeManagers but found $ACTIVE_NODES"
    print_info "This may resolve itself in a minute. Continuing..."
fi

# Step 4: Start Spark History Server
print_info "Step 4/5: Starting Spark History Server..."

if [[ -z "$SPARK_HOME" ]]; then
    print_error "SPARK_HOME not set. Please set it in ~/.bashrc"
    exit 1
fi

$SPARK_HOME/sbin/start-history-server.sh
sleep 3

# Verify Spark History Server started
if jps | grep -q "HistoryServer"; then
    print_success "Spark History Server started successfully"
else
    print_error "Failed to start Spark History Server"
fi

# Step 5: Final health check
print_header "📊 Cluster Health Report"

print_info "Running processes on master node (m-1):"
jps | grep -v "Jps"

print_info "\nHDFS Status:"
hdfs dfsadmin -report | grep -E "Live datanodes|Configured Capacity|DFS Used%"

print_info "\nYARN Nodes:"
yarn node -list 2>/dev/null | head -5

print_info "\nWeb UIs (replace <m-1-ip> with your public IP):"
echo -e "${GREEN}  HDFS NameNode:        http://<m-1-ip>:9870${NC}"
echo -e "${GREEN}  YARN ResourceManager: http://<m-1-ip>:8088${NC}"
echo -e "${GREEN}  Spark History Server: http://<m-1-ip>:18080${NC}"

print_header "✅ Cluster Startup Complete!"

# Final summary
NAMENODE_STATUS=$(jps | grep -c "NameNode")
RESOURCEMANAGER_STATUS=$(jps | grep -c "ResourceManager")
HISTORYSERVER_STATUS=$(jps | grep -c "HistoryServer")

if [[ "$NAMENODE_STATUS" -eq 1 ]] && [[ "$RESOURCEMANAGER_STATUS" -eq 1 ]] && [[ "$HISTORYSERVER_STATUS" -eq 1 ]]; then
    print_success "All master services are running!"
    print_success "Cluster is ready for use! 🎉"
    exit 0
else
    print_warning "Some services may not be running correctly"
    print_info "Check the logs in \$HADOOP_HOME/logs/ for details"
    exit 1
fi
