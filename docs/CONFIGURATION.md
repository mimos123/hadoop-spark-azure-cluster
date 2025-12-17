# ⚙️ Configuration Reference

Comprehensive guide to Hadoop and Spark configuration files, tuning parameters, and optimization strategies.

## 📖 Table of Contents

- [Configuration Files Overview](#-configuration-files-overview)
- [Hadoop Core Configuration](#-hadoop-core-configuration)
- [HDFS Configuration](#-hdfs-configuration)
- [YARN Configuration](#-yarn-configuration)
- [MapReduce Configuration](#-mapreduce-configuration)
- [Spark Configuration](#-spark-configuration)
- [Memory Tuning Guidelines](#-memory-tuning-guidelines)
- [Performance Optimization](#-performance-optimization)
- [Configuration Templates](#-configuration-templates)

---

## 📋 Configuration Files Overview

Your cluster uses these configuration files:

| File | Location | Purpose |
|------|----------|---------|
| `core-site.xml` | `$HADOOP_HOME/etc/hadoop/` | Core Hadoop settings |
| `hdfs-site.xml` | `$HADOOP_HOME/etc/hadoop/` | HDFS configuration |
| `yarn-site.xml` | `$HADOOP_HOME/etc/hadoop/` | YARN resource manager settings |
| `mapred-site.xml` | `$HADOOP_HOME/etc/hadoop/` | MapReduce framework settings |
| `spark-defaults.conf` | `$SPARK_HOME/conf/` | Spark application defaults |
| `hadoop-env.sh` | `$HADOOP_HOME/etc/hadoop/` | Hadoop environment variables |
| `workers` | `$HADOOP_HOME/etc/hadoop/` | List of worker nodes |

---

## 🌐 Hadoop Core Configuration

**File:** `$HADOOP_HOME/etc/hadoop/core-site.xml`

### Essential Properties

```xml
<configuration>
    <!-- NameNode URI -->
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://m-1:9000</value>
        <description>
            The default file system URI. Points to the NameNode.
            Used by all Hadoop components to access HDFS.
        </description>
    </property>

    <!-- Temporary directory -->
    <property>
        <name>hadoop.tmp.dir</name>
        <value>/home/hadoop/hadoop/tmp</value>
        <description>
            Base for temporary directories. Should be on a local disk
            with sufficient space. Cleaned up on restart.
        </description>
    </property>

    <!-- I/O file buffer size -->
    <property>
        <name>io.file.buffer.size</name>
        <value>131072</value>
        <description>
            Buffer size for reading/writing files. Default: 4096
            Increase for better I/O performance. Use 131072 (128KB) or 262144 (256KB).
        </description>
    </property>
</configuration>
```

### Performance Tuning

| Property | Default | Recommended | Description |
|----------|---------|-------------|-------------|
| `io.file.buffer.size` | 4096 | 131072 | File I/O buffer size (bytes) |
| `io.sort.mb` | 100 | 256 | Memory for sorting (MB) |
| `io.sort.factor` | 10 | 50 | Streams to merge at once |

---

## 💾 HDFS Configuration

**File:** `$HADOOP_HOME/etc/hadoop/hdfs-site.xml`

### Essential Properties

```xml
<configuration>
    <!-- Replication factor -->
    <property>
        <name>dfs.replication</name>
        <value>2</value>
        <description>
            Number of replicas for each block. For 2-node cluster, use 2.
            For single node, use 1. For production 3+ nodes, use 3.
        </description>
    </property>

    <!-- NameNode metadata directory -->
    <property>
        <name>dfs.namenode.name.dir</name>
        <value>file:///home/hadoop/hadoop/hdfs/namenode</value>
        <description>
            Where NameNode stores namespace and transaction logs.
            CRITICAL: Backup this directory regularly!
            Can specify multiple directories separated by commas for redundancy.
        </description>
    </property>

    <!-- DataNode data directory -->
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>file:///home/hadoop/hadoop/hdfs/datanode</value>
        <description>
            Where DataNodes store blocks. Can specify multiple directories
            separated by commas to use multiple disks.
        </description>
    </property>

    <!-- NameNode Web UI -->
    <property>
        <name>dfs.namenode.http-address</name>
        <value>m-1:9870</value>
        <description>NameNode Web UI address</description>
    </property>

    <!-- Block size -->
    <property>
        <name>dfs.blocksize</name>
        <value>134217728</value>
        <description>
            HDFS block size in bytes. Default: 134217728 (128MB)
            Larger blocks = less metadata, better for large files
            Smaller blocks = more parallelism, better for small files
        </description>
    </property>
</configuration>
```

### Advanced Properties

```xml
<configuration>
    <!-- Enable WebHDFS -->
    <property>
        <name>dfs.webhdfs.enabled</name>
        <value>true</value>
        <description>Enable REST API for HDFS access</description>
    </property>

    <!-- NameNode handler threads -->
    <property>
        <name>dfs.namenode.handler.count</name>
        <value>20</value>
        <description>
            Number of server threads to handle RPC requests.
            Default: 10. Increase for high concurrency.
            Formula: 20 * log2(cluster_size)
        </description>
    </property>

    <!-- DataNode handler threads -->
    <property>
        <name>dfs.datanode.handler.count</name>
        <value>10</value>
        <description>Number of DataNode server threads</description>
    </property>

    <!-- Permissions -->
    <property>
        <name>dfs.permissions.enabled</name>
        <value>true</value>
        <description>Enable HDFS permissions. Set false for development.</description>
    </property>
</configuration>
```

---

## 🎯 YARN Configuration

**File:** `$HADOOP_HOME/etc/hadoop/yarn-site.xml`

### Essential Properties

```xml
<configuration>
    <!-- ResourceManager hostname -->
    <property>
        <name>yarn.resourcemanager.hostname</name>
        <value>m-1</value>
        <description>Hostname of the ResourceManager</description>
    </property>

    <!-- ResourceManager addresses -->
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

    <!-- Shuffle service for MapReduce -->
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
        <description>Required for MapReduce to work</description>
    </property>

    <!-- NodeManager memory -->
    <property>
        <name>yarn.nodemanager.resource.memory-mb</name>
        <value>3072</value>
        <description>
            Total memory available to YARN on each node.
            For 4GB VM: Use 3072 (leave 1GB for OS)
            For 8GB VM: Use 6144 (leave 2GB for OS)
        </description>
    </property>

    <!-- Maximum allocation -->
    <property>
        <name>yarn.scheduler.maximum-allocation-mb</name>
        <value>3072</value>
        <description>
            Maximum memory a single container can request.
            Should match yarn.nodemanager.resource.memory-mb
        </description>
    </property>

    <!-- Minimum allocation -->
    <property>
        <name>yarn.scheduler.minimum-allocation-mb</name>
        <value>512</value>
        <description>Minimum memory a container can request</description>
    </property>

    <!-- CPU cores -->
    <property>
        <name>yarn.nodemanager.resource.cpu-vcores</name>
        <value>2</value>
        <description>
            Number of CPU cores available to YARN on each node.
            For B2s VM: Use 2
            For D2s_v3 VM: Use 2
        </description>
    </property>
</configuration>
```

### Memory Enforcement

```xml
<configuration>
    <!-- Physical memory check -->
    <property>
        <name>yarn.nodemanager.pmem-check-enabled</name>
        <value>true</value>
        <description>
            Kill containers exceeding physical memory limits.
            Set false for development if containers are killed frequently.
        </description>
    </property>

    <!-- Virtual memory check -->
    <property>
        <name>yarn.nodemanager.vmem-check-enabled</name>
        <value>false</value>
        <description>
            Kill containers exceeding virtual memory limits.
            Often disabled as virtual memory usage is hard to predict.
        </description>
    </property>

    <!-- Virtual to physical memory ratio -->
    <property>
        <name>yarn.nodemanager.vmem-pmem-ratio</name>
        <value>2.1</value>
        <description>
            Virtual memory can be up to 2.1x physical memory.
            Increase if containers are killed for virtual memory.
        </description>
    </property>
</configuration>
```

---

## 🗺️ MapReduce Configuration

**File:** `$HADOOP_HOME/etc/hadoop/mapred-site.xml`

### Essential Properties

```xml
<configuration>
    <!-- Use YARN as framework -->
    <property>
        <name>mapreduce.framework.name</name>
        <value>yarn</value>
        <description>Execution framework. Must be 'yarn'</description>
    </property>

    <!-- Classpath -->
    <property>
        <name>mapreduce.application.classpath</name>
        <value>$HADOOP_HOME/share/hadoop/mapreduce/*:$HADOOP_HOME/share/hadoop/mapreduce/lib/*</value>
    </property>

    <!-- ApplicationMaster memory -->
    <property>
        <name>yarn.app.mapreduce.am.resource.mb</name>
        <value>512</value>
        <description>
            Memory for ApplicationMaster.
            For 4GB VM: 512MB
            For 8GB VM: 1024MB
        </description>
    </property>

    <!-- Map task memory -->
    <property>
        <name>mapreduce.map.memory.mb</name>
        <value>512</value>
        <description>
            Memory per Map task.
            Adjust based on your data and available memory.
        </description>
    </property>

    <!-- Reduce task memory -->
    <property>
        <name>mapreduce.reduce.memory.mb</name>
        <value>512</value>
        <description>
            Memory per Reduce task.
            Typically 2x map memory for sort/merge operations.
        </description>
    </property>

    <!-- Map JVM heap -->
    <property>
        <name>mapreduce.map.java.opts</name>
        <value>-Xmx410m</value>
        <description>
            JVM heap for Map tasks. Should be 80% of mapreduce.map.memory.mb
        </description>
    </property>

    <!-- Reduce JVM heap -->
    <property>
        <name>mapreduce.reduce.java.opts</name>
        <value>-Xmx410m</value>
        <description>
            JVM heap for Reduce tasks. Should be 80% of mapreduce.reduce.memory.mb
        </description>
    </property>
</configuration>
```

### Performance Tuning

```xml
<configuration>
    <!-- Map-side aggregation -->
    <property>
        <name>mapreduce.map.output.compress</name>
        <value>true</value>
        <description>Compress map output to reduce network I/O</description>
    </property>

    <property>
        <name>mapreduce.map.output.compress.codec</name>
        <value>org.apache.hadoop.io.compress.SnappyCodec</value>
        <description>Use Snappy for fast compression</description>
    </property>

    <!-- Reduce-side tuning -->
    <property>
        <name>mapreduce.reduce.shuffle.parallelcopies</name>
        <value>10</value>
        <description>
            Number of parallel transfers during shuffle.
            Increase for better shuffle performance.
        </description>
    </property>

    <!-- Sort buffer -->
    <property>
        <name>mapreduce.task.io.sort.mb</name>
        <value>200</value>
        <description>
            Memory for sorting map output.
            Increase for better performance with large datasets.
        </description>
    </property>
</configuration>
```

---

## ⚡ Spark Configuration

**File:** `$SPARK_HOME/conf/spark-defaults.conf`

### Essential Properties

```properties
# Master
spark.master                     yarn

# Event logging for History Server
spark.eventLog.enabled           true
spark.eventLog.dir               hdfs://m-1:9000/spark-logs

# History Server
spark.history.fs.logDirectory    hdfs://m-1:9000/spark-logs
spark.yarn.historyServer.address m-1:18080
spark.history.ui.port            18080

# Driver settings (for client mode)
spark.driver.memory              512m
spark.driver.cores               1

# Executor settings
spark.executor.memory            512m
spark.executor.cores             1
spark.executor.instances         2

# Dynamic allocation (optional - enables auto-scaling)
spark.dynamicAllocation.enabled  false
spark.dynamicAllocation.minExecutors 1
spark.dynamicAllocation.maxExecutors 2
```

### Memory Tuning

```properties
# Memory overhead (for YARN container)
spark.yarn.executor.memoryOverhead  128m
spark.yarn.driver.memoryOverhead    128m

# Memory fractions
spark.memory.fraction               0.6
spark.memory.storageFraction        0.5

# Serialization (faster than Java serialization)
spark.serializer                    org.apache.spark.serializer.KryoSerializer
spark.kryoserializer.buffer.max     64m
```

### Performance Optimization

```properties
# Shuffle
spark.shuffle.compress              true
spark.shuffle.spill.compress        true

# Network
spark.network.timeout               300s
spark.rpc.askTimeout                300s

# Locality
spark.locality.wait                 3s

# SQL optimization
spark.sql.adaptive.enabled          true
spark.sql.adaptive.coalescePartitions.enabled true
```

---

## 💡 Memory Tuning Guidelines

### For 4GB VMs (Standard_B2s)

#### YARN Configuration
```
Total RAM:          4096 MB
OS Reserve:         1024 MB
YARN Available:     3072 MB
```

**yarn-site.xml:**
```xml
<property>
    <name>yarn.nodemanager.resource.memory-mb</name>
    <value>3072</value>
</property>
<property>
    <name>yarn.scheduler.maximum-allocation-mb</name>
    <value>3072</value>
</property>
```

#### MapReduce Configuration

**mapred-site.xml:**
```xml
<property>
    <name>yarn.app.mapreduce.am.resource.mb</name>
    <value>512</value>
</property>
<property>
    <name>mapreduce.map.memory.mb</name>
    <value>512</value>
</property>
<property>
    <name>mapreduce.reduce.memory.mb</name>
    <value>512</value>
</property>
```

#### Spark Configuration

**spark-defaults.conf:**
```properties
spark.driver.memory              512m
spark.executor.memory            512m
spark.executor.instances         1
spark.yarn.executor.memoryOverhead  128m
```

### For 8GB VMs (Standard_D2s_v3)

#### YARN Configuration
```
Total RAM:          8192 MB
OS Reserve:         2048 MB
YARN Available:     6144 MB
```

**yarn-site.xml:**
```xml
<property>
    <name>yarn.nodemanager.resource.memory-mb</name>
    <value>6144</value>
</property>
<property>
    <name>yarn.scheduler.maximum-allocation-mb</name>
    <value>6144</value>
</property>
```

#### MapReduce Configuration

**mapred-site.xml:**
```xml
<property>
    <name>yarn.app.mapreduce.am.resource.mb</name>
    <value>1024</value>
</property>
<property>
    <name>mapreduce.map.memory.mb</name>
    <value>1024</value>
</property>
<property>
    <name>mapreduce.reduce.memory.mb</name>
    <value>1024</value>
</property>
```

#### Spark Configuration

**spark-defaults.conf:**
```properties
spark.driver.memory              1g
spark.executor.memory            1g
spark.executor.instances         2
spark.yarn.executor.memoryOverhead  256m
```

---

## 🚀 Performance Optimization

### Quick Wins

1. **Enable Compression**
   - Reduces network I/O and storage
   - Use Snappy codec (fast) or LZ4 (faster)

2. **Increase I/O Buffer Size**
   - `io.file.buffer.size`: 131072 (128KB)
   - Better sequential I/O performance

3. **Tune HDFS Block Size**
   - Large files (>1GB): 256MB blocks
   - Small files (<100MB): 128MB blocks (default)

4. **Enable Spark Adaptive Query Execution**
   - `spark.sql.adaptive.enabled: true`
   - Optimizes query plans at runtime

5. **Use Kryo Serialization**
   - Faster than Java serialization
   - Smaller serialized size

### Monitoring and Adjustment

**Check Resource Utilization:**
```bash
# YARN resource usage
yarn top

# HDFS usage
hdfs dfsadmin -report

# Node health
free -h
df -h
```

**Identify Bottlenecks:**
- **High CPU, Low Memory:** Reduce parallelism
- **Low CPU, High Memory:** Increase parallelism
- **High Network I/O:** Enable compression
- **High Disk I/O:** Increase replication or use more DataNodes

---

## 📦 Configuration Templates

We provide complete configuration examples in the `config/examples/` directory:

```bash
config/examples/
├── core-site.xml          # Core Hadoop settings
├── hdfs-site.xml          # HDFS configuration
├── yarn-site.xml          # YARN resource management
├── mapred-site.xml        # MapReduce settings
├── spark-defaults.conf    # Spark defaults
└── README.md             # Configuration guide
```

### Using Templates

```bash
# Copy template to your Hadoop config directory
cp config/examples/core-site.xml $HADOOP_HOME/etc/hadoop/

# Edit with your specific values
nano $HADOOP_HOME/etc/hadoop/core-site.xml

# Sync to all nodes
scp $HADOOP_HOME/etc/hadoop/core-site.xml hadoop@m-2:$HADOOP_HOME/etc/hadoop/

# Restart services for changes to take effect
stop-dfs.sh
stop-yarn.sh
start-dfs.sh
start-yarn.sh
```

---

## 🔄 Applying Configuration Changes

### Changes That Require Restart

- HDFS configuration (hdfs-site.xml, core-site.xml)
- YARN configuration (yarn-site.xml)
- MapReduce configuration (mapred-site.xml)

**Process:**
```bash
# 1. Update configuration files
nano $HADOOP_HOME/etc/hadoop/yarn-site.xml

# 2. Copy to all nodes
scp $HADOOP_HOME/etc/hadoop/yarn-site.xml hadoop@m-2:$HADOOP_HOME/etc/hadoop/

# 3. Restart affected services
stop-yarn.sh
start-yarn.sh

# 4. Verify changes
yarn node -list
```

### Changes That Don't Require Restart

- Spark application configurations (spark-defaults.conf)
  - Takes effect for new applications
- Dynamic HDFS parameters
  - Can be changed with `hdfs dfsadmin` commands

---

## 📚 Additional Resources

- [Installation Guide](INSTALLATION.md) - Initial cluster setup
- [Shutdown & Restart Guide](SHUTDOWN-RESTART.md) - Proper procedures
- [Troubleshooting Guide](TROUBLESHOOTING.md) - Common issues

### Official Documentation

- [Hadoop Configuration](https://hadoop.apache.org/docs/r3.3.6/hadoop-project-dist/hadoop-common/ClusterSetup.html)
- [YARN Configuration](https://hadoop.apache.org/docs/r3.3.6/hadoop-yarn/hadoop-yarn-common/yarn-default.xml)
- [Spark Configuration](https://spark.apache.org/docs/3.3.2/configuration.html)

---

**💡 Pro Tip:** Always test configuration changes on a development cluster before applying to production! 🎯
