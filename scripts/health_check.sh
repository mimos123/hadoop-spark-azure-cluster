#!/bin/bash
# Check Hadoop & Spark cluster health
# Author: Mohamed Amine Belhassine
# Usage: ./health_check.sh

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

print_header "🏥 Cluster Health Check Report"
echo "Generated: $(date)"
echo "Hostname: $(hostname)"
echo ""

# Check 1: Java Processes
print_header "1. Java Processes"

print_info "Master Node (m-1):"
M1_JPS=$(jps | grep -v "Jps")
if [[ -z "$M1_JPS" ]]; then
    print_error "No Hadoop/Spark processes running on m-1"
else
    echo "$M1_JPS" | while read -r line; do
        echo "  ✓ $line"
    done
    
    # Check essential services on master
    if echo "$M1_JPS" | grep -q "NameNode"; then
        print_success "NameNode is running"
    else
        print_error "NameNode is NOT running"
    fi
    
    if echo "$M1_JPS" | grep -q "ResourceManager"; then
        print_success "ResourceManager is running"
    else
        print_error "ResourceManager is NOT running"
    fi
    
    if echo "$M1_JPS" | grep -q "SecondaryNameNode"; then
        print_success "SecondaryNameNode is running"
    else
        print_warning "SecondaryNameNode is NOT running"
    fi
    
    if echo "$M1_JPS" | grep -q "HistoryServer"; then
        print_success "Spark History Server is running"
    else
        print_warning "Spark History Server is NOT running"
    fi
fi

# Check worker node if accessible
print_info "\nWorker Node (m-2):"
if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no m-2 "exit" 2>/dev/null; then
    M2_JPS=$(ssh m-2 "jps" | grep -v "Jps")
    if [[ -z "$M2_JPS" ]]; then
        print_warning "No Hadoop/Spark processes running on m-2"
    else
        echo "$M2_JPS" | while read -r line; do
            echo "  ✓ $line"
        done
        
        if echo "$M2_JPS" | grep -q "DataNode"; then
            print_success "DataNode is running on m-2"
        else
            print_error "DataNode is NOT running on m-2"
        fi
        
        if echo "$M2_JPS" | grep -q "NodeManager"; then
            print_success "NodeManager is running on m-2"
        else
            print_error "NodeManager is NOT running on m-2"
        fi
    fi
else
    print_error "Cannot connect to m-2 via SSH"
fi

# Check 2: HDFS Health
print_header "2. HDFS Health"

if jps | grep -q "NameNode"; then
    # Check safe mode
    SAFE_MODE=$(hdfs dfsadmin -safemode get 2>/dev/null)
    if echo "$SAFE_MODE" | grep -q "OFF"; then
        print_success "Safe mode is OFF"
    else
        print_error "Safe mode is ON - cluster is read-only!"
    fi
    
    # Check DataNodes
    LIVE_NODES=$(hdfs dfsadmin -report 2>/dev/null | grep "Live datanodes" | awk '{print $3}' | sed 's/://g')
    if [[ "$LIVE_NODES" -eq 2 ]]; then
        print_success "All 2 DataNodes are alive"
    elif [[ "$LIVE_NODES" -eq 1 ]]; then
        print_warning "Only 1 DataNode is alive (expected 2)"
    else
        print_error "No DataNodes are alive"
    fi
    
    # Check for missing blocks
    MISSING_BLOCKS=$(hdfs dfsadmin -report 2>/dev/null | grep "Missing blocks" | awk '{print $3}')
    if [[ "$MISSING_BLOCKS" -eq 0 ]] 2>/dev/null; then
        print_success "No missing blocks"
    else
        print_error "Missing blocks detected: $MISSING_BLOCKS"
    fi
    
    # Check under-replicated blocks
    UNDER_REP=$(hdfs dfsadmin -report 2>/dev/null | grep "Under replicated blocks" | awk '{print $4}')
    if [[ "$UNDER_REP" -eq 0 ]] 2>/dev/null; then
        print_success "No under-replicated blocks"
    else
        print_warning "Under-replicated blocks: $UNDER_REP"
    fi
    
    # Check capacity
    print_info "\nStorage Capacity:"
    hdfs dfsadmin -report 2>/dev/null | grep -E "Configured Capacity|DFS Used|DFS Remaining" | while read -r line; do
        echo "  $line"
    done
else
    print_error "NameNode is not running - cannot check HDFS health"
fi

# Check 3: YARN Health
print_header "3. YARN Health"

if jps | grep -q "ResourceManager"; then
    # Check active nodes
    ACTIVE_NODES=$(yarn node -list 2>/dev/null | grep "RUNNING" | wc -l)
    if [[ "$ACTIVE_NODES" -eq 2 ]]; then
        print_success "All 2 NodeManagers are active"
    elif [[ "$ACTIVE_NODES" -eq 1 ]]; then
        print_warning "Only 1 NodeManager is active (expected 2)"
    else
        print_error "No NodeManagers are active"
    fi
    
    # List nodes
    print_info "\nYARN Nodes:"
    yarn node -list 2>/dev/null | head -5
    
    # Check running applications
    RUNNING_APPS=$(yarn application -list 2>/dev/null | grep "RUNNING" | wc -l)
    if [[ "$RUNNING_APPS" -gt 0 ]]; then
        print_info "\nRunning YARN applications: $RUNNING_APPS"
    else
        print_info "\nNo running YARN applications"
    fi
else
    print_error "ResourceManager is not running - cannot check YARN health"
fi

# Check 4: Disk Space
print_header "4. Disk Space"

print_info "Master Node (m-1):"
df -h / | tail -1 | awk '{print "  / (root):  " $3 " used, " $4 " available (" $5 " used)"}'

HADOOP_TMP_USAGE=$(du -sh $HADOOP_HOME/tmp 2>/dev/null | awk '{print $1}')
print_info "  Hadoop tmp: $HADOOP_TMP_USAGE"

HADOOP_LOGS_USAGE=$(du -sh $HADOOP_HOME/logs 2>/dev/null | awk '{print $1}')
print_info "  Hadoop logs: $HADOOP_LOGS_USAGE"

if ssh -o ConnectTimeout=5 m-2 "exit" 2>/dev/null; then
    print_info "\nWorker Node (m-2):"
    ssh m-2 "df -h / | tail -1" | awk '{print "  / (root):  " $3 " used, " $4 " available (" $5 " used)"}'
fi

# Check 5: Memory Usage
print_header "5. Memory Usage"

print_info "Master Node (m-1):"
free -h | grep "Mem:" | awk '{print "  Total: " $2 " | Used: " $3 " | Available: " $7}'

if ssh -o ConnectTimeout=5 m-2 "exit" 2>/dev/null; then
    print_info "\nWorker Node (m-2):"
    ssh m-2 "free -h | grep 'Mem:'" | awk '{print "  Total: " $2 " | Used: " $3 " | Available: " $7}'
fi

# Check 6: Network Connectivity
print_header "6. Network Connectivity"

if ping -c 1 m-1 >/dev/null 2>&1; then
    print_success "m-1 is reachable"
else
    print_error "m-1 is NOT reachable"
fi

if ping -c 1 m-2 >/dev/null 2>&1; then
    print_success "m-2 is reachable"
else
    print_error "m-2 is NOT reachable"
fi

# Final Summary
print_header "📊 Summary"

ALL_OK=true

# Count issues
if ! jps | grep -q "NameNode"; then
    print_error "NameNode is not running"
    ALL_OK=false
fi

if ! jps | grep -q "ResourceManager"; then
    print_error "ResourceManager is not running"
    ALL_OK=false
fi

LIVE_NODES=$(hdfs dfsadmin -report 2>/dev/null | grep "Live datanodes" | awk '{print $3}' | sed 's/://g')
if [[ "$LIVE_NODES" -lt 2 ]] 2>/dev/null; then
    print_warning "Not all DataNodes are active ($LIVE_NODES/2)"
    ALL_OK=false
fi

ACTIVE_NODES=$(yarn node -list 2>/dev/null | grep "RUNNING" | wc -l)
if [[ "$ACTIVE_NODES" -lt 2 ]] 2>/dev/null; then
    print_warning "Not all NodeManagers are active ($ACTIVE_NODES/2)"
    ALL_OK=false
fi

if $ALL_OK; then
    print_success "Cluster is healthy! All systems operational. 🎉"
    exit 0
else
    print_warning "Cluster has some issues. Check the report above for details."
    print_info "See docs/TROUBLESHOOTING.md for solutions."
    exit 1
fi
