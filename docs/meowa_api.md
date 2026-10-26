# Meowa Pixel Gen API

Read from https://meowa.ai/api-docs on 2026-10-26.

## Authentication

- Base URL: `https://api.meowa.ai`.
- Send `Authorization: Bearer <key>`; read the key from Windows User environment variable `MEOWA_API_KEY`.
- Never put the secret in repository files, prompts, generated assets, or game exports.
- Meowa and PixelLab are separate services. Do not use this key for PixelLab.

## Pixel generation

1. Read `GET /api/pixel-gen/template-info` for current templates and configuration; public requests list public templates, authenticated requests also include user templates.
2. Submit `POST /api/pixel-gen` using multipart/form-data. Required fields: `template_name`, `requirement`. Optional fields: `template_config` (JSON), `reference_file`, `reference_files`, `aspect_ratio` (default `1:1`), `temperature` (default `0.0`).
3. Keep the returned `api_job_id`; follow `poll_url` and `poll_interval_seconds` when supplied, or poll `GET /api/pixel-gen/jobs?id=<api_job_id>`.
4. Status values: `queued`, `pending`, `success`, `failure`, `cancelled`. Do not resubmit merely because a job is pending.
5. On success, inspect `output.url`, `output.final_sprite_paths`, `output.sprite_pack_preview_path`, and `output.metadata` as appropriate.
6. Download routes include `/api/pixel-gen/jobs/{api_job_id}/download`, `/preview/download`, and `/outputs/{output_index}/download`.

## Cost and errors

The documentation currently lists Gemini image generation at 10/20/40 credits for 1K/2K/4K. Background removal adds 0 for none, 5 for standard, or advanced from 10 credits per actual 1K call. `pixel_gen_general` normalizes advanced removal to standard. Check current template metadata before submitting; these are not guarantees of native sprite dimensions or every workflow's total cost.

Submission can report `generation_credits`, `remove_background_credits`, `credit_cost`, and `remove_bg_method`.

Errors: 401 authentication, 402 insufficient credits, 409 incompatible job state, 422 invalid fields. Reading the docs and saving configuration did not submit a generation or validate the API key against the service.
