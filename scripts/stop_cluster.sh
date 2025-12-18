#!/bin/bash
# Gracefully stop all Hadoop & Spark services
# Author: Mohamed Amine Belhassine
# Usage: ./stop_cluster.sh

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
if [[ "$(hostname)" != "m-1" ]]; then
    print_warning "This script should be run on the master node (m-1)"
    print_info "Current hostname: $(hostname)"
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

print_header "🛑 Stopping Hadoop & Spark Cluster"

# Check for running YARN applications
print_info "Checking for running YARN applications..."
RUNNING_APPS=$(yarn application -list 2>/dev/null | grep "RUNNING" | wc -l)

if [[ "$RUNNING_APPS" -gt 0 ]]; then
    print_warning "There are $RUNNING_APPS running YARN applications!"
    yarn application -list 2>/dev/null | grep "RUNNING" | head -10
    print_warning "Stopping the cluster will terminate these applications."
    read -p "Continue? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Shutdown cancelled."
        exit 0
    fi
fi

# Step 1: Stop Spark History Server
print_info "Step 1/3: Stopping Spark History Server..."

if [[ -z "$SPARK_HOME" ]]; then
    print_warning "SPARK_HOME not set. Skipping Spark History Server shutdown."
else
    if jps | grep -q "HistoryServer"; then
        $SPARK_HOME/sbin/stop-history-server.sh
        sleep 2
        
        if ! jps | grep -q "HistoryServer"; then
            print_success "Spark History Server stopped"
        else
            print_warning "Spark History Server may still be running"
        fi
    else
        print_info "Spark History Server is not running"
    fi
fi

# Step 2: Stop YARN
print_info "Step 2/3: Stopping YARN (ResourceManager, NodeManagers)..."

if jps | grep -q "ResourceManager\|NodeManager"; then
    stop-yarn.sh
    sleep 5
    
    if ! jps | grep -q "ResourceManager"; then
        print_success "YARN stopped"
    else
        print_warning "YARN ResourceManager may still be running"
    fi
else
    print_info "YARN is not running"
fi

# Step 3: Stop HDFS
print_info "Step 3/3: Stopping HDFS (NameNode, DataNodes, SecondaryNameNode)..."

if jps | grep -q "NameNode\|DataNode\|SecondaryNameNode"; then
    # Save HDFS namespace before stopping (optional but recommended)
    print_info "Saving HDFS namespace..."
    if hdfs dfsadmin -safemode enter 2>/dev/null && \
       hdfs dfsadmin -saveNamespace 2>/dev/null && \
       hdfs dfsadmin -safemode leave 2>/dev/null; then
        print_success "HDFS namespace saved"
    else
        print_warning "Could not save HDFS namespace (may not be critical)"
    fi
    
    stop-dfs.sh
    sleep 5
    
    if ! jps | grep -q "NameNode"; then
        print_success "HDFS stopped"
    else
        print_warning "HDFS NameNode may still be running"
    fi
else
    print_info "HDFS is not running"
fi

# Verification
print_header "📊 Shutdown Verification"

print_info "Running Java processes:"
JPS_OUTPUT=$(jps | grep -v "Jps")

if [[ -z "$JPS_OUTPUT" ]]; then
    print_success "All Hadoop/Spark services have been stopped"
else
    print_warning "Some processes may still be running:"
    echo "$JPS_OUTPUT"
    print_info "You may need to manually stop these processes"
fi

# Final message
print_header "✅ Cluster Shutdown Complete!"

print_success "All services have been stopped gracefully"
print_info "\nNext steps:"
echo -e "${GREEN}  1. Verify no services running: ${NC}jps"
echo -e "${GREEN}  2. Deallocate Azure VMs to save costs${NC}"
echo -e "${YELLOW}     Azure Portal: Stop both m-1 and m-2 VMs${NC}"
echo -e "${YELLOW}     Azure CLI:${NC}"
echo -e "     ${BLUE}az vm deallocate --resource-group <rg-name> --name m-1${NC}"
echo -e "     ${BLUE}az vm deallocate --resource-group <rg-name> --name m-2${NC}"

print_info "\nTo restart the cluster later:"
echo -e "${GREEN}  1. Start Azure VMs${NC}"
echo -e "${GREEN}  2. Run: ${NC}./scripts/start_cluster.sh"

exit 0
