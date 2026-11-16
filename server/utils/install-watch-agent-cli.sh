#!/usr/bin/env bash
# ==============================================================================
#  INSTALLER FOR watch-agent, watch-subagents & zedCheck
#  - Bare-Metal / Zero-Host-Install Rule compliant:
#      On bare-metal hosts, writes ONLY inside $HOME (~/.local/bin,
#      ~/.local/share/antigravity-tools, shell RCs, ~/.config/zed, ~/workspace/*/.zed).
#      Inside KVM Guest VMs ONLY (systemd-detect-virt --vm), also installs
#      /usr/local/bin/{watch-agent,watch-subagents,watch-subagent,zedCheck} so
#      already-open Zed Remote SSH terminal tabs resolve them immediately.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_DIR="${HOME}/.local/share/antigravity-tools"
BIN_DIR="${HOME}/.local/bin"

mkdir -p "$TOOLS_DIR" "$BIN_DIR"

if [ -f "${SCRIPT_DIR}/watch-agent-activity.sh" ]; then
    if [ "${SCRIPT_DIR}" != "${TOOLS_DIR}" ]; then
        cp "${SCRIPT_DIR}/watch-agent-activity.sh" "${TOOLS_DIR}/watch-agent-activity.sh"
    fi
    chmod +x "${TOOLS_DIR}/watch-agent-activity.sh"
fi

if [ -f "${SCRIPT_DIR}/watch-subagents.sh" ]; then
    if [ "${SCRIPT_DIR}" != "${TOOLS_DIR}" ]; then
        cp "${SCRIPT_DIR}/watch-subagents.sh" "${TOOLS_DIR}/watch-subagents.sh"
    fi
    chmod +x "${TOOLS_DIR}/watch-subagents.sh"
fi

cat > "${BIN_DIR}/watch-agent" <<'EOF'
#!/usr/bin/env bash
exec "${HOME}/.local/share/antigravity-tools/watch-agent-activity.sh" "$@"
EOF
chmod +x "${BIN_DIR}/watch-agent"

cat > "${BIN_DIR}/zedCheck" <<'EOF'
#!/usr/bin/env bash
exec "${HOME}/.local/share/antigravity-tools/watch-agent-activity.sh" "$@"
EOF
chmod +x "${BIN_DIR}/zedCheck"

cat > "${BIN_DIR}/watch-subagents" <<'EOF'
#!/usr/bin/env bash
exec "${HOME}/.local/share/antigravity-tools/watch-agent-activity.sh" --subagents-only "$@"
EOF
chmod +x "${BIN_DIR}/watch-subagents"

cat > "${BIN_DIR}/watch-subagent" <<'EOF'
#!/usr/bin/env bash
exec "${HOME}/.local/share/antigravity-tools/watch-agent-activity.sh" --subagents-only "$@"
EOF
chmod +x "${BIN_DIR}/watch-subagent"

# Inside Guest VMs ONLY (never bare-metal hosts), also install /usr/local/bin wrappers
# so already-open Zed terminal tabs with default PATH=/usr/local/bin:/usr/bin work immediately.
if command -v systemd-detect-virt >/dev/null 2>&1 && systemd-detect-virt --vm >/dev/null 2>&1; then
    if sudo -n true >/dev/null 2>&1; then
        sudo -n tee /usr/local/bin/watch-agent >/dev/null <<'VMEOF'
#!/usr/bin/env bash
if [ -x "${HOME}/.local/share/antigravity-tools/watch-agent-activity.sh" ]; then
    exec "${HOME}/.local/share/antigravity-tools/watch-agent-activity.sh" "$@"
fi
for cand in /home/*/.local/share/antigravity-tools/watch-agent-activity.sh; do
    [ -x "$cand" ] && exec "$cand" "$@"
done
echo "watch-agent-activity.sh not found" >&2; exit 1
VMEOF
        sudo -n tee /usr/local/bin/zedCheck >/dev/null <<'VMEOF'
#!/usr/bin/env bash
exec /usr/local/bin/watch-agent "$@"
VMEOF
        sudo -n tee /usr/local/bin/watch-subagents >/dev/null <<'VMEOF'
#!/usr/bin/env bash
exec /usr/local/bin/watch-agent --subagents-only "$@"
VMEOF
        sudo -n tee /usr/local/bin/watch-subagent >/dev/null <<'VMEOF'
#!/usr/bin/env bash
exec /usr/local/bin/watch-agent --subagents-only "$@"
VMEOF
        sudo -n chmod +x /usr/local/bin/watch-agent /usr/local/bin/zedCheck /usr/local/bin/watch-subagents /usr/local/bin/watch-subagent
    fi
fi

# Ensure ~/.local/bin & ~/.gemini/bin are at the TOP of ~/.bashrc (before interactive guard) + ~/.profile + zsh RCs
PYTHON_BIN="$(command -v python3 || echo /usr/bin/python3)"
"$PYTHON_BIN" - <<'PYCONF'
import glob, json, os, shutil

home = os.path.expanduser("~")
tools_watch = os.path.join(home, ".local", "share", "antigravity-tools", "watch-agent-activity.sh")
tools_sub = os.path.join(home, ".local", "share", "antigravity-tools", "watch-subagents.sh")
marker = "# Antigravity & Zed CLI PATH (watch-agent, watch-subagents, agy)"
snippet = f'{marker}\nexport PATH="$HOME/.local/bin:$HOME/.gemini/bin:$PATH"\n'

# 1. Prepend PATH export to ~/.bashrc (above non-interactive early return) & ensure in ~/.profile / ~/.zshenv / ~/.zshrc
for rc_name, prepend in ((".bashrc", True), (".profile", False), (".zshenv", True), (".zshrc", False)):
    rc_path = os.path.join(home, rc_name)
    if not os.path.isfile(rc_path) and rc_name in (".zshenv", ".zshrc"):
        continue
    cur = open(rc_path, "r", encoding="utf-8", errors="replace").read() if os.path.isfile(rc_path) else ""
    if marker not in cur:
        new_cur = (snippet + "\n" + cur) if prepend else (cur.rstrip() + "\n\n" + snippet)
        open(rc_path, "w", encoding="utf-8").write(new_cur)

# 2. Non-destructively update ~/.config/zed/settings.json (terminal.env.PATH + heal invalid tool_permissions 'default')
zed_dir = os.path.join(home, ".config", "zed")
os.makedirs(zed_dir, exist_ok=True)
settings_fp = os.path.join(zed_dir, "settings.json")
if os.path.isfile(settings_fp):
    try:
        raw_s = open(settings_fp, "r", encoding="utf-8").read()
        clean_s = "\n".join(ln for ln in raw_s.splitlines() if not ln.lstrip().startswith("//"))
        s_obj = json.loads(clean_s)
        if isinstance(s_obj, dict):
            changed = False
            ag = s_obj.get("agent")
            if isinstance(ag, dict) and isinstance(ag.get("tool_permissions"), dict):
                if ag["tool_permissions"].get("default") == "default":
                    ag["tool_permissions"]["default"] = "allow"
                    changed = True
            term = s_obj.setdefault("terminal", {})
            if isinstance(term, dict):
                env_d = term.setdefault("env", {})
                if isinstance(env_d, dict):
                    want_prefix = f"{home}/.local/bin:{home}/.gemini/bin"
                    cur_p = str(env_d.get("PATH") or "")
                    if want_prefix not in cur_p:
                        env_d["PATH"] = f"{want_prefix}:/opt/homebrew/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
                        changed = True
            if changed:
                open(settings_fp, "w", encoding="utf-8").write(json.dumps(s_obj, indent=2) + "\n")
    except Exception:
        pass

# 3. Helper to merge watch-agent, watch-subagents & zedCheck into any tasks.json
def _merge_tasks_file(t_path):
    existing = []
    if os.path.isfile(t_path):
        try:
            raw = open(t_path, "r", encoding="utf-8").read()
            cleaned = "\n".join(ln for ln in raw.splitlines() if not ln.lstrip().startswith("//"))
            parsed = json.loads(cleaned)
            if isinstance(parsed, list):
                existing = parsed
        except Exception:
            existing = []
    desired = [
        {
            "label": "zedCheck",
            "command": "bash",
            "args": ["-lc", "exec \"$HOME/.local/bin/watch-agent\""],
            "use_new_terminal": True,
            "allow_concurrent_runs": False,
            "reveal": "always",
        },
        {
            "label": "watch-agent (Unified Agent & Subagent Monitor)",
            "command": "bash",
            "args": ["-lc", "exec \"$HOME/.local/bin/watch-agent\""],
            "use_new_terminal": True,
            "allow_concurrent_runs": False,
            "reveal": "always",
        },
        {
            "label": "watch-subagents (Delegated Subagents Only)",
            "command": "bash",
            "args": ["-lc", "exec \"$HOME/.local/bin/watch-subagents\""],
            "use_new_terminal": True,
            "allow_concurrent_runs": False,
            "reveal": "always",
        },
    ]
    by_label = {str(t.get("label") or ""): t for t in existing if isinstance(t, dict)}
    for d in desired:
        by_label[d["label"]] = d
    open(t_path, "w", encoding="utf-8").write(json.dumps(list(by_label.values()), indent=2) + "\n")

_merge_tasks_file(os.path.join(zed_dir, "tasks.json"))

# 4. Ensure alt-shift-4 -> watch-subagents in ~/.config/zed/keymap.json (alongside alt-4 -> zedCheck)
keymap_fp = os.path.join(zed_dir, "keymap.json")
if os.path.isfile(keymap_fp):
    try:
        raw_k = open(keymap_fp, "r", encoding="utf-8").read()
        clean_k = "\n".join(ln for ln in raw_k.splitlines() if not ln.lstrip().startswith("//"))
        k_arr = json.loads(clean_k)
        if isinstance(k_arr, list) and k_arr and isinstance(k_arr[0], dict) and isinstance(k_arr[0].get("bindings"), dict):
            b = k_arr[0]["bindings"]
            if "alt-4" not in b:
                b["alt-4"] = ["task::Spawn", {"task_name": "zedCheck"}]
            b["alt-shift-4"] = ["task::Spawn", {"task_name": "watch-subagents (Delegated Subagents Only)"}]
            open(keymap_fp, "w", encoding="utf-8").write(json.dumps(k_arr, indent=2) + "\n")
    except Exception:
        pass

# 5. Refresh existing onboarded ~/workspace/*/.zed/watch-agent-activity.sh & tasks.json
ws_root = os.path.join(home, "workspace")
if os.path.isdir(ws_root) and os.path.isfile(tools_watch):
    for proj_zed in glob.glob(os.path.join(ws_root, "*", ".zed")) + glob.glob(os.path.join(ws_root, ".*", ".zed")):
        if not os.path.isdir(proj_zed) or os.path.basename(os.path.dirname(proj_zed)) in (".", ".."):
            continue
        try:
            dst_w = os.path.join(proj_zed, "watch-agent-activity.sh")
            shutil.copy2(tools_watch, dst_w)
            os.chmod(dst_w, 0o755)
            if os.path.isfile(tools_sub):
                dst_s = os.path.join(proj_zed, "watch-subagents.sh")
                shutil.copy2(tools_sub, dst_s)
                os.chmod(dst_s, 0o755)
            _merge_tasks_file(os.path.join(proj_zed, "tasks.json"))
        except Exception:
            pass
PYCONF

echo "INSTALLED_WATCH_CLI_OK:${BIN_DIR}/watch-agent,${BIN_DIR}/watch-subagents"
