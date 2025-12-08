# 备注

这实验架构：
- 8p8d
  - prefill 节点是 h20
  - decode 节点是 r6kd

```yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: vllm-decode
  namespace: pd-demo
  uid: 8a98c009-de0b-4719-95be-d31dca6990ab
  resourceVersion: '20137828'
  generation: 142
  creationTimestamp: '2025-11-26T09:46:12Z'
  annotations:
    deployment.kubernetes.io/revision: '68'
    kubectl.kubernetes.io/last-applied-configuration: >
      {"apiVersion":"apps/v1","kind":"Deployment","metadata":{"annotations":{},"name":"vllm-decode","namespace":"pd-demo"},"spec":{"replicas":2,"selector":{"matchLabels":{"app":"vllm-decode"}},"template":{"metadata":{"labels":{"app":"vllm-decode"}},"spec":{"containers":[{"args":["source
      /opt/venv/bin/activate\n/opt/venv/bin/vllm serve
      /models/Qwen3-30B-A3B-Instruct-2507-FP8 \\\n  --served-model-name
      Qwen3-30B-A3B-Instruct-2507-FP8 \\\n  --trust-remote-code \\\n 
      --enable-expert-parallel \\\n  --tensor-parallel-size 1 \\\n 
      --no-enable-prefix-caching \\\n  --gpu-memory-utilization 0.85 \\\n 
      --max-model-len 100000 \\\n  --max-num-seqs 128 \\\n 
      --disable-log-requests \\\n  --port 8002 \\\n  --kv-transfer-config
      '{\"kv_connector\":\"LMCacheConnectorV1\",\"kv_role\":\"kv_both\"}'\n"],"command":["/bin/bash","-c"],"env":[{"name":"VLLM_HOST_IP","valueFrom":{"fieldRef":{"fieldPath":"status.podIP"}}},{"name":"LMCACHE_USE_EXPERIMENTAL","value":"True"},{"name":"LMCACHE_CHUNK_SIZE","value":"512"},{"name":"LMCACHE_MAX_LOCAL_CPU_SIZE","value":"48"},{"name":"LMCACHE_LOCAL_CPU","value":"False"},{"name":"LMCACHE_LOG_LEVEL","value":"DEBUG"},{"name":"VLLM_LOGGING_LEVEL","value":"DEBUG"},{"name":"PYTHONHASHSEED","value":"0"},{"name":"LMCACHE_GDS_PATH","value":"/mnt/400gb/cache/deepseek-r1/"},{"name":"LMCACHE_EXTRA_CONFIG","value":"{\"use_direct_io\":true,\"save_only_first_rank\":false,\"gds_retry_to_read\":true}"},{"name":"LMCACHE_CUFILE_BUFFER_SIZE","value":"8192"},{"name":"PYTORCH_CUDA_ALLOC_CONF","value":"expandable_segments:True"},{"name":"PROMETHEUS_MULTIPROC_DIR","value":"/tmp/lmcache_prometheus"}],"image":"docker.1ms.run/lmcache/vllm-openai:nightly-2025-11-26-pd-weka","name":"vllm-decode","ports":[{"containerPort":8002,"name":"http"}],"resources":{"limits":{"nvidia.com/gpu":1},"requests":{"nvidia.com/gpu":1}},"securityContext":{},"volumeMounts":[{"mountPath":"/models","name":"models"},{"mountPath":"/mnt/400gb","name":"pd-gds"},{"mountPath":"/run/udev","name":"udev"},{"mountPath":"/daocloud","name":"daocloud"},{"mountPath":"/benchmark_results","name":"benchmark-results"}]}],"nodeSelector":{"kubernetes.io/hostname":"r6kd-node-1"},"volumes":[{"hostPath":{"path":"/data"},"name":"models"},{"hostPath":{"path":"/mnt/supercloud/pd-gds"},"name":"pd-gds"},{"hostPath":{"path":"/run/udev"},"name":"udev"},{"hostPath":{"path":"/root/daocloud"},"name":"daocloud"},{"hostPath":{"path":"/root/daocloud/benchmark_results"},"name":"benchmark-results"}]}}}}
    workload.kpanda.io/last-replicas: '1'
spec:
  replicas: 0
  selector:
    matchLabels:
      app: vllm-decode
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: vllm-decode
      annotations:
        workload.kpanda.io/last-restart-timestamp: '1764471305'
    spec:
      volumes:
        - name: models
          hostPath:
            path: /data
            type: ''
        - name: pd-gds
          hostPath:
            path: /mnt/supercloud/pd-gds
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
        - name: vllm-decode
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
                --tensor-parallel-size 2 \
                --no-enable-prefix-caching \
                --gpu-memory-utilization 0.85 \
                --max-model-len 60000 \
                --max-num-seqs 32 \
                --disable-log-requests \
                --kv_cache_dtype fp8 \
                --port 8002 \
                --kv-transfer-config '{"kv_connector":"LMCacheConnectorV1","kv_role":"kv_both"}'
          ports:
            - name: http-vllm
              containerPort: 8002
              protocol: TCP
          env:
            - name: VLLM_HOST_IP
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: status.podIP
            - name: TORCH_CUDA_ARCH_LIST
              value: '12.0'
            - name: LMCACHE_USE_EXPERIMENTAL
              value: 'True'
            - name: LMCACHE_CHUNK_SIZE
              value: '512'
            - name: LMCACHE_MAX_LOCAL_CPU_SIZE
              value: '48'
            - name: LMCACHE_LOCAL_CPU
              value: 'False'
            - name: LMCACHE_LOG_LEVEL
              value: DEBUG
            - name: VLLM_LOGGING_LEVEL
              value: DEBUG
            - name: PYTHONHASHSEED
              value: '0'
            - name: LMCACHE_GDS_PATH
              value: /mnt/400gb/cache/deepseek-r1/
            - name: LMCACHE_EXTRA_CONFIG
              value: >-
                {"use_direct_io":true,"save_only_first_rank":false,"gds_retry_to_read":false}
            - name: LMCACHE_CUFILE_BUFFER_SIZE
              value: '8192'
            - name: PYTORCH_CUDA_ALLOC_CONF
              value: expandable_segments:True
            - name: PROMETHEUS_MULTIPROC_DIR
              value: /tmp/lmcache_prometheus
          resources:
            limits:
              nvidia.com/gpu: '2'
            requests:
              nvidia.com/gpu: '2'
          volumeMounts:
            - name: models
              mountPath: /models
            - name: pd-gds
              mountPath: /mnt/400gb
            - name: udev
              mountPath: /run/udev
            - name: daocloud
              mountPath: /daocloud
            - name: benchmark-results
              mountPath: /benchmark_results
          startupProbe:
            httpGet:
              path: /health
              port: 8002
              scheme: HTTP
            timeoutSeconds: 1
            periodSeconds: 10
            successThreshold: 1
            failureThreshold: 60
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: IfNotPresent
          securityContext: {}
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
  observedGeneration: 142
  conditions:
    - type: Available
      status: 'True'
      lastUpdateTime: '2025-11-30T11:13:41Z'
      lastTransitionTime: '2025-11-30T11:13:41Z'
      reason: MinimumReplicasAvailable
      message: Deployment has minimum availability.
    - type: Progressing
      status: 'True'
      lastUpdateTime: '2025-11-30T11:13:41Z'
      lastTransitionTime: '2025-11-26T09:46:12Z'
      reason: NewReplicaSetAvailable
      message: ReplicaSet "vllm-decode-6bb6b7fd95" has successfully progressed.
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: vllm-prefill
  namespace: pd-demo
  uid: abd11a0c-e79d-4785-8eaa-f226943c9980
  resourceVersion: '20137898'
  generation: 107
  creationTimestamp: '2025-11-26T09:46:11Z'
  annotations:
    deployment.kubernetes.io/revision: '45'
    kubectl.kubernetes.io/last-applied-configuration: >
      {"apiVersion":"apps/v1","kind":"Deployment","metadata":{"annotations":{},"name":"vllm-prefill","namespace":"pd-demo"},"spec":{"replicas":2,"selector":{"matchLabels":{"app":"vllm-prefill"}},"template":{"metadata":{"labels":{"app":"vllm-prefill"}},"spec":{"containers":[{"args":["source
      /opt/venv/bin/activate\n/opt/venv/bin/vllm serve
      /models/Qwen3-30B-A3B-Instruct-2507-FP8 \\\n  --served-model-name
      Qwen3-30B-A3B-Instruct-2507-FP8 \\\n  --trust-remote-code \\\n 
      --enable-expert-parallel \\\n  --tensor-parallel-size 1 \\\n 
      --no-enable-prefix-caching \\\n  --gpu-memory-utilization 0.85 \\\n 
      --max-model-len 100000 \\\n  --disable-log-requests \\\n  --port 8001
      \\\n  --kv-transfer-config
      '{\"kv_connector\":\"LMCacheConnectorV1\",\"kv_role\":\"kv_both\"}'\n"],"command":["/bin/bash","-c"],"env":[{"name":"VLLM_HOST_IP","valueFrom":{"fieldRef":{"fieldPath":"status.podIP"}}},{"name":"LMCACHE_USE_EXPERIMENTAL","value":"True"},{"name":"LMCACHE_CHUNK_SIZE","value":"512"},{"name":"LMCACHE_MAX_LOCAL_CPU_SIZE","value":"48"},{"name":"LMCACHE_LOCAL_CPU","value":"False"},{"name":"LMCACHE_LOG_LEVEL","value":"DEBUG"},{"name":"VLLM_LOGGING_LEVEL","value":"DEBUG"},{"name":"PYTHONHASHSEED","value":"0"},{"name":"LMCACHE_GDS_PATH","value":"/mnt/400gb/cache/deepseek-r1/"},{"name":"LMCACHE_EXTRA_CONFIG","value":"{\"use_direct_io\":true,\"save_only_first_rank\":false}"},{"name":"LMCACHE_CUFILE_BUFFER_SIZE","value":"8192"},{"name":"PYTORCH_CUDA_ALLOC_CONF","value":"expandable_segments:True"},{"name":"PROMETHEUS_MULTIPROC_DIR","value":"/tmp/lmcache_prometheus"}],"image":"docker.hlmirror.com/lmcache/vllm-openai:v0.3.9post2-pd-weka","name":"vllm-prefill","ports":[{"containerPort":8001,"name":"http"}],"resources":{"limits":{"nvidia.com/gpu":1},"requests":{"nvidia.com/gpu":1}},"securityContext":{},"volumeMounts":[{"mountPath":"/models","name":"models"},{"mountPath":"/mnt/400gb","name":"pd-gds"},{"mountPath":"/run/udev","name":"udev"},{"mountPath":"/daocloud","name":"daocloud"},{"mountPath":"/benchmark_results","name":"benchmark-results"}]}],"nodeSelector":{"kubernetes.io/hostname":"h20"},"volumes":[{"hostPath":{"path":"/data"},"name":"models"},{"hostPath":{"path":"/mnt/supercloud/pd-gds"},"name":"pd-gds"},{"hostPath":{"path":"/run/udev"},"name":"udev"},{"hostPath":{"path":"/root/daocloud"},"name":"daocloud"},{"hostPath":{"path":"/root/daocloud/benchmark_results"},"name":"benchmark-results"}]}}}}
    workload.kpanda.io/last-replicas: '1'
spec:
  replicas: 0
  selector:
    matchLabels:
      app: vllm-prefill
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: vllm-prefill
      annotations:
        workload.kpanda.io/last-restart-timestamp: '1764317513'
    spec:
      volumes:
        - name: models
          hostPath:
            path: /data
            type: ''
        - name: pd-gds
          hostPath:
            path: /mnt/supercloud/pd-gds
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
        - name: vllm-prefill
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
                --max-model-len 80000 \
                --max-num-seqs 64 \
                --disable-log-requests \
                --kv_cache_dtype fp8 \
                --port 8001 \
                --kv-transfer-config '{"kv_connector":"LMCacheConnectorV1","kv_role":"kv_both"}'
          ports:
            - name: http-vllm
              containerPort: 8001
              protocol: TCP
          env:
            - name: VLLM_HOST_IP
              valueFrom:
                fieldRef:
                  apiVersion: v1
                  fieldPath: status.podIP
            - name: LMCACHE_USE_EXPERIMENTAL
              value: 'True'
            - name: LMCACHE_CHUNK_SIZE
              value: '512'
            - name: LMCACHE_MAX_LOCAL_CPU_SIZE
              value: '48'
            - name: LMCACHE_LOCAL_CPU
              value: 'False'
            - name: LMCACHE_LOG_LEVEL
              value: DEBUG
            - name: VLLM_LOGGING_LEVEL
              value: DEBUG
            - name: PYTHONHASHSEED
              value: '0'
            - name: LMCACHE_GDS_PATH
              value: /mnt/400gb/cache/deepseek-r1/
            - name: LMCACHE_EXTRA_CONFIG
              value: '{"use_direct_io":true,"save_only_first_rank":false}'
            - name: LMCACHE_CUFILE_BUFFER_SIZE
              value: '8192'
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
            - name: pd-gds
              mountPath: /mnt/400gb
            - name: udev
              mountPath: /run/udev
            - name: daocloud
              mountPath: /daocloud
            - name: benchmark-results
              mountPath: /benchmark_results
          startupProbe:
            httpGet:
              path: /health
              port: 8001
              scheme: HTTP
            timeoutSeconds: 1
            periodSeconds: 10
            successThreshold: 1
            failureThreshold: 60
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          imagePullPolicy: IfNotPresent
          securityContext: {}
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
  observedGeneration: 107
  conditions:
    - type: Progressing
      status: 'True'
      lastUpdateTime: '2025-11-30T03:35:15Z'
      lastTransitionTime: '2025-11-26T09:46:11Z'
      reason: NewReplicaSetAvailable
      message: ReplicaSet "vllm-prefill-5c77655f98" has successfully progressed.
    - type: Available
      status: 'True'
      lastUpdateTime: '2025-11-30T10:10:03Z'
      lastTransitionTime: '2025-11-30T10:10:03Z'
      reason: MinimumReplicasAvailable
      message: Deployment has minimum availability.
```
