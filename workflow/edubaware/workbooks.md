# Workbooks in an ICM folder

A workbook is one `.html` page that your folder's AI writes and a person opens: to check something, choose, fill in or arrange it, then hand the result back. It's an ordinary ICM file. It lives in a stage, a `CONTEXT.md` says when to make it and what comes back, and it works on any platform that can open a web page. On EdubaWare it gets extra powers (section 5). Elsewhere it falls back to a download.

---

## 1. When a workbook earns its place

Add one where a person has to **do something** at a handoff, and doing it in chat would be clumsy:

| The handoff | Workbook | What comes back |
|---|---|---|
| Sam checks this week's numbers | the table, with a tick and a comment per row | `checked-stock.json` |
| Priya picks 3 of 12 draft headlines | cards to pick from | `picks.json` |
| Arrange the seating plan | drag-and-drop tables | `layout.json` |
| Fill in the event details | a short form | `event-details.md` |

Don't add one just to show results. A `.md` file does that, and it renders everywhere. One workbook per handoff is plenty.

---

## 2. Where it lives (ordinary ICM)

- **In the stage that uses it.** The stage's `CONTEXT.md` says:
  - when to write the workbook and where (for example `02-review/output/review.html`);
  - what data to bake into it;
  - the **action** the person takes, and the file that comes back (`checked-stock.json`);
  - where to look for that file, and what to do with it next.
- **A starter page** can sit in the stage (for example `02-review/review-template.html`). The AI copies it and fills in the data block, so it doesn't redesign the page every run.
- **The handoff is still a pause.** The next stage starts only once the file is back. If nothing comes back, the stage says what to do (ask again, or carry on without it, and how).
- **Name the file once and use the same name everywhere:** in the stage's `CONTEXT.md`, in the page's action, and in the next stage's inputs.

Example lines for a stage `CONTEXT.md`:

```markdown
5. Write `output/review.html` from `review-template.html`: put this week's rows
   into its `data` block. Tell Sam to open it and press **Save checks**.
6. Pause. Sam's checks come back as `checked-stock.json` (attached in chat, or
   uploaded). Don't go on without it. Rows Sam didn't tick are "not checked".
```

---

## 3. Rules that make it portable

1. **One self-contained file.** CSS and JS go inline. No `<script src>`, no stylesheet links, no web fonts, no images by URL (not even a picture next to it). Inline images as `data:` URIs.
2. **Bake the data in** when the AI writes the page:
   `<script type="application/json" id="data">{ ... }</script>`. Don't load it with `fetch`.
3. **Scripts go at the end of `<body>`.**
4. **No network.** No `fetch`, form posts or trackers. Results leave as a file, through an action.
5. **No browser dialogs or new tabs.** `alert`/`confirm`/`prompt` and `target=_blank` don't work in EdubaWare's sandboxed frame. Show messages in the page.
6. **It must still work without storage.** Saved drafts are a bonus, never the only copy.
7. **Keep it under about 1 MB.** Big pages lose their extras on some platforms (EdubaWare: 8 MB).
8. **Stand-in data only**, and no passwords or keys in the page, ever.

---

## 4. Actions: named after the job, not the platform

A button says what the person is doing in **your** workflow: **Save layout**, **Approve draft**, **Send picks**, **Save checks**. Never "Send to chat", "Attach" or "Download JSON": those name the plumbing, and the plumbing changes from platform to platform.

Every action is the same three things:

- a **file** (name and contents) that holds the result;
- a **one-line instruction** for the AI ("Save the layout from layout.json to output/layout.json");
- a **label** for the button.

Then one helper delivers it, whatever the platform:

```html
<button type="button" id="save">Save layout</button>
<p id="next" hidden></p>
<pre id="copy" hidden></pre>

<script>
  // One action = a file + an instruction. EdubaWare: attach and ask.
  // Opened from disk: download the file. Framed without the bridge (downloads
  // are blocked there): show the text to copy into the chat.
  async function act(file, contents, instruction) {
    if (window.eduba && window.eduba.chat) {
      try {
        await window.eduba.chat.attachFile(file, contents);
        await window.eduba.chat.stage(instruction);
        return;
      } catch (e) { /* unavailable or discarded: fall through */ }
    }
    const next = document.getElementById("next");
    if (window.parent !== window) {
      next.textContent = `Copy this into the chat: "${instruction}" followed by:`;
      const copy = document.getElementById("copy");
      copy.textContent = contents;
      copy.hidden = false;
    } else {
      const a = document.createElement("a");
      a.href = URL.createObjectURL(new Blob([contents], { type: "text/plain" }));
      a.download = file;
      a.click();
      next.textContent = `Downloaded ${file}. Give it to your AI and say: "${instruction}"`;
    }
    next.hidden = false;
  }

  document.getElementById("save").addEventListener("click", () => {
    const layout = { tables: [] /* read from the page */ };
    act("layout.json", JSON.stringify(layout, null, 2),
        "Save the layout from layout.json to output/layout.json");
  });
</script>
```

- **Actions with no file** (for example "Next stage") pass the instruction only: `stage(instruction)` on EdubaWare, and elsewhere show the instruction to type or paste.
- **The person always confirms.** On EdubaWare, nothing is sent until they press the platform's confirm button; `stage` waits for that choice. Elsewhere, they upload the file and type the line themselves.
- **File names** use letters, digits, `-`, `_` and `.`, with an extension of `.json`, `.md`, `.txt`, `.csv` or `.yaml` (a portable subset of what EdubaWare accepts). Keep contents under about 100 K characters.

---

## 5. Platform notes

| | What a workbook can do there |
|---|---|
| **EdubaWare** | Opens interactive in the workbench file drawer and the Preview screen. Actions attach the file and post the instruction after the person confirms, and the file arrives at `workspace-inputs/<file>`. Form fields are saved per person. Full limits: `edubaware-integrations.md` §6. |
| **Claude Code, Cursor and other local agents** | The person opens the file in a browser. Actions download it, and the person moves it into the folder (or tells the AI where it is). |
| **A chat app with file upload** | Opens in a browser after download. Actions download it, and the person uploads it with the instruction. |
| **No browser at all** | The stage still works if its `CONTEXT.md` also accepts the result typed in chat ("or paste the checks as a list"). |

So the stage's "where to look" line should cover more than one platform: *"`checked-stock.json`: in the attached files, or wherever the person says they put it."*

---

## 6. Checklist

- [ ] The page sits at a handoff where a person does something, not just reads.
- [ ] The stage's `CONTEXT.md` says when to write it, what data goes in, the action, the file that comes back, and what to do without it.
- [ ] Every button is named after the job, and each action is a file plus an instruction.
- [ ] One file: no external scripts, styles, fonts, images or `fetch`. Data is baked in. Scripts are at the end of `<body>`. No `alert` or new tabs.
- [ ] It works when opened straight from disk: try it, and the action downloads.
- [ ] Stand-in data, no secrets, under about 1 MB.
