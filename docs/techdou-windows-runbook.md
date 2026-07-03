# TechDou Video Studio Windows Runbook

## Current Scope

This runbook is for the Windows PC version only. It does not modify the Tencent Cloud server.

## Install

From `E:\projects\generate_videos\MoneyPrinterTurbo`:

```powershell
uv sync --frozen
```

The verified local install used Python `3.11.7` and installed 125 packages.

## Start

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Start-TechDouVideoStudio.ps1
```

Default local URLs:

- WebUI: `http://127.0.0.1:8501`
- API docs: `http://127.0.0.1:18080/docs`
- Health check: `http://127.0.0.1:18080/ping` (returns `"pong"`)

The start script now performs a health check against `/ping` after launching the API, and warns (without aborting) if the API does not become healthy within 5 seconds.

Use `-NoBrowser` if you only want to start services:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Start-TechDouVideoStudio.ps1 -NoBrowser
```

Use `-Foreground` to run the API in the current console window with live log output (useful for debugging or teaching the pipeline):

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Start-TechDouVideoStudio.ps1 -Foreground
```

## Stop

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Stop-TechDouVideoStudio.ps1
```

## Configuration

Local runtime settings live in `config.toml`. This file is ignored by Git because it can contain API keys.

Important local defaults:

- `listen_host = "127.0.0.1"` keeps API local to this PC.
- `listen_port = 18080` avoids the occupied `8080` port on this machine.
- `project_name = "TechDou Video Studio"` controls FastAPI and WebUI branding.
- `subtitle_provider = "edge"` uses Edge TTS timing when possible.

## API Keys

Minimum useful keys for online generation:

- One language model provider key, such as OpenAI-compatible, Qwen, DeepSeek, MiniMax, or Ollama.
- One material source key, such as Pexels or Pixabay.

Offline or local-material workflows can use local clips from `storage/local_videos`, but script generation still needs a language model unless you paste the script manually.

## Logs

Runtime logs are written to `logs/`:

- `logs/techdou-api.out.log`
- `logs/techdou-api.err.log`
- `logs/techdou-webui.out.log`
- `logs/techdou-webui.err.log`

## Common Issues

Port occupied:

```powershell
Get-NetTCPConnection -LocalPort 8501,18080 -State Listen
```

API key missing:

- Open WebUI basic settings.
- Fill the selected language model provider key.
- Fill Pexels or Pixabay key if using online materials.

Video generation stuck on audio or subtitle:

- Check whether the selected voice matches the script language.
- Keep the proxy/VPN state consistent if Edge TTS or material download is slow.
- Try a shorter script first.

## Pipeline Resume (断点续跑)

Each pipeline stage (script / terms / audio / subtitle / materials / video) persists its artifacts to `storage/tasks/<task_id>/manifest.json` on success. This enables two workflows:

1. **Continue after a stop point**: run `start(task_id, params, stop_at="audio")` first, then later `start(task_id, params, stop_at="video", resume=True)` reuses the already-generated script/terms/audio without re-calling the LLM or TTS.
2. **Recover from failure**: if a run fails midway, re-run with `resume=True` to skip completed stages whose artifact files still exist.

Caveat: the TTS `sub_maker` object is in-memory and cannot be persisted. `resume=True` can fully reuse a `custom_audio_file`, but for the normal TTS path it regenerates audio (since the subtitle timeline can't be recovered). Script, terms, and materials are pure data/file artifacts and are always safe to reuse.

The `resume` parameter defaults to `False`, so existing WebUI / CLI behavior is unchanged.

## LLM Provider Registry (Agent / 调用方)

The LLM dispatch is now data-driven via `_PROVIDER_REGISTRY` in `app/services/llm.py`. Adding a new provider means adding one `ProviderConfig` entry instead of editing a 460-line if/elif chain. Each entry declares whether it needs an api_key / base_url, its defaults, and which `client_kind` handles the call.

For Agent / programmatic callers, `llm.generate_response_structured(prompt)` returns an `LLMResult(ok, text, error_code, error_message)` instead of a flat string. The `error_code` is one of `MISSING_API_KEY`, `MISSING_MODEL`, `MISSING_BASE_URL`, `PROVIDER_DISABLED`, `EMPTY_RESPONSE`, `PROVIDER_ERROR`, `UNKNOWN_PROVIDER`, letting callers decide between retry / fallback / prompting the user for config. The legacy `llm._generate_response(prompt)` still returns a string (`"Error: ..."` on failure) for backward compatibility.

The `/api/v1/scripts`, `/api/v1/terms`, and `/api/v1/social-metadata` endpoints are now `async` and offload the synchronous provider SDKs to a thread pool, so long LLM calls no longer consume FastAPI worker threads.

## Windows Software Packaging Direction

Recommended path:

1. Keep this repo as the backend and WebUI kernel.
2. Add a small Tauri or Electron shell that starts the local Python service.
3. Bundle Python runtime and `.venv` during packaging.
4. Put user config, logs, and generated videos under a stable app data directory.
5. Add an installer only after local launcher behavior is stable.
