# Configuration Examples

This directory contains example configuration files for Hadoop and Spark. These templates include detailed comments explaining each property.

## 📁 Files

| File | Description | Target Location |
|------|-------------|-----------------|
| `core-site.xml` | Hadoop core configuration | `$HADOOP_HOME/etc/hadoop/` |
| `hdfs-site.xml` | HDFS configuration | `$HADOOP_HOME/etc/hadoop/` |
| `yarn-site.xml` | YARN resource management | `$HADOOP_HOME/etc/hadoop/` |
| `mapred-site.xml` | MapReduce configuration | `$HADOOP_HOME/etc/hadoop/` |
| `spark-defaults.conf` | Spark defaults | `$SPARK_HOME/conf/` |

## 🚀 Quick Start

### 1. Copy Configuration Files

```bash
# Copy Hadoop configurations
cp config/examples/core-site.xml $HADOOP_HOME/etc/hadoop/
cp config/examples/hdfs-site.xml $HADOOP_HOME/etc/hadoop/
cp config/examples/yarn-site.xml $HADOOP_HOME/etc/hadoop/
cp config/examples/mapred-site.xml $HADOOP_HOME/etc/hadoop/

# Copy Spark configuration
cp config/examples/spark-defaults.conf $SPARK_HOME/conf/
```

### 2. Customize for Your Environment

Edit the files to match your setup:

**Replace hostnames:**
- `m-1` → Your master node hostname
- `m-2` → Your worker node hostname

**Adjust memory settings** based on your VM size:

**For 4GB VMs (Standard_B2s):**
- `yarn.nodemanager.resource.memory-mb`: 3072
- `yarn.app.mapreduce.am.resource.mb`: 512
- `spark.executor.memory`: 512m

**For 8GB VMs (Standard_D2s_v3):**
- `yarn.nodemanager.resource.memory-mb`: 6144
- `yarn.app.mapreduce.am.resource.mb`: 1024
- `spark.executor.memory`: 1g

### 3. Sync to All Nodes

```bash
# Copy configurations to worker node
scp $HADOOP_HOME/etc/hadoop/core-site.xml hadoop@m-2:$HADOOP_HOME/etc/hadoop/
scp $HADOOP_HOME/etc/hadoop/hdfs-site.xml hadoop@m-2:$HADOOP_HOME/etc/hadoop/
scp $HADOOP_HOME/etc/hadoop/yarn-site.xml hadoop@m-2:$HADOOP_HOME/etc/hadoop/
scp $HADOOP_HOME/etc/hadoop/mapred-site.xml hadoop@m-2:$HADOOP_HOME/etc/hadoop/

scp $SPARK_HOME/conf/spark-defaults.conf hadoop@m-2:$SPARK_HOME/conf/
```

### 4. Restart Services

```bash
# Stop services
stop-yarn.sh
stop-dfs.sh

# Start services
start-dfs.sh
start-yarn.sh
$SPARK_HOME/sbin/start-history-server.sh
```

## ⚙️ Configuration Details

### core-site.xml

**Key Properties:**
- `fs.defaultFS`: NameNode URI (hdfs://m-1:9000)
- `hadoop.tmp.dir`: Temporary directory path
- `io.file.buffer.size`: I/O buffer size (128KB recommended)

**When to modify:**
- Initial setup
- Changing master node hostname
- Performance tuning

### hdfs-site.xml

**Key Properties:**
- `dfs.replication`: Number of replicas (2 for 2-node cluster)
- `dfs.namenode.name.dir`: NameNode metadata directory (CRITICAL - backup regularly!)
- `dfs.datanode.data.dir`: DataNode data directory
- `dfs.blocksize`: HDFS block size (128MB default)

**When to modify:**
- Initial setup
- Adding/removing nodes (adjust replication)
- Changing storage paths
- Performance tuning

### yarn-site.xml

**Key Properties:**
- `yarn.resourcemanager.hostname`: Master node hostname
- `yarn.nodemanager.resource.memory-mb`: Total memory for containers
- `yarn.nodemanager.resource.cpu-vcores`: CPU cores available
- `yarn.scheduler.maximum-allocation-mb`: Max memory per container

**When to modify:**
- Initial setup
- Changing VM size (adjust memory settings)
- Resource allocation issues
- Performance tuning

**Memory Configuration Guide:**

| VM Size | Total RAM | OS Reserve | YARN Memory |
|---------|-----------|------------|-------------|
| B2s (4GB) | 4096 MB | 1024 MB | 3072 MB |
| D2s_v3 (8GB) | 8192 MB | 2048 MB | 6144 MB |

### mapred-site.xml

**Key Properties:**
- `mapreduce.framework.name`: Must be 'yarn'
- `yarn.app.mapreduce.am.resource.mb`: ApplicationMaster memory
- `mapreduce.map.memory.mb`: Map task memory
- `mapreduce.reduce.memory.mb`: Reduce task memory
- `mapreduce.map.output.compress`: Enable compression (true recommended)

**When to modify:**
- Initial setup
- Changing VM size (adjust memory settings)
- MapReduce job failures due to memory
- Performance tuning

**Memory Allocation Tips:**
- ApplicationMaster: 512MB (4GB VM) or 1024MB (8GB VM)
- Map tasks: 512MB (4GB VM) or 1024MB (8GB VM)
- Reduce tasks: Same as map or 2x for sort-heavy jobs
- JVM heap: ~80% of container memory

### spark-defaults.conf

**Key Properties:**
- `spark.master`: Cluster manager (yarn)
- `spark.eventLog.enabled`: Enable event logging (true)
- `spark.eventLog.dir`: Event log directory (hdfs://m-1:9000/spark-logs)
- `spark.executor.memory`: Memory per executor
- `spark.executor.instances`: Number of executors
- `spark.serializer`: Serialization (KryoSerializer recommended)

**When to modify:**
- Initial setup
- Spark job failures due to memory
- Performance tuning
- Enabling/disabling dynamic allocation

**Before using Spark:**
```bash
# Create event log directory in HDFS
hdfs dfs -mkdir -p /spark-logs
hdfs dfs -chmod 777 /spark-logs
```

## 🎯 Common Adjustments

### Increase Memory for Jobs

**MapReduce:**
```xml
<!-- In mapred-site.xml -->
<property>
    <name>mapreduce.map.memory.mb</name>
    <value>1024</value>  <!-- Increase from 512 -->
</property>
```

**Spark:**
```properties
# In spark-defaults.conf
spark.executor.memory            1g  # Increase from 512m
```

### Enable More Parallelism

**YARN:**
```xml
<!-- In yarn-site.xml -->
<property>
    <name>yarn.nodemanager.resource.cpu-vcores</name>
    <value>4</value>  <!-- If your VM has 4 cores -->
</property>
```

**Spark:**
```properties
# In spark-defaults.conf
spark.executor.cores             2  # Increase from 1
spark.executor.instances         3  # Increase from 2
```

### Optimize for Small Files

**HDFS:**
```xml
<!-- In hdfs-site.xml -->
<property>
    <name>dfs.blocksize</name>
    <value>67108864</value>  <!-- 64MB instead of 128MB -->
</property>
```

### Enable Compression

**MapReduce:**
```xml
<!-- In mapred-site.xml -->
<property>
    <name>mapreduce.map.output.compress</name>
    <value>true</value>
</property>
<property>
    <name>mapreduce.map.output.compress.codec</name>
    <value>org.apache.hadoop.io.compress.SnappyCodec</value>
</property>
```

## 🔍 Validation

### Check Configuration Syntax

```bash
# Hadoop configurations are XML
xmllint --noout $HADOOP_HOME/etc/hadoop/core-site.xml
xmllint --noout $HADOOP_HOME/etc/hadoop/hdfs-site.xml
xmllint --noout $HADOOP_HOME/etc/hadoop/yarn-site.xml
xmllint --noout $HADOOP_HOME/etc/hadoop/mapred-site.xml
```

### Verify Configuration Applied

```bash
# Check Hadoop configuration
hadoop conf | grep -A 1 "fs.defaultFS"

# Check YARN configuration
yarn conf | grep -A 1 "yarn.resourcemanager.hostname"

# Check running values
hdfs getconf -confKey dfs.replication
yarn conf -get yarn.nodemanager.resource.memory-mb
```

## 🚨 Troubleshooting

### Configuration Not Taking Effect

**Solution:**
1. Verify file is in correct location
2. Check file permissions (should be readable by hadoop user)
3. Restart affected services
4. Check logs for configuration errors

### Memory Settings Too High

**Symptoms:**
- Containers fail to launch
- "Not enough memory" errors

**Solution:**
```bash
# Check available memory
free -h

# Reduce memory settings in yarn-site.xml and mapred-site.xml
# Leave at least 1GB for OS
```

### XML Syntax Errors

**Symptoms:**
- Services fail to start
- "Invalid XML" errors in logs

**Solution:**
```bash
# Validate XML syntax
xmllint --noout <config-file.xml>

# Common issues:
# - Missing closing tags
# - Special characters not escaped
# - Incorrect nesting
```

## 📚 Additional Resources

- [Hadoop Configuration Reference](https://hadoop.apache.org/docs/r3.3.6/hadoop-project-dist/hadoop-common/ClusterSetup.html)
- [YARN Configuration](https://hadoop.apache.org/docs/r3.3.6/hadoop-yarn/hadoop-yarn-common/yarn-default.xml)
- [Spark Configuration Guide](https://spark.apache.org/docs/3.3.2/configuration.html)
- [Configuration Reference](../docs/CONFIGURATION.md) - Detailed tuning guide

## 💡 Best Practices

1. **Always backup** configuration files before making changes
2. **Test changes** on one node before applying cluster-wide
3. **Document** any customizations you make
4. **Version control** your configurations
5. **Sync configurations** across all nodes after changes
6. **Restart services** for changes to take effect
7. **Monitor logs** after configuration changes

---

**Need help?** Check the [Troubleshooting Guide](../docs/TROUBLESHOOTING.md) or [Configuration Reference](../docs/CONFIGURATION.md).
