***REMOVED*** DRAG — local RAG for RPG PDFs

4-component stack deployed to namespace `drag`. Argo CD picks it up via `div/applicationset.yaml`.

| Component | Workload | Image |
|-----------|----------|-------|
| Qdrant (vectors) | StatefulSet | `docker.io/qdrant/qdrant:v1.19.0` |
| Embedding server | Deployment (gguf baked into the image) | `ghcr.io/example/drag-llama-embed:latest` |
| drag-app (FastAPI pipeline + OpenAI adapter) | Deployment | `ghcr.io/example/drag-app:latest` |
| Open WebUI (frontend) | StatefulSet | `ghcr.io/open-webui/open-webui:v0.11.0` |

Exposed at **https://drag.example.com** (HTTPRoute → `drag-webui`).

***REMOVED******REMOVED*** Prerequisites before sync

1. **Push the two app images** to GHCR (the cluster pulls from there):
   ```
   podman tag drag-app:latest ghcr.io/example/drag-app:latest && podman push ghcr.io/example/drag-app:latest
   podman tag drag-llama-embed:latest ghcr.io/example/drag-llama-embed:latest && podman push ghcr.io/example/drag-llama-embed:latest
   ```
2. **External LLM box** must be reachable from the cluster: `http://9800x3d.lan.example.com:9931` (set in `drag-app-config`).
3. **First boot is slow**: `drag-app` downloads docling + bge-reranker models (~4GB) into the `drag-hf-cache` PVC on first ingest/query; persists, so subsequent boots are fast. If the cluster has no HF egress, pre-populate the PVC. (The embed gguf is baked into its image, so no first-boot fetch.)

***REMOVED******REMOVED*** Notes / tradeoffs

- `drag-app` runs as non-root (uid 1001; fsGroup 1001). HF models go to the `drag-hf-cache` PVC (`HF_HOME=/data/hf-cache`); parse/embed caches under `/app` are chowned to 1001 in the image.
- Book ingestion is out-of-band via `POST /ingest` (docling), not through Open WebUI upload.
