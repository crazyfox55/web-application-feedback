# What EdubaWare gives an ICM with no admin setup

Everything here works for any template author or operator without API keys, MCP grants or org settings. Verified against EdubaWare master `369354dd` on 2026-10-26. **(unverified)** marks behaviour that lives outside the EdubaWare repo (Claude Agent SDK, Radzen) or that hasn't been tested.

"Workbench" means the classic workspace screen (`/workbenches/...`). "Preview screen" means the newer `/nova/w/...` screen; differences are noted.

---

## 1. How your folder is loaded

**Entry file goes into the system prompt.**
- The platform takes the first non-empty file among `CLAUDE.md`, `CONTEXT.md` and `ICM-GUIDE.md` in the workspace root and puts **only that file** into the system prompt. With a root `CLAUDE.md`, the root `CONTEXT.md` is *not* preloaded.
- It is cut at **20,000 characters**. Keep the entry file short and route elsewhere.
- If the root has none of the three, the platform looks inside the top-level folder, but only if exactly one qualifies (dot-folders, `workspace-inputs/` and the never-saved folders in section 3 don't count). With two or more, nothing is loaded.
- `AGENTS.md` isn't read directly. If the root has only one of `CLAUDE.md` / `AGENTS.md`, the platform creates the other as an alias, so either name works. Root only.
- The agent also loads the project's `.claude/` settings source, so `CLAUDE.md` probably arrives a second time as project memory and `.claude/settings.json` is probably honoured **(unverified)**.
- The prompt is built when the agent connects; edits to the entry file mid-chat may not show until it reconnects.

**Stage files are not auto-loaded.** `01_x/CONTEXT.md` and the like reach the agent only when it reads them, so the entry file must say where to go.

**Skills.** Skills under `.claude/skills/<name>/SKILL.md` at the workspace root are found, and the `Skill` tool is allowed. A top-level `skills/` folder is **not** found; the agent just reads it like any other file.

**No manifest.** EdubaWare reads no `icm.yaml`/`manifest.json`. Besides the entry file and `.claude/`, only the folder layout matters (input slots, section 4).

**Upload rules for a template zip** (every rule is a hard error):
- 2,000 files, 5 GB compressed, 10 GB uncompressed. No per-file cap and no banned extensions.
- A single top-level wrapper folder is stripped, but only if **every** entry is inside it. A stray root file or `__MACOSX/` folder stops the strip.
- Paths that differ only by case are refused, as are Windows reserved names (`con`, `nul.txt`, …), `..`, segments ending in a dot or space, and paths over 1,024 characters.
- Empty folders are dropped.

**Reserved name.** Don't name a folder `.platform/`: it is skipped at any depth. The platform keeps its own session files in the root `.platform/`.

---

## 2. What the agent can do in the container

- **Working directory:** the workspace root. All chats on one workbench share it.
- **Tools:** Read, Write, Edit, MultiEdit, Glob, Grep, LS, NotebookRead, NotebookEdit, Bash, WebFetch, WebSearch, Skill. Sub-agents (Agent/Task), Workflow, Cron, Monitor and messaging tools are switched off.
- **Per turn:** at most **100 agent steps** by default, and the chat reply is cut at **12,000 characters**. Put long results in files.
- **Software:** Python 3.12, Node 22 (pnpm, yarn), git, gh, curl, wget, rsync, tar, zip/unzip/7z, jq, yq, ripgrep, fd, uv. Playwright Chromium is installed without its system libraries, so it may not launch **(unverified)**. **No** pandas, openpyxl, python-pptx or LibreOffice. Anything installed during a session is lost when the container recycles. Plan for Python's standard library.
- **Network:** outbound internet is open; there is no proxy or allowlist. Secrets for private services come only through the External API proxy (admin setup).
- **Slash commands:** each user message is wrapped ("Current participant message: …") before it reaches the agent, so a typed `/command` probably never fires **(unverified)**.

---

## 3. Saving: what survives

- **Files are saved at the end of each completed turn.** A cancelled or failed turn isn't saved then; its files are picked up by the next completed turn only if the container hasn't recycled. Deleted files stay deleted.
- **These folders are never saved, at any depth, any case:** `build`, `dist`, `env`, `venv`, `.venv`, `node_modules`, `__pycache__`, `.git`, `.cache`, `.platform`, `.mypy_cache`, `.pytest_cache`, `.ruff_cache`, `.tox`. For example, `outputs/build/report.md` is **lost**, and a cloned repo comes back without `.git`. Empty folders and symlinks aren't saved either.
- **Each new workbench starts from a fresh copy** of the template version its deployment pins. Existing workbenches **never** move to a newer version.
- **Concurrent chats.** One chat runs one turn at a time, but separate chats on the same workbench (for example in a "One Workbench" deployment) can run turns at the same time on the same files. Last write wins.

---

## 4. Chat attachments → `workspace-inputs/`

- **Paperclip uploads** (Preview screen: "+" or drag-and-drop): an attached file lands at **`workspace-inputs/<original file name>`**, never renamed.
- **Inputs-panel uploads:** a file uploaded into an input *slot* lands at that slot's target path. Slots are inferred from top-level `inputs/`, `setup/` and `references/` folders that contain a file (for example `inputs/<name>`). Nested folders such as `stages/03/references/` make no slot.
- **The agent is told.** Its message gets this line added:
  `[workspace inputs] This message has N attached file(s). Available at: workspace-inputs/…`
  If the sync is still running, the line says so.
- **Limits:** 250 MB per file and 25 files per upload. Any file type is accepted, and ZIPs are **not** unpacked.
- **Clashes:**
  - Workbench: two attachments that resolve to the same path, ignoring case, are refused (identical names included). The Preview screen replaces the older copy instead.
  - An attachment at the exact path of a template file replaces it.
  - `<path>.backup` is kept only for agent edits not yet saved by a completed turn; a saved agent edit is overwritten without a backup.

---

## 5. Seeing and downloading files

Every saved file appears in the file tree. Clicking a file opens a preview drawer. Preview type is chosen **by extension only**:

| Extension | Shown as |
|---|---|
| `.html`, `.htm` | interactive **workbook** (section 6) |
| `.md`, `.markdown` | rendered markdown (section 7) |
| `.png .jpg .jpeg .gif .webp .bmp .ico` | image |
| `.svg` | image (section 8) |
| `.txt .json .yaml .yml .toml .ini .cfg .csv .log .xml .py .js .jsx .ts .tsx .cs .css .scss .razor .sh .sql .gitignore .env` | plain text, no syntax colouring |
| anything else (`.pdf`, `.docx`, `.xlsx`, `.jsonl`, `.tsv`, `.ipynb`, …) | download only |

**Limits:**
- Text previews stop at 750,000 bytes and show a "truncated" note.
- HTML, images and SVG over 10 MB aren't shown inline.
- The copy button appears only for text files under 1 MB that aren't truncated.
- **CSV is shown as plain text, not a table, and there's no PDF viewer.**

**Downloads:**
- Every preview has a Download link.
- **Export** downloads the whole workspace as a ZIP (everything except `.platform/`).
- The `outputs/` folder name is only a convention; it means nothing special to the platform.

**Linking between files.** A relative link in a markdown file, like `[next](../02_inputs/CONTEXT.md)`, or in an agent chat message (resolved from the workspace root), opens that file in the drawer.

**Preview screen:** previews workbooks, images and SVG like the workbench and intercepts relative links, but has no Export ZIP button.

---

## 6. Workbooks: interactive HTML

For when to add a workbook and how to make one that also works off EdubaWare, see `workbooks.md`.

**What makes a workbook.** Any file ending in `.html` or `.htm`, in **any folder**. There's no manifest or flag. It runs in a frame sandboxed with `allow-scripts` only: scripts run, but the page is cut off from the app and the network, and `alert`/`confirm`/`prompt`, popups (`target=_blank`) and downloads don't work.

### What a workbook may contain

| Allowed | Blocked |
|---|---|
| Inline `<script>`, `onclick=`, `eval` | `<script src="…">` (any external or sibling file) |
| Inline `<style>` and `style=""` | `<link rel=stylesheet href="…">` |
| Images, media and fonts as `data:` URIs | Images by URL (including sibling workspace files like `chart.png`) and `blob:` images |
| | `fetch`, XHR, WebSocket, form submits |

**So a workbook must be one self-contained file.** Have the agent bake its data into the HTML when writing it (for example a `<script>const DATA = {...}</script>` block), and inline images as `data:` URIs.

**Put scripts in `<body>`.** The bridge is inserted at the end of `<head>`, so a script before it can run before `window.eduba` exists. `DOMContentLoaded`/`load` may be held back up to 3 s while saved state loads.

### The `window.eduba` bridge

Calls return Promises. All except `chat.stage` time out after 15 s.

| Call | What it does |
|---|---|
| `eduba.ready(meta)` | Handshake. Optional. |
| `eduba.context.get()` | Returns `{organizationName, incubatorName}` for display; missing fields are omitted. |
| `eduba.ui.toast(text, level)` | Small popup for 4 s. `level`: `good`, `bad`, `warn`/`warning`, anything else is info. |
| `eduba.chat.stage(text)` | Opens a confirm dialog (workbench: *"This workbook wants to post to chat"*, Preview screen: *"Send this to the chat?"*) with **Discard** / **Send to chat**. On Send the text is posted as the user's message and the agent replies. Waits for the user: resolves on Send, rejects on Discard. **This is how a button "talks to" the agent.** |
| `eduba.chat.attachFile(name, text)` | Attaches a file to the user's **next** chat message (with a toast saying so). It lands at `workspace-inputs/<name>` (section 4). |
| `localStorage` / `eduba.storage.local` | Saved state (see below). `eduba.storage.ready` resolves `{persistent}` once it has loaded. |

**Example: a button that asks the agent something**

```html
<button id="go">Ask for interpretation</button>
<script>
  document.getElementById("go").addEventListener("click", async () => {
    if (!window.eduba) return;            // opened outside EdubaWare
    try {
      await window.eduba.chat.stage("Interpret outputs/analysis.json. State any limits.");
    } catch (e) { /* user discarded, or chat isn't available here */ }
  });
</script>
```

### Limits

- **`attachFile` names:** up to 128 characters of letters, digits, `.`, `-`, `_` and space; no `/`, `\` or `..`; extension one of `.md .txt .json .csv .html .htm .xml .yaml .yml`. A name already attached and not yet sent is refused.
- **Size:** each call's payload is capped at about **128 K characters** (after JSON encoding).
- **Rate:** about 20 calls in a burst, then 5 per second.
- **Saved state:**
  - `localStorage` is kept in **the user's browser**, per user and per file, never in the workspace. **The agent can't see it.**
  - Up to 512 K characters per workbook. The browser keeps at most 25 workbooks / 1.5 M characters; least recently used are dropped first.
  - Form fields are auto-saved and restored. Opt out with `data-eduba-autosave="off"` on a container.
  - `sessionStorage` is in memory only.
- **Size cut-offs:** above 8 MB the workbook still renders, but without `window.eduba` or saved state. Above 10 MB it's download-only.
- **Where the chat calls work:** the workbench drawer and the Preview screen. Through the Download link they do nothing. `window.eduba.chat` can exist where chat is unavailable, so treat a rejected call as "not available" rather than relying on `if (window.eduba)` alone.

---

## 7. Markdown

Markdown in chat messages and in `.md` file previews is rendered the same way.

- **Works:**
  - headings, bold and italic, lists, links, images, blockquotes, horizontal rules, inline code and code blocks;
  - **tables**, which are drawn as a data grid;
  - **raw HTML**, through a safety filter **(unverified: the filter lives in Radzen)**.
- **Not supported:** syntax highlighting (code blocks are plain); task-list checkboxes, footnotes, strikethrough and clickable heading anchors **(unverified)**.
- **Mermaid: not supported.** A ```` ```mermaid ```` block shows as plain code.
- **Math (LaTeX / KaTeX / MathJax): not supported.** `$x^2$` shows as typed.
- **Images in markdown:** `![](outputs/chart.png)` does **not** load the workspace file. To show a picture, have the user open the image file itself, or embed it as a `data:` URI inside an HTML workbook.
- The Preview screen strips YAML front matter from documents.

---

## 8. SVG

- **An `.svg` file** previews as a picture (an `<img>`), on both screens. Scripts and links inside it don't run.
- **Inline `<svg>` in markdown or chat** is probably stripped by the HTML filter **(unverified)**.
- **Inside a workbook**, inline `<svg>` markup is ordinary HTML and draws normally **(not tested)**.
