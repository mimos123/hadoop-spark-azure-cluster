# 🛑 Shutdown & Restart Procedures

> ⚠️ **CRITICAL DOCUMENT** - Read this carefully to avoid data loss and cluster issues!

This is the **most important document** in this repository. Improper shutdown/restart procedures are the #1 cause of cluster failures and data issues.

## 📖 Table of Contents

- [Quick Reference](#-quick-reference)
- [Proper Shutdown Procedure](#-proper-shutdown-procedure)
- [Proper Restart Procedure](#-proper-restart-procedure)
- [What Happens If You Forget to Stop Services](#-what-happens-if-you-forget-to-stop-services)
- [Recovery Procedures](#-recovery-procedures)
- [Automated Scripts](#-automated-scripts)
- [Cost Optimization Tips](#-cost-optimization-tips)
- [Checklists](#-checklists)

---

## 🎯 Quick Reference

### Shutdown Commands (Master Node m-1)
```bash
# Stop all services
stop-dfs.sh
stop-yarn.sh
$SPARK_HOME/sbin/stop-history-server.sh

# Verify services stopped
jps  # Should only show 'Jps'
```

### Restart Commands (Master Node m-1)
```bash
# Start HDFS
start-dfs.sh

# Wait for HDFS to be ready
hdfs dfsadmin -safemode wait

# Start YARN
start-yarn.sh

# Start Spark History Server
$SPARK_HOME/sbin/start-history-server.sh

# Verify services
jps  # Should show: NameNode, SecondaryNameNode, ResourceManager, HistoryServer
```

---

## 🛑 Proper Shutdown Procedure

### Step-by-Step Guide

> ⚠️ **Always follow this exact order!**

#### 1️⃣ Pre-Shutdown Safety Checks (Master Node m-1)

First, verify no jobs are running:

```bash
# Check YARN applications
yarn application -list

# Check HDFS health
hdfs dfsadmin -report

# Save HDFS namespace (recommended)
hdfs dfsadmin -safemode enter
hdfs dfsadmin -saveNamespace
hdfs dfsadmin -safemode leave
```

**Expected Output:**
- No running applications
- All DataNodes should be alive
- Namespace saved successfully

#### 2️⃣ Stop Services in Correct Order (Master Node m-1)

```bash
# Stop Spark History Server first
$SPARK_HOME/sbin/stop-history-server.sh
echo "✓ Spark History Server stopped"

# Stop YARN (Resource Manager & Node Managers)
stop-yarn.sh
echo "✓ YARN stopped"

# Wait a few seconds for graceful shutdown
sleep 5

# Stop HDFS (NameNode, DataNodes, Secondary NameNode)
stop-dfs.sh
echo "✓ HDFS stopped"
```

#### 3️⃣ Verify Services Stopped (Both Nodes)

**On Master (m-1):**
```bash
jps
```
**Expected Output:** Only `Jps` should be listed

**On Worker (m-2):**
```bash
jps
```
**Expected Output:** Only `Jps` should be listed

> ⚠️ If you see other processes (NameNode, DataNode, ResourceManager, NodeManager), stop them manually:
> ```bash
> # Find the process ID and kill gracefully
> kill -15 <PID>
> ```

#### 4️⃣ Deallocate Azure VMs

**Using Azure Portal:**
1. Go to Azure Portal → Virtual Machines
2. Select both `m-1` and `m-2`
3. Click **Stop** (this deallocates the VMs to save costs)
4. Wait for status to show "Stopped (deallocated)"

**Using Azure CLI:**
```bash
# Stop both VMs
az vm deallocate --resource-group <your-resource-group> --name m-1
az vm deallocate --resource-group <your-resource-group> --name m-2
```

**Cost Impact:**
- 💰 **Deallocated:** Only pay for storage (~$1-5/month)
- 💸 **Stopped but not deallocated:** Still pay full compute costs!

#### 5️⃣ Verify Shutdown

**Check VM Status:**
```bash
az vm list --resource-group <your-resource-group> --query "[].{Name:name, PowerState:powerState}" -o table
```

**Expected Output:**
```
Name    PowerState
------  -----------------------
m-1     VM deallocated
m-2     VM deallocated
```

---

## 🚀 Proper Restart Procedure

### Step-by-Step Guide

#### 1️⃣ Start Azure VMs

**Using Azure Portal:**
1. Go to Azure Portal → Virtual Machines
2. Select both `m-1` and `m-2`
3. Click **Start**
4. Wait 2-3 minutes for VMs to boot completely

**Using Azure CLI:**
```bash
# Start both VMs
az vm start --resource-group <your-resource-group> --name m-1
az vm start --resource-group <your-resource-group> --name m-2

# Verify VMs are running
az vm list --resource-group <your-resource-group> --show-details --query "[].{Name:name, PowerState:powerState}" -o table
```

#### 2️⃣ Wait for SSH Access

```bash
# Test SSH connectivity
ssh hadoop@<m-1-public-ip>
ssh hadoop@<m-2-public-ip>
```

> 💡 **Tip:** It may take 1-2 minutes after the VM shows "Running" for SSH to become available.

#### 3️⃣ Start Services in Correct Order (Master Node m-1)

**Start HDFS First:**
```bash
# SSH into m-1
ssh hadoop@<m-1-public-ip>

# Start HDFS
start-dfs.sh
```

**Expected Output:**
```
Starting namenodes on [m-1]
Starting datanodes
Starting secondary namenodes [m-1]
```

**Wait for HDFS to Exit Safe Mode:**
```bash
# This command waits until HDFS is ready
hdfs dfsadmin -safemode wait

# Check HDFS status
hdfs dfsadmin -report
```

**Expected Output:**
- Shows both nodes (m-1 and m-2) as live DataNodes
- Available capacity matches total capacity

**Start YARN:**
```bash
start-yarn.sh
```

**Expected Output:**
```
Starting resourcemanager
Starting nodemanagers
```

**Start Spark History Server:**
```bash
$SPARK_HOME/sbin/start-history-server.sh
```

#### 4️⃣ Verify Cluster Health

**Check Running Processes (m-1):**
```bash
jps
```

**Expected Output:**
```
12345 NameNode
12346 SecondaryNameNode
12347 ResourceManager
12348 HistoryServer
12349 Jps
```

**Check Running Processes (m-2):**
```bash
ssh hadoop@m-2 "jps"
```

**Expected Output:**
```
23456 DataNode
23457 NodeManager
23458 Jps
```

**Check HDFS Health:**
```bash
hdfs dfsadmin -report
```

**Expected Output:**
- Live datanodes: 2 (both m-1 and m-2)
- No missing blocks
- Under-replicated blocks: 0

**Check YARN Nodes:**
```bash
yarn node -list
```

**Expected Output:**
```
Total Nodes:2
         Node-Id             Node-State Node-Http-Address
m-2:45454                       RUNNING m-2:8042
m-1:45454                       RUNNING m-1:8042
```

**Test HDFS Operations:**
```bash
# Create test directory
hdfs dfs -mkdir -p /test/restart

# Write test file
echo "Cluster restart successful!" | hdfs dfs -put - /test/restart/test.txt

# Read test file
hdfs dfs -cat /test/restart/test.txt

# Cleanup
hdfs dfs -rm -r /test/restart
```

#### 5️⃣ Access Web UIs

Verify all web interfaces are accessible:

| Service | URL | Expected Status |
|---------|-----|----------------|
| HDFS NameNode | http://`<m-1-ip>`:9870 | Shows 2 live nodes |
| YARN ResourceManager | http://`<m-1-ip>`:8088 | Shows 2 active nodes |
| Spark History Server | http://`<m-1-ip>`:18080 | Shows completed apps |
| YARN Node Manager (m-2) | http://`<m-2-ip>`:8042 | Shows node info |

---

## ⚠️ What Happens If You Forget to Stop Services

### The Problem

When you stop/deallocate Azure VMs **without** stopping Hadoop/Spark services first:

```
VM Running → Services Running → VM Stopped Abruptly → Corrupted State
```

### Technical Explanation

1. **HDFS NameNode** maintains metadata in memory and periodically writes to disk
2. **DataNodes** have edit logs and block metadata
3. **YARN** tracks job status and resource allocation
4. Abrupt shutdown can cause:
   - Uncommitted transactions lost
   - Incomplete metadata writes
   - Corrupted edit logs
   - Block reports mismatch

### What's Protected

✅ **Data blocks** - HDFS replication protects actual data  
✅ **Committed transactions** - Already written to edit logs  
✅ **Finalized blocks** - Properly closed files

### What's NOT Protected

❌ **In-flight operations** - Operations in progress when VM stopped  
❌ **Memory state** - NameNode's in-memory metadata  
❌ **Uncommitted edits** - Recent changes not yet written to disk  
❌ **Running jobs** - YARN applications in progress

### Potential Issues

1. **HDFS Enters Safe Mode**
   - NameNode won't allow writes
   - Cluster becomes read-only
   - Must wait for block reports from all DataNodes

2. **Missing DataNodes**
   - m-2 (worker) may not reconnect automatically
   - Shows as "Dead" in NameNode UI
   - Blocks may appear under-replicated

3. **YARN Node Managers Not Registering**
   - ResourceManager doesn't see worker nodes
   - Can't submit jobs
   - Cluster appears to have no capacity

4. **Corrupted Edit Logs** (rare but serious)
   - NameNode fails to start
   - May need to restore from checkpoint
   - Potential data loss if no recent checkpoint

5. **Port Conflicts**
   - Stale PID files prevent service startup
   - Services think they're already running

---

## 🔧 Recovery Procedures

### Issue 1: HDFS Stuck in Safe Mode

**Symptoms:**
```
Name node is in safe mode
```

**Recovery:**
```bash
# Check safe mode status
hdfs dfsadmin -safemode get

# Wait for block reports (recommended)
hdfs dfsadmin -safemode wait

# OR force leave safe mode (if waiting too long)
hdfs dfsadmin -safemode leave

# Verify cluster health
hdfs dfsadmin -report
```

### Issue 2: DataNode (m-2) Not Appearing

**Symptoms:**
```
Live datanodes: 1 (only m-1)
```

**Recovery Steps:**

1. **Check if DataNode is running on m-2:**
```bash
ssh hadoop@m-2 "jps"
```

2. **If not running, start it:**
```bash
ssh hadoop@m-2 "hdfs --daemon start datanode"
```

3. **Check DataNode logs:**
```bash
ssh hadoop@m-2 "tail -50 $HADOOP_HOME/logs/hadoop-hadoop-datanode-m-2.log"
```

4. **Common fixes:**

**Clock Skew Issue:**
```bash
# Sync time on both nodes
ssh hadoop@m-1 "sudo ntpdate pool.ntp.org"
ssh hadoop@m-2 "sudo ntpdate pool.ntp.org"
```

**Incorrect Hostname:**
```bash
# Verify /etc/hosts on both nodes
cat /etc/hosts | grep -E "m-1|m-2"

# Should show:
# <internal-ip-m-1> m-1
# <internal-ip-m-2> m-2
```

**Firewall/Network Issue:**
```bash
# Test connectivity from m-2 to m-1
ssh hadoop@m-2 "telnet m-1 9000"
```

### Issue 3: YARN NodeManager Not Registering

**Symptoms:**
```
Total Nodes: 1 (only m-1 shows)
```

**Recovery:**

1. **Check NodeManager on m-2:**
```bash
ssh hadoop@m-2 "jps"
# Should show NodeManager
```

2. **If not running:**
```bash
ssh hadoop@m-2 "yarn --daemon start nodemanager"
```

3. **Check logs:**
```bash
ssh hadoop@m-2 "tail -50 $HADOOP_HOME/logs/yarn-hadoop-nodemanager-m-2.log"
```

4. **Verify ResourceManager can reach m-2:**
```bash
yarn node -list -all
```

### Issue 4: Services Won't Start (Port Already in Use)

**Symptoms:**
```
Address already in use
```

**Recovery:**

1. **Find stale processes:**
```bash
# Check what's using the port
sudo netstat -tulpn | grep :9000    # NameNode
sudo netstat -tulpn | grep :8088    # ResourceManager
sudo netstat -tulpn | grep :18080   # Spark History
```

2. **Clean up stale PID files:**
```bash
rm -f $HADOOP_HOME/tmp/hadoop-hadoop-*.pid
```

3. **Kill stale processes (if found):**
```bash
# Kill gracefully
kill -15 <PID>

# If that doesn't work, force kill
kill -9 <PID>
```

4. **Restart services:**
```bash
start-dfs.sh
start-yarn.sh
```

### Issue 5: Corrupted Edit Logs

**Symptoms:**
```
NameNode failed to start
Error: FSImage and edit logs are corrupted
```

**Recovery (Advanced):**

1. **Try to recover from checkpoint:**
```bash
cd $HADOOP_HOME

# Stop all services
stop-dfs.sh

# Import checkpoint
hdfs namenode -importCheckpoint

# Start NameNode
hdfs --daemon start namenode

# Verify
hdfs dfsadmin -report
```

2. **If that fails, restore from backup:**
```bash
# Stop services
stop-dfs.sh

# Restore dfs.namenode.name.dir from backup
# (You should have backups of this directory!)

# Format ONLY if absolutely necessary (WILL LOSE ALL DATA)
# hdfs namenode -format  # DANGER!

# Start services
start-dfs.sh
```

### Full Recovery Procedure (Nuclear Option)

If all else fails, here's the complete cluster restart procedure:

```bash
# ON MASTER (m-1)

# 1. Stop everything
stop-yarn.sh
$SPARK_HOME/sbin/stop-history-server.sh
stop-dfs.sh

# 2. Clean temporary files
rm -rf $HADOOP_HOME/tmp/*
rm -rf $HADOOP_HOME/logs/*
rm -rf $SPARK_HOME/logs/*

# 3. Clean PID files
rm -f $HADOOP_HOME/tmp/*.pid

# 4. On worker, clean temp files
ssh hadoop@m-2 "rm -rf $HADOOP_HOME/tmp/*"
ssh hadoop@m-2 "rm -rf $HADOOP_HOME/logs/*"

# 5. Restart services in correct order
start-dfs.sh
hdfs dfsadmin -safemode wait
start-yarn.sh
$SPARK_HOME/sbin/start-history-server.sh

# 6. Verify
jps
hdfs dfsadmin -report
yarn node -list
```

> ⚠️ **Warning:** This procedure clears temporary files but preserves HDFS data. However, always backup important data first!

---

## 🤖 Automated Scripts

We provide scripts to automate the shutdown/restart process:

### Pre-Shutdown Check

```bash
# Run before shutting down
./scripts/pre_shutdown_check.sh
```

**What it does:**
- Checks for running YARN applications
- Verifies HDFS health
- Saves HDFS namespace
- Warns if unsafe to shutdown

### Graceful Shutdown

```bash
# Stops all services gracefully
./scripts/stop_cluster.sh
```

**What it does:**
- Stops services in correct order
- Verifies each service stopped
- Reports any issues
- Safe to deallocate VMs after this completes

### Cluster Startup

```bash
# Starts all services with health checks
./scripts/start_cluster.sh
```

**What it does:**
- Starts services in correct order
- Waits for HDFS to exit safe mode
- Verifies all nodes are active
- Reports cluster status

### Health Check

```bash
# Check cluster health anytime
./scripts/health_check.sh
```

**What it does:**
- Lists all running Java processes
- Checks HDFS DataNode status
- Checks YARN NodeManager status
- Verifies disk space
- Reports any issues

---

## 💰 Cost Optimization Tips

### Understanding Azure VM Costs

| VM State | Compute Cost | Storage Cost | Monthly Cost (B2s) |
|----------|-------------|--------------|-------------------|
| Running | ✓ Full | ✓ Full | ~$15-20 |
| Stopped | ✓ Full | ✓ Full | ~$15-20 |
| Deallocated | ❌ None | ✓ Full | ~$2-5 |

> 💡 **Key Insight:** Always **deallocate** VMs, don't just **stop** them!

### Best Practices

1. **Daily Development Pattern:**
   ```
   Morning:   Start VMs → Start services → Work
   Evening:   Stop services → Deallocate VMs
   Savings:   ~50-70% of compute costs
   ```

2. **Weekend Shutdown:**
   ```
   Friday:    Stop services → Deallocate VMs
   Monday:    Start VMs → Start services
   Savings:   ~30% of total monthly costs
   ```

3. **Extended Shutdown:**
   ```
   Before vacation: Stop services → Deallocate VMs → Export important data
   After vacation:  Start VMs → Start services → Verify data
   ```

### Automation for Cost Savings

**Create Azure Automation Scripts:**

```bash
# In Azure Portal: Automation → Runbooks
# Schedule VM stop every evening at 6 PM
# Schedule VM start every morning at 8 AM
```

**Use Azure DevTest Labs:**
- Auto-shutdown policies
- Cost management alerts
- Budget thresholds

---

## ✅ Checklists

### Before Shutdown Checklist

- [ ] No running YARN applications (`yarn application -list`)
- [ ] No active Spark jobs
- [ ] HDFS health is good (`hdfs dfsadmin -report`)
- [ ] All DataNodes are alive
- [ ] No under-replicated blocks
- [ ] HDFS namespace saved (`hdfs dfsadmin -saveNamespace`)
- [ ] Important data backed up (if any)
- [ ] Services stopped in correct order:
  - [ ] Spark History Server stopped
  - [ ] YARN stopped (`stop-yarn.sh`)
  - [ ] HDFS stopped (`stop-dfs.sh`)
- [ ] Verified services stopped (`jps` shows only `Jps`)
- [ ] VMs deallocated (not just stopped!)

### After Restart Checklist

- [ ] VMs started and running
- [ ] SSH access working
- [ ] Services started in correct order:
  - [ ] HDFS started (`start-dfs.sh`)
  - [ ] HDFS out of safe mode (`hdfs dfsadmin -safemode get`)
  - [ ] YARN started (`start-yarn.sh`)
  - [ ] Spark History Server started
- [ ] Master node processes (`jps` on m-1):
  - [ ] NameNode running
  - [ ] SecondaryNameNode running
  - [ ] ResourceManager running
  - [ ] HistoryServer running
- [ ] Worker node processes (`jps` on m-2):
  - [ ] DataNode running
  - [ ] NodeManager running
- [ ] HDFS health check:
  - [ ] 2 live DataNodes (`hdfs dfsadmin -report`)
  - [ ] No missing blocks
  - [ ] No under-replicated blocks
- [ ] YARN health check:
  - [ ] 2 active nodes (`yarn node -list`)
  - [ ] ResourceManager UI accessible
- [ ] Web UIs accessible:
  - [ ] HDFS NameNode UI (port 9870)
  - [ ] YARN ResourceManager UI (port 8088)
  - [ ] Spark History Server UI (port 18080)
- [ ] Test HDFS operations (read/write test)
- [ ] Test YARN job submission (optional)

---

## 📚 Additional Resources

- [Installation Guide](INSTALLATION.md) - Initial cluster setup
- [Troubleshooting Guide](TROUBLESHOOTING.md) - Common issues and solutions
- [Configuration Reference](CONFIGURATION.md) - Tuning and optimization

---

## 🆘 Still Having Issues?

If you follow these procedures and still experience problems:

1. Check the [Troubleshooting Guide](TROUBLESHOOTING.md)
2. Review service logs in `$HADOOP_HOME/logs/`
3. Open an issue with:
   - Output of `jps` on both nodes
   - Output of `hdfs dfsadmin -report`
   - Output of `yarn node -list`
   - Recent logs from both nodes

---

**Remember:** Taking an extra 2 minutes to properly shutdown saves hours of debugging later! 🎯
