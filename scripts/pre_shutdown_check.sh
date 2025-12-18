#!/bin/bash
# Pre-shutdown safety checks for Hadoop & Spark cluster
# Author: Mohamed Amine Belhassine
# Usage: ./pre_shutdown_check.sh

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

ISSUES_FOUND=0

print_header "🔍 Pre-Shutdown Safety Checks"

# Check 1: Running YARN Applications
print_info "Check 1/5: Looking for running YARN applications..."

if ! jps | grep -q "ResourceManager"; then
    print_warning "ResourceManager is not running - skipping YARN application check"
else
    RUNNING_APPS=$(yarn application -list 2>/dev/null | grep "RUNNING" | wc -l)
    
    if [[ "$RUNNING_APPS" -eq 0 ]]; then
        print_success "No running YARN applications"
    else
        print_error "Found $RUNNING_APPS running YARN application(s)!"
        print_info "Running applications:"
        yarn application -list 2>/dev/null | grep "RUNNING" | head -10
        print_warning "Shutting down now will terminate these applications"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
fi

# Check 2: HDFS Health
print_info "\nCheck 2/5: Checking HDFS health..."

if ! jps | grep -q "NameNode"; then
    print_warning "NameNode is not running - skipping HDFS health check"
else
    # Check safe mode
    SAFE_MODE=$(hdfs dfsadmin -safemode get 2>/dev/null)
    if echo "$SAFE_MODE" | grep -q "OFF"; then
        print_success "HDFS safe mode is OFF"
    else
        print_warning "HDFS is in safe mode - may indicate issues"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
    
    # Check DataNodes
    LIVE_NODES=$(hdfs dfsadmin -report 2>/dev/null | grep "Live datanodes" | awk '{print $3}' | sed 's/://g')
    if [[ "$LIVE_NODES" -eq 2 ]]; then
        print_success "All 2 DataNodes are alive"
    else
        print_warning "Only $LIVE_NODES DataNode(s) alive (expected 2)"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
    
    # Check for missing blocks
    MISSING_BLOCKS=$(hdfs dfsadmin -report 2>/dev/null | grep "Missing blocks" | awk '{print $3}')
    if [[ -n "$MISSING_BLOCKS" ]] && [[ "$MISSING_BLOCKS" -eq 0 ]]; then
        print_success "No missing blocks"
    else
        print_error "Missing blocks detected: $MISSING_BLOCKS"
        print_warning "You may lose data if you shutdown now!"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
    
    # Check under-replicated blocks
    UNDER_REP=$(hdfs dfsadmin -report 2>/dev/null | grep "Under replicated blocks" | awk '{print $4}')
    if [[ -n "$UNDER_REP" ]] && [[ "$UNDER_REP" -eq 0 ]]; then
        print_success "No under-replicated blocks"
    else
        print_warning "Under-replicated blocks: $UNDER_REP"
        print_info "This is usually okay, but consider waiting for replication to complete"
    fi
fi

# Check 3: Save HDFS Namespace
print_info "\nCheck 3/5: Saving HDFS namespace..."

if ! jps | grep -q "NameNode"; then
    print_warning "NameNode is not running - skipping namespace save"
else
    print_info "Entering safe mode..."
    if hdfs dfsadmin -safemode enter 2>/dev/null; then
        print_success "Entered safe mode"
        
        print_info "Saving namespace..."
        if hdfs dfsadmin -saveNamespace 2>/dev/null; then
            print_success "Namespace saved successfully"
        else
            print_error "Failed to save namespace"
            ISSUES_FOUND=$((ISSUES_FOUND + 1))
        fi
        
        print_info "Leaving safe mode..."
        if hdfs dfsadmin -safemode leave 2>/dev/null; then
            print_success "Left safe mode"
        else
            print_warning "Failed to leave safe mode - may need manual intervention"
        fi
    else
        print_error "Failed to enter safe mode"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
fi

# Check 4: Disk Space
print_info "\nCheck 4/5: Checking disk space..."

DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//g')
if [[ "$DISK_USAGE" -lt 90 ]]; then
    print_success "Disk usage is acceptable ($DISK_USAGE%)"
else
    print_warning "Disk usage is high ($DISK_USAGE%)"
    print_info "Consider cleaning up logs before shutdown"
fi

# Check 5: Worker Node Connectivity
print_info "\nCheck 5/5: Checking worker node connectivity..."

if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no m-2 "exit" 2>/dev/null; then
    print_success "m-2 is reachable via SSH"
else
    print_error "Cannot connect to m-2 via SSH"
    print_warning "Worker node may already be down or unreachable"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# Final Summary
print_header "📊 Safety Check Summary"

if [[ "$ISSUES_FOUND" -eq 0 ]]; then
    print_success "All safety checks passed! ✅"
    print_success "Safe to proceed with shutdown."
    print_info "\nRecommended shutdown procedure:"
    echo -e "${GREEN}  1. Run: ${NC}./scripts/stop_cluster.sh"
    echo -e "${GREEN}  2. Verify services stopped: ${NC}jps"
    echo -e "${GREEN}  3. Deallocate VMs in Azure Portal or CLI${NC}"
    exit 0
else
    print_warning "Found $ISSUES_FOUND issue(s) during safety checks! ⚠️"
    print_warning "\nIt is NOT recommended to shutdown now."
    print_info "\nRecommended actions:"
    echo -e "${YELLOW}  1. Wait for running applications to complete${NC}"
    echo -e "${YELLOW}  2. Fix HDFS issues (check docs/TROUBLESHOOTING.md)${NC}"
    echo -e "${YELLOW}  3. Re-run this script${NC}"
    echo -e "${YELLOW}  4. Only then proceed with shutdown${NC}"
    
    echo ""
    read -p "Do you still want to proceed with shutdown? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_warning "Proceeding with shutdown despite issues..."
        print_info "\nRun: ${BLUE}./scripts/stop_cluster.sh${NC}"
        exit 0
    else
        print_info "Shutdown cancelled. Good choice!"
        exit 1
    fi
fi
