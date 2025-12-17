# 📦 Installation Guide

Complete step-by-step guide for deploying a 2-node Hadoop and Spark cluster on Microsoft Azure.

## 📖 Table of Contents

- [Overview](#-overview)
- [Prerequisites](#-prerequisites)
- [Phase 1: Azure VM Setup](#-phase-1-azure-vm-setup)
- [Phase 2: Network Configuration](#-phase-2-network-configuration)
- [Phase 3: SSH Setup](#-phase-3-ssh-setup)
- [Phase 4: Java Installation](#-phase-4-java-installation)
- [Phase 5: Hadoop Installation](#-phase-5-hadoop-installation)
- [Phase 6: Hadoop Configuration](#-phase-6-hadoop-configuration)
- [Phase 7: Spark Installation](#-phase-7-spark-installation)
- [Phase 8: Cluster Startup](#-phase-8-cluster-startup)
- [Phase 9: Verification](#-phase-9-verification)
- [Next Steps](#-next-steps)

---

## 🎯 Overview

This guide will help you set up:
- **2 Azure VMs** (m-1 master, m-2 worker)
- **Hadoop 3.3.6** (HDFS + YARN)
- **Spark 3.3.2**
- **Ubuntu 22.04 LTS**

**Estimated Time:** 60-90 minutes

**Estimated Cost:** $15-40/month (depending on VM size and usage)

---

## ✅ Prerequisites

### Required

- ✓ Azure account with active subscription
- ✓ Basic Linux command line knowledge
- ✓ SSH client (Terminal on Mac/Linux, PuTTY on Windows)
- ✓ Text editor (nano, vim, or VS Code with Remote-SSH)

### Recommended

- Azure CLI installed ([Installation Guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
- Basic understanding of Hadoop/Spark concepts
- 2-4 hours of uninterrupted time for initial setup

---

## 🏗️ Phase 1: Azure VM Setup

### 1.1 Create Resource Group

**Using Azure Portal:**

1. Go to [Azure Portal](https://portal.azure.com)
2. Navigate to **Resource groups** → **Create**
3. Fill in details:
   - **Subscription:** Your subscription
   - **Resource group:** `hadoop-cluster-rg`
   - **Region:** Choose closest to you (e.g., `East US`, `West Europe`)
4. Click **Review + Create** → **Create**

**Using Azure CLI:**

```bash
# Login to Azure
az login

# Create resource group
az group create \
  --name hadoop-cluster-rg \
  --location eastus
```

### 1.2 Create Virtual Network

**Using Azure Portal:**

1. Navigate to **Virtual networks** → **Create**
2. Fill in details:
   - **Resource group:** `hadoop-cluster-rg`
   - **Name:** `hadoop-vnet`
   - **Region:** Same as resource group
   - **IPv4 address space:** `10.0.0.0/16`
   - **Subnet name:** `hadoop-subnet`
   - **Subnet address range:** `10.0.1.0/24`
3. Click **Review + Create** → **Create**

**Using Azure CLI:**

```bash
# Create virtual network
az network vnet create \
  --resource-group hadoop-cluster-rg \
  --name hadoop-vnet \
  --address-prefix 10.0.0.0/16 \
  --subnet-name hadoop-subnet \
  --subnet-prefix 10.0.1.0/24
```

### 1.3 Create Virtual Machines

We'll create two VMs: **m-1** (master) and **m-2** (worker)

**Recommended VM Sizes:**

| VM Size | vCPUs | RAM | Storage | Monthly Cost* | Use Case |
|---------|-------|-----|---------|--------------|----------|
| Standard_B2s | 2 | 4 GB | 8 GB | ~$15-20 | Learning/Development |
| Standard_D2s_v3 | 2 | 8 GB | 16 GB | ~$35-40 | Production/Testing |

*Approximate costs when deallocated nightly

#### Create Master VM (m-1)

**Using Azure Portal:**

1. Navigate to **Virtual machines** → **Create** → **Azure virtual machine**
2. **Basics tab:**
   - **Resource group:** `hadoop-cluster-rg`
   - **Virtual machine name:** `m-1`
   - **Region:** Same as resource group
   - **Image:** `Ubuntu Server 22.04 LTS - Gen2`
   - **Size:** `Standard_B2s` (or `Standard_D2s_v3`)
   - **Authentication type:** `SSH public key`
   - **Username:** `hadoop`
   - **SSH public key source:** Generate new key pair
   - **Key pair name:** `hadoop-ssh-key`
3. **Disks tab:**
   - **OS disk type:** `Standard SSD`
   - **Delete with VM:** Checked
4. **Networking tab:**
   - **Virtual network:** `hadoop-vnet`
   - **Subnet:** `hadoop-subnet`
   - **Public IP:** Create new → `m-1-ip`
   - **NIC network security group:** `Basic`
   - **Public inbound ports:** `Allow selected ports`
   - **Select inbound ports:** `SSH (22)`
5. **Management tab:**
   - **Boot diagnostics:** Disable (to save costs)
6. Click **Review + Create** → **Create**
7. **Download private key** when prompted (save as `hadoop-ssh-key.pem`)

**Using Azure CLI:**

```bash
# Create public IP for m-1
az network public-ip create \
  --resource-group hadoop-cluster-rg \
  --name m-1-ip \
  --sku Standard \
  --allocation-method Static

# Create m-1 VM
az vm create \
  --resource-group hadoop-cluster-rg \
  --name m-1 \
  --vnet-name hadoop-vnet \
  --subnet hadoop-subnet \
  --image Ubuntu2204 \
  --size Standard_B2s \
  --admin-username hadoop \
  --public-ip-address m-1-ip \
  --generate-ssh-keys \
  --output json \
  --verbose
```

#### Create Worker VM (m-2)

Repeat the same process for m-2:

**Using Azure Portal:** Follow the same steps but:
- **Virtual machine name:** `m-2`
- **Key pair name:** Use existing `hadoop-ssh-key`
- **Public IP:** Create new → `m-2-ip`

**Using Azure CLI:**

```bash
# Create public IP for m-2
az network public-ip create \
  --resource-group hadoop-cluster-rg \
  --name m-2-ip \
  --sku Standard \
  --allocation-method Static

# Create m-2 VM
az vm create \
  --resource-group hadoop-cluster-rg \
  --name m-2 \
  --vnet-name hadoop-vnet \
  --subnet hadoop-subnet \
  --image Ubuntu2204 \
  --size Standard_B2s \
  --admin-username hadoop \
  --public-ip-address m-2-ip \
  --ssh-key-values ~/.ssh/id_rsa.pub \
  --output json \
  --verbose
```

### 1.4 Get VM IP Addresses

**Using Azure Portal:**
1. Navigate to each VM
2. Copy the **Public IP address**

**Using Azure CLI:**

```bash
# Get both public and private IPs
az vm list-ip-addresses \
  --resource-group hadoop-cluster-rg \
  --output table
```

**Save these IPs** - you'll need them throughout the setup:

```
m-1 Public IP:  <m-1-public-ip>
m-1 Private IP: <m-1-private-ip>  (typically 10.0.1.4)
m-2 Public IP:  <m-2-public-ip>
m-2 Private IP: <m-2-private-ip>  (typically 10.0.1.5)
```

---

## 🌐 Phase 2: Network Configuration

### 2.1 Configure Network Security Group (NSG)

We need to open ports for Hadoop and Spark web UIs.

**Using Azure Portal:**

1. Navigate to **Network Security Groups** → Find your NSG (created with VMs)
2. Go to **Inbound security rules** → **Add**

Add these rules:

| Name | Port | Protocol | Source | Description |
|------|------|----------|--------|-------------|
| HDFS-NameNode | 9870 | TCP | Your IP | HDFS NameNode UI |
| YARN-ResourceManager | 8088 | TCP | Your IP | YARN ResourceManager UI |
| Spark-History | 18080 | TCP | Your IP | Spark History Server |
| YARN-NodeManager | 8042 | TCP | Your IP | YARN NodeManager UI |

> 💡 **Security Tip:** Use **Your IP** as source instead of **Any** to restrict access to only your location.

**Using Azure CLI:**

```bash
# Get your NSG name
NSG_NAME=$(az network nsg list --resource-group hadoop-cluster-rg --query "[0].name" -o tsv)

# Add rules
az network nsg rule create \
  --resource-group hadoop-cluster-rg \
  --nsg-name $NSG_NAME \
  --name HDFS-NameNode \
  --priority 1001 \
  --source-address-prefixes $(curl -s ifconfig.me)/32 \
  --destination-port-ranges 9870 \
  --access Allow \
  --protocol Tcp

az network nsg rule create \
  --resource-group hadoop-cluster-rg \
  --nsg-name $NSG_NAME \
  --name YARN-ResourceManager \
  --priority 1002 \
  --source-address-prefixes $(curl -s ifconfig.me)/32 \
  --destination-port-ranges 8088 \
  --access Allow \
  --protocol Tcp

az network nsg rule create \
  --resource-group hadoop-cluster-rg \
  --nsg-name $NSG_NAME \
  --name Spark-History \
  --priority 1003 \
  --source-address-prefixes $(curl -s ifconfig.me)/32 \
  --destination-port-ranges 18080 \
  --access Allow \
  --protocol Tcp

az network nsg rule create \
  --resource-group hadoop-cluster-rg \
  --nsg-name $NSG_NAME \
  --name YARN-NodeManager \
  --priority 1004 \
  --source-address-prefixes $(curl -s ifconfig.me)/32 \
  --destination-port-ranges 8042 \
  --access Allow \
  --protocol Tcp
```

### 2.2 Configure Hostnames

**On BOTH m-1 and m-2:**

```bash
# SSH into m-1
ssh -i hadoop-ssh-key.pem hadoop@<m-1-public-ip>

# Edit /etc/hosts (use private IPs for inter-node communication)
sudo nano /etc/hosts

# Add these lines (replace with your actual private IPs):
10.0.1.4 m-1
10.0.1.5 m-2

# Save and exit (Ctrl+X, Y, Enter)
```

Repeat on m-2:

```bash
# SSH into m-2
ssh -i hadoop-ssh-key.pem hadoop@<m-2-public-ip>

# Edit /etc/hosts
sudo nano /etc/hosts

# Add the same lines:
10.0.1.4 m-1
10.0.1.5 m-2

# Save and exit
```

**Verify hostname resolution:**

```bash
# On both nodes
ping -c 2 m-1
ping -c 2 m-2
```

---

## 🔐 Phase 3: SSH Setup

Setup passwordless SSH between nodes for Hadoop services.

### 3.1 Generate SSH Keys (on m-1)

```bash
# SSH into m-1
ssh -i hadoop-ssh-key.pem hadoop@<m-1-public-ip>

# Generate SSH key pair (press Enter for all prompts)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

### 3.2 Copy Public Key to Both Nodes

```bash
# On m-1, copy key to itself (for localhost)
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys

# Copy key to m-2
ssh-copy-id -i ~/.ssh/id_rsa.pub hadoop@m-2
# Type 'yes' when prompted, enter password if asked
```

### 3.3 Verify Passwordless SSH

```bash
# On m-1, test SSH to both nodes
ssh m-1 'hostname'  # Should print: m-1
ssh m-2 'hostname'  # Should print: m-2

# Should NOT ask for password
```

---

## ☕ Phase 4: Java Installation

Hadoop and Spark require Java. We'll install OpenJDK 8 (most compatible).

**On BOTH m-1 and m-2:**

```bash
# Update package list
sudo apt update

# Install OpenJDK 8
sudo apt install -y openjdk-8-jdk

# Verify installation
java -version
# Should show: openjdk version "1.8.0_xxx"

# Set JAVA_HOME
echo 'export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64' >> ~/.bashrc
echo 'export PATH=$PATH:$JAVA_HOME/bin' >> ~/.bashrc

# Reload bashrc
source ~/.bashrc

# Verify JAVA_HOME
echo $JAVA_HOME
# Should print: /usr/lib/jvm/java-8-openjdk-amd64
```

---

## 🐘 Phase 5: Hadoop Installation

**On BOTH m-1 and m-2:**

### 5.1 Download Hadoop

```bash
# Download Hadoop 3.3.6
cd ~
wget https://archive.apache.org/dist/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz

# Extract
tar -xzf hadoop-3.3.6.tar.gz

# Rename for convenience
mv hadoop-3.3.6 hadoop

# Cleanup
rm hadoop-3.3.6.tar.gz
```

### 5.2 Set Environment Variables

```bash
# Add Hadoop environment variables
cat >> ~/.bashrc << 'EOF'

# Hadoop Environment
export HADOOP_HOME=/home/hadoop/hadoop
export HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
export HADOOP_MAPRED_HOME=$HADOOP_HOME
export HADOOP_COMMON_HOME=$HADOOP_HOME
export HADOOP_HDFS_HOME=$HADOOP_HOME
export YARN_HOME=$HADOOP_HOME
export PATH=$PATH:$HADOOP_HOME/bin:$HADOOP_HOME/sbin
EOF

# Reload bashrc
source ~/.bashrc

# Verify
hadoop version
# Should show: Hadoop 3.3.6
```

---

## ⚙️ Phase 6: Hadoop Configuration

Configure Hadoop **ONLY on m-1** (master), then copy to m-2.

### 6.1 Configure hadoop-env.sh

```bash
# On m-1
nano $HADOOP_HOME/etc/hadoop/hadoop-env.sh

# Add/uncomment these lines:
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HADOOP_LOG_DIR=${HADOOP_HOME}/logs

# Save and exit
```

### 6.2 Configure core-site.xml

```bash
# On m-1
nano $HADOOP_HOME/etc/hadoop/core-site.xml
```

Replace the contents with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://m-1:9000</value>
        <description>NameNode URI</description>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>/home/hadoop/hadoop/tmp</value>
        <description>Temporary directory</description>
    </property>
</configuration>
```

### 6.3 Configure hdfs-site.xml

```bash
# On m-1
nano $HADOOP_HOME/etc/hadoop/hdfs-site.xml
```

Replace the contents with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>2</value>
        <description>Number of replications (we have 2 nodes)</description>
    </property>
    <property>
        <name>dfs.namenode.name.dir</name>
        <value>file:///home/hadoop/hadoop/hdfs/namenode</value>
        <description>NameNode metadata directory</description>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>file:///home/hadoop/hadoop/hdfs/datanode</value>
        <description>DataNode data directory</description>
    </property>
    <property>
        <name>dfs.namenode.http-address</name>
        <value>m-1:9870</value>
        <description>NameNode Web UI address</description>
    </property>
</configuration>
```

### 6.4 Configure yarn-site.xml

```bash
# On m-1
nano $HADOOP_HOME/etc/hadoop/yarn-site.xml
```

Replace the contents with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>m-1</value>
        <description>ResourceManager hostname</description>
    </property>
    <property>
        <name>yarn.resourcemanager.address</name>
        <value>m-1:8032</value>
    </property>
    <property>
        <name>yarn.resourcemanager.scheduler.address</name>
        <value>m-1:8030</value>
    </property>
    <property>
        <name>yarn.resourcemanager.resource-tracker.address</name>
        <value>m-1:8031</value>
    </property>
    <property>
        <name>yarn.resourcemanager.webapp.address</name>
        <value>m-1:8088</value>
    </property>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
    <property>
        <name>yarn.nodemanager.resource.memory-mb</name>
        <value>3072</value>
        <description>Memory for NodeManager (adjust based on VM size)</description>
    </property>
    <property>
        <name>yarn.scheduler.maximum-allocation-mb</name>
        <value>3072</value>
    </property>
    <property>
        <name>yarn.nodemanager.resource.cpu-vcores</name>
        <value>2</value>
        <description>CPU cores for NodeManager</description>
    </property>
</configuration>
```

> 💡 **Memory Settings:**
> - For **4GB VMs** (B2s): Use 3072 MB
> - For **8GB VMs** (D2s_v3): Use 6144 MB

### 6.5 Configure mapred-site.xml

```bash
# On m-1
nano $HADOOP_HOME/etc/hadoop/mapred-site.xml
```

Replace the contents with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
        <description>Use YARN as the execution framework</description>
    </property>
    <property>
        <name>mapreduce.application.classpath</name>
        <value>$HADOOP_HOME/share/hadoop/mapreduce/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*</value>
    </property>
    <property>
        <name>yarn.app.mapreduce.am.resource.mb</name>
        <value>512</value>
        <description>Memory for ApplicationMaster</description>
    </property>
    <property>
        <name>mapreduce.map.memory.mb</name>
        <value>512</value>
        <description>Memory for Map tasks</description>
    </property>
    <property>
        <name>mapreduce.reduce.memory.mb</name>
        <value>512</value>
        <description>Memory for Reduce tasks</description>
    </property>
</configuration>
```

### 6.6 Configure Workers File

```bash
# On m-1
nano $HADOOP_HOME/etc/hadoop/workers
```

Replace contents with:

```
m-1
m-2
```

### 6.7 Copy Configuration to m-2

```bash
# On m-1, copy Hadoop directory to m-2
scp -r $HADOOP_HOME/etc/hadoop/* hadoop@m-2:$HADOOP_HOME/etc/hadoop/
```

### 6.8 Create HDFS Directories

**On BOTH m-1 and m-2:**

```bash
# Create HDFS directories
mkdir -p $HADOOP_HOME/hdfs/namenode
mkdir -p $HADOOP_HOME/hdfs/datanode
mkdir -p $HADOOP_HOME/tmp
mkdir -p $HADOOP_HOME/logs
```

---

## ⚡ Phase 7: Spark Installation

**On BOTH m-1 and m-2:**

### 7.1 Download Spark

```bash
# Download Spark 3.3.2 (pre-built for Hadoop 3.3)
cd ~
wget https://archive.apache.org/dist/spark/spark-3.3.2/spark-3.3.2-bin-hadoop3.tgz

# Extract
tar -xzf spark-3.3.2-bin-hadoop3.tgz

# Rename for convenience
mv spark-3.3.2-bin-hadoop3 spark

# Cleanup
rm spark-3.3.2-bin-hadoop3.tgz
```

### 7.2 Set Environment Variables

```bash
# Add Spark environment variables
cat >> ~/.bashrc << 'EOF'

# Spark Environment
export SPARK_HOME=/home/hadoop/spark
export PATH=$PATH:$SPARK_HOME/bin:$SPARK_HOME/sbin
export PYSPARK_PYTHON=/usr/bin/python3
EOF

# Reload bashrc
source ~/.bashrc

# Verify
spark-submit --version
# Should show: version 3.3.2
```

### 7.3 Configure Spark

**On m-1:**

```bash
# Copy template
cp $SPARK_HOME/conf/spark-defaults.conf.template $SPARK_HOME/conf/spark-defaults.conf

# Edit configuration
nano $SPARK_HOME/conf/spark-defaults.conf
```

Add these lines:

```properties
spark.master                     yarn
spark.eventLog.enabled           true
spark.eventLog.dir               hdfs://m-1:9000/spark-logs
spark.history.fs.logDirectory    hdfs://m-1:9000/spark-logs
spark.yarn.historyServer.address m-1:18080
spark.history.ui.port            18080
```

**Copy configuration to m-2:**

```bash
# On m-1
scp $SPARK_HOME/conf/spark-defaults.conf hadoop@m-2:$SPARK_HOME/conf/
```

---

## 🚀 Phase 8: Cluster Startup

Now let's start the cluster for the first time!

### 8.1 Format HDFS NameNode (ONLY ONCE!)

**On m-1:**

```bash
# Format NameNode (only do this ONCE!)
hdfs namenode -format

# You should see: "Storage directory ... has been successfully formatted"
```

> ⚠️ **Warning:** Never run `hdfs namenode -format` again after initial setup! It will erase all HDFS data.

### 8.2 Start HDFS

**On m-1:**

```bash
# Start HDFS
start-dfs.sh
```

**Expected Output:**
```
Starting namenodes on [m-1]
Starting datanodes
Starting secondary namenodes [m-1]
```

**Verify HDFS is running:**

```bash
# Check processes on m-1
jps
# Should show: NameNode, DataNode, SecondaryNameNode, Jps

# Check processes on m-2
ssh m-2 "jps"
# Should show: DataNode, Jps

# Check HDFS status
hdfs dfsadmin -report
# Should show 2 live datanodes
```

### 8.3 Create Spark Log Directory

**On m-1:**

```bash
# Create directory in HDFS for Spark logs
hdfs dfs -mkdir -p /spark-logs
hdfs dfs -chmod 777 /spark-logs

# Verify
hdfs dfs -ls /
```

### 8.4 Start YARN

**On m-1:**

```bash
# Start YARN
start-yarn.sh
```

**Expected Output:**
```
Starting resourcemanager
Starting nodemanagers
```

**Verify YARN is running:**

```bash
# Check processes on m-1
jps
# Should show: NameNode, DataNode, SecondaryNameNode, ResourceManager, NodeManager, Jps

# Check processes on m-2
ssh m-2 "jps"
# Should show: DataNode, NodeManager, Jps

# Check YARN nodes
yarn node -list
# Should show 2 nodes (m-1 and m-2) in RUNNING state
```

### 8.5 Start Spark History Server

**On m-1:**

```bash
# Start Spark History Server
$SPARK_HOME/sbin/start-history-server.sh

# Verify
jps
# Should now also show: HistoryServer
```

---

## ✅ Phase 9: Verification

Let's verify everything is working correctly!

### 9.1 Check All Services

**On m-1:**

```bash
jps
```

**Expected Output:**
```
12345 NameNode
12346 DataNode
12347 SecondaryNameNode
12348 ResourceManager
12349 NodeManager
12350 HistoryServer
12351 Jps
```

**On m-2:**

```bash
ssh m-2 "jps"
```

**Expected Output:**
```
23456 DataNode
23457 NodeManager
23458 Jps
```

### 9.2 Access Web UIs

Open these URLs in your browser (replace `<m-1-public-ip>` with actual IP):

| Service | URL | What to Check |
|---------|-----|---------------|
| HDFS NameNode | http://`<m-1-public-ip>`:9870 | Shows 2 live nodes |
| YARN ResourceManager | http://`<m-1-public-ip>`:8088 | Shows 2 active nodes |
| Spark History Server | http://`<m-1-public-ip>`:18080 | Server is accessible |
| YARN NodeManager (m-2) | http://`<m-2-public-ip>`:8042 | Shows node details |

### 9.3 Test HDFS Operations

```bash
# Create test directory
hdfs dfs -mkdir -p /test

# Create a test file
echo "Hello Hadoop!" > test.txt
hdfs dfs -put test.txt /test/

# List files
hdfs dfs -ls /test

# Read file
hdfs dfs -cat /test/test.txt

# Should output: Hello Hadoop!

# Cleanup
rm test.txt
hdfs dfs -rm -r /test
```

### 9.4 Test YARN with MapReduce

```bash
# Run the classic Pi estimation example
yarn jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar pi 4 100

# Should output estimated value of Pi (around 3.14...)
```

Check YARN ResourceManager UI (http://`<m-1-public-ip>`:8088) - you should see the completed application.

### 9.5 Test Spark

```bash
# Run Spark Pi example
spark-submit \
  --class org.apache.spark.examples.SparkPi \
  --master yarn \
  --deploy-mode cluster \
  --driver-memory 512m \
  --executor-memory 512m \
  --executor-cores 1 \
  $SPARK_HOME/examples/jars/spark-examples_2.12-3.3.2.jar \
  100

# Should output estimated value of Pi
```

Check Spark History Server UI (http://`<m-1-public-ip>`:18080) - you should see the completed application.

### 9.6 Test PySpark

```bash
# Start PySpark shell
pyspark --master yarn

# In the PySpark shell, run:
data = [1, 2, 3, 4, 5]
rdd = sc.parallelize(data)
result = rdd.map(lambda x: x * 2).collect()
print(result)

# Should output: [2, 4, 6, 8, 10]

# Exit PySpark
exit()
```

---

## 🎉 Next Steps

Congratulations! Your Hadoop & Spark cluster is up and running! 🎊

### What to do next:

1. **Bookmark Web UIs** for easy access
2. **Read the Shutdown/Restart Guide** - [docs/SHUTDOWN-RESTART.md](SHUTDOWN-RESTART.md)
   - ⚠️ **CRITICAL:** Learn proper shutdown procedures to avoid data corruption!
3. **Review Troubleshooting Guide** - [docs/TROUBLESHOOTING.md](TROUBLESHOOTING.md)
4. **Explore Configuration Options** - [docs/CONFIGURATION.md](CONFIGURATION.md)
5. **Use Automation Scripts** - Located in `scripts/` directory

### Common First Tasks:

- Upload datasets to HDFS
- Run your first MapReduce job
- Submit Spark applications
- Explore HDFS and YARN web UIs
- Set up automation scripts for daily use

### Important Reminders:

> ⚠️ **Always properly shutdown services before stopping Azure VMs!**
> 
> See [Shutdown & Restart Guide](SHUTDOWN-RESTART.md) for detailed procedures.

> 💰 **Save money by deallocating VMs when not in use!**
> 
> Deallocated VMs only cost ~$2-5/month vs ~$15-20/month when running.

---

## 🆘 Getting Help

If you encounter issues during installation:

1. Check the [Troubleshooting Guide](TROUBLESHOOTING.md)
2. Review log files:
   - Hadoop logs: `$HADOOP_HOME/logs/`
   - Spark logs: `$SPARK_HOME/logs/`
3. Verify all configuration files are correct
4. Ensure hostnames resolve correctly: `ping m-1` and `ping m-2`
5. Check firewall rules and network connectivity
6. Open an issue on GitHub with:
   - Output of `jps` on both nodes
   - Output of `hdfs dfsadmin -report`
   - Output of `yarn node -list`
   - Any error messages from logs

---

**🎯 You've completed the installation! Great job!** Now make sure to read the [Shutdown/Restart Guide](SHUTDOWN-RESTART.md) before stopping your VMs! 🚀
