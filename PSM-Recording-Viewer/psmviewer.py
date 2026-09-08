#!/usr/bin/env python3
"""
CyberArk PSM Recording Viewer  (v1.16)
--------------------------------------
Lists and plays PSM / PSM for SSH / OPM session recordings via the PAM - Self-Hosted REST API.
Stdlib only (Python 3.8+) - no pip installs.

Feature history
    v1.16 transcode speed. v1.15 fixed VFR finalize failures by forcing a constant frame rate
          (fps=N), but PSM screen captures are ~98% idle, so CFR DUPLICATES the still frames to
          fill every second and the encode got much slower. v1.16 uses a ladder that tries the
          FAST path first and only pays the cost if a file actually needs it:
            1) fast : keep variable frame rate (encode only the frames that changed) with
                      regenerated monotonic timestamps (-fflags +genpts, -fps_mode vfr). This is
                      as fast as pre-v1.15 and still finalizes cleanly for almost all files.
            2) cfr  : the v1.15 fps=N normalization (frames duplicated) - only if (1) fails.
            3) frag : fragmented MP4 (no seek-back trailer) - last resort.
          Also adds --preset (default veryfast; use ultrafast for a big speed-up on screen content).
    v1.15 fps normalization + fragmented-MP4 fallback for VFR captures.
    v1.14 a 2xx response is never an auth failure (PSM data mentions "expired"); PASWS006E LB hint.
    v1.12 resizable player (bottom-right corner grip) + Close (X) that reflows the page.
    v1.9  keepalive resets the PVWA idle timer; any 401 prompts reauth.
    v1.8  SAML via getSAMLResponse.exe (WebView2, FIDO2), plus paste and ACS fallbacks.

    python psmviewer.py --pvwa https://pvwa.example.com --ffmpeg --cache C:\\psmcache --preset ultrafast
"""

import argparse
import base64
import http.server
import json
import mimetypes
import os
import re
import shutil
import socketserver
import ssl
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import webbrowser

APP_VERSION = "1.16"

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CACHE_DIR = os.path.join(BASE_DIR, "cache")
TEMPLATE = os.path.join(BASE_DIR, "templates", "index.html")

CFG = {"pvwa": "", "auth": "CyberArk", "verify": True, "timeout": 300,
       "ffmpeg": None, "ffmpeg_version": None, "ffmpeg_error": None,
       "scpr": None, "player": None, "cache": CACHE_DIR, "fps": 15, "preset": "veryfast",
       "idle": True, "idle_min": 10.0, "idle_noise": "-65dB", "idle_pad": 3.0,
       "saml_url": None, "saml_helper": None, "saml_helper_error": None,
       "acs_enabled": False, "acs": "", "helper_timeout": 300,
       "keepalive": True, "keepalive_interval": 240, "lock_timeout": 0}
STATE = {"token": None, "user": None, "method": None}
SESSION = {"expired": False, "reason": "", "auth_time": 0.0, "last_ok": 0.0,
           "keepalive_ok": True, "keepalive_at": 0.0}
CACHE_LOCK = threading.Lock()
JOBS = {}
JOBS_LOCK = threading.Lock()
SAML_EVENT = {"ok": False, "message": "", "seq": 0, "running": False}
KEEPALIVE = {"endpoint": None, "reason": ""}

FOURCC = {"SCPR": "ScreenPressor (PSM default)", "MSVC": "Microsoft Video 1",
          "CRAM": "Microsoft Video 1", "SPV1": "Screenpresso", "cvid": "Cinepak",
          "MJPG": "Motion JPEG", "H264": "H.264", "avc1": "H.264", "XVID": "Xvid"}

B64_RE = re.compile(r"[A-Za-z0-9+/=]{200,}")


def now():
    return time.time()


# --------------------------------------------------------------------------- #
def probe_ffmpeg(spec):
    if spec is None:
        return None, None, None, None, None
    path = None
    if spec == "auto":
        path = shutil.which("ffmpeg") or shutil.which("ffmpeg.exe")
        if not path:
            for guess in (r"C:\ffmpeg\bin\ffmpeg.exe", r"C:\Program Files\ffmpeg\bin\ffmpeg.exe",
                          r"C:\tools\ffmpeg\bin\ffmpeg.exe",
                          os.path.expanduser(r"~\ffmpeg\bin\ffmpeg.exe")):
                if os.path.exists(guess):
                    path = guess
                    break
        if not path:
            return None, None, None, None, ("ffmpeg was not found on PATH. Pass the full path, "
                                            'e.g. --ffmpeg "C:\\ffmpeg\\bin\\ffmpeg.exe"')
    else:
        path = spec
        if os.path.isdir(path):
            for cand in ("ffmpeg.exe", "ffmpeg", os.path.join("bin", "ffmpeg.exe")):
                if os.path.exists(os.path.join(path, cand)):
                    path = os.path.join(path, cand)
                    break
        if not os.path.exists(path):
            found = shutil.which(spec)
            if found:
                path = found
            else:
                return None, None, None, None, "ffmpeg not found at %s" % spec
    try:
        out = subprocess.run([path, "-version"], capture_output=True, timeout=20)
        if out.returncode != 0:
            return None, None, None, None, "ffmpeg at %s failed (exit %d)" % (path, out.returncode)
        first = out.stdout.decode("utf-8", "replace").splitlines()[0].strip()
    except Exception as e:
        return None, None, None, None, "Could not execute %s: %s" % (path, e)
    scpr = None
    try:
        dec = subprocess.run([path, "-hide_banner", "-decoders"], capture_output=True, timeout=20)
        scpr = b"scpr" in dec.stdout.lower()
    except Exception:
        pass
    freeze = None
    try:
        fl = subprocess.run([path, "-hide_banner", "-filters"], capture_output=True, timeout=20)
        freeze = b"freezedetect" in fl.stdout.lower()
    except Exception:
        pass
    return path, first, scpr, freeze, None


def resolve_helper(spec):
    if not spec:
        return None, None
    path = spec
    if os.path.isdir(path):
        for cand in ("getSAMLResponse.exe", "getSAMLResponse-Interactive.exe"):
            if os.path.exists(os.path.join(path, cand)):
                path = os.path.join(path, cand)
                break
    if not os.path.exists(path):
        found = shutil.which(spec)
        if found:
            path = found
        else:
            return None, ("getSAMLResponse helper not found at %s - download the pre-built binary "
                          "from github.com/allynl93/getSAMLResponse-Interactive releases" % spec)
    if not sys.platform.startswith("win"):
        return path, ("the getSAMLResponse helper is a Windows executable; on this platform use "
                      "the paste or ACS flow instead")
    return path, None


# --------------------------------------------------------------------------- #
def _ssl_ctx():
    ctx = ssl.create_default_context()
    if not CFG["verify"]:
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
    return ctx


def pvwa_call(method, path, body=None, query=None, raw=False, form=None):
    url = CFG["pvwa"].rstrip("/") + "/PasswordVault/API/" + path.lstrip("/")
    if query:
        clean = {k: v for k, v in query.items() if v not in (None, "")}
        if clean:
            url += "?" + urllib.parse.urlencode(clean)
    if form is not None:
        data = urllib.parse.urlencode(form).encode()
        ctype = "application/x-www-form-urlencoded"
    else:
        data = json.dumps(body).encode() if body is not None else None
        ctype = "application/json"
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", ctype)
    if STATE["token"]:
        req.add_header("Authorization", STATE["token"])
    try:
        resp = urllib.request.urlopen(req, context=_ssl_ctx(), timeout=CFG["timeout"])
    except urllib.error.HTTPError as e:
        detail = e.read().decode("utf-8", "replace")
        try:
            detail = json.loads(detail)
        except Exception:
            pass
        return e.code, {"error": detail or e.reason}
    except Exception as e:
        return 0, {"error": str(e)}
    if raw:
        return resp.status, resp
    payload = resp.read().decode("utf-8", "replace")
    resp.close()
    if not payload:
        return resp.status, {}
    try:
        return resp.status, json.loads(payload)
    except json.JSONDecodeError:
        return resp.status, payload


def classify_auth_failure(status, data):
    """A 2xx is NEVER an auth failure, even if its body says "expired". Returns (bool, reason)."""
    if status and 200 <= status < 300:
        return False, ""
    blob = json.dumps(data).lower() if isinstance(data, dict) else str(data or "").lower()
    lb_sig = ("pasws006e" in blob) or ("missing, invalid or expired" in blob)
    if status in (401, 403) or lb_sig:
        if lb_sig:
            return True, ("PVWA rejected the session token (PASWS006E). This almost always means a "
                          "load balancer sent the request to a different PVWA node than the one "
                          "that issued the token. Point --pvwa at a single PVWA node's FQDN instead "
                          "of the load-balancer VIP, or have the LB use source-IP persistence.")
        return True, "The PVWA session token expired or was invalidated. Please sign in again."
    return False, ""


def is_auth_failure(status, data):
    return classify_auth_failure(status, data)[0]


def mark_authenticated(user, method):
    STATE["user"], STATE["method"] = user, method
    SESSION.update(expired=False, reason="", auth_time=now(), last_ok=now(),
                   keepalive_ok=True, keepalive_at=now())


def mark_expired(reason):
    if STATE["token"]:
        try:
            pvwa_call("POST", "Auth/Logoff")
        except Exception:
            pass
    STATE["token"] = None
    SESSION.update(expired=True, reason=reason or "Your PVWA session is no longer valid.")


def note_result(status, data, where=""):
    if not STATE["token"]:
        return False
    if status and 200 <= status < 300:
        SESSION["last_ok"] = now()
        return False
    failed, reason = classify_auth_failure(status, data)
    if failed:
        snippet = (json.dumps(data)[:200] if isinstance(data, dict) else str(data)[:200])
        sys.stderr.write("[session] auth failure on %s: HTTP %s %s\n"
                         % (where or "PVWA call", status, snippet))
        mark_expired(reason)
        return True
    return False


def logon(username, password, auth_type):
    STATE["token"] = None
    status, data = pvwa_call("POST", "Auth/%s/Logon" % auth_type,
                             {"username": username, "password": password,
                              "concurrentSession": True})
    if status != 200:
        return False, data.get("error", data) if isinstance(data, dict) else data
    token = data if isinstance(data, str) else (data.get("CyberArkLogonResult") or "")
    if not token:
        return False, "Logon succeeded but no session token was returned."
    STATE["token"] = token.strip('"')
    mark_authenticated(username, auth_type)
    return True, "ok"


def saml_logon(saml_response, how="SAML"):
    STATE["token"] = None
    saml_response = (saml_response or "").strip()
    if "%" in saml_response and "<" not in saml_response:
        saml_response = urllib.parse.unquote(saml_response)
    saml_response = re.sub(r"\s+", "", saml_response)
    if not saml_response:
        return False, "No SAMLResponse supplied."
    status, data = pvwa_call("POST", "auth/SAML/Logon",
                             form={"concurrentSession": "true", "apiUse": "true",
                                   "SAMLResponse": saml_response})
    if status != 200:
        msg = data.get("error", data) if isinstance(data, dict) else data
        txt = msg if isinstance(msg, str) else json.dumps(msg)
        low = txt.lower()
        hint = ""
        if "404" in txt or "not found" in low:
            hint = (" PVWA returned 404 for auth/SAML/Logon - SAML is not enabled, or IdP-initiated "
                    "SSO is off (web.config needs EnableIdPInitiatedSso = yes).")
        elif "sso response" in low or "serialization" in low or "base-64" in low:
            hint = " PVWA could not parse the assertion - it was not the raw base64 SAMLResponse."
        elif "pasws035e" in low or "authentication failure" in low:
            hint = (" PVWA rejected the assertion. Most often the PartnerIdentityProvider Name in "
                    "saml.config is missing its trailing slash, or both the response and assertion "
                    "are signed.")
        elif "audience" in low:
            hint = " Audience mismatch - Entra Identifier must equal the PVWA ServiceProvider name."
        return False, str(txt)[:600] + hint
    token = data if isinstance(data, str) else (data.get("CyberArkLogonResult") or "")
    if not token:
        return False, "SAML logon succeeded but no session token was returned."
    STATE["token"] = token.strip('"')
    info = decode_assertion(saml_response)
    mark_authenticated(info.get("nameId") or "SAML user", how)
    return True, "ok"


def run_saml_helper():
    SAML_EVENT.update(running=True, ok=False,
                      message="Opening the sign-in window - complete authentication there...",
                      seq=SAML_EVENT["seq"] + 1)
    try:
        proc = subprocess.run([CFG["saml_helper"], CFG["saml_url"]],
                              capture_output=True, timeout=CFG["helper_timeout"])
        out = proc.stdout.decode("utf-8", "replace")
        err = proc.stderr.decode("utf-8", "replace")
        if proc.returncode != 0 and not out.strip():
            SAML_EVENT.update(running=False, ok=False, seq=SAML_EVENT["seq"] + 1,
                              message="Helper exited with code %s. %s"
                                      % (proc.returncode, (err or out)[-400:]))
            return
        assertion = extract_assertion(out)
        if not assertion:
            SAML_EVENT.update(running=False, ok=False, seq=SAML_EVENT["seq"] + 1,
                              message=("The helper returned no SAML assertion. The window was "
                                       "probably closed early, or the Entra app has a Sign-on URL "
                                       "set. Output: %s" % ((out or err)[:300] or "<empty>")))
            return
        ok, msg = saml_logon(assertion, how="SAML (helper)")
        SAML_EVENT.update(running=False, ok=ok, seq=SAML_EVENT["seq"] + 1,
                          message=("Signed in as %s" % STATE["user"]) if ok else msg)
    except subprocess.TimeoutExpired:
        SAML_EVENT.update(running=False, ok=False, seq=SAML_EVENT["seq"] + 1,
                          message="Timed out after %ds waiting for sign-in." % CFG["helper_timeout"])
    except Exception as e:
        SAML_EVENT.update(running=False, ok=False, seq=SAML_EVENT["seq"] + 1, message=str(e))


def _saml_xml(b64):
    try:
        xml = base64.b64decode(b64 + "=" * (-len(b64) % 4)).decode("utf-8", "replace")
    except Exception:
        return None
    xml_s = xml.lstrip("\ufeff \t\r\n")
    return xml if (xml_s.startswith("<") and "Response" in xml) else None


def extract_assertion(text):
    if not text:
        return ""
    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    b64_lines = [l for l in lines if re.fullmatch(r"[A-Za-z0-9+/=]+", l)]
    joined = "".join(b64_lines)
    if len(joined) >= 100 and _saml_xml(joined):
        return joined
    for cand in sorted((l for l in b64_lines if len(l) >= 100), key=len, reverse=True):
        if _saml_xml(cand):
            return cand
    flat = re.sub(r"\s+", "", text)
    starts = [m.start() for p in ("PHNhbWxwOl", "PHNhbWwycDpS", "PD94bWw", "PHJlc3BvbnNl",
                                  "PHNhbWw6", "PHNhbWxwOlJlc3BvbnNl")
              for m in re.finditer(re.escape(p), flat)]
    for s in sorted(set(starts)):
        run = B64_RE.search(flat[s:])
        cand = run.group(0) if run else flat[s:]
        for cut in range(0, min(len(cand), 400), 4):
            trial = cand[:len(cand) - cut]
            if len(trial) < 100:
                break
            xml = _saml_xml(trial)
            if xml and xml.rstrip().endswith(">"):
                return trial
    return ""


def decode_assertion(b64):
    out = {}
    try:
        xml = base64.b64decode(b64 + "=" * (-len(b64) % 4)).decode("utf-8", "replace")
    except Exception:
        return out
    for key, pat in (("nameId", r"<(?:\w+:)?NameID[^>]*>([^<]+)<"),
                     ("audience", r"<(?:\w+:)?Audience[^>]*>([^<]+)<"),
                     ("issuer", r"<(?:\w+:)?Issuer[^>]*>([^<]+)<")):
        m = re.search(pat, xml)
        if m:
            out[key] = m.group(1).strip()
    m = re.search(r'NotOnOrAfter="([^"]+)"', xml)
    if m:
        out["notOnOrAfter"] = m.group(1)
    return out


def logoff():
    if STATE["token"]:
        try:
            pvwa_call("POST", "Auth/Logoff")
        except Exception:
            pass
    STATE["token"] = None
    STATE["user"] = None
    STATE["method"] = None
    SESSION.update(expired=False, reason="", auth_time=0.0, last_ok=0.0)
    with CACHE_LOCK:
        shutil.rmtree(CFG["cache"], ignore_errors=True)


# --------------------------------------------------------------------------- #
def keepalive_ping():
    order = [KEEPALIVE["endpoint"]] if KEEPALIVE["endpoint"] else ["Server", "recordings?limit=1"]
    for ep in order:
        if not ep:
            continue
        if "?" in ep:
            base, qs = ep.split("?", 1)
            q = {k: v[0] for k, v in urllib.parse.parse_qs(qs).items()}
            status, data = pvwa_call("GET", base, query=q)
        else:
            status, data = pvwa_call("GET", ep)
        if status and 200 <= status < 300:
            KEEPALIVE["endpoint"] = ep
            return True
        failed, reason = classify_auth_failure(status, data)
        if failed:
            KEEPALIVE["reason"] = reason
            return False
    return True


def keepalive_loop():
    while True:
        time.sleep(max(5, CFG["keepalive_interval"]))
        if not (CFG["keepalive"] and STATE["token"] and not SESSION["expired"]):
            continue
        alive = keepalive_ping()
        SESSION["keepalive_at"] = now()
        if alive:
            SESSION["keepalive_ok"] = True
            SESSION["last_ok"] = now()
        else:
            SESSION["keepalive_ok"] = False
            mark_expired(KEEPALIVE.get("reason") or "The PVWA session timed out. Please sign in again.")


def session_view():
    age = now() - SESSION["auth_time"] if SESSION["auth_time"] else 0
    since_ok = now() - SESSION["last_ok"] if SESSION["last_ok"] else 0
    lock_remaining = None
    if CFG["lock_timeout"] and SESSION["auth_time"]:
        lock_remaining = max(0, CFG["lock_timeout"] * 60 - age)
    return {"signedIn": bool(STATE["token"]), "tokenExpired": SESSION["expired"],
            "expiryReason": SESSION["reason"], "authMethod": STATE["method"], "user": STATE["user"],
            "sessionAgeSec": int(age), "sinceLastOkSec": int(since_ok),
            "keepalive": CFG["keepalive"], "keepaliveIntervalSec": CFG["keepalive_interval"],
            "keepaliveOk": SESSION["keepalive_ok"], "lockTimeoutMin": CFG["lock_timeout"] or 0,
            "lockRemainingSec": int(lock_remaining) if lock_remaining is not None else None}


# --------------------------------------------------------------------------- #
SIGS = [(b"\x1aE\xdf\xa3", 0, "video/webm", ".webm"),
        (b"RIFF", 0, "video/x-msvideo", ".avi"),
        (b"ftyp", 4, "video/mp4", ".mp4"),
        (b"\x30\x26\xb2\x75", 0, "video/x-ms-wmv", ".wmv"),
        (b"PK\x03\x04", 0, "application/zip", ".zip"),
        (b"%PDF", 0, "application/pdf", ".pdf"),
        (b"\x1f\x8b", 0, "application/gzip", ".gz")]


def sniff(head):
    for sig, off, mime, ext in SIGS:
        if head[off:off + len(sig)] == sig:
            return mime, ext
    return "application/octet-stream", ".bin"


def avi_fourcc(path):
    try:
        with open(path, "rb") as fh:
            head = fh.read(8192)
        i = head.find(b"strh")
        while i != -1:
            if head[i + 8:i + 12] == b"vids":
                cc = head[i + 12:i + 16].decode("ascii", "replace").strip("\x00 ")
                return cc or None
            i = head.find(b"strh", i + 4)
    except Exception:
        pass
    return None


class SessionExpired(Exception):
    pass


def cache_recording(rec_id):
    safe_id = re.sub(r"[^A-Za-z0-9._-]", "_", rec_id)
    with CACHE_LOCK:
        os.makedirs(CFG["cache"], exist_ok=True)
        meta_path = os.path.join(CFG["cache"], safe_id + ".meta.json")
        if os.path.exists(meta_path):
            meta = json.load(open(meta_path))
            if os.path.exists(meta["path"]):
                return meta["path"], meta["mime"], meta["ext"]
        status, resp = pvwa_call("POST", "recordings/%s/Play/"
                                 % urllib.parse.quote(rec_id, safe=""), raw=True)
        if status != 200:
            body = resp if isinstance(resp, dict) else {"error": ""}
            if note_result(status, body, where="recordings/{id}/Play") or status in (401, 403):
                raise SessionExpired("session expired while fetching the recording")
            raise RuntimeError("Play failed (HTTP %s): %s" % (status, resp))
        tmp = os.path.join(CFG["cache"], safe_id + ".download")
        head = b""
        with open(tmp, "wb") as fh:
            while True:
                chunk = resp.read(1 << 20)
                if not chunk:
                    break
                if len(head) < 16:
                    head += chunk[:16]
                fh.write(chunk)
        resp.close()
        SESSION["last_ok"] = now()
        srv_mime = (resp.headers.get("Content-Type") or "").split(";")[0].strip()
        mime, ext = sniff(head)
        if mime == "application/octet-stream" and srv_mime.startswith("video/"):
            mime, ext = srv_mime, (mimetypes.guess_extension(srv_mime) or ".bin")
        final = os.path.join(CFG["cache"], safe_id + ext)
        os.replace(tmp, final)
        json.dump({"path": final, "mime": mime, "ext": ext}, open(meta_path, "w"))
        return final, mime, ext


# --------------------------------------------------------------------------- #
DUR_RE = re.compile(r"Duration:\s*(\d+):(\d+):([\d.]+)")
TIME_RE = re.compile(r"time=\s*(\d+):(\d+):([\d.]+)")
FSTART_RE = re.compile(r"freeze_start:\s*([\d.]+)")
FEND_RE = re.compile(r"freeze_end:\s*([\d.]+)")


def set_job(rec_id, **kw):
    with JOBS_LOCK:
        JOBS.setdefault(rec_id, {}).update(kw)


class FreezeParser:
    def __init__(self):
        self.segments = []
        self._open = None

    def feed(self, line):
        m = FSTART_RE.search(line)
        if m:
            self._open = float(m.group(1))
            return
        m = FEND_RE.search(line)
        if m and self._open is not None:
            end = float(m.group(1))
            if end > self._open:
                self.segments.append([round(self._open, 3), round(end, 3)])
            self._open = None

    def close(self, total):
        if self._open is not None and total and total > self._open:
            self.segments.append([round(self._open, 3), round(total, 3)])
            self._open = None
        return self.segments


def _detect_suffix():
    return ",freezedetect=n=%s:d=%s" % (CFG["idle_noise"], CFG["idle_min"]) if CFG["idle"] else ""


def encode_profiles(src, tmp_out):
    """Ordered attempts, fastest first. Each is a full re-encode; we stop at the first success.

      fast : keep the source's VARIABLE frame rate - encode only the frames that actually changed,
             which is what makes idle-heavy PSM captures fast. -fflags +genpts regenerates monotonic
             timestamps and -fps_mode vfr preserves the sparse timing, which fixes the finalize
             failure for almost all files without duplicating frames.
      cfr  : normalize to a constant frame rate (fps=N). Correct but slower because still frames are
             duplicated to fill every second. Only used if 'fast' fails.
      frag : fragmented MP4 (empty moov up front, no seek-back trailer). Last resort.
    """
    ff = CFG["ffmpeg"]
    fps = int(CFG["fps"] or 15)
    preset = CFG["preset"] or "veryfast"
    scale = "scale=trunc(iw/2)*2:trunc(ih/2)*2"
    vf_plain = scale + _detect_suffix()
    vf_cfr = scale + (",fps=%d" % fps) + _detect_suffix()
    enc = ["-c:v", "libx264", "-preset", preset, "-crf", "26", "-pix_fmt", "yuv420p", "-an"]

    fast = ([ff, "-hide_banner", "-nostdin", "-y", "-fflags", "+genpts", "-i", src,
             "-vf", vf_plain] + enc + ["-fps_mode", "vfr", "-f", "mp4", tmp_out])
    cfr = ([ff, "-hide_banner", "-nostdin", "-y", "-i", src, "-vf", vf_cfr]
           + enc + ["-f", "mp4", tmp_out])
    frag = ([ff, "-hide_banner", "-nostdin", "-y", "-i", src, "-vf", vf_cfr]
            + enc + ["-movflags", "+frag_keyframe+empty_moov+default_base_moof", "-f", "mp4",
                     tmp_out])
    return [("fast", fast), ("cfr", cfr), ("frag", frag)]


def run_encode(rec_id, cmd, detect, note):
    """Run one attempt, streaming progress + parsing freeze segments.
       Returns (returncode, total_seconds, segments, stderr_tail)."""
    proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    fp = FreezeParser()
    total, buf, tail = 0.0, b"", b""
    while True:
        chunk = proc.stderr.read(256)
        if not chunk:
            break
        tail = (tail + chunk)[-8192:]
        buf += chunk
        parts = re.split(rb"[\r\n]", buf)
        buf = parts.pop()
        for raw_line in parts:
            line = raw_line.decode("utf-8", "replace")
            if not total:
                m = DUR_RE.search(line)
                if m:
                    total = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))
            if detect:
                fp.feed(line)
            m = TIME_RE.search(line)
            if m and total:
                done = int(m.group(1)) * 3600 + int(m.group(2)) * 60 + float(m.group(3))
                set_job(rec_id, pct=min(99, int(done * 100 / max(total, 0.001))),
                        idle=list(fp.segments))
    if buf and detect:
        fp.feed(buf.decode("utf-8", "replace"))
    proc.wait()
    return proc.returncode, total, fp.close(total), tail.decode("utf-8", "replace")


def transcode_worker(rec_id):
    try:
        set_job(rec_id, state="fetching", pct=0, message="Retrieving recording from the Vault...")
        try:
            src, mime, ext = cache_recording(rec_id)
        except SessionExpired:
            set_job(rec_id, state="error", expired=True,
                    message="Your PVWA session expired. Sign in again, then retry.")
            return
        base = os.path.splitext(src)[0]
        out = base + ".h264.mp4"
        seg_path = base + ".idle.json"
        if ext == ".mp4":
            set_job(rec_id, state="done", pct=100, path=src, message="Already MP4.", idle=[], duration=0)
            return
        if os.path.exists(out) and os.path.getsize(out) > 0:
            idle, dur = [], 0
            if os.path.exists(seg_path):
                try:
                    saved = json.load(open(seg_path))
                    idle, dur = saved.get("idle", []), saved.get("duration", 0)
                except Exception:
                    pass
            set_job(rec_id, state="done", pct=100, path=out, message="Cached.", idle=idle, duration=dur)
            return
        tmp_out = base + ".tmp.mp4"
        for stale in (tmp_out, out):
            if os.path.exists(stale):
                try:
                    os.remove(stale)
                except OSError:
                    pass

        cc = avi_fourcc(src) or "?"
        detect = CFG["idle"]
        profiles = encode_profiles(src, tmp_out)
        labels = {"fast": "", "cfr": "  (retry: constant frame rate)",
                  "frag": "  (retry: fragmented MP4)"}

        last_tail = ""
        total = 0.0
        segments = []
        used = None
        for name, cmd in profiles:
            set_job(rec_id, state="transcoding", pct=0, codec=cc, idle=[],
                    message="Transcoding %s to H.264%s...%s"
                            % (FOURCC.get(cc, cc),
                               " and scanning for idle time" if detect else "",
                               labels.get(name, "")))
            if os.path.exists(tmp_out):
                try:
                    os.remove(tmp_out)
                except OSError:
                    pass
            rc, total, segments, last_tail = run_encode(rec_id, cmd, detect, name)
            if rc == 0 and os.path.exists(tmp_out) and os.path.getsize(tmp_out) > 0:
                used = name
                break

        if not used:
            low = last_tail.lower()
            if cc == "SCPR" and CFG["scpr"] is False:
                hint = " This ffmpeg build has no ScreenPressor (scpr) decoder - use a full build."
            elif "no space" in low or "enospc" in low:
                hint = " The drive holding the cache is out of space."
            else:
                hint = (" The video encoded but writing the MP4 failed on all attempts (VFR, "
                        "constant-rate, and fragmented). Remaining likely causes: antivirus locking "
                        "new files in the cache folder (add an exclusion for %s), a read-only or "
                        "full drive, or a broken ffmpeg build." % CFG["cache"])
            set_job(rec_id, state="error", cmd=" ".join(profiles[-1][1]),
                    message="ffmpeg failed (codec %s).%s\n\n%s" % (cc, hint, last_tail[-700:]))
            if os.path.exists(tmp_out):
                try:
                    os.remove(tmp_out)
                except OSError:
                    pass
            return

        os.replace(tmp_out, out)
        idle = segments
        try:
            json.dump({"idle": idle, "duration": total}, open(seg_path, "w"))
        except OSError:
            pass
        saved = sum(b - a for a, b in idle)
        extra = {"fast": "", "cfr": " (constant frame rate)",
                 "frag": " (fragmented MP4)"}.get(used, "")
        if detect and idle:
            msg = "Ready%s - %d idle stretch%s found (%s skippable)." % (
                extra, len(idle), "" if len(idle) == 1 else "es", fmt_hms(saved))
        elif detect:
            msg = "Ready%s - no idle time detected." % extra
        else:
            msg = "Ready%s." % extra
        set_job(rec_id, state="done", pct=100, path=out, message=msg,
                idle=idle, duration=round(total, 3))
    except Exception as e:
        set_job(rec_id, state="error", message=str(e))


def fmt_hms(sec):
    sec = int(sec or 0)
    h, m, s = sec // 3600, (sec % 3600) // 60, sec % 60
    return ("%dh %dm" % (h, m)) if h else (("%dm %ds" % (m, s)) if m else "%ds" % s)


# --------------------------------------------------------------------------- #
ACS_OK = """<!DOCTYPE html><html><head><meta charset="utf-8"><title>Signed in</title>
<style>body{background:#0f141a;color:#e6edf3;font:15px/1.5 "Segoe UI",Arial,sans-serif;
display:flex;align-items:center;justify-content:center;height:100vh;margin:0}
.b{background:#171f28;border:1px solid #26313d;border-radius:8px;padding:28px 34px;text-align:center;max-width:420px}
h1{font-size:17px;margin:0 0 8px;color:#3fb950}p{color:#8b98a5;margin:6px 0}</style></head>
<body><div class="b"><h1>&#10003; Signed in to PVWA</h1><p>%s</p>
<p>You can close this tab and return to the viewer.</p></div>
<script>setTimeout(function(){window.close()},1500)</script></body></html>"""
ACS_ERR = """<!DOCTYPE html><html><head><meta charset="utf-8"><title>Sign-in failed</title>
<style>body{background:#0f141a;color:#e6edf3;font:15px/1.5 "Segoe UI",Arial,sans-serif;
display:flex;align-items:center;justify-content:center;height:100vh;margin:0}
.b{background:#171f28;border:1px solid #7a2f2f;border-radius:8px;padding:28px 34px;max-width:620px}
h1{font-size:17px;margin:0 0 10px;color:#e5534b}pre{white-space:pre-wrap;word-break:break-word;
background:#0d1218;padding:10px;border-radius:4px;font-size:12px;color:#f0a0a0}</style></head>
<body><div class="b"><h1>SAML sign-in failed</h1><pre>%s</pre></div></body></html>"""


# --------------------------------------------------------------------------- #
class Handler(http.server.BaseHTTPRequestHandler):
    server_version = "PSMRecordingViewer/" + APP_VERSION

    def log_message(self, fmt, *args):
        sys.stderr.write("[%s] %s\n" % (self.log_date_time_string(), fmt % args))

    def send_json(self, obj, status=200):
        body = json.dumps(obj).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def send_html(self, html, status=200):
        body = html.encode("utf-8", "replace")
        self.send_response(status)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def read_body(self):
        n = int(self.headers.get("Content-Length") or 0)
        if not n:
            return {}
        try:
            return json.loads(self.rfile.read(n) or b"{}")
        except Exception:
            return {}

    def read_form(self):
        n = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(n).decode("utf-8", "replace") if n else ""
        return {k: v[0] for k, v in urllib.parse.parse_qs(raw).items()}

    def require_auth(self):
        if not STATE["token"]:
            self.send_json({"error": SESSION["reason"] or "Not signed in to PVWA.",
                            "code": "SESSION_EXPIRED" if SESSION["expired"] else "NO_SESSION"}, 401)
            return False
        return True

    def authed_get(self, path, query=None):
        status, data = pvwa_call("GET", path, query=query)
        if note_result(status, data, where=path):
            self.send_json({"error": SESSION["reason"], "code": "SESSION_EXPIRED"}, 401)
            return None
        return status, data

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path, qs = parsed.path, urllib.parse.parse_qs(parsed.query)
        one = lambda k: (qs.get(k) or [None])[0]
        if path in ("/", "/index.html"):
            return self.serve_index()
        if path == "/api/session":
            base = {"version": APP_VERSION, "pvwa": CFG["pvwa"], "authType": CFG["auth"],
                    "saml": bool(CFG["saml_url"]), "samlUrl": CFG["saml_url"],
                    "helper": bool(CFG["saml_helper"]), "helperPath": CFG["saml_helper"],
                    "helperError": CFG["saml_helper_error"], "acsEnabled": CFG["acs_enabled"],
                    "acs": CFG["acs"], "ffmpeg": bool(CFG["ffmpeg"]), "ffmpegPath": CFG["ffmpeg"],
                    "ffmpegVersion": CFG["ffmpeg_version"], "ffmpegError": CFG["ffmpeg_error"],
                    "scpr": CFG["scpr"], "cache": CFG["cache"], "idle": CFG["idle"],
                    "idleMin": CFG["idle_min"], "idleNoise": CFG["idle_noise"],
                    "idlePad": CFG["idle_pad"], "localPlayer": CFG["player"] or "system default",
                    "canOpenLocal": sys.platform.startswith("win") or bool(CFG["player"])}
            base.update(session_view())
            return self.send_json(base)
        if path == "/api/heartbeat":
            v = session_view()
            v["samlSeq"] = SAML_EVENT["seq"]
            v["samlRunning"] = SAML_EVENT["running"]
            return self.send_json(v)
        if path == "/api/saml/status":
            return self.send_json({"signedIn": bool(STATE["token"]), "user": STATE["user"],
                                   "seq": SAML_EVENT["seq"], "ok": SAML_EVENT["ok"],
                                   "running": SAML_EVENT["running"], "message": SAML_EVENT["message"]})
        if path == "/api/recordings":
            if not self.require_auth():
                return
            res = self.authed_get("recordings", query={
                "limit": one("limit") or 25, "offset": one("offset") or 0, "sort": one("sort"),
                "search": one("search"), "safe": one("safe"), "fromTime": one("fromTime"),
                "toTime": one("toTime"), "activities": one("activities")})
            if res is None:
                return
            return self.send_json(res[1], res[0] or 502)
        m = re.match(r"^/api/segments/(.+)$", path)
        if m:
            rid = urllib.parse.unquote(m.group(1))
            with JOBS_LOCK:
                job = JOBS.get(rid) or {}
            return self.send_json({"idle": job.get("idle", []), "duration": job.get("duration", 0),
                                   "state": job.get("state", "idle")})
        m = re.match(r"^/api/transcode/(.+)$", path)
        if m:
            rid = urllib.parse.unquote(m.group(1))
            with JOBS_LOCK:
                return self.send_json(JOBS.get(rid) or {"state": "idle"})
        m = re.match(r"^/api/recordings/([^/]+)(?:/(activities|properties))?$", path)
        if m:
            if not self.require_auth():
                return
            rid, sub = urllib.parse.unquote(m.group(1)), m.group(2)
            p = "recordings/%s" % urllib.parse.quote(rid, safe="")
            if sub:
                p += "/" + sub
            res = self.authed_get(p)
            if res is None:
                return
            return self.send_json(res[1], res[0] or 502)
        m = re.match(r"^/(media|download)/(.+)$", path)
        if m:
            if not STATE["token"]:
                return self.send_error(401, "Not signed in")
            return self.serve_media(urllib.parse.unquote(m.group(2)),
                                    attachment=(m.group(1) == "download"), fmt=one("fmt"))
        self.send_error(404, "Not found")

    def do_POST(self):
        path = urllib.parse.urlparse(self.path).path
        if path == "/api/saml/helper":
            if not CFG["saml_helper"]:
                return self.send_json({"ok": False, "error": CFG["saml_helper_error"]
                                       or "No --saml-helper configured."}, 400)
            if not CFG["saml_url"]:
                return self.send_json({"ok": False, "error": "No --saml-url configured."}, 400)
            if SAML_EVENT["running"]:
                return self.send_json({"ok": True, "already": True})
            threading.Thread(target=run_saml_helper, daemon=True).start()
            return self.send_json({"ok": True})
        if path == "/saml/acs":
            if not CFG["acs_enabled"]:
                return self.send_html(ACS_ERR % "The local ACS endpoint is disabled. "
                                                "Start with --saml-acs to enable it.", 403)
            form = self.read_form()
            assertion = form.get("SAMLResponse", "")
            if not assertion:
                SAML_EVENT.update(ok=False, running=False, seq=SAML_EVENT["seq"] + 1,
                                  message="No SAMLResponse in the POST body.")
                return self.send_html(ACS_ERR % "No SAMLResponse field was posted.", 400)
            ok, msg = saml_logon(assertion, how="SAML (ACS)")
            SAML_EVENT.update(ok=ok, running=False, seq=SAML_EVENT["seq"] + 1,
                              message=("Signed in as %s" % STATE["user"]) if ok else msg)
            return self.send_html((ACS_OK % ("Signed in as " + str(STATE["user"]))) if ok
                                  else ACS_ERR % msg, 200 if ok else 401)
        if path == "/api/saml/open":
            if not CFG["saml_url"]:
                return self.send_json({"ok": False, "error": "No --saml-url configured."}, 400)
            try:
                webbrowser.open(CFG["saml_url"], new=2)
            except Exception as e:
                return self.send_json({"ok": False, "error": str(e)}, 500)
            return self.send_json({"ok": True})
        if path == "/api/saml/paste":
            b = self.read_body()
            ok, msg = saml_logon(b.get("samlResponse", ""), how="SAML (paste)")
            SAML_EVENT.update(ok=ok, running=False, seq=SAML_EVENT["seq"] + 1, message=msg)
            return self.send_json({"ok": ok, "message": msg, "user": STATE["user"]},
                                  200 if ok else 401)
        if path == "/api/saml/inspect":
            b = self.read_body()
            raw = re.sub(r"\s+", "", (b.get("samlResponse") or ""))
            return self.send_json(decode_assertion(raw))
        if path == "/api/login":
            b = self.read_body()
            ok, msg = logon(b.get("username", ""), b.get("password", ""),
                            b.get("authType") or CFG["auth"])
            return self.send_json({"ok": ok, "message": msg, "user": STATE["user"]},
                                  200 if ok else 401)
        if path == "/api/logout":
            logoff()
            return self.send_json({"ok": True})
        m = re.match(r"^/api/transcode/(.+)$", path)
        if m:
            if not self.require_auth():
                return
            if not CFG["ffmpeg"]:
                return self.send_json(
                    {"error": "Transcoding is disabled on the server. %s Restart with --ffmpeg."
                              % (CFG["ffmpeg_error"] or "The --ffmpeg flag was not supplied.")}, 400)
            rid = urllib.parse.unquote(m.group(1))
            body = self.read_body()
            with JOBS_LOCK:
                job = JOBS.get(rid)
                busy = job and job.get("state") in ("fetching", "transcoding")
                if body.get("force") and not busy:
                    JOBS.pop(rid, None)
            if not busy:
                JOBS[rid] = {"state": "fetching", "pct": 0, "message": "Queued..."}
                threading.Thread(target=transcode_worker, args=(rid,), daemon=True).start()
            return self.send_json({"ok": True})
        m = re.match(r"^/api/open-local/(.+)$", path)
        if m:
            if not self.require_auth():
                return
            rid = urllib.parse.unquote(m.group(1))
            try:
                src, _, _ = cache_recording(rid)
            except SessionExpired:
                return self.send_json({"ok": False, "error": SESSION["reason"],
                                       "code": "SESSION_EXPIRED"}, 401)
            except Exception as e:
                return self.send_json({"ok": False, "error": str(e)}, 500)
            try:
                if CFG["player"]:
                    subprocess.Popen([CFG["player"], src])
                elif sys.platform.startswith("win"):
                    os.startfile(src)  # noqa
                elif sys.platform == "darwin":
                    subprocess.Popen(["open", src])
                else:
                    subprocess.Popen(["xdg-open", src])
            except Exception as e:
                return self.send_json({"ok": False, "error": str(e)}, 500)
            return self.send_json({"ok": True, "path": src})
        self.send_error(404, "Not found")

    def serve_index(self):
        try:
            body = open(TEMPLATE, "rb").read()
        except OSError:
            return self.send_error(500, "templates/index.html is missing")
        if b"__APP_VERSION__" not in body:
            sys.stderr.write("WARNING: templates/index.html looks stale (no version marker).\n")
        body = body.replace(b"__APP_VERSION__", APP_VERSION.encode())
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
        self.send_header("Pragma", "no-cache")
        self.send_header("Expires", "0")
        self.end_headers()
        self.wfile.write(body)

    def serve_media(self, rec_id, attachment=False, fmt=None):
        try:
            if fmt == "mp4":
                with JOBS_LOCK:
                    job = JOBS.get(rec_id) or {}
                if job.get("state") != "done" or not job.get("path"):
                    return self.send_error(409, "Transcode not ready")
                path, mime, ext = job["path"], "video/mp4", ".mp4"
            else:
                path, mime, ext = cache_recording(rec_id)
        except SessionExpired:
            return self.send_error(401, "Session expired")
        except Exception as e:
            return self.send_error(502, "Unable to retrieve recording: %s" % e)
        size = os.path.getsize(path)
        start, end, status = 0, size - 1, 200
        rng = self.headers.get("Range")
        if rng:
            m = re.match(r"bytes=(\d*)-(\d*)", rng)
            if m:
                if m.group(1):
                    start = int(m.group(1))
                    end = int(m.group(2)) if m.group(2) else size - 1
                else:
                    start = max(0, size - int(m.group(2)))
                end = min(end, size - 1)
                status = 206
        length = max(0, end - start + 1)
        self.send_response(status)
        self.send_header("Content-Type", mime)
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(length))
        if status == 206:
            self.send_header("Content-Range", "bytes %d-%d/%d" % (start, end, size))
        if attachment:
            self.send_header("Content-Disposition", 'attachment; filename="%s"'
                             % (re.sub(r"[^A-Za-z0-9._-]", "_", rec_id) + ext))
        self.end_headers()
        with open(path, "rb") as fh:
            fh.seek(start)
            remaining = length
            while remaining > 0:
                chunk = fh.read(min(1 << 20, remaining))
                if not chunk:
                    break
                try:
                    self.wfile.write(chunk)
                except (BrokenPipeError, ConnectionResetError):
                    return
                remaining -= len(chunk)


class ThreadedServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


# --------------------------------------------------------------------------- #
def selftest():
    if not CFG["ffmpeg"]:
        return True, "skipped (transcoding disabled)"
    os.makedirs(CFG["cache"], exist_ok=True)
    probe = os.path.join(CFG["cache"], "_selftest.tmp.mp4")
    cmd = [CFG["ffmpeg"], "-hide_banner", "-nostdin", "-y", "-f", "lavfi",
           "-i", "color=c=black:s=64x64:d=1", "-c:v", "libx264", "-pix_fmt", "yuv420p",
           "-f", "mp4", probe]
    try:
        r = subprocess.run(cmd, capture_output=True, timeout=60)
        ok = r.returncode == 0 and os.path.exists(probe) and os.path.getsize(probe) > 0
        msg = "OK" if ok else r.stderr.decode("utf-8", "replace")[-300:]
    except Exception as e:
        ok, msg = False, str(e)
    finally:
        if os.path.exists(probe):
            try:
                os.remove(probe)
            except OSError:
                pass
    return ok, msg


def clean_saml_url(u):
    if not u:
        return None
    u = u.strip().strip("'\"<>")
    u = re.sub(r"(%27|%22|'|\")+$", "", u)
    return u


def main():
    ap = argparse.ArgumentParser(description="CyberArk PSM Recording Viewer v" + APP_VERSION)
    ap.add_argument("--pvwa", required=True)
    ap.add_argument("--auth", default="CyberArk",
                    choices=["CyberArk", "LDAP", "RADIUS", "Windows", "SAML"])
    ap.add_argument("--saml-url")
    ap.add_argument("--saml-helper")
    ap.add_argument("--saml-acs", action="store_true")
    ap.add_argument("--helper-timeout", type=int, default=300)
    ap.add_argument("--keepalive-interval", type=int, default=240,
                    help="Seconds between keepalive pings (default 240; 0 disables).")
    ap.add_argument("--lock-timeout", type=int, default=0,
                    help="Vault LockTimeout in minutes; enables countdown + early reauth prompt.")
    ap.add_argument("--fps", type=int, default=15,
                    help="Frame rate used ONLY by the constant-rate fallback (default 15). The fast "
                         "path keeps the source's variable frame rate, so this rarely matters.")
    ap.add_argument("--preset", default="veryfast",
                    help="libx264 preset (default veryfast). Use 'ultrafast' for a big speed-up on "
                         "screen content, or 'faster'/'fast' to trade speed for smaller files.")
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=8080)
    ap.add_argument("--insecure", action="store_true")
    ap.add_argument("--timeout", type=int, default=300)
    ap.add_argument("--ffmpeg", nargs="?", const="auto")
    ap.add_argument("--player")
    ap.add_argument("--cache")
    ap.add_argument("--no-idle", action="store_true")
    ap.add_argument("--idle-min", type=float, default=10.0)
    ap.add_argument("--idle-noise", default="-65dB")
    ap.add_argument("--idle-pad", type=float, default=3.0)
    args = ap.parse_args()

    ffpath, ffver, scpr, freeze, fferr = probe_ffmpeg(args.ffmpeg)
    idle_on = (not args.no_idle) and bool(ffpath) and (freeze is not False)
    saml_url = clean_saml_url(args.saml_url)
    helper, helper_err = resolve_helper(args.saml_helper)
    acs = "http://%s:%d/saml/acs" % ("127.0.0.1" if args.host in ("0.0.0.0", "") else args.host,
                                     args.port)
    cache = os.path.abspath(args.cache) if args.cache else CACHE_DIR

    CFG.update(pvwa=args.pvwa, auth=args.auth, verify=not args.insecure, timeout=args.timeout,
               ffmpeg=ffpath, ffmpeg_version=ffver, ffmpeg_error=fferr, scpr=scpr,
               player=args.player, idle=idle_on, idle_min=args.idle_min,
               idle_noise=args.idle_noise, idle_pad=max(0.0, args.idle_pad),
               fps=max(1, args.fps), preset=args.preset, saml_url=saml_url, saml_helper=helper,
               saml_helper_error=helper_err, acs_enabled=bool(args.saml_acs), acs=acs,
               helper_timeout=args.helper_timeout, keepalive=(args.keepalive_interval > 0),
               keepalive_interval=args.keepalive_interval, lock_timeout=max(0, args.lock_timeout),
               cache=cache)
    shutil.rmtree(CFG["cache"], ignore_errors=True)

    if not os.path.exists(TEMPLATE):
        print("ERROR: %s is missing." % TEMPLATE)
        sys.exit(1)
    tpl = open(TEMPLATE, "rb").read()

    print("=" * 74)
    print(" PSM Recording Viewer v%s  ->  http://%s:%d" % (APP_VERSION, args.host, args.port))
    print("=" * 74)
    print(" PVWA        : %s (%s)%s" % (args.pvwa, args.auth,
                                        "  [TLS validation OFF]" if args.insecure else ""))
    print(" Template    : %s" % ("v%s OK" % APP_VERSION if b"__APP_VERSION__" in tpl
                                 else "*** STALE - replace templates/index.html ***"))
    print(" Cache       : %s" % CFG["cache"])
    if CFG["keepalive"]:
        print(" Session     : keepalive every %ds%s" % (CFG["keepalive_interval"],
              ", LockTimeout %dm (countdown on)" % CFG["lock_timeout"] if CFG["lock_timeout"] else ""))
    else:
        print(" Session     : keepalive OFF - UI prompts reauth on 401.")
    if saml_url:
        print(" SAML        : ENABLED")
        if helper and not helper_err:
            print("   helper    : %s (WebView2, FIDO2 capable, no Entra changes)" % helper)
        elif helper_err:
            print("   helper    : *** %s" % helper_err)
        else:
            print("   helper    : not configured - pass --saml-helper for one-click sign-in")
    else:
        print(" SAML        : off  (pass --saml-url to enable)")
    if args.ffmpeg is None:
        print(" Transcoding : DISABLED - you did not pass --ffmpeg.")
    elif fferr:
        print(" Transcoding : DISABLED - %s" % fferr)
    else:
        print(" Transcoding : ENABLED  (%s)" % ffpath)
        print("   speed     : fast VFR path first (encodes only changed frames), preset=%s;"
              % CFG["preset"])
        print("               constant-rate (fps=%d) and fragmented MP4 are fallbacks." % CFG["fps"])
        if scpr is False:
            print("   scpr      : *** NOT FOUND *** use a full build from gyan.dev or BtbN")
        if idle_on:
            print("   idle skip : ON  (min %.0fs, noise %s, resume %.0fs early)"
                  % (args.idle_min, args.idle_noise, CFG["idle_pad"]))
        ok, msg = selftest()
        print("   mux test  : %s" % ("MP4 muxing OK" if ok else "*** FAILED *** " + msg))
    print(" Ctrl+C to stop.")
    print("=" * 74)

    threading.Thread(target=keepalive_loop, daemon=True).start()
    srv = ThreadedServer((args.host, args.port), Handler)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        logoff()
        shutil.rmtree(CFG["cache"], ignore_errors=True)
        print("\nSigned off and cache cleared.")


if __name__ == "__main__":
    main()

