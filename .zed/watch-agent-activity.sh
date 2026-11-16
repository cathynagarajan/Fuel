#!/usr/bin/env bash
# ==============================================================================
#  UNIFIED ANTIGRAVITY AGENT & SUBAGENT LIVE MONITOR (Zed IDE — Alt+4)
#  Single unified stream that watches in real time:
#    1. Main Agent conversation transcript.jsonl   -> labeled [AGENT    <id>]
#    2. Delegated Subagents (via invoke_subagent)  -> labeled [SUBAGENT <id>]
#    3. Inter-agent messages (send_message / handoffs)
#    4. Active background task logs (task-*.log)   -> labeled [AGENT/SUBAGENT <id>] [BG-LOG]
#
#  Usage:
#    watch-agent                        # Watch all active Agent & Subagent activity
#    watch-agent --subagents-only       # Watch ONLY delegated Subagents & handoffs
#    watch-subagents                    # Same as watch-agent --subagents-only
#    watch-agent <conv-id>              # Watch a specific conversation/subagent ID
#    watch-agent --status               # Non-blocking 1-shot status & subagent check
# ==============================================================================
set -u

BRAIN_DIR="${HOME}/.gemini/antigravity-cli/brain"
INVOKED_AS="$(basename "$0")"
FIRST_ARG="${1:-all}"
SECOND_ARG="${2:-}"

MODE_NAME="zedCheck"
SUBAGENTS_ONLY="0"

if [ "$INVOKED_AS" = "watch-subagents" ] || [ "$INVOKED_AS" = "watch-subagent" ] || [ "$INVOKED_AS" = "watch-subagents.sh" ]; then
    SUBAGENTS_ONLY="1"
    MODE_NAME="zedSubagents"
fi

if [ "$FIRST_ARG" = "--subagents-only" ] || [ "$FIRST_ARG" = "--subagents" ] || [ "$FIRST_ARG" = "subagents" ] || [ "$FIRST_ARG" = "-s" ]; then
    SUBAGENTS_ONLY="1"
    MODE_NAME="zedSubagents"
    TARGET_ARG="${SECOND_ARG:-all}"
else
    TARGET_ARG="$FIRST_ARG"
fi

USER_SAFE="$(id -un 2>/dev/null || echo "${USER:-dev}")"
PID_FILE="/tmp/${MODE_NAME}_${USER_SAFE}.pid"
TTY_FILE="/tmp/${MODE_NAME}_${USER_SAFE}.tty"

# Non-status interactive runs replace only the same user+mode monitor instance
if [ "$TARGET_ARG" != "--status" ] && [ "$TARGET_ARG" != "--once" ] && [ "$SECOND_ARG" != "--status" ] && [ "$SECOND_ARG" != "--once" ]; then
    if [ -f "$PID_FILE" ]; then
        OLD_PID="$(cat "$PID_FILE" 2>/dev/null || true)"
        if [ -n "$OLD_PID" ] && [ "$OLD_PID" != "$$" ]; then
            kill "$OLD_PID" 2>/dev/null || true
        fi
    fi
    printf "\033]0;%s\007" "$MODE_NAME"
    echo "$$" > "$PID_FILE" 2>/dev/null || true
    tty 2>/dev/null > "$TTY_FILE" || true
fi

PYTHON_BIN="$(command -v python3 || echo /usr/bin/python3)"
exec -a "$MODE_NAME" "$PYTHON_BIN" - "$BRAIN_DIR" "$TARGET_ARG" "$MODE_NAME" "$SUBAGENTS_ONLY" "$PID_FILE" "$SECOND_ARG" <<'PY'
import sys, os, glob, json, time, re, shutil, textwrap, subprocess
from datetime import datetime

brain_dir = sys.argv[1]
target_arg = sys.argv[2] if len(sys.argv) > 2 else "all"
mode_name = sys.argv[3] if len(sys.argv) > 3 else "zedCheck"
subagents_only = (sys.argv[4] == "1") if len(sys.argv) > 4 else False
pid_file = sys.argv[5] if len(sys.argv) > 5 else f"/tmp/{mode_name}.pid"
extra_arg = sys.argv[6] if len(sys.argv) > 6 else ""

status_only = target_arg in ("--status", "--once") or extra_arg in ("--status", "--once")
if target_arg in ("--subagents-only", "--subagents", "subagents", "-s"):
    subagents_only = True
    target_arg = "all"

target_conv = target_arg if (target_arg not in ("all", "--status", "--once") and not target_arg.startswith("-")) else None

if not status_only:
    my_pid = os.getpid()
    try:
        ps_lines = subprocess.check_output(["ps", "-eo", "pid,user,args"], text=True, stderr=subprocess.DEVNULL).splitlines()
        cur_user = os.environ.get("USER") or ""
        for pl in ps_lines:
            parts = pl.strip().split(None, 2)
            if len(parts) == 3 and parts[0].isdigit():
                pid_val = int(parts[0])
                p_user, p_args = parts[1], parts[2]
                if pid_val != my_pid and (not cur_user or p_user == cur_user):
                    if "antigravity-cli/brain" in p_args and f" {mode_name} " in f" {p_args} ":
                        try:
                            os.kill(pid_val, 15)
                        except Exception:
                            pass
    except Exception:
        pass

C_RESET  = "\033[0m"
C_BOLD   = "\033[1m"
C_DIM    = "\033[2m"
C_CYAN   = "\033[36m"
C_GREEN  = "\033[32m"
C_YELLOW = "\033[33m"
C_BLUE   = "\033[34m"
C_MAG    = "\033[35m"
C_RED    = "\033[31m"

UUID_RE = re.compile(r"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}", re.I)
ANSI_RE = re.compile(r"\x1b\[[0-9;]*[a-zA-Z]|\x1b\][^\x07]*\x07")

def get_term_cols():
    for fd in (1, 0, 2):
        try:
            c = os.get_terminal_size(fd).columns
            if c and c > 20:
                return c
        except Exception:
            pass
    return shutil.get_terminal_size((100, 24)).columns

def rule_line(ch="-"):
    cols = get_term_cols()
    return ch * max(40, min(92, cols - 2))

def ts():
    return datetime.now().strftime("%H:%M:%S")

import signal

def _handle_hangup(signum, frame):
    sys.exit(0)

for _sig in ("SIGHUP", "SIGTERM"):
    if hasattr(signal, _sig):
        try:
            signal.signal(getattr(signal, _sig), _handle_hangup)
        except Exception:
            pass

_brain_roots = [brain_dir]
_alt_brain = os.path.expanduser("~/.gemini/antigravity/brain")
if _alt_brain != brain_dir and os.path.isdir(_alt_brain):
    _brain_roots.append(_alt_brain)

def all_transcripts():
    seen_real = set()
    files = []
    for br in _brain_roots:
        for p in glob.glob(os.path.join(br, "*", ".system_generated", "logs", "transcript.jsonl")):
            rp = os.path.realpath(p)
            if rp not in seen_real:
                seen_real.add(rp)
                files.append(p)
    files.sort(key=os.path.getmtime, reverse=True)
    return files

def find_transcript_for_cid(cid):
    for br in _brain_roots:
        cand = os.path.join(br, cid, ".system_generated", "logs", "transcript.jsonl")
        if os.path.isfile(cand):
            return cand
    return os.path.join(brain_dir, cid, ".system_generated", "logs", "transcript.jsonl")

def active_qwen_sessions():
    qdir = os.path.expanduser("~/.gemini/config/qwen_state")
    active = []
    if os.path.isdir(qdir):
        for sf in sorted(glob.glob(os.path.join(qdir, "*.json")), key=os.path.getmtime, reverse=True)[:4]:
            try:
                data = json.load(open(sf, "r", encoding="utf-8"))
                if data.get("enabled"):
                    active.append(f"{os.path.basename(sf)[:8]} ({data.get('target', 'spark')})")
            except Exception:
                pass
    return active

conv_meta = {}
seen_steps = {}
seen_parts = {}
task_offsets = {}

def discover_subagents_from_transcript(t_path, parent_id):
    """Scan a transcript for invoke_subagent calls and tool results to label child conversations."""
    pending_roles = []
    try:
        with open(t_path, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                try:
                    obj = json.loads(line)
                except Exception:
                    continue
                for tc in (obj.get("tool_calls") or []):
                    tname = tc.get("name") or tc.get("tool_name") or ""
                    if tname == "invoke_subagent":
                        args = tc.get("arguments") or tc.get("args") or {}
                        if isinstance(args, str):
                            try:
                                args = json.loads(args)
                            except Exception:
                                args = {}
                        role = args.get("Role") or args.get("TypeName") or "Subagent"
                        pending_roles.append(role)
                content = obj.get("content") or ""
                if pending_roles and ("conversationId" in content or "Subagent" in content or "subagent" in content or obj.get("truncated_fields")):
                    scan_text = content
                    if not UUID_RE.findall(scan_text) and obj.get("truncated_fields"):
                        full_p = t_path.replace("transcript.jsonl", "transcript_full.jsonl")
                        if os.path.isfile(full_p):
                            try:
                                scan_text = open(full_p, "r", encoding="utf-8", errors="replace").read(262144)
                            except Exception:
                                pass
                    for m in UUID_RE.findall(scan_text):
                        if m != parent_id and m not in conv_meta:
                            role_label = pending_roles.pop(0)
                            conv_meta[m] = {
                                "role": role_label,
                                "is_subagent": True,
                                "parent": parent_id,
                            }
                            if not pending_roles:
                                break
                # Also detect [Message] ... sender=<uuid> subagent replies
                if "sender=" in content and ("subagent" in content.lower() or "conversation" in content.lower()):
                    for sm in re.findall(r"sender=([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})", content, re.I):
                        if sm != parent_id and sm not in conv_meta:
                            conv_meta[sm] = {"role": "Subagent", "is_subagent": True, "parent": parent_id}
    except Exception:
        pass

t_files = all_transcripts()
for tf in t_files[:20]:
    cid = os.path.basename(os.path.dirname(os.path.dirname(os.path.dirname(tf))))
    discover_subagents_from_transcript(tf, cid)

if status_only:
    sub_items = [
        {"id": cid, "role": m.get("role", "Subagent"), "parent": m.get("parent")}
        for cid, m in conv_meta.items() if m.get("is_subagent")
    ]
    primary_cid = ""
    if t_files:
        primary_cid = os.path.basename(os.path.dirname(os.path.dirname(os.path.dirname(t_files[0]))))
    print(json.dumps({
        "ok": True,
        "mode": "subagents_only" if subagents_only else "unified",
        "session_name": mode_name,
        "brain_dir": brain_dir,
        "transcript_count": len(t_files),
        "active_agent": primary_cid,
        "discovered_subagents": sub_items,
        "active_qwen_sessions": active_qwen_sessions(),
    }, indent=2))
    sys.exit(0)

print(f"\033[2J\033[H\033]0;{mode_name}\007", end="", flush=True)
print(rule_line("="), flush=True)
try:
    with open(pid_file, "w", encoding="utf-8") as pf:
        pf.write(str(os.getpid()))
except Exception:
    pass

if subagents_only:
    print(f"{C_BOLD}{C_MAG}  ANTIGRAVITY DELEGATED SUBAGENTS LIVE MONITOR [Session: watch-subagents]{C_RESET}", flush=True)
    print(f"  Filter: {C_BOLD}{C_MAG}[SUBAGENT]{C_RESET} steps, {C_MAG}invoke_subagent{C_RESET} spawns & {C_MAG}send_message{C_RESET} handoffs only", flush=True)
else:
    print(f"{C_BOLD}{C_CYAN}  ANTIGRAVITY UNIFIED AGENT & SUBAGENT LIVE MONITOR [Session: {mode_name}]{C_RESET}", flush=True)
    print(f"  Badges: {C_BOLD}{C_CYAN}[AGENT]{C_RESET} = Main Agent | {C_BOLD}{C_MAG}[SUBAGENT]{C_RESET} = Delegated Subagent", flush=True)
q_active = active_qwen_sessions()
if q_active:
    print(f"  Qwen Bridge: {C_GREEN}{', '.join(q_active)}{C_RESET}", flush=True)
print(rule_line("="), flush=True)

if not t_files:
    print(f"{C_YELLOW}  [STANDBY] Waiting for Antigravity conversation in {brain_dir}...{C_RESET}", flush=True)
    while not t_files:
        time.sleep(2.5)
        t_files = all_transcripts()
    print(f"{C_GREEN}  [CONNECTED] Detected active Antigravity conversation — streaming live activity...{C_RESET}", flush=True)

for tf in t_files[:20]:
    cid = os.path.basename(os.path.dirname(os.path.dirname(os.path.dirname(tf))))
    discover_subagents_from_transcript(tf, cid)

primary_t = t_files[0]
primary_conv_dir = os.path.dirname(os.path.dirname(os.path.dirname(primary_t)))
primary_id = os.path.basename(primary_conv_dir)

if target_conv:
    primary_id = target_conv
    if primary_id not in conv_meta:
        conv_meta[primary_id] = {"role": "Agent", "is_subagent": False, "parent": None}
elif primary_id not in conv_meta:
    conv_meta[primary_id] = {"role": "Agent", "is_subagent": False, "parent": None}

print(f"  Active Agent : {C_BOLD}{C_CYAN}{primary_id[:18]}{C_RESET}", flush=True)
all_subs = [f"{cid[:8]} ({m['role']})" for cid, m in conv_meta.items() if m.get("is_subagent")]
if all_subs:
    print(f"  Subagents    : {C_MAG}{', '.join(all_subs[:5])}{C_RESET}", flush=True)
else:
    wait_note = "Standing by — will stream immediately when invoke_subagent is called" if subagents_only else "None yet (auto-attaches on invoke_subagent)"
    print(f"  Subagents    : {C_DIM}{wait_note}{C_RESET}", flush=True)
print(rule_line("-"), flush=True)

def badge_for(conv_id, compact=False):
    meta = conv_meta.get(conv_id, {})
    if compact:
        short = conv_id[:4]
        if meta.get("is_subagent"):
            return f"{C_BOLD}{C_MAG}[SUB {short}]{C_RESET}"
        return f"{C_BOLD}{C_CYAN}[AGY {short}]{C_RESET}"
    short = conv_id[:8]
    if meta.get("is_subagent"):
        return f"{C_BOLD}{C_MAG}[SUBAGENT {short}]{C_RESET}"
    return f"{C_BOLD}{C_CYAN}[AGENT    {short}]{C_RESET}"

def make_prefix(conv_id, idx, color, icon_label_wide, icon_label_compact):
    cols = get_term_cols()
    label = (icon_label_compact if cols < 85 else icon_label_wide).strip()
    b = badge_for(conv_id, compact=(cols < 85))
    return f"[{ts()}] {b} [S{idx}] {color}{label}{C_RESET}:"

def print_wrapped(prefix, msg_text, color_cont=""):
    cols = get_term_cols()
    indent_str = "  "
    avail = max(24, cols - len(indent_str) - 2)
    print(prefix, flush=True)
    clean_text = " ".join(ln.strip() for ln in (msg_text or "").splitlines() if ln.strip())
    if len(clean_text) > 320:
        clean_text = clean_text[:317] + "..."
    if not clean_text:
        return
    wrapped = textwrap.wrap(clean_text, width=avail, break_long_words=True, break_on_hyphens=False)
    if not wrapped:
        wrapped = [clean_text[:avail]]
    for line_part in wrapped:
        print(f"{indent_str}{color_cont}{line_part}{C_RESET if color_cont else ''}", flush=True)

def format_step(conv_id, obj):
    meta = conv_meta.get(conv_id, {})
    is_sub = bool(meta.get("is_subagent", False))
    role_prefix = f"[{meta.get('role', 'Subagent')}] " if is_sub and meta.get("role") else ""

    idx = obj.get("step_index", "?")
    stype = obj.get("type", "")
    source = obj.get("source", "")
    content = (obj.get("content") or "").strip()
    thinking = (obj.get("thinking") or "").strip()
    tcalls = obj.get("tool_calls") or []
    parts_done = seen_parts.setdefault((conv_id, idx), set())

    if stype in ("USER_INPUT", "SYSTEM_MESSAGE"):
        if "input" in parts_done:
            return
        is_subagent_handoff = ("subagent" in content.lower() or "conversationId" in content)
        if subagents_only and not is_sub and not is_subagent_handoff:
            parts_done.add("input")
            return
        parts_done.add("input")
        if "<SYSTEM_MESSAGE>" in content and "Task id" in content:
            prefix = make_prefix(conv_id, idx, f"{C_BOLD}{C_GREEN}", "🔔 BG TASK DONE    ", "🔔 BG DONE ")
            print_wrapped(prefix, "Background command finished -> resumed")
        elif is_subagent_handoff:
            first = content.replace("<SYSTEM_MESSAGE>", "").replace("</SYSTEM_MESSAGE>", "").strip().splitlines()[0] if content else ""
            prefix = make_prefix(conv_id, idx, f"{C_BOLD}{C_MAG}", "🤝 SUBAGENT MSG    ", "🤝 SUB MSG ")
            print_wrapped(prefix, first)
        else:
            clean = content.split("<ADDITIONAL_METADATA>")[0].replace("<USER_REQUEST>", "").replace("</USER_REQUEST>", "").strip()
            clean_lines = [ln.strip() for ln in clean.splitlines() if ln.strip()]
            user_msg = " ".join(clean_lines) if clean_lines else ""
            lbl_w = "🎯 SUBAGENT PROMPT " if is_sub else "👤 USER INPUT      "
            lbl_c = "🎯 PROMPT  " if is_sub else "👤 INPUT   "
            prefix = make_prefix(conv_id, idx, f"{C_BOLD}{C_BLUE}", lbl_w, lbl_c)
            print_wrapped(prefix, f"{role_prefix}{user_msg}")

    elif stype == "PLANNER_RESPONSE":
        if thinking and "thinking" not in parts_done:
            parts_done.add("thinking")
            if not subagents_only or is_sub:
                first_t = " ".join(ln.strip() for ln in thinking.splitlines() if ln.strip())
                prefix = make_prefix(conv_id, idx, C_MAG, "🧠 THINKING        ", "🧠 THINK   ")
                print_wrapped(prefix, f"{role_prefix}{first_t}")
        for tc_i, tc in enumerate(tcalls):
            tc_key = f"tool_{tc_i}"
            if tc_key in parts_done:
                continue
            parts_done.add(tc_key)
            tname = tc.get("name") or tc.get("tool_name") or "tool"
            args = tc.get("arguments") or tc.get("args") or {}
            if isinstance(args, str):
                try:
                    args = json.loads(args)
                except Exception:
                    args = {}
            if tname == "invoke_subagent":
                role = args.get("Role") or "Subagent"
                t_type = args.get("TypeName") or "self"
                prompt_preview = " ".join(ln.strip() for ln in (args.get("Prompt") or "").strip().splitlines() if ln.strip())
                prefix = make_prefix(conv_id, idx, f"{C_BOLD}{C_MAG}", "🚀 SPAWN SUBAGENT  ", "🚀 SPAWN   ")
                print_wrapped(prefix, f"{role} (type={t_type}) — {prompt_preview}")
            elif tname in ("send_message", "define_subagent", "manage_subagents"):
                rcpt = (args.get("Recipient") or args.get("Name") or args.get("Action") or "")[:18]
                msg = " ".join(ln.strip() for ln in (args.get("Message") or args.get("Description") or "").splitlines() if ln.strip())
                prefix = make_prefix(conv_id, idx, C_MAG, "📨 SUBAGENT COORD  ", "📨 COORD   ")
                print_wrapped(prefix, f"{tname} -> {rcpt} ({msg})" if msg else f"{tname} ({rcpt})")
            elif not subagents_only or is_sub:
                summary = args.get("toolSummary") or args.get("Path") or args.get("Action") or args.get("query") or ""
                prefix = make_prefix(conv_id, idx, C_YELLOW, "⚙️  TOOL CALL       ", "⚙️  TOOL    ")
                tool_text = f'{tname} ("{summary}")' if summary else f'{tname} ()'
                print_wrapped(prefix, tool_text)
        if content and "content" not in parts_done:
            parts_done.add("content")
            if not subagents_only or is_sub:
                first_c = content.splitlines()[0]
                lbl_w = "🏁 SUBAGENT DONE   " if is_sub else "✅ AGENT REPLY     "
                lbl_c = "🏁 SUB DONE" if is_sub else "✅ REPLY   "
                prefix = make_prefix(conv_id, idx, C_GREEN, lbl_w, lbl_c)
                print_wrapped(prefix, f"{role_prefix}{first_c}")
                if not is_sub:
                    idle_pfx = make_prefix(conv_id, idx, f"{C_BOLD}{C_CYAN}", "⏸️  STATE           ", "⏸️  STATE   ")
                    print_wrapped(idle_pfx, "IDLE — Waiting for user input")
                print(rule_line("-"), flush=True)

    elif "TOOL" in stype or source == "TOOL" or stype == "GENERIC":
        if "running as a background task" in content and "bgtask" not in parts_done:
            parts_done.add("bgtask")
            if not subagents_only or is_sub:
                prefix = make_prefix(conv_id, idx, C_YELLOW, "⏳ BG TASK STARTED ", "⏳ BG START")
                print_wrapped(prefix, "Streaming live log lines below...")

def _line_has_subagent_event(cid, raw_line):
    if conv_meta.get(cid, {}).get("is_subagent"):
        return True
    if any(k in raw_line for k in ("invoke_subagent", "send_message", "define_subagent", "manage_subagents", "conversationId")):
        return True
    return False

initial_printed = [0]
_orig_print_wrapped = print_wrapped
def print_wrapped(prefix, msg_text, color_cont=""):
    initial_printed[0] += 1
    return _orig_print_wrapped(prefix, msg_text, color_cont)

initial_convs = [primary_id] + [cid for cid, m in conv_meta.items() if cid != primary_id and m.get("is_subagent")]
for cid in initial_convs:
    tp = find_transcript_for_cid(cid)
    if not os.path.exists(tp):
        continue
    try:
        with open(tp, "r", encoding="utf-8", errors="replace") as f:
            lines = f.readlines()
        if subagents_only and not conv_meta.get(cid, {}).get("is_subagent"):
            sub_indices = [idx_i for idx_i, rl in enumerate(lines) if _line_has_subagent_event(cid, rl)]
            replay_set = set(sub_indices[-10:])
            for idx_i, l in enumerate(lines):
                try:
                    o = json.loads(l)
                    sidx = o.get("step_index")
                    seen_steps[(cid, sidx)] = (o.get("status"), len(l))
                    if idx_i in replay_set:
                        format_step(cid, o)
                    else:
                        seen_parts[(cid, sidx)] = {"input", "thinking", "content", "bgtask"} | {f"tool_{i}" for i in range(len(o.get("tool_calls") or []))}
                except Exception:
                    pass
        else:
            tail_count = 8 if conv_meta.get(cid, {}).get("is_subagent") else 5
            for l in lines[:-tail_count]:
                try:
                    o = json.loads(l)
                    sidx = o.get("step_index")
                    seen_steps[(cid, sidx)] = (o.get("status"), len(l))
                    seen_parts[(cid, sidx)] = {"input", "thinking", "content", "bgtask"} | {f"tool_{i}" for i in range(len(o.get("tool_calls") or []))}
                except Exception:
                    pass
            for l in lines[-tail_count:]:
                try:
                    o = json.loads(l)
                    sidx = o.get("step_index")
                    seen_steps[(cid, sidx)] = (o.get("status"), len(l))
                    format_step(cid, o)
                except Exception:
                    pass
    except Exception:
        pass
    cdir_init = os.path.dirname(os.path.dirname(os.path.dirname(tp)))
    for tl in glob.glob(os.path.join(cdir_init, ".system_generated", "tasks", "task-*.log")):
        try:
            task_offsets[tl] = os.path.getsize(tl)
        except Exception:
            pass

if subagents_only and initial_printed[0] == 0:
    print(f"  [{ts()}] {C_BOLD}{C_MAG}[WATCH-SUBAGENTS]{C_RESET} 📡 Live listener ready — waiting for {C_MAG}invoke_subagent{C_RESET} / {C_MAG}[SUBAGENT]{C_RESET} activity (Ctrl+C to stop)...", flush=True)

startup_mtime = time.time()

while True:
    try:
        current_files = all_transcripts()
        for tp in current_files[:12]:
            cdir = os.path.dirname(os.path.dirname(os.path.dirname(tp)))
            cid = os.path.basename(cdir)
            discover_subagents_from_transcript(tp, cid)

        for tp in current_files[:12]:
            try:
                mtime = os.path.getmtime(tp)
            except Exception:
                continue
            cdir = os.path.dirname(os.path.dirname(os.path.dirname(tp)))
            cid = os.path.basename(cdir)
            if target_conv and cid != target_conv:
                continue
            if cid not in conv_meta and mtime < startup_mtime - 5:
                continue

            if cid not in conv_meta:
                conv_meta[cid] = {"role": "Agent", "is_subagent": False, "parent": None}
                if not subagents_only:
                    print(f"\n  [{ts()}] {C_BOLD}{C_CYAN}[AGENT    {cid[:8]}]{C_RESET} 🔗 Attached to new main Agent session: {cid}", flush=True)

            is_sub_conv = bool(conv_meta.get(cid, {}).get("is_subagent", False))

            try:
                with open(tp, "r", encoding="utf-8", errors="replace") as f:
                    for l in f:
                        try:
                            o = json.loads(l)
                            sidx = o.get("step_index")
                            key = (o.get("status"), len(l))
                            if seen_steps.get((cid, sidx)) != key:
                                seen_steps[(cid, sidx)] = key
                                format_step(cid, o)
                        except Exception:
                            pass
            except Exception:
                pass

            if not subagents_only or is_sub_conv:
                for tl in glob.glob(os.path.join(cdir, ".system_generated", "tasks", "task-*.log")):
                    try:
                        sz = os.path.getsize(tl)
                        prev = task_offsets.get(tl, 0)
                        if tl not in task_offsets:
                            task_offsets[tl] = 0
                            prev = 0
                            prefix_open = make_prefix(cid, "BG", C_YELLOW, "📂 STREAMING LOG   ", "📂 BG LOG  ")
                            print_wrapped(prefix_open, os.path.basename(tl))
                        if sz > prev:
                            with open(tl, "r", encoding="utf-8", errors="replace") as tf:
                                tf.seek(prev)
                                chunk = tf.read()
                                task_offsets[tl] = tf.tell()
                            for tline in chunk.splitlines():
                                tline_s = tline.strip()
                                if tline_s:
                                    prefix = make_prefix(cid, "BG", C_DIM, "📄 TASK OUTPUT     ", "📄 OUTPUT  ")
                                    print_wrapped(prefix, tline_s)
                    except Exception:
                        pass

        time.sleep(0.4)
    except (KeyboardInterrupt, BrokenPipeError, EOFError):
        label_stop = "Delegated Subagents Monitor" if subagents_only else "Unified Agent & Subagent Monitor"
        print(f"\n{C_CYAN}Stopped {label_stop}.{C_RESET}", flush=True)
        break
PY
