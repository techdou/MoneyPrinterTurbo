# TechDou Video Studio Product Plan

## One Sentence

TechDou Video Studio is a Windows-first short-video production workbench for 豆哥: it turns an inquiry-style idea discussion into script, voice, subtitles, footage, and exportable short videos.

## Why This Product

MoneyPrinterTurbo already has the useful engine: script generation, keyword generation, text-to-speech, subtitles, material download or local material upload, video composition, and task APIs. The gap is product shape.

The target product should not feel like a random "AI generate" page. It should feel like a local production desk:

- Ask better questions before generating.
- Keep every creative decision visible.
- Make local Windows usage simple.
- Keep cloud deployment optional, not required for the first version.
- Let Douge learn the pipeline while still getting output quickly.

## Target User

Primary user: 豆哥, a computer technology graduate student who wants direct tools, explainable steps, and repeatable workflows.

Secondary user: future teammates or classmates who may use presets without touching API keys or backend configuration.

## Current Kernel

The imported upstream commit is `48b08719c9690739a79dc70665db8dbd109c2afc`.

Useful existing surfaces:

- `webui/Main.py`: Streamlit WebUI.
- `main.py`: FastAPI server entry.
- `app/controllers/v1/video.py`: task API for video, audio, subtitle, materials, and task query.
- `app/services/task.py`: core pipeline: script, terms, audio, subtitle, materials, final video.
- `config.toml`: local runtime configuration.

Local verified URLs:

- WebUI: `http://127.0.0.1:8501`
- API docs: `http://127.0.0.1:18080/docs`

## Product Direction

Use a "learning production console" direction: quiet, dense, and work-focused. The interface should guide the creator through decisions instead of hiding the pipeline.

Recommended first-screen structure:

1. Idea intake
   - Subject, target audience, platform, desired tone, duration.
   - A "clarify first" button that generates 3 to 5 questions before script generation.
2. Script board
   - Hook, body, takeaway, call to action.
   - The user can approve or rewrite each block.
3. Material strategy
   - Online stock, local material, or mixed mode.
   - Keywords shown in story order.
4. Voice and subtitle style
   - Voice preset, speed, subtitle position, font, and background.
5. Render queue
   - Status, progress, output folder, open output, retry.

## Distinctive Optimizations

- Inquiry-first generation: generate short diagnostic questions before script generation, matching Douge's question-driven interaction style.
- Local-first Windows workflow: one script starts API and WebUI, opens the browser, and writes logs under `logs/`.
- Explainable pipeline: show the five core stages and current stage instead of only a spinner. *(Partially landed: each stage now persists artifacts to `manifest.json`, enabling resume and per-stage inspection; see the Windows Runbook.)*
- Preset packs: "study explainer", "tool demo", "research summary", "course note", "product update".
- Brand kit: store default font, subtitle style, intro/outro, BGM volume, and platform defaults.
- Local material library: put reusable clips under `storage/local_videos` and make local material mode first-class.
- Cost and dependency awareness: show which steps need API keys, network, or GPU-like local compute. *(Foundation landed: LLM calls now return structured `LLMResult` with `error_code` so future routing can reason about provider health/config; see the Windows Runbook.)*
- Safer local default: API listens on `127.0.0.1` by default, not `0.0.0.0`. *(Landed: `config.example.toml` now ships `listen_host = "127.0.0.1"` so fresh installs inherit the safe default, and the launcher health-checks `/ping` after startup.)*

## Future

- Desktop app shell: package the local WebUI as a Windows app using Tauri or Electron, with one-click start/stop.
- Local GPU mode: use the Windows GPU laptop for Whisper or local model acceleration when needed.
- OpenClaw integration: send a topic from Longxia Dou and receive a rendered video task link.
- Feishu workflow: create a video idea from Feishu, send draft script back for approval, then render.
- Content memory: remember successful topics, prompts, voices, and subtitle styles.
- Asset scoring: rate downloaded footage by relevance before rendering.
- Batch generation: turn a CSV or markdown outline into a queue of videos.
- Publishing assistant: generate title, description, tags, and platform-specific metadata before upload.

## Extend

Extension points should stay small and testable:

- `app/services/techdou_questions.py`: inquiry question generator.
- `app/services/techdou_presets.py`: preset definitions and defaults.
- `app/controllers/v1/techdou.py`: APIs for question sets, presets, and render profiles.
- `webui/techdou_components.py`: UI fragments for the guided workflow.
- `storage/brand_kits/`: local brand style files.
- `storage/local_videos/`: reusable user-owned clips.
- `docs/`: user-facing runbooks and deployment notes.

## Implementation Order

1. Keep upstream runnable locally.
2. Add Windows launcher and local-only config.
3. Add guided product docs and preset definitions.
4. Split Streamlit UI into smaller components.
5. Add inquiry-first workflow without changing the existing direct-generation path.
6. Add persistent task history and output browsing.
7. Package as a Windows desktop app.
8. Revisit cloud deployment after local product shape is stable.

## Acceptance Criteria For The First Local Product

- `uv sync --frozen` installs dependencies.
- `scripts/Start-TechDouVideoStudio.ps1` starts WebUI and API locally.
- `http://127.0.0.1:8501` returns WebUI.
- `http://127.0.0.1:18080/docs` returns API docs with product name.
- No cloud server service is modified.
- Future server deployment remains a separate decision.
