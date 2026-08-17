# CyberArk PSM Recording Viewer

A local, **stdlib-only** web app that lists, inspects, and plays **CyberArk PSM / PSM for SSH / OPM** session recordings through the **PAM – Self-Hosted REST API**.

- 🐍 **Python 3.8+**, standard library only — no `pip install`, no external Python packages.
- 🖥️ Runs entirely on `127.0.0.1` (loopback) by default. The session token lives only in server memory.
- 🎞️ Transcodes classic **ScreenPressor (SCPR)** captures to browser-playable **H.264/MP4** on the fly (via `ffmpeg`).
- ⏩ Detects and lets you **skip idle time** — PSM screen captures are often ~98% idle.
- 🔐 Sign in with **CyberArk / LDAP / RADIUS / Windows** or **SAML** (helper, paste, or ACS relay).

> ⚠️ **This is a community/utility tool, not an official CyberArk product.** It is provided as‑is. Test in a non‑production environment first and follow your organization's security policies.

---

## Table of contents

- [How it works](#how-it-works)
- [Requirements](#requirements)
- [Install](#install)
- [Quick start](#quick-start)
- [Authentication](#authentication)
- [Transcoding & idle-skip](#transcoding--idle-skip)
- [Command-line flags](#command-line-flags)
- [Configuration file (start script)](#configuration-file-start-script)
- [Permissions required](#permissions-required)
- [Troubleshooting](#troubleshooting)
- [Security notes](#security-notes)
- [Project layout](#project-layout)
- [License](#license)

---

## How it works

The tool is a tiny HTTP server built on Python's `http.server`. It proxies authenticated calls to your PVWA's REST API (`/PasswordVault/API/...`), streams recordings from the Vault into a local cache, and — for legacy SCPR/AVI captures that browsers can't decode — runs `ffmpeg` to produce an H.264 MP4 that plays inline. A timeline widget marks idle stretches so you can jump straight to activity.

```
Browser (127.0.0.1:8080)  ⇄  psmviewer.py  ⇄  PVWA REST API  ⇄  Vault
                                   │
                                   └── ffmpeg → H.264/MP4 (cache)
```

---

## Requirements

| Component | Notes |
|---|---|
| **Python 3.8+** | Standard library only. On Windows you can bundle a portable Python next to the script. |
| **A reachable PVWA** | PAM – Self-Hosted with the REST API enabled. |
| **`ffmpeg`** *(optional but recommended)* | Needed for **in-browser playback** of SCPR/AVI recordings. Use a **full build** (must include the `scpr` decoder), e.g. from [gyan.dev](https://www.gyan.dev/ffmpeg/builds/) or [BtbN](https://github.com/BtbN/FFmpeg-Builds/releases). |
| **PSMCodec** *(optional)* | Only if you want **Open in local player** for native AVI playback on Windows. |
| **getSAMLResponse.exe** *(optional)* | For one-click SAML sign-in with FIDO2/MFA support. See [getSAMLResponse-Interactive](https://github.com/allynl93/getSAMLResponse-Interactive). |

---

## Install

```bash
git clone https://github.com/<your-org>/psm-recording-viewer.git
cd psm-recording-viewer
```

The repository layout must keep `index.html` inside a `templates/` folder next to `psmviewer.py`:

```
psmviewer.py
templates/index.html
start.cmd            # optional Windows launcher
```

No dependencies to install — you're done.

---

## Quick start

### Minimal (username/password, no transcoding)

```bash
python psmviewer.py --pvwa https://pvwa.example.com
```

Then open <http://127.0.0.1:8080>.

### With in-browser playback (recommended)

```bash
python psmviewer.py \
  --pvwa https://pvwa.example.com \
  --ffmpeg /path/to/ffmpeg \
  --cache /path/to/psmcache \
  --preset veryfast
```

If `ffmpeg` is on your `PATH`, you can simply pass `--ffmpeg` with no value and it will be auto-located.

> **Behind a load balancer?** Point `--pvwa` at a **single PVWA node's FQDN**, or configure source‑IP persistence on the LB. Otherwise the token issued by one node may be rejected by another (error `PASWS006E`). See [Troubleshooting](#troubleshooting).

---

## Authentication

Choose the method that matches your PVWA configuration with `--auth`:

| `--auth` | Sign-in flow |
|---|---|
| `CyberArk` *(default)* | Username & password |
| `LDAP` | Username & password |
| `RADIUS` | Username & password (+ challenge) |
| `Windows` | Username & password |
| `SAML` | Federated sign-in (see below) |

### SAML options

SAML is enabled by passing `--saml-url` (your IdP-initiated sign-in URL). Then pick one relay:

1. **Helper (recommended)** — `--saml-helper /path/to/getSAMLResponse.exe`
   Opens an Edge **WebView2** window, so full MFA (**FIDO2 / YubiKey**) works with **no changes to your IdP app registration**.
2. **Paste assertion** — no extra flags. Sign in through your IdP in a browser, copy the base64 `SAMLResponse`, and paste it. Nothing is written to disk.
3. **ACS relay** — `--saml-acs` exposes a local `http://127.0.0.1:8080/saml/acs` endpoint that must be registered as a **Reply URL** on your IdP app.

> Your PVWA must have SAML enabled and, for IdP-initiated SSO, `EnableIdPInitiatedSso = yes` in `web.config`. If the assertion is rejected, check that the SP name / audience matches and that the IdP entity name has the correct trailing slash in `saml.config`.

---

## Transcoding & idle-skip

Classic PSM recordings are encoded with **ScreenPressor (SCPR)**, which browsers cannot decode. When `--ffmpeg` is supplied, **Play in browser** transcodes to H.264/MP4 using a **speed-first fallback ladder**:

1. **fast** — keeps the source's *variable* frame rate and encodes **only the frames that changed** (`-fflags +genpts`, `-fps_mode vfr`). Fast, and finalizes cleanly for almost all files.
2. **cfr** — normalizes to a constant frame rate (`fps=N`). Correct but slower (still frames get duplicated). Used only if step 1 fails.
3. **frag** — fragmented MP4 (no seek-back trailer). Last resort.

You'll see “Ready”, or “Ready (constant frame rate)” / “(fragmented MP4)” if a fallback was needed.

**Make it faster:**

```bash
--preset ultrafast     # big speed-up on screen content (slightly larger files)
--preset faster        # middle ground
```

**Idle detection** (on by default when `ffmpeg` supports `freezedetect`) marks silent/still stretches so the player can auto-skip them. Tune with `--idle-min`, `--idle-noise`, and `--idle-pad`.

---

## Command-line flags

| Flag | Default | Notes |
|---|---|---|
| `--pvwa` | *required* | PVWA base URL. Use a single node FQDN if behind a load balancer. |
| `--auth` | `CyberArk` | One of `CyberArk`, `LDAP`, `RADIUS`, `Windows`, `SAML`. |
| `--saml-url` | none | IdP-initiated sign-in URL (enables SAML). |
| `--saml-helper` | none | Path to `getSAMLResponse.exe` for one-click SSO. |
| `--saml-acs` | off | Enable the local ACS relay endpoint. |
| `--helper-timeout` | `300` | Seconds to wait for the SAML helper window. |
| `--ffmpeg` | off | Path to `ffmpeg` (or bare flag to auto-locate). Required for in-browser playback. |
| `--player` | none | Path to a local video player for **Open in local player**. |
| `--preset` | `veryfast` | libx264 preset; use `ultrafast` for max speed. |
| `--fps` | `15` | Only used by the constant-rate fallback. |
| `--no-idle` | off | Disable idle detection. |
| `--idle-min` | `10` | Minimum idle length (seconds) to flag. |
| `--idle-noise` | `-65dB` | Silence threshold for idle detection. |
| `--idle-pad` | `3` | Resume this many seconds *before* activity. |
| `--cache` | `./cache` | Local cache path. Add an AV exclusion if scans are aggressive. |
| `--keepalive-interval` | `240` | Seconds between keepalive pings (resets the PVWA idle timer); `0` disables. |
| `--lock-timeout` | `0` | Vault `LockTimeout` in minutes; enables a countdown + early reauth prompt. |
| `--timeout` | `300` | HTTP request timeout (seconds). |
| `--host` | `127.0.0.1` | Bind address. **Keep on loopback** unless you understand the risk. |
| `--port` | `8080` | Listen port. |
| `--insecure` | off | Disable TLS certificate validation (**not recommended**). |

---

## Configuration file (start script)

On Windows, a `start.cmd` launcher makes day-to-day use one double-click. **Edit the values at the top for your environment** — the ones below are placeholders:

```bat
@echo off
setlocal
cd /d "%~dp0"

REM ====== EDIT THESE FOR YOUR ENVIRONMENT ======
set PVWA=https://pvwa.example.com
set PORT=8080
set AUTH=CyberArk

REM --- SAML (optional). Leave blank to disable. ---
REM Example IdP-initiated URL (replace APP_ID and TENANT_ID with your own):
set SAMLURL=https://launcher.myapps.microsoft.com/api/signin/<APP_ID>?tenantId=<TENANT_ID>
set SAMLHELPER=.\bin\getSAMLResponse.exe

REM --- Session ---
set KEEPALIVE=240
set LOCKTIMEOUT=15

REM --- Transcoding ---
set FFMPEG=.\bin\ffmpeg.exe
set PLAYER=
set CACHE=%TEMP%\psmcache
set PRESET=veryfast
set FPS=15

REM --- Idle detection ---
set IDLEMIN=30
set IDLENOISE=-60dB
set IDLEPAD=7
REM =============================================

set ARGS=--pvwa %PVWA% --auth %AUTH% --port %PORT%
if not "%SAMLURL%"=="" set ARGS=%ARGS% --saml-url "%SAMLURL%"
if not "%SAMLHELPER%"=="" if exist "%SAMLHELPER%" set ARGS=%ARGS% --saml-helper "%SAMLHELPER%"
if not "%KEEPALIVE%"=="" set ARGS=%ARGS% --keepalive-interval %KEEPALIVE%
if not "%LOCKTIMEOUT%"=="" set ARGS=%ARGS% --lock-timeout %LOCKTIMEOUT%
if "%FFMPEG%"=="" ( set ARGS=%ARGS% --ffmpeg ) else ( if exist "%FFMPEG%" ( set ARGS=%ARGS% --ffmpeg "%FFMPEG%" ) else ( set ARGS=%ARGS% --ffmpeg ) )
if not "%PLAYER%"=="" set ARGS=%ARGS% --player "%PLAYER%"
if not "%CACHE%"=="" set ARGS=%ARGS% --cache "%CACHE%"
if not "%PRESET%"=="" set ARGS=%ARGS% --preset %PRESET%
if not "%FPS%"=="" set ARGS=%ARGS% --fps %FPS%
if not "%IDLEMIN%"=="" set ARGS=%ARGS% --idle-min %IDLEMIN%
if not "%IDLENOISE%"=="" set ARGS=%ARGS% --idle-noise=%IDLENOISE%
if not "%IDLEPAD%"=="" set ARGS=%ARGS% --idle-pad %IDLEPAD%

set PYEXE=.\Python\python.exe
if not exist "%PYEXE%" set PYEXE=python

start "" cmd /c "timeout /t 2 >nul & start "" http://127.0.0.1:%PORT%"
"%PYEXE%" "%~dp0psmviewer.py" %ARGS%
pause
```

> 🔒 **Do not commit real values.** Keep your organization's PVWA hostname, IdP `APP_ID`/`TENANT_ID`, and any internal paths out of the repo. Use placeholders (as above) or a local, git‑ignored copy.

---

## Permissions required

The signing-in account needs **View Audit** / **Auditors** membership on the relevant Safes to list and play recordings. Without it, the recordings list will be empty or access will be denied.

---

## Troubleshooting

| Symptom | Likely cause & fix |
|---|---|
| **`401` a few seconds after signing in**, or `PASWS006E` | A load balancer routed a request to a different PVWA node than the one that issued your token. Point `--pvwa` at a **single node FQDN**, or enable **source-IP persistence** on the LB. |
| **“Transcoding disabled”** | You didn't pass `--ffmpeg`, or the path was wrong. Provide a valid `ffmpeg` path. |
| **ffmpeg has no `scpr` decoder** | You're using a minimal build. Install a **full** ffmpeg (gyan.dev / BtbN). |
| **“Conversion failed!” / MP4 won't finalize** | The tool auto-retries with constant-rate then fragmented MP4. If all fail, check for **antivirus locking** files in the cache folder (add an exclusion) or a full/read-only drive. |
| **SAML returns 404 for `auth/SAML/Logon`** | SAML isn't enabled, or IdP-initiated SSO is off (`EnableIdPInitiatedSso = yes` in `web.config`). |
| **SAML “authentication failure” / `PASWS035E`** | Check the IdP entity name trailing slash in `saml.config`, and that you're not double-signing response + assertion. |
| **Audience mismatch** | The IdP Identifier must equal the PVWA ServiceProvider name. |
| **Recordings list empty** | Missing **View Audit** rights on the Safe(s). |

The server prints a diagnostic banner on startup (PVWA target, template version, cache path, ffmpeg status, SAML status, and a mux self-test) — check it first.

---

## Security notes

- **Bind to loopback.** Keep `--host 127.0.0.1`. The PVWA token is held in server memory with no per-browser session, so anyone who can reach the port can use your session.
- **Cache contains recordings.** Cached/transcoded media is written to `--cache` and cleared on sign-out and shutdown. Put it on a protected local disk.
- **Don't use `--insecure`** except for isolated lab testing — it disables TLS validation.
- **Keep secrets out of the repo.** Never commit real PVWA hostnames, IdP tenant/app IDs, or internal paths.

---

## Project layout

```
psmviewer.py            # the server (stdlib only)
templates/index.html    # the single-page UI
start.cmd               # optional Windows launcher (edit placeholders)
README.md               # this file
```

---

## License

Choose a license appropriate for your organization (e.g. [MIT](https://opensource.org/licenses/MIT)) and add a `LICENSE` file. Until a license is added, no usage rights are granted by default.

---

*Not affiliated with or endorsed by CyberArk. “CyberArk”, “PSM”, and related marks are trademarks of their respective owners.*
