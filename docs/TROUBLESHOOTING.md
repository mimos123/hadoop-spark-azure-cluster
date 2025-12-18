# 🔧 Troubleshooting Guide

Comprehensive guide to diagnosing and fixing common issues with your Hadoop & Spark cluster.

## 📖 Table of Contents

- [Quick Diagnostics](#-quick-diagnostics)
- [Services Not Starting](#-services-not-starting)
- [DataNode Issues](#-datanode-issues)
- [YARN NodeManager Issues](#-yarn-nodemanager-issues)
- [HDFS Safe Mode Problems](#-hdfs-safe-mode-problems)
- [Memory and Resource Issues](#-memory-and-resource-issues)
- [Spark Job Failures](#-spark-job-failures)
- [Network and Connectivity](#-network-and-connectivity)
- [Web UI Access Issues](#-web-ui-access-issues)
- [Permission Errors](#-permission-errors)
- [Log Locations](#-log-locations)
- [Advanced Recovery](#-advanced-recovery)

---

## 🔍 Quick Diagnostics

Before diving into specific issues, run these commands to get cluster health status:

```bash
# Check running Java processes
jps

# Check HDFS health
hdfs dfsadmin -report

# Check YARN nodes
yarn node -list

# Check disk space
df -h

# Check memory usage
free -h

# Check recent logs for errors
tail -50 $HADOOP_HOME/logs/hadoop-hadoop-namenode-m-1.log | grep ERROR
tail -50 $HADOOP_HOME/logs/hadoop-hadoop-datanode-m-1.log | grep ERROR
```

---

## 🚫 Services Not Starting

### Issue: Services Not Starting on m-2 (Worker Node)

**Symptoms:**
- `jps` on m-2 doesn't show DataNode or NodeManager
- HDFS reports only 1 live datanode
- YARN shows only 1 active node

**Common Causes & Solutions:**

#### 1. SSH Connectivity Issue

**Check:**
```bash
# From m-1, try SSH to m-2
ssh m-2 'hostname'
```

**Fix:**
```bash
# Regenerate SSH keys if needed
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
ssh-copy-id hadoop@m-2

# Test again
ssh m-2 'echo Connection successful'
```

#### 2. Hostname Resolution Failure

**Check:**
```bash
# On both nodes
cat /etc/hosts | grep -E "m-1|m-2"
ping -c 2 m-1
ping -c 2 m-2
```

**Fix:**
```bash
# On both m-1 and m-2, ensure /etc/hosts contains:
sudo nano /etc/hosts

# Add (use your actual private IPs):
10.0.1.4 m-1
10.0.1.5 m-2
```

#### 3. Firewall Blocking Ports

**Check:**
```bash
# From m-2, test connectivity to m-1
telnet m-1 9000    # HDFS
telnet m-1 8032    # YARN ResourceManager

# If telnet not installed:
nc -zv m-1 9000
nc -zv m-1 8032
```

**Fix:**
```bash
# Disable firewall temporarily to test (not recommended for production)
sudo ufw disable

# OR open specific ports
sudo ufw allow from 10.0.1.0/24 to any port 9000
sudo ufw allow from 10.0.1.0/24 to any port 8032
sudo ufw allow from 10.0.1.0/24 to any port 8030
sudo ufw allow from 10.0.1.0/24 to any port 8031
```

#### 4. Configuration Not Synced

**Check:**
```bash
# Compare configuration files
diff $HADOOP_HOME/etc/hadoop/core-site.xml \
     <(ssh m-2 "cat $HADOOP_HOME/etc/hadoop/core-site.xml")
```

**Fix:**
```bash
# Re-copy configuration from m-1 to m-2
scp -r $HADOOP_HOME/etc/hadoop/* hadoop@m-2:$HADOOP_HOME/etc/hadoop/
```

#### 5. Services Need Manual Start

**Check:**
```bash
# See if start scripts reached m-2
ssh m-2 "ls -la $HADOOP_HOME/logs/"
```

**Fix:**
```bash
# Manually start services on m-2
ssh m-2 "hdfs --daemon start datanode"
ssh m-2 "yarn --daemon start nodemanager"

# Verify
ssh m-2 "jps"
```

### Issue: Port Already in Use

**Symptoms:**
```
Address already in use
java.net.BindException: Port 9000 is already in use
```

**Solution:**

```bash
# Find process using the port
sudo netstat -tulpn | grep :9000

# OR
sudo lsof -i :9000

# Kill the process gracefully
kill -15 <PID>

# If that doesn't work, force kill
kill -9 <PID>

# Restart services
start-dfs.sh
start-yarn.sh
```

### Issue: Stale PID Files

**Symptoms:**
```
namenode is already running as process 12345
```

**Solution:**

```bash
# Remove stale PID files
rm -f $HADOOP_HOME/tmp/*.pid

# Try starting again
start-dfs.sh
start-yarn.sh
```

---

## 📊 DataNode Issues

### Issue: DataNode Not Connecting to NameNode

**Symptoms:**
- HDFS reports 0 or 1 live datanodes (should be 2)
- DataNode logs show connection errors

**Diagnostic Commands:**

```bash
# Check HDFS report
hdfs dfsadmin -report

# Check DataNode logs on m-2
ssh m-2 "tail -100 $HADOOP_HOME/logs/hadoop-hadoop-datanode-m-2.log"

# Look for these error patterns:
# - "Connection refused"
# - "Incompatible clusterIDs"
# - "Incorrect versions"
```

#### Fix 1: ClusterID Mismatch

**Cause:** NameNode was reformatted after DataNodes were initialized.

**Solution:**

```bash
# Stop HDFS on all nodes
stop-dfs.sh

# On m-2, clear DataNode data
ssh m-2 "rm -rf $HADOOP_HOME/hdfs/datanode/*"

# On m-1, also clear if needed
rm -rf $HADOOP_HOME/hdfs/datanode/*

# Restart HDFS
start-dfs.sh

# Wait and check
sleep 10
hdfs dfsadmin -report
```

#### Fix 2: Clock Skew

**Cause:** System clocks on m-1 and m-2 are out of sync.

**Solution:**

```bash
# Install and sync time on both nodes
sudo apt install -y ntpdate

# Sync time
sudo ntpdate pool.ntp.org

# On m-2
ssh m-2 "sudo ntpdate pool.ntp.org"

# Verify time matches
date
ssh m-2 "date"

# Restart DataNode
ssh m-2 "hdfs --daemon stop datanode"
ssh m-2 "hdfs --daemon start datanode"
```

#### Fix 3: Network Unreachable

**Solution:**

```bash
# Test network connectivity
ping -c 4 m-2

# Test HDFS port
nc -zv m-1 9000

# Check Azure Network Security Group rules
# Ensure internal traffic between VMs is allowed
```

### Issue: DataNode Disk Space Full

**Symptoms:**
```
Not able to place enough replicas
No space left on device
```

**Solution:**

```bash
# Check disk usage
df -h
ssh m-2 "df -h"

# Find large files
du -sh $HADOOP_HOME/* | sort -hr | head -10

# Clean up HDFS trash
hdfs dfs -expunge

# Clean up old logs
rm -f $HADOOP_HOME/logs/*.log.1
rm -f $HADOOP_HOME/logs/*.out.1

# If needed, add more disk space or increase Azure VM disk size
```

---

## 🎯 YARN NodeManager Issues

### Issue: NodeManager Not Registering with ResourceManager

**Symptoms:**
- `yarn node -list` shows only 1 node (should be 2)
- ResourceManager UI shows 1 active node

**Diagnostic Commands:**

```bash
# Check YARN nodes
yarn node -list

# Check NodeManager logs on m-2
ssh m-2 "tail -100 $HADOOP_HOME/logs/yarn-hadoop-nodemanager-m-2.log"
```

#### Fix 1: NodeManager Not Running

**Solution:**

```bash
# Check if NodeManager is running on m-2
ssh m-2 "jps | grep NodeManager"

# If not running, start it
ssh m-2 "yarn --daemon start nodemanager"

# Wait and verify
sleep 5
yarn node -list
```

#### Fix 2: ResourceManager Address Misconfigured

**Check Configuration:**

```bash
# Verify yarn-site.xml on m-2
ssh m-2 "grep -A 1 'yarn.resourcemanager.hostname' $HADOOP_HOME/etc/hadoop/yarn-site.xml"

# Should show: <value>m-1</value>
```

**Fix:**

```bash
# Re-copy configuration from m-1
scp $HADOOP_HOME/etc/hadoop/yarn-site.xml hadoop@m-2:$HADOOP_HOME/etc/hadoop/

# Restart NodeManager on m-2
ssh m-2 "yarn --daemon stop nodemanager"
ssh m-2 "yarn --daemon start nodemanager"
```

#### Fix 3: Insufficient Resources

**Check:**

```bash
# Check NodeManager resources on m-2
ssh m-2 "grep -E 'memory-mb|cpu-vcores' $HADOOP_HOME/etc/hadoop/yarn-site.xml"
```

**Fix:**

```bash
# Ensure values are reasonable for your VM size
# For 4GB VM (B2s):
# yarn.nodemanager.resource.memory-mb: 3072
# yarn.nodemanager.resource.cpu-vcores: 2

# Edit if needed
nano $HADOOP_HOME/etc/hadoop/yarn-site.xml

# Copy to m-2 and restart
scp $HADOOP_HOME/etc/hadoop/yarn-site.xml hadoop@m-2:$HADOOP_HOME/etc/hadoop/
ssh m-2 "yarn --daemon stop nodemanager"
ssh m-2 "yarn --daemon start nodemanager"
```

---

## 🔒 HDFS Safe Mode Problems

### Issue: HDFS Stuck in Safe Mode

**Symptoms:**
```
Name node is in safe mode
Cannot create directory. Name node is in safe mode
```

**Explanation:**

HDFS enters safe mode on startup and waits for:
- DataNodes to register
- Block reports from all DataNodes
- Minimum replication requirements met

#### Quick Fix: Wait

**Recommended approach:**

```bash
# Wait for safe mode to exit automatically
hdfs dfsadmin -safemode wait

# This command blocks until safe mode is off
# Usually takes 30-60 seconds
```

#### Force Leave Safe Mode (Use with Caution)

**When to use:** If safe mode persists for > 5 minutes

```bash
# Check safe mode status
hdfs dfsadmin -safemode get

# Force leave safe mode
hdfs dfsadmin -safemode leave

# Verify
hdfs dfsadmin -safemode get
# Should show: Safe mode is OFF
```

#### Persistent Safe Mode Issues

**If safe mode keeps returning:**

```bash
# Check for missing blocks
hdfs fsck / -files -blocks -locations

# Look for:
# - Missing blocks
# - Under-replicated blocks
# - Corrupted blocks

# If under-replicated, wait for DataNodes to report
hdfs dfsadmin -report

# If blocks are missing/corrupted, you may need recovery
hdfs dfsadmin -safemode enter
hdfs fsck / -delete  # Deletes corrupted files
hdfs dfsadmin -safemode leave
```

---

## 💾 Memory and Resource Issues

### Issue: Out of Memory Errors

**Symptoms:**
```
java.lang.OutOfMemoryError: Java heap space
Container killed by YARN for exceeding memory limits
```

#### For NameNode/ResourceManager OOM

**Fix:**

```bash
# Edit hadoop-env.sh
nano $HADOOP_HOME/etc/hadoop/hadoop-env.sh

# Add/modify:
export HADOOP_NAMENODE_OPTS="-Xmx1024m"
export YARN_RESOURCEMANAGER_OPTS="-Xmx1024m"

# Restart services
stop-dfs.sh
stop-yarn.sh
start-dfs.sh
start-yarn.sh
```

#### For MapReduce Jobs

**Fix:**

```bash
# Edit mapred-site.xml
nano $HADOOP_HOME/etc/hadoop/mapred-site.xml

# Reduce memory allocation:
<property>
    <name>yarn.app.mapreduce.am.resource.mb</name>
    <value>512</value>  <!-- Reduce from 1024 -->
</property>
<property>
    <name>mapreduce.map.memory.mb</name>
    <value>512</value>  <!-- Reduce from 1024 -->
</property>
<property>
    <name>mapreduce.reduce.memory.mb</name>
    <value>512</value>  <!-- Reduce from 1024 -->
</property>

# Copy to m-2 and restart
scp $HADOOP_HOME/etc/hadoop/mapred-site.xml hadoop@m-2:$HADOOP_HOME/etc/hadoop/
stop-yarn.sh
start-yarn.sh
```

### Issue: Container Killed by YARN

**Symptoms:**
```
Container [pid=12345,containerID=container_xxx] is running beyond physical memory limits
Current usage: 1.5 GB of 1 GB physical memory used
```

**Fix:**

```bash
# Option 1: Increase memory limits
nano $HADOOP_HOME/etc/hadoop/yarn-site.xml

# Increase:
<property>
    <name>yarn.nodemanager.resource.memory-mb</name>
    <value>4096</value>  <!-- Increase if VM has enough RAM -->
</property>

# Option 2: Disable strict memory enforcement (not recommended for production)
<property>
    <name>yarn.nodemanager.pmem-check-enabled</name>
    <value>false</value>
</property>
<property>
    <name>yarn.nodemanager.vmem-check-enabled</name>
    <value>false</value>
</property>

# Restart YARN
stop-yarn.sh
start-yarn.sh
```

---

## ⚡ Spark Job Failures

### Issue: Spark Application Fails to Start

**Symptoms:**
```
Application application_xxx failed 2 times
Final app status: FAILED
```

**Diagnostic Commands:**

```bash
# Check YARN application logs
yarn logs -applicationId <application_id>

# Check Spark event logs
hdfs dfs -ls /spark-logs

# Check if event log directory exists and is writable
hdfs dfs -test -d /spark-logs && echo "Directory exists" || echo "Directory missing"
hdfs dfs -test -w /spark-logs && echo "Writable" || echo "Not writable"
```

#### Fix 1: Missing Spark Event Log Directory

**Solution:**

```bash
# Create directory
hdfs dfs -mkdir -p /spark-logs
hdfs dfs -chmod 777 /spark-logs

# Verify
hdfs dfs -ls -d /spark-logs
```

#### Fix 2: Insufficient YARN Resources

**Solution:**

```bash
# Check available resources
yarn node -list

# Reduce Spark resource requirements
spark-submit \
  --master yarn \
  --deploy-mode cluster \
  --driver-memory 512m \      # Reduce from 1g
  --executor-memory 512m \    # Reduce from 1g
  --executor-cores 1 \        # Reduce from 2
  --num-executors 1 \         # Reduce from 2
  your-application.jar
```

#### Fix 3: SPARK_HOME Not Set

**Solution:**

```bash
# Verify SPARK_HOME on both nodes
echo $SPARK_HOME
ssh m-2 "echo \$SPARK_HOME"

# If not set, add to ~/.bashrc on both nodes
echo 'export SPARK_HOME=/home/hadoop/spark' >> ~/.bashrc
echo 'export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin' >> ~/.bashrc
source ~/.bashrc

# On m-2
ssh m-2 "echo 'export SPARK_HOME=/home/hadoop/spark' >> ~/.bashrc"
ssh m-2 "echo 'export PATH=\$PATH:\$SPARK_HOME/bin:\$SPARK_HOME/sbin' >> ~/.bashrc"
```

### Issue: Spark History Server Not Showing Applications

**Symptoms:**
- History server starts but shows no applications
- Completed applications don't appear

**Fix:**

```bash
# Check if event logs are being written
hdfs dfs -ls /spark-logs

# If empty, check spark-defaults.conf
cat $SPARK_HOME/conf/spark-defaults.conf | grep eventLog

# Should have:
# spark.eventLog.enabled           true
# spark.eventLog.dir               hdfs://m-1:9000/spark-logs

# If missing, add them
nano $SPARK_HOME/conf/spark-defaults.conf

# Restart History Server
$SPARK_HOME/sbin/stop-history-server.sh
$SPARK_HOME/sbin/start-history-server.sh
```

---

## 🌐 Network and Connectivity

### Issue: Cannot SSH Between Nodes

**Symptoms:**
```
Permission denied (publickey)
Connection refused
```

**Fix:**

```bash
# Regenerate SSH keys
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

# Copy to both nodes
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
ssh-copy-id hadoop@m-2

# Set correct permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/.ssh/id_rsa

# Test
ssh m-1 'hostname'
ssh m-2 'hostname'
```

### Issue: Nodes Cannot Resolve Hostnames

**Symptoms:**
```
UnknownHostException: m-1
Name or service not known
```

**Fix:**

```bash
# On both nodes, check /etc/hosts
cat /etc/hosts

# Should contain (use your actual private IPs):
10.0.1.4 m-1
10.0.1.5 m-2

# If missing, add them
sudo nano /etc/hosts

# Test resolution
ping -c 2 m-1
ping -c 2 m-2
nslookup m-1
nslookup m-2
```

---

## 🌍 Web UI Access Issues

### Issue: Cannot Access Web UIs from Browser

**Symptoms:**
- Timeout when accessing http://`<public-ip>`:9870
- Connection refused errors

**Checklist:**

1. **Verify services are running:**
```bash
jps
# Should show NameNode, ResourceManager, HistoryServer
```

2. **Check service is listening on correct port:**
```bash
sudo netstat -tulpn | grep 9870   # NameNode
sudo netstat -tulpn | grep 8088   # ResourceManager
sudo netstat -tulpn | grep 18080  # Spark History
```

3. **Verify Azure Network Security Group rules:**
```bash
# Using Azure CLI
az network nsg rule list \
  --resource-group hadoop-cluster-rg \
  --nsg-name <your-nsg-name> \
  --output table

# Should show rules for ports: 9870, 8088, 18080, 8042
```

4. **Add missing NSG rules:**
```bash
# Get NSG name
NSG_NAME=$(az network nsg list --resource-group hadoop-cluster-rg --query "[0].name" -o tsv)

# Add rule for HDFS UI
az network nsg rule create \
  --resource-group hadoop-cluster-rg \
  --nsg-name $NSG_NAME \
  --name HDFS-UI \
  --priority 1001 \
  --source-address-prefixes $(curl -s ifconfig.me)/32 \
  --destination-port-ranges 9870 \
  --access Allow \
  --protocol Tcp
```

5. **Check local firewall:**
```bash
# Temporarily disable to test
sudo ufw status
sudo ufw disable

# If that fixes it, open specific ports
sudo ufw allow 9870/tcp
sudo ufw allow 8088/tcp
sudo ufw allow 18080/tcp
sudo ufw enable
```

### Issue: Web UI Shows Wrong IP Address

**Symptoms:**
- Web UI redirects to internal IP (10.0.x.x)
- Links in UI don't work from external browser

**Fix:**

This is expected behavior for internal links. Use public IPs when accessing from external browser, but internal cluster communication uses private IPs.

For better experience, you can set up SSH tunneling:

```bash
# From your local machine, create SSH tunnel
ssh -L 9870:localhost:9870 \
    -L 8088:localhost:8088 \
    -L 18080:localhost:18080 \
    -i hadoop-ssh-key.pem \
    hadoop@<m-1-public-ip>

# Now access via localhost:
# http://localhost:9870  (HDFS)
# http://localhost:8088  (YARN)
# http://localhost:18080 (Spark)
```

---

## 🔐 Permission Errors

### Issue: Permission Denied on HDFS

**Symptoms:**
```
Permission denied: user=hadoop, access=WRITE, inode="/":hadoop:supergroup:drwxr-xr-x
```

**Fix:**

```bash
# Check HDFS permissions
hdfs dfs -ls /

# Change ownership if needed
hdfs dfs -chown -R hadoop:hadoop /user/hadoop

# Or create user directory
hdfs dfs -mkdir -p /user/hadoop
hdfs dfs -chown hadoop:hadoop /user/hadoop
```

### Issue: Cannot Write to Local Directories

**Symptoms:**
```
Permission denied: /home/hadoop/hadoop/logs
```

**Fix:**

```bash
# Fix ownership
sudo chown -R hadoop:hadoop /home/hadoop/hadoop
sudo chown -R hadoop:hadoop /home/hadoop/spark

# Fix permissions
chmod -R 755 /home/hadoop/hadoop
chmod -R 755 /home/hadoop/spark
```

---

## 📝 Log Locations

Know where to find logs for troubleshooting:

### Hadoop Logs

```bash
# NameNode logs
$HADOOP_HOME/logs/hadoop-hadoop-namenode-m-1.log

# DataNode logs (on each node)
$HADOOP_HOME/logs/hadoop-hadoop-datanode-*.log

# ResourceManager logs
$HADOOP_HOME/logs/yarn-hadoop-resourcemanager-m-1.log

# NodeManager logs (on each node)
$HADOOP_HOME/logs/yarn-hadoop-nodemanager-*.log

# View recent errors
tail -100 $HADOOP_HOME/logs/hadoop-hadoop-namenode-m-1.log | grep ERROR
```

### Spark Logs

```bash
# Spark History Server logs
$SPARK_HOME/logs/spark-hadoop-org.apache.spark.deploy.history.HistoryServer-*.out

# Application event logs (in HDFS)
hdfs dfs -ls /spark-logs

# YARN application logs
yarn logs -applicationId <application_id>
```

### Useful Log Commands

```bash
# Follow logs in real-time
tail -f $HADOOP_HOME/logs/hadoop-hadoop-namenode-m-1.log

# Search for specific errors
grep -i "error" $HADOOP_HOME/logs/*.log

# View logs from all nodes
for node in m-1 m-2; do
    echo "=== Logs from $node ==="
    ssh $node "tail -20 $HADOOP_HOME/logs/hadoop-hadoop-datanode-$node.log"
done
```

---

## 🆘 Advanced Recovery

### Full Cluster Reset (Last Resort)

**Warning:** This will stop all services and clear temporary files. HDFS data will be preserved.

```bash
# 1. Stop all services
stop-yarn.sh
$SPARK_HOME/sbin/stop-history-server.sh
stop-dfs.sh

# 2. Clean temporary files on m-1
rm -rf $HADOOP_HOME/tmp/*
rm -rf $HADOOP_HOME/logs/*
rm -f $HADOOP_HOME/tmp/*.pid

# 3. Clean temporary files on m-2
ssh m-2 "rm -rf $HADOOP_HOME/tmp/*"
ssh m-2 "rm -rf $HADOOP_HOME/logs/*"
ssh m-2 "rm -f $HADOOP_HOME/tmp/*.pid"

# 4. Restart services
start-dfs.sh
hdfs dfsadmin -safemode wait
start-yarn.sh
$SPARK_HOME/sbin/start-history-server.sh

# 5. Verify cluster health
jps
hdfs dfsadmin -report
yarn node -list
```

### HDFS Metadata Corruption Recovery

**Only if NameNode fails to start due to corrupted metadata:**

```bash
# 1. Stop HDFS
stop-dfs.sh

# 2. Try to import last checkpoint
hdfs namenode -importCheckpoint

# 3. If that works, start NameNode
hdfs --daemon start namenode

# 4. Verify
hdfs dfsadmin -report

# 5. If importCheckpoint fails, you may need to format
# WARNING: This will erase all HDFS data!
# hdfs namenode -format
```

---

## 📚 Additional Resources

- [Shutdown & Restart Guide](SHUTDOWN-RESTART.md) - Proper procedures to avoid issues
- [Installation Guide](INSTALLATION.md) - Complete setup instructions
- [Configuration Guide](CONFIGURATION.md) - Tuning and optimization

---

## 🆘 Still Stuck?

If none of these solutions work:

1. **Collect diagnostic information:**
```bash
# Run health check script
./scripts/health_check.sh > cluster-health.txt

# Collect logs
tar -czf logs.tar.gz $HADOOP_HOME/logs/
```

2. **Open an issue** on GitHub with:
   - Detailed description of the problem
   - What you've already tried
   - Output of diagnostic commands
   - Relevant log excerpts
   - Your VM configuration (size, OS version)

3. **Check official documentation:**
   - [Hadoop Documentation](https://hadoop.apache.org/docs/r3.3.6/)
   - [Spark Documentation](https://spark.apache.org/docs/3.3.2/)

---

**Remember:** Most issues can be prevented by following proper [shutdown/restart procedures](SHUTDOWN-RESTART.md)! 🎯
