# Elasticsearch 8 Postman API Collection

A comprehensive Postman Collection (v2.1.0) to test, manage, and query your AWS Elasticsearch 8 deployment.

---

## 📁 Collection Structure & Included Endpoints

### **1. Cluster Health & Status**
* `GET 1.1 - Root Info & Version`: Returns cluster name, version info (`8.13.0`), and tagline.
* `GET 1.2 - Cluster Health Status`: Inspects cluster health (`green`, `yellow`, `red`) and active/unassigned shard counts.
* `GET 1.3 - Cluster Stats`: Returns memory pool, JVM heap, and storage utilization.
* `GET 1.4 - Nodes Info & Stats`: Displays detailed metrics per cluster node.

### **2. Index Management**
* `PUT 2.1 - Create Index with Mappings`: Creates the `app-logs` index with single-shard settings and field data types (`keyword`, `integer`, `date`, `text`).
* `GET 2.2 - Get Index Details`: Inspects settings and mappings for `app-logs`.
* `GET 2.3 - Get Index Mappings`: Retrieves mapping schema for `app-logs`.
* `DELETE 2.4 - Delete Index`: Removes the `app-logs` index.

### **3. Document Operations (CRUD)**
* `POST 3.1 - Index Document (Create / Upsert)`: Inserts a document into `/app-logs/_doc/1`.
* `GET 3.2 - Get Document by ID`: Retrieves document `ID: 1`.
* `POST 3.3 - Partial Update Document`: Updates specific fields using `_update`.
* `DELETE 3.4 - Delete Document by ID`: Deletes document `ID: 1`.

### **4. Search & Aggregations**
* `GET 4.1 - Search All Documents`: Executes a `match_all` query.
* `POST 4.2 - Term Query Search`: Searches for exact keyword matches (`service: payment-gateway`).
* `POST 4.3 - Range Query Search`: Filters documents by latency threshold (`latency_ms` between 50 and 200).
* `POST 4.4 - Metrics Aggregation`: Calculates average latency and groups document counts by `status`.

### **5. Performance & Resource Monitoring (JVM & Disk)**
* `GET 5.1 - Node Memory & JVM Heap %`: Tabular overview of Heap % (`heap.percent`), current/max heap, host RAM %, and CPU via `/_cat/nodes`.
* `GET 5.2 - JVM Garbage Collection & Memory Stats`: Granular JVM stats and GC collectors (`young` & `old` collection counts and pause duration in ms) via `/_nodes/stats/jvm`.
* `GET 5.3 - Disk Allocation per Node`: Physical disk usage and percentage per node via `/_cat/allocation`.
* `GET 5.4 - Cluster Disk Watermark Settings`: Inspects cluster thresholds (`low: 85%`, `high: 90%`, `flood_stage: 95%`) via `/_cluster/settings`.
* `GET 5.5 - Check Read-Only Block on Indices`: Verifies whether any index is currently locked in read-only mode by flood-stage disk protection.

---

## 🚀 How to Import and Run in Postman

### Step 1: Open Port Forwarding Tunnel
Make sure your AWS SSM Session Manager tunnel is active on your machine:

```bash
# Connect through the Internal Load Balancer (recommended for cluster)
aws ssm start-session \
  --target <PRIMARY_INSTANCE_ID> \
  --document-name AWS-StartPortForwardingSessionToRemoteHost \
  --parameters '{"host":["<ILB_DNS_NAME>"],"portNumber":["9200"],"localPortNumber":["9200"]}'

# Or direct port forwarding to a single node:
aws ssm start-session \
  --target <PRIMARY_INSTANCE_ID> \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["9200"],"localPortNumber":["9200"]}'
```

### Step 2: Import into Postman
1. Open **Postman**.
2. Click **Import** (top left).
3. Drag & drop [Elasticsearch_API_Collection.json](file:///Users/dio.pratama/Projects/dio-github/aws-iac-lab/postman-collection/Elasticsearch_API_Collection.json) into Postman.

### Step 3: Configure Password & Variables
1. Select the imported **Elasticsearch 8 API Suite** collection in Postman.
2. Go to the **Variables** tab.
3. Set the `password` Current Value to your cluster password (e.g. `SuperSecureLabPass123!`).
4. Click **Save** (`Cmd+S` or `Ctrl+S`).

*All requests inherit Basic Auth automatically using `{{username}}` and `{{password}}` variables.*
