# 备注

这实验架构：
- 8p8d
  - prefill 节点是 r6kd
  - decode 节点是 h20

该实验开启了 weka

```yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: vllm-decode-h20-weka
  namespace: pd-demo
  uid: 74a04fdc-7bf9-4564-a6ca-2d1749b6c862
  resourceVersion: '20965542'
  generation: 8
  creationTimestamp: '2025-12-01T02:48:54Z'
  annotations:
    deployment.kubernetes.io/revision: '2'
    workload.kpanda.io/last-replicas: '8'
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
        workload.kpanda.io/last-restart-timestamp: '1764564524'
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
            - name: LMCACHE_WEKA_PATH
              value: /mnt/400gb/cache/deepseek-r1/
            - name: LMCACHE_SAVE_DECODE_CACHE
              value: 'True'
            - name: LMCACHE_EXTRA_CONFIG
              value: >-
                {"use_direct_io":true,"save_only_first_rank":false,"gds_retry_to_read":true,"gds_io_threads":8}
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
  observedGeneration: 8
  conditions:
    - type: Available
      status: 'True'
      lastUpdateTime: '2025-12-01T04:14:18Z'
      lastTransitionTime: '2025-12-01T04:14:18Z'
      reason: MinimumReplicasAvailable
      message: Deployment has minimum availability.
    - type: Progressing
      status: 'True'
      lastUpdateTime: '2025-12-01T05:04:23Z'
      lastTransitionTime: '2025-12-01T02:48:54Z'
      reason: NewReplicaSetAvailable
      message: >-
        ReplicaSet "vllm-decode-h20-weka-54cfd6fbb4" has successfully
        progressed.
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: vllm-prefill-r6kd-weka
  namespace: pd-demo
  uid: a7bbd3c7-45d3-493c-80ec-21ff2cb24a0e
  resourceVersion: '20965627'
  generation: 9
  creationTimestamp: '2025-12-01T02:47:16Z'
  annotations:
    deployment.kubernetes.io/revision: '2'
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
        workload.kpanda.io/last-restart-timestamp: '1764564275'
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
                --max-model-len 60000 \
                --max-num-seqs 32 \
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
            - name: LMCACHE_WEKA_PATH
              value: /mnt/400gb/cache/deepseek-r1/
            - name: LMCACHE_SAVE_DECODE_CACHE
              value: 'True'
            - name: LMCACHE_EXTRA_CONFIG
              value: >-
                {"use_direct_io":true,"save_only_first_rank":false,"gds_retry_to_read":false,"gds_io_threads":8}
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
  observedGeneration: 9
  conditions:
    - type: Available
      status: 'True'
      lastUpdateTime: '2025-12-01T04:14:43Z'
      lastTransitionTime: '2025-12-01T04:14:43Z'
      reason: MinimumReplicasAvailable
      message: Deployment has minimum availability.
    - type: Progressing
      status: 'True'
      lastUpdateTime: '2025-12-01T04:48:25Z'
      lastTransitionTime: '2025-12-01T02:47:16Z'
      reason: NewReplicaSetAvailable
      message: >-
        ReplicaSet "vllm-prefill-r6kd-weka-76df7f46c9" has successfully
        progressed.
```
