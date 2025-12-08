# path image

```bash
# h20
nerdctl run --entrypoint /bin/bash --network host --shm-size 32g --gpus all -it --name vllm-server-deepseek \
-e VLLM_HOST_IP=10.20.10.2 -v /data:/models \
-v /mnt/supercloud/gds-400gb:/mnt/400gb \
-v /run/udev:/run/udev \
-v /800Gb:/mnt/800gb -v /root/daocloud:/daocloud \
-v /root/daocloud/benchmark_results:/benchmark_results docker.hlmirror.com/lmcache/vllm-openai:v0.3.9post2


# r6kd
nerdctl run --entrypoint /bin/bash --network host --shm-size 32g --gpus all -it --name vllm-server-deepseek \
-e VLLM_HOST_IP=10.20.10.2 -v /data:/models \
-v /mnt/supercloud/gds-400gb:/mnt/400gb \
-v /run/udev:/run/udev \
-v /800Gb:/mnt/800gb -v /root/daocloud:/daocloud \
-v /root/daocloud/benchmark_results:/benchmark_results docker.1ms.run/lmcache/vllm-openai:nightly-2025-11-26


source /opt/venv/bin/activate

python -c "import site; print(site.getsitepackages())"
# ['/opt/venv/lib/python3.12/site-packages', '/opt/venv/local/lib/python3.12/dist-packages', '/opt/venv/lib/python3/dist-packages', '/opt/venv/lib/python3.12/dist-packages']

vi /opt/venv/lib/python3.12/site-packages/lmcache/v1/storage_backend/gds_backend.py

# check gds_retry_to_read & gds_retry_timeout
cat /opt/venv/lib/python3.12/site-packages/lmcache/v1/storage_backend/gds_backend.py | grep gds_retry


vi /opt/venv/lib/python3.12/site-packages/lmcache/v1/storage_backend/weka_gds_backend.py
# check
cat  /opt/venv/lib/python3.12/site-packages/lmcache/v1/storage_backend/weka_gds_backend.py | grep use_direct


nerdctl ps | grep vllm

nerdctl commit 134ad104c62d docker.hlmirror.com/lmcache/vllm-openai:v0.3.9post2-pd-weka
nerdctl commit edddd9b12ed8 docker.hlmirror.com/lmcache/vllm-openai:v0.3.9post2-pd-weka

nerdctl commit 4c35b483432e docker.1ms.run/lmcache/vllm-openai:nightly-2025-11-26-pd-weka
```
