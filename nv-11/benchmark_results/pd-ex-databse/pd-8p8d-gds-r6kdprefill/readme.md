# 备注

这实验架构：
- 8p8d
  - prefill 节点是 r6kd
  - decode 节点是 h20

```yaml
kind: Deployment
apiVersion: apps/v1
metadata:
  name: vllm-decode-h20
  namespace: pd-demo
  uid: b2333262-29ba-4fcf-84be-35c606ecdd52
  resourceVersion: '20859175'
  generation: 11
  creationTimestamp: '2025-12-01T01:41:51Z'
  annotations:
    deployment.kubernetes.io/revision: '3'
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
            - name: LMCACHE_GDS_PATH
              value: /mnt/400gb/cache/deepseek-r1/
            - name: LMCACHE_EXTRA_CONFIG
              value: >-
                {"use_direct_io":true,"save_only_first_rank":false,"gds_retry_to_read":true}
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
  observedGeneration: 11
  conditions:
    - type: Progressing
      status: 'True'
      lastUpdateTime: '2025-12-01T02:13:47Z'
      lastTransitionTime: '2025-12-01T01:41:51Z'
      reason: NewReplicaSetAvailable
      message: ReplicaSet "vllm-decode-h20-55956d887d" has successfully progressed.
    - type: Available
      status: 'True'
      lastUpdateTime: '2025-12-01T02:49:00Z'
      lastTransitionTime: '2025-12-01T02:49:00Z'
      reason: MinimumReplicasAvailable
      message: Deployment has minimum availability.
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: vllm-prefill-r6kd
  namespace: pd-demo
  uid: edc24619-dcef-4dc1-bcc6-0cc1e310d3da
  resourceVersion: '20859062'
  generation: 7
  creationTimestamp: '2025-12-01T01:57:09Z'
  annotations:
    deployment.kubernetes.io/revision: '2'
    workload.kpanda.io/last-replicas: '8'
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
            - name: LMCACHE_GDS_PATH
              value: /mnt/400gb/cache/deepseek-r1/
            - name: LMCACHE_EXTRA_CONFIG
              value: >-
                {"use_direct_io":true,"save_only_first_rank":false,"gds_retry_to_read":false}
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
  observedGeneration: 7
  conditions:
    - type: Progressing
      status: 'True'
      lastUpdateTime: '2025-12-01T02:49:22Z'
      lastTransitionTime: '2025-12-01T01:57:09Z'
      reason: NewReplicaSetAvailable
      message: ReplicaSet "vllm-prefill-r6kd-b76d8c4d" has successfully progressed.
    - type: Available
      status: 'True'
      lastUpdateTime: '2025-12-01T02:57:27Z'
      lastTransitionTime: '2025-12-01T02:57:27Z'
      reason: MinimumReplicasAvailable
      message: Deployment has minimum availability.
```
