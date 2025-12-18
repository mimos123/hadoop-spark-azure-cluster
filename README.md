# 🚀 Hadoop & Spark Multi-Node Cluster on Azure

![Hadoop](https://img.shields.io/badge/Hadoop-3.3.6-orange)
![Spark](https://img.shields.io/badge/Spark-3.3.2-red)
![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04-purple)
![Azure](https://img.shields.io/badge/Azure-Cloud-blue)

Complete guide for deploying a production-ready 2-node Apache Hadoop and Apache Spark cluster on Microsoft Azure Virtual Machines.

---

## 📋 Project Overview

This repository provides comprehensive documentation and automation scripts for deploying and managing a Hadoop & Spark cluster on Azure.

### Technology Stack

- **Apache Hadoop 3.3.6** - Distributed storage (HDFS) and resource management (YARN)
- **Apache Spark 3.3.2** - Fast distributed computing engine
- **Ubuntu 22.04 LTS** - Operating system
- **Microsoft Azure** - Cloud infrastructure
- **Java 8** - Runtime environment

### Cluster Configuration

```
┌─────────────────────────────────────────────────────────┐
│                    Azure Virtual Network                 │
│                      (10.0.0.0/16)                      │
│                                                          │
│  ┌──────────────────────┐  ┌──────────────────────┐   │
│  │   Master Node (m-1)  │  │  Worker Node (m-2)   │   │
│  │                       │  │                       │   │
│  │  • NameNode          │  │  • DataNode          │   │
│  │  • SecondaryNameNode │  │  • NodeManager       │   │
│  │  • ResourceManager   │  │                       │   │
│  │  • NodeManager       │  │                       │   │
│  │  • DataNode          │  │                       │   │
│  │  • HistoryServer     │  │                       │   │
│  │                       │  │                       │   │
│  │  Public IP: X.X.X.X  │  │  Public IP: Y.Y.Y.Y  │   │
│  │  Private IP: 10.0.1.4│  │  Private IP: 10.0.1.5│   │
│  └──────────────────────┘  └──────────────────────┘   │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

**Node Roles:**
- **m-1 (Master):** Manages cluster coordination, metadata, and resource allocation
- **m-2 (Worker):** Executes tasks and stores data

---

## ✅ Prerequisites

### Required

- ✓ **Azure Account** with active subscription ([Free trial available](https://azure.microsoft.com/free/))
- ✓ **SSH Client** (Terminal on Mac/Linux, PuTTY on Windows)
- ✓ **Basic Linux knowledge** (commands, file editing)

### Recommended

- Azure CLI installed ([Installation guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
- Basic understanding of Hadoop/Spark concepts
- 2-4 hours for initial setup

### Azure Resources

- **2 Virtual Machines** (Standard_B2s or Standard_D2s_v3)
- **1 Virtual Network** with subnet
- **1 Network Security Group** with configured rules
- **2 Public IP addresses** (optional but recommended)

**Estimated Monthly Cost:**
- With nightly deallocation: **$15-30/month**
- Always running: **$30-80/month**

---

## 🚀 Quick Start

Get your cluster running in 5 simple steps:

### 1️⃣ Create Azure VMs

```bash
# Create resource group
az group create --name hadoop-cluster-rg --location eastus

# Create VMs (m-1 and m-2)
# See detailed instructions in docs/INSTALLATION.md
```

### 2️⃣ Install Software

```bash
# On both nodes: Install Java, Hadoop, and Spark
sudo apt update
sudo apt install -y openjdk-8-jdk
wget https://archive.apache.org/dist/hadoop/common/hadoop-3.3.6/hadoop-3.3.6.tar.gz
# ... (see Installation Guide for complete steps)
```

### 3️⃣ Configure Cluster

```bash
# Configure Hadoop and Spark settings
# Copy configuration templates from config/examples/
# See docs/INSTALLATION.md for detailed configuration
```

### 4️⃣ Start Services

```bash
# On master node (m-1)
hdfs namenode -format  # Only once!
start-dfs.sh
start-yarn.sh
$SPARK_HOME/sbin/start-history-server.sh
```

### 5️⃣ Verify

```bash
# Check services are running
jps
hdfs dfsadmin -report
yarn node -list
```

**🎉 That's it! Your cluster is ready!**

For complete step-by-step instructions, see the **[Installation Guide](docs/INSTALLATION.md)**.

---

## 🛑 Shutdown & Restart Procedures

> ⚠️ **CRITICAL:** Always properly shutdown services before stopping Azure VMs to prevent data corruption!

### ⚠️ WARNING: Improper Shutdown Risks

Stopping Azure VMs **without** stopping Hadoop/Spark services first can cause:
- ❌ HDFS enters safe mode indefinitely
- ❌ DataNodes fail to reconnect
- ❌ Corrupted metadata and edit logs
- ❌ Lost in-flight operations
- ❌ YARN nodes not registering

### ✅ Proper Shutdown Procedure

**Run on Master Node (m-1):**

```bash
# 1. Stop Spark History Server
$SPARK_HOME/sbin/stop-history-server.sh

# 2. Stop YARN
stop-yarn.sh

# 3. Stop HDFS
stop-dfs.sh

# 4. Verify all services stopped
jps  # Should only show 'Jps'
```

**Then in Azure Portal:**
```bash
# Deallocate VMs (not just stop!)
az vm deallocate --resource-group hadoop-cluster-rg --name m-1
az vm deallocate --resource-group hadoop-cluster-rg --name m-2
```

### ✅ Proper Restart Procedure

**Start Azure VMs first:**
```bash
# Start both VMs
az vm start --resource-group hadoop-cluster-rg --name m-1
az vm start --resource-group hadoop-cluster-rg --name m-2

# Wait 2-3 minutes for VMs to boot
```

**Then on Master Node (m-1):**

```bash
# 1. Start HDFS
start-dfs.sh

# 2. Wait for HDFS to be ready
hdfs dfsadmin -safemode wait

# 3. Start YARN
start-yarn.sh

# 4. Start Spark History Server
$SPARK_HOME/sbin/start-history-server.sh

# 5. Verify cluster health
jps
hdfs dfsadmin -report
yarn node -list
```

### 🤖 Use Automation Scripts

We provide scripts to automate these procedures:

```bash
# Before deallocating VMs
./scripts/pre_shutdown_check.sh  # Safety checks
./scripts/stop_cluster.sh         # Stop all services

# After starting VMs
./scripts/start_cluster.sh        # Start all services
./scripts/health_check.sh         # Verify cluster health
```

### 📖 Complete Guide

For detailed procedures, troubleshooting, and recovery steps, see the **[Shutdown & Restart Guide](docs/SHUTDOWN-RESTART.md)** (Most important document!)

### 💰 Cost Savings

Properly deallocating VMs when not in use saves **50-70%** on compute costs:

| Usage Pattern | Monthly Cost (B2s) | Savings |
|---------------|-------------------|---------|
| Always Running | $30-40 | $0 |
| Deallocate Nightly | $15-20 | 50% |
| Deallocate Weekends | $20-25 | 33% |

---

## 🌐 Web UI Access

Access these web interfaces from your browser (replace `<m-1-ip>` with your master node's public IP):

| Service | URL | Port | What You'll See |
|---------|-----|------|-----------------|
| **HDFS NameNode** | http://`<m-1-ip>`:9870 | 9870 | Cluster overview, live nodes, storage capacity |
| **YARN ResourceManager** | http://`<m-1-ip>`:8088 | 8088 | Running applications, cluster metrics, nodes |
| **Spark History Server** | http://`<m-1-ip>`:18080 | 18080 | Completed Spark applications, stages, jobs |
| **YARN NodeManager (m-1)** | http://`<m-1-ip>`:8042 | 8042 | Node details, containers, logs |
| **YARN NodeManager (m-2)** | http://`<m-2-ip>`:8042 | 8042 | Node details, containers, logs |

### Required Network Security Group Rules

Ensure these ports are open in your Azure NSG (restrict source to your IP for security):

```bash
# Add NSG rules (use Azure CLI or Portal)
az network nsg rule create --name HDFS-UI --priority 1001 --destination-port-ranges 9870
az network nsg rule create --name YARN-UI --priority 1002 --destination-port-ranges 8088
az network nsg rule create --name Spark-UI --priority 1003 --destination-port-ranges 18080
az network nsg rule create --name NodeManager-UI --priority 1004 --destination-port-ranges 8042
```

---

## ✅ Testing & Verification

### Test HDFS

```bash
# Create test file
echo "Hello Hadoop!" > test.txt

# Upload to HDFS
hdfs dfs -put test.txt /

# List files
hdfs dfs -ls /

# Read file
hdfs dfs -cat /test.txt

# Delete file
hdfs dfs -rm /test.txt
```

### Test MapReduce

```bash
# Run Pi estimation example
yarn jar $HADOOP_HOME/share/hadoop/mapreduce/hadoop-mapreduce-examples-3.3.6.jar pi 4 100

# Check YARN UI for completed application
```

### Test Spark

```bash
# Submit Spark job
spark-submit \
  --class org.apache.spark.examples.SparkPi \
  --master yarn \
  --deploy-mode cluster \
  $SPARK_HOME/examples/jars/spark-examples_2.12-3.3.2.jar \
  100

# Check Spark History Server for completed application
```

### Test PySpark

```bash
# Start PySpark shell
pyspark --master yarn

# Run test code
>>> data = [1, 2, 3, 4, 5]
>>> rdd = sc.parallelize(data)
>>> result = rdd.map(lambda x: x * 2).collect()
>>> print(result)
[2, 4, 6, 8, 10]
```

---

## 🔧 Troubleshooting Quick Reference

### Common Issues

| Issue | Quick Fix | Details |
|-------|-----------|---------|
| **Services not starting on m-2** | Check SSH connectivity and hostname resolution | [Guide](docs/TROUBLESHOOTING.md#services-not-starting) |
| **HDFS stuck in safe mode** | `hdfs dfsadmin -safemode wait` or `leave` | [Guide](docs/TROUBLESHOOTING.md#hdfs-safe-mode-problems) |
| **DataNode not connecting** | Check clock sync, clear DataNode data | [Guide](docs/TROUBLESHOOTING.md#datanode-issues) |
| **Out of memory errors** | Reduce container memory in configs | [Guide](docs/TROUBLESHOOTING.md#memory-and-resource-issues) |
| **Port already in use** | Kill stale processes, remove PID files | [Guide](docs/TROUBLESHOOTING.md#services-not-starting) |
| **Cannot access web UIs** | Check NSG rules, verify services running | [Guide](docs/TROUBLESHOOTING.md#web-ui-access-issues) |

### Quick Health Check

```bash
# Check all services
jps  # On both m-1 and m-2

# Check HDFS
hdfs dfsadmin -report

# Check YARN
yarn node -list

# Check disk space
df -h

# Check logs
tail -50 $HADOOP_HOME/logs/hadoop-hadoop-namenode-m-1.log
```

See **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)** for comprehensive solutions.

---

## 📁 Repository Structure

```
hadoop-spark-azure-cluster/
├── README.md                    # This file - main documentation
├── LICENSE                      # MIT License
├── CONTRIBUTING.md             # Contributing guidelines
├── .gitignore                  # Git ignore rules
│
├── docs/                       # Detailed documentation
│   ├── INSTALLATION.md         # Complete installation guide
│   ├── SHUTDOWN-RESTART.md     # Critical shutdown/restart procedures ⚠️
│   ├── TROUBLESHOOTING.md      # Comprehensive troubleshooting guide
│   └── CONFIGURATION.md        # Configuration reference and tuning
│
├── scripts/                    # Automation scripts
│   ├── start_cluster.sh        # Start all services with health checks
│   ├── stop_cluster.sh         # Gracefully stop all services
│   ├── health_check.sh         # Check cluster health
│   └── pre_shutdown_check.sh   # Pre-shutdown safety checks
│
└── config/                     # Configuration templates
    ├── examples/               # Example configuration files
    │   ├── core-site.xml       # Hadoop core configuration
    │   ├── hdfs-site.xml       # HDFS configuration
    │   ├── yarn-site.xml       # YARN configuration
    │   ├── mapred-site.xml     # MapReduce configuration
    │   └── spark-defaults.conf # Spark configuration
    └── README.md               # Configuration documentation
```

---

## 📚 Documentation Links

### Getting Started
- **[Installation Guide](docs/INSTALLATION.md)** - Complete setup from scratch (60-90 minutes)
- **[Quick Start](#-quick-start)** - 5-step overview for experienced users

### Critical Operations
- **[Shutdown & Restart Guide](docs/SHUTDOWN-RESTART.md)** - ⚠️ READ THIS FIRST! Most important document
- **[Troubleshooting Guide](docs/TROUBLESHOOTING.md)** - Solutions to common problems

### Configuration & Optimization
- **[Configuration Reference](docs/CONFIGURATION.md)** - Detailed configuration guide and tuning
- **[Configuration Examples](config/examples/)** - Ready-to-use configuration templates

### Automation
- **[Cluster Management Scripts](scripts/)** - Automation scripts for daily operations

---

## 🤝 Contributing

We welcome contributions! Whether it's:
- 🐛 Bug reports
- 📖 Documentation improvements
- ✨ New features
- 💡 Suggestions

Please see **[CONTRIBUTING.md](CONTRIBUTING.md)** for guidelines.

### How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test thoroughly
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## ⭐ Credits

### Author

**Mohamed Amine Belhassine**
- GitHub: [@mimos123](https://github.com/mimos123)

### Acknowledgments

- Apache Hadoop community for excellent documentation
- Apache Spark community for powerful computing framework
- Microsoft Azure for reliable cloud infrastructure
- All contributors who help improve this guide

### Built With

- [Apache Hadoop](https://hadoop.apache.org/) - Distributed storage and processing
- [Apache Spark](https://spark.apache.org/) - Unified analytics engine
- [Microsoft Azure](https://azure.microsoft.com/) - Cloud computing platform

---

## 🎯 Key Reminders

> ⚠️ **ALWAYS** read the [Shutdown & Restart Guide](docs/SHUTDOWN-RESTART.md) before stopping your VMs!

> 💰 **ALWAYS** deallocate VMs (not just stop) to save 50-70% on costs!

> 🔍 **ALWAYS** verify cluster health after restart with `jps`, `hdfs dfsadmin -report`, and `yarn node -list`!

> 📚 **ALWAYS** check the [Troubleshooting Guide](docs/TROUBLESHOOTING.md) if something doesn't work!

---

## 🆘 Getting Help

1. Check the [Troubleshooting Guide](docs/TROUBLESHOOTING.md)
2. Review the [Installation Guide](docs/INSTALLATION.md)
3. Read service logs in `$HADOOP_HOME/logs/`
4. Open an [issue](https://github.com/mimos123/hadoop-spark-azure-cluster/issues) with:
   - Detailed problem description
   - Output of `jps`, `hdfs dfsadmin -report`, `yarn node -list`
   - Relevant log excerpts
   - Your VM configuration

---

## 📞 Support

If you find this project helpful:
- ⭐ Star this repository
- 🐛 Report issues
- 📖 Improve documentation
- 💬 Share with others

---

**Happy Clustering! 🚀** Let's build something amazing with Hadoop & Spark!
