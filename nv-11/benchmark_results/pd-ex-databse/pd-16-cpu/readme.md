
# 备注
这个实验 加上了 LMCACHE_LOCAL_CPU = True

```yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: vllm-cpu-h20
  namespace: pd-demo
  uid: 9c613991-8d86-458a-a138-1c9211251d80
  resourceVersion: '21060950'
  generation: 15
  creationTimestamp: '2025-11-28T07:22:49Z'
  annotations:
    deployment.kubernetes.io/revision: '5'
    kubectl.kubernetes.io/last-applied-configuration: >
      {"apiVersion":"apps/v1","kind":"Deployment","metadata":{"annotations":{},"name":"vllm-cpu-h20","namespace":"pd-demo"},"spec":{"replicas":1,"selector":{"matchLabels":{"app":"vllm-cpu","node":"h20"}},"template":{"metadata":{"labels":{"app":"vllm-cpu","node":"h20"}},"spec":{"containers":[{"args":["mkdir
      -p /tmp/lmcache_prometheus\nsource
      /opt/venv/bin/activate\n/opt/venv/bin/vllm serve
      /models/Qwen3-30B-A3B-Instruct-2507-FP8 \\\n  --served-model-name
      Qwen3-30B-A3B-Instruct-2507-FP8 \\\n  --trust-remote-code \\\n 
      --enable-expert-parallel \\\n  --tensor-parallel-size 1 \\\n 
      --no-enable-prefix-caching \\\n  --gpu-memory-utilization 0.9 \\\n 
      --max-model-len 100010 \\\n  --max-num-seqs 128 \\\n 
      --disable-log-requests \\\n  --kv_cache_dtype fp8 \\\n  --port 8000 \\\n 
      --kv-transfer-config
      '{\"kv_connector\":\"LMCacheConnectorV1\",\"kv_role\":\"kv_both\"}'\n"],"command":["/bin/bash","-c"],"env":[{"name":"VLLM_HOST_IP","valueFrom":{"fieldRef":{"apiVersion":"v1","fieldPath":"status.podIP"}}},{"name":"PYTHONHASHSEED","value":"0"},{"name":"LMCACHE_USE_EXPERIMENTAL","value":"True"},{"name":"LMCACHE_CHUNK_SIZE","value":"512"},{"name":"LMCACHE_MAX_LOCAL_CPU_SIZE","value":"48"},{"name":"LMCACHE_LOG_LEVEL","value":"DEBUG"},{"name":"VLLM_LOGGING_LEVEL","value":"DEBUG"},{"name":"PROMETHEUS_MULTIPROC_DIR","value":"/tmp/lmcache_prometheus"}],"image":"docker.hlmirror.com/lmcache/vllm-openai:v0.3.9post2-pd-weka","imagePullPolicy":"IfNotPresent","name":"vllm-cpu","ports":[{"containerPort":8000,"name":"http-vllm","protocol":"TCP"}],"resources":{"limits":{"nvidia.com/gpu":"1"},"requests":{"nvidia.com/gpu":"1"}},"volumeMounts":[{"mountPath":"/models","name":"models"},{"mountPath":"/run/udev","name":"udev"},{"mountPath":"/daocloud","name":"daocloud"},{"mountPath":"/benchmark_results","name":"benchmark-results"}]}],"nodeSelector":{"kubernetes.io/hostname":"h20"},"volumes":[{"hostPath":{"path":"/data","type":""},"name":"models"},{"hostPath":{"path":"/run/udev","type":""},"name":"udev"},{"hostPath":{"path":"/root/daocloud","type":""},"name":"daocloud"},{"hostPath":{"path":"/root/daocloud/benchmark_results","type":""},"name":"benchmark-results"}]}}}}
    workload.kpanda.io/last-replicas: '8'
spec:
  replicas: 0
  selector:
    matchLabels:
      app: vllm-cpu
      node: h20
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: vllm-cpu
        node: h20
    spec:
      volumes:
        - name: models
          hostPath:
            path: /data
            type: ''
        - name: udev
          hostPath:
            path: /run/udev
            type: ''
        - name: daocloud
          hostPath:
            path: /root/daocloud
            type: ''
        - name: benchmark-results
          hostPath:
            path: /root/daocloud/benchmark_results
            type: ''
      containers:
        - name: vllm-cpu
          image: docker.hlmirror.com/lmcache/vllm-openai:v0.3.9post2-pd-weka
          command:
            - /bin/bash
            - '-c'
          args:
            - |
              mkdir -p /tmp/lmcache_prometheus
              source /opt/venv/bin/activate
              /opt/venv/bin/vllm serve /models/Qwen3-30B-A3B-Instruct-2507-FP8 \
                --served-model-name Qwen3-30B-A3B-Instruct-2507-FP8 \
                --trust-remote-code \
                --enable-expert-parallel \
                --tensor-parallel-size 1 \
                --no-enable-prefix-caching \
                --gpu-memory-utilization 0.9 \
                --max-model-len 100010 \
                --max-num-seqs 128 \
                --disable-log-requests \
                --kv_cache_dtype fp8 \
                --port 8000 \
                --kv-transfer-config '{"kv_connector":"LMCacheConnectorV1","kv_role":"kv_both"}'
          ports:
            - name: http-vllm
              containerPort: 8000
              protocol: TCP
          env:
            - name: VLLM_HOST_IP
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: status.podIP
            - name: PYTHONHASHSEED
              value: '0'
            - name: LMCACHE_USE_EXPERIMENTAL
              value: 'True'
            - name: LMCACHE_CHUNK_SIZE
              value: '512'
            - name: LMCACHE_LOCAL_CPU
              value: 'True'
            - name: LMCACHE_MAX_LOCAL_CPU_SIZE
              value: '48'
            - name: LMCACHE_LOG_LEVEL
              value: DEBUG
            - name: VLLM_LOGGING_LEVEL
              value: DEBUG
            - name: PROMETHEUS_MULTIPROC_DIR
              value: /tmp/lmcache_prometheus
          resources:
            limits:
              nvidia.com/gpu: '1'
            requests:
              nvidia.com/gpu: '1'
          volumeMounts:
            - name: models
              mountPath: /models
            - name: udev
              mountPath: /run/udev
            - name: daocloud
              mountPath: /daocloud
            - name: benchmark-results
              mountPath: /benchmark_results
          startupProbe:
            httpGet:
              path: /health
              port: 8000
              scheme: HTTP
            timeoutSeconds: 1
            periodSeconds: 10
            successThreshold: 1
            failureThreshold: 60
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: IfNotPresent
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
      dnsPolicy: ClusterFirst
      nodeSelector:
        kubernetes.io/hostname: h20
      securityContext: {}
      schedulerName: default-scheduler
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%
      maxSurge: 25%
  revisionHistoryLimit: 10
  progressDeadlineSeconds: 600
status:
  observedGeneration: 15
  conditions:
    - type: Progressing
      status: 'True'
      lastUpdateTime: '2025-12-01T05:38:39Z'
      lastTransitionTime: '2025-11-28T07:22:49Z'
      reason: NewReplicaSetAvailable
      message: ReplicaSet "vllm-cpu-h20-95d6b696f" has successfully progressed.
    - type: Available
      status: 'True'
      lastUpdateTime: '2025-12-01T06:00:43Z'
      lastTransitionTime: '2025-12-01T06:00:43Z'
      reason: MinimumReplicasAvailable
      message: Deployment has minimum availability.
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: vllm-cpu-r6kd
  namespace: pd-demo
  uid: 32c3dc77-8153-404a-9437-e40370cf9eb7
  resourceVersion: '21061059'
  generation: 15
  creationTimestamp: '2025-11-28T07:22:49Z'
  annotations:
    deployment.kubernetes.io/revision: '6'
    kubectl.kubernetes.io/last-applied-configuration: >
      {"apiVersion":"apps/v1","kind":"Deployment","metadata":{"annotations":{},"name":"vllm-cpu-r6kd","namespace":"pd-demo"},"spec":{"replicas":1,"selector":{"matchLabels":{"app":"vllm-cpu","node":"r6kd-node-1"}},"template":{"metadata":{"labels":{"app":"vllm-cpu","node":"r6kd-node-1"}},"spec":{"containers":[{"args":["mkdir
      -p /tmp/lmcache_prometheus\nsource
      /opt/venv/bin/activate\n/opt/venv/bin/vllm serve
      /models/Qwen3-30B-A3B-Instruct-2507-FP8 \\\n  --served-model-name
      Qwen3-30B-A3B-Instruct-2507-FP8 \\\n  --trust-remote-code \\\n 
      --enable-expert-parallel \\\n  --tensor-parallel-size 1 \\\n 
      --no-enable-prefix-caching \\\n  --gpu-memory-utilization 0.85 \\\n 
      --max-model-len 100010 \\\n  --max-num-seqs 128 \\\n 
      --disable-log-requests \\\n  --kv_cache_dtype fp8 \\\n  --port 8000 \\\n 
      --kv-transfer-config
      '{\"kv_connector\":\"LMCacheConnectorV1\",\"kv_role\":\"kv_both\"}'\n"],"command":["/bin/bash","-c"],"env":[{"name":"VLLM_HOST_IP","valueFrom":{"fieldRef":{"apiVersion":"v1","fieldPath":"status.podIP"}}},{"name":"PYTHONHASHSEED","value":"0"},{"name":"LMCACHE_USE_EXPERIMENTAL","value":"True"},{"name":"LMCACHE_CHUNK_SIZE","value":"512"},{"name":"LMCACHE_MAX_LOCAL_CPU_SIZE","value":"48"},{"name":"LMCACHE_LOG_LEVEL","value":"DEBUG"},{"name":"VLLM_LOGGING_LEVEL","value":"DEBUG"},{"name":"PROMETHEUS_MULTIPROC_DIR","value":"/tmp/lmcache_prometheus"}],"image":"docker.hlmirror.com/lmcache/vllm-openai:v0.3.9post2-pd-weka","imagePullPolicy":"IfNotPresent","name":"vllm-cpu","ports":[{"containerPort":8000,"name":"http-vllm","protocol":"TCP"}],"resources":{"limits":{"nvidia.com/gpu":"1"},"requests":{"nvidia.com/gpu":"1"}},"volumeMounts":[{"mountPath":"/models","name":"models"},{"mountPath":"/run/udev","name":"udev"},{"mountPath":"/daocloud","name":"daocloud"},{"mountPath":"/benchmark_results","name":"benchmark-results"}]}],"nodeSelector":{"kubernetes.io/hostname":"r6kd-node-1"},"volumes":[{"hostPath":{"path":"/data","type":""},"name":"models"},{"hostPath":{"path":"/run/udev","type":""},"name":"udev"},{"hostPath":{"path":"/root/daocloud","type":""},"name":"daocloud"},{"hostPath":{"path":"/root/daocloud/benchmark_results","type":""},"name":"benchmark-results"}]}}}}
    workload.kpanda.io/last-replicas: '8'
spec:
  replicas: 0
  selector:
    matchLabels:
      app: vllm-cpu
      node: r6kd-node-1
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: vllm-cpu
        node: r6kd-node-1
    spec:
      volumes:
        - name: models
          hostPath:
            path: /data
            type: ''
        - name: udev
          hostPath:
            path: /run/udev
            type: ''
        - name: daocloud
          hostPath:
            path: /root/daocloud
            type: ''
        - name: benchmark-results
          hostPath:
            path: /root/daocloud/benchmark_results
            type: ''
      containers:
        - name: vllm-cpu
          image: docker.1ms.run/lmcache/vllm-openai:nightly-2025-11-26-pd-weka
          command:
            - /bin/bash
            - '-c'
          args:
            - |
              mkdir -p /tmp/lmcache_prometheus
              source /opt/venv/bin/activate
              /opt/venv/bin/vllm serve /models/Qwen3-30B-A3B-Instruct-2507-FP8 \
                --served-model-name Qwen3-30B-A3B-Instruct-2507-FP8 \
                --trust-remote-code \
                --enable-expert-parallel \
                --tensor-parallel-size 1 \
                --no-enable-prefix-caching \
                --gpu-memory-utilization 0.85 \
                --max-model-len 100010 \
                --max-num-seqs 128 \
                --disable-log-requests \
                --kv_cache_dtype fp8 \
                --port 8000 \
                --kv-transfer-config '{"kv_connector":"LMCacheConnectorV1","kv_role":"kv_both"}'
          ports:
            - name: http-vllm
              containerPort: 8000
              protocol: TCP
          env:
            - name: VLLM_HOST_IP
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: status.podIP
            - name: PYTHONHASHSEED
              value: '0'
            - name: LMCACHE_USE_EXPERIMENTAL
              value: 'True'
            - name: LMCACHE_CHUNK_SIZE
              value: '512'
            - name: LMCACHE_LOCAL_CPU
              value: 'True'
            - name: LMCACHE_MAX_LOCAL_CPU_SIZE
              value: '48'
            - name: LMCACHE_LOG_LEVEL
              value: DEBUG
            - name: VLLM_LOGGING_LEVEL
              value: DEBUG
            - name: PROMETHEUS_MULTIPROC_DIR
              value: /tmp/lmcache_prometheus
          resources:
            limits:
              nvidia.com/gpu: '1'
            requests:
              nvidia.com/gpu: '1'
          volumeMounts:
            - name: models
              mountPath: /models
            - name: udev
              mountPath: /run/udev
            - name: daocloud
              mountPath: /daocloud
            - name: benchmark-results
              mountPath: /benchmark_results
          startupProbe:
            httpGet:
              path: /health
              port: 8000
              scheme: HTTP
            timeoutSeconds: 1
            periodSeconds: 10
            successThreshold: 1
            failureThreshold: 60
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: IfNotPresent
      restartPolicy: Always
      terminationGracePeriodSeconds: 30
      dnsPolicy: ClusterFirst
      nodeSelector:
        kubernetes.io/hostname: r6kd-node-1
      securityContext: {}
      schedulerName: default-scheduler
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 25%
      maxSurge: 25%
  revisionHistoryLimit: 10
  progressDeadlineSeconds: 600
status:
  observedGeneration: 15
  conditions:
    - type: Progressing
      status: 'True'
      lastUpdateTime: '2025-12-01T05:38:59Z'
      lastTransitionTime: '2025-11-28T07:22:49Z'
      reason: NewReplicaSetAvailable
      message: ReplicaSet "vllm-cpu-r6kd-867996786b" has successfully progressed.
    - type: Available
      status: 'True'
      lastUpdateTime: '2025-12-01T06:00:48Z'
      lastTransitionTime: '2025-12-01T06:00:48Z'
      reason: MinimumReplicasAvailable
      message: Deployment has minimum availability.
```
