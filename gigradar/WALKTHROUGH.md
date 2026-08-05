# Build Walkthrough — node by node

GigRadar is a single n8n workflow: three source branches fan into one canonical stream, which is
deduped, scored by AI, gated, and drafted into cover letters. Nodes below are grouped by the four
stages on the canvas.

---

## Stage 1 — Fetch + normalize (3 sources)

### 1. Schedule Trigger
Fires the whole pipeline daily (`triggerAtHour: 8`). Fans out to all three source branches at once.
> Set the workflow **Timezone** (Settings → Timezone) if the exact run-hour matters — with none
> set, the hour is interpreted in the n8n instance's timezone.

### 2. HTTP Request  *(OnlineJobs.ph — self-scraped, free)*
`GET https://www.onlinejobs.ph/jobseekers/jobsearch?jobkeyword=n8n&…` with a browser `User-Agent`
header and **Response Format = Text**. OLJ's weak bot protection means no proxy/actor is needed.
Returns the raw search-results HTML as `data`.

### 3. [Code: Split]
Splits the HTML into one item per job card:
```js
return html.split('<!-- Start -->').slice(1).map(h => ({ json: { html: h } }));
```
Each job card on the page is fenced by `<!-- Start -->` / `<!-- End -->` comments. Splitting on
them avoids needing the `cheerio` external module (which n8n blocks unless
`NODE_FUNCTION_ALLOW_EXTERNAL=cheerio` is set on the host).

### 4. HTML  *(Extract, once per item)*
Pulls fields out of each card with CSS selectors: `url` (`a` → href attribute), `title` (`h4.fs-16`),
`type` (`h4 .badge`), `posted_at` (`p.fs-13` → `data-temp` attribute — already a clean timestamp),
`pay` (`dd.col`), `description` (`div.desc`), `skills` (`div.job-tag a.badge`, **Return Array on**).

### 5. Normalize ① (OLJ)  *(Code)*
Maps the extracted fields to the **canonical record** and does two cleanups OLJ needs:
- **Title bleed** — the job type sometimes rides along in the title (`"… Full Time"`); strip it.
- **Backslash URLs** — some hrefs use `\`; convert to `/` and make absolute.

```js
return items.map(item => {
  const j = item.json;
  let title = (j.title || '').replace(/\s+/g,' ').trim();
  const type = (j.type || '').trim();
  if (type && title.endsWith(type)) title = title.slice(0, -type.length).trim();
  let url = (j.url || '').replace(/\\/g,'/').trim();
  if (url && !/^https?:\/\//i.test(url)) url = 'https://www.onlinejobs.ph' + (url.startsWith('/')?'':'/') + url;
  let skills = Array.isArray(j.skills) ? j.skills : (j.skills ? [j.skills] : []);
  return { json: {
    id: null, source: 'onlinejobs', title, url, company: null,
    pay: (j.pay||'').trim() || null, type: type || null,
    posted_at: j.posted_at || null, description: (j.description||'').trim() || null,
    skills: skills.map(s => String(s).trim()).filter(Boolean),
  }};
});
```

### 6. HTTP Request1 → 7. Normalize ② (LinkedIn)  *(Apify)*
`POST https://api.apify.com/v2/acts/harvestapi~linkedin-job-search/run-sync-get-dataset-items?token=YOUR_APIFY_TOKEN`
with JSON body `{ "jobTitles": ["n8n","GoHighLevel","AI automation","Make.com"], "maxItems": 10, "sortBy": "date" }`.
`run-sync-get-dataset-items` runs the actor and returns its dataset in one call. Normalize ② maps
LinkedIn's shape: `title←title`, `url←linkedinUrl`, `company←company.name` (nested), `type←employmentType`,
`posted_at←postedDate`, `description←descriptionText`. LinkedIn has no skills array, so `skills←jobFunctions`.

### 8. HTTP Request2 → 9. Normalize ③ (Upwork)  *(Apify)*
Same Apify call shape against `chronometrica~upwork-job-scraper` (no-cookie — it never touches a
real Upwork account). Normalize ③ maps: `title←title`, `url←url`, `skills←skills` (a real array —
Upwork's is the richest), `posted_at←published_at`, `type←engagement_type`; `pay` is built from
`budget_amount` or the `hourly_min/max_amount` range; `company` is null (Upwork clients are anonymous).

---

## Stage 2 — Merge + dedupe ledger

### 10. Merge  *(Append, 3 inputs)*
Concatenates all three normalized branches into one stream. Because every branch emits the identical
canonical shape, everything downstream is source-agnostic.

### 11. Add id  *(Code)*
Stamps a stable id on each job — a **cyrb53** hash of `source|url` (pure JS; `require('crypto')` is
blocked in the n8n sandbox):
```js
function hashId(str){ let h1=0xdeadbeef,h2=0x41c6ce57;
  for(let i=0;i<str.length;i++){const c=str.charCodeAt(i);
    h1=Math.imul(h1^c,2654435761); h2=Math.imul(h2^c,1597334677);}
  h1=Math.imul(h1^(h1>>>16),2246822507)^Math.imul(h2^(h2>>>13),3266489909);
  h2=Math.imul(h2^(h2>>>16),2246822507)^Math.imul(h1^(h1>>>13),3266489909);
  return (h2>>>0).toString(16).padStart(8,'0')+(h1>>>0).toString(16).padStart(8,'0'); }
return items.map(it => { it.json.id = hashId(`${it.json.source}|${it.json.url}`); return it; });
```

### 12. Remove Duplicates
Operation **"Remove Items Processed in Previous Executions"**, Keep = **"Value Is New"**, value to
dedupe on = `{{ $json.id }}`. n8n persists the seen-ids in its own dedup store, so a job seen on any
prior run is dropped here — **before** the AI call, so seen jobs never cost anything. Its two
consumers hang off the kept output.

### 13. Append row in sheet  *(Google Sheets — the ledger)*
Appends every new job to the `seen` tab (`id · source · title · url · seen_at`) with
`seen_at = {{ $now.toISO() }}`. This is the human-readable audit trail; the dedup *mechanism* is
node 12.

---

## Stage 3 — AI scoring

### 14. Message a model  *(OpenAI `gpt-4o-mini`, temperature 0)*
Scores each new job against the profile. System prompt = the skill rubric (see
`prompts/scoring-prompt.txt`); user message passes the job's title/type/pay/skills/description.
**JSON output** → `{score, reasons[], red_flags[], matched_skills[]}`. Temperature 0 keeps scores
comparable run to run.

### 15. Attach score  *(Code)*
The OpenAI node returns only its own response and drops the job fields, so this re-joins them **by
index** (order is preserved 1:1):
```js
const jobs = $('Remove Duplicates').all();   // the deduped jobs
const ai   = $input.all();                    // the AI responses, same order
function parse(n){ let t = n.json?.output?.[0]?.content?.[0]?.text ?? n.json?.text ?? n.json;
  if (typeof t === 'string'){ try { t = JSON.parse(t); } catch(e){ t = {}; } } return t || {}; }
return jobs.map((job,i) => { const s = parse(ai[i]);
  return { json: { ...job.json,
    score: Number(s.score)||0,
    reasons: s.reasons||[], red_flags: s.red_flags||[], matched_skills: s.matched_skills||[] }};});
```
> The reference is `$('Remove Duplicates')` — the node that feeds the scorer. Point it at whatever
> node is the scorer's *input*, or the by-index pairing mis-aligns once dedup filters anything.

### 16. Log score  *(Google Sheets — the audit log)*
Appends **every** scored job (winners and losers) to the `scored` tab, joining the arrays to strings
(`{{ $json.red_flags.join(' | ') }}`). Keeping the rejects with their `reasons`/`red_flags` is what
lets you tune the rubric and threshold later.

### 17. If  *(score ≥ 70)*
Number condition `{{ $json.score }}` **is greater than or equal to** `70`. True → the drafter;
false → stop (still logged in `scored`).

---

## Stage 4 — Cover-letter drafter → Slack

### 18. Winners  *(No Operation)*
A pass-through that gives the ≥70 items a **stable node name** to reference from node 20 — the same
by-index re-join trick as Attach score, and it survives rewiring the branches.

### 19. Message a model1  *(OpenAI `gpt-4o-mini`)*
Drafts a proposal per winner. System prompt = `prompts/cover-letter-prompt.txt`: 90–140 words,
open with a concrete detail from *their* post, address the client as "you", a banned-phrases list to
kill AI fluff, and an **honesty rule** — only claim shipped builds, name real gaps. Left at default
temperature so the copy reads natural.

### 20. Attach draft  *(Code)*
Re-joins each draft to its job by index (`$('Winners').all()` paired with `$input.all()`), attaching
the proposal text as `proposal`.

### 21. Send a message  *(Slack → #gigradar)*
Posts each winner for human review:
```
*{{ $json.title }}*  ·  score {{ $json.score }}
{{ $json.url }}

{{ $json.proposal }}

_Matched: {{ $json.matched_skills.join(', ') }}_
```
**Never auto-submits** — a person reads the draft and decides whether to send.

---

## Error handling

The workflow's **Error Workflow** (Settings → Error Workflow) points at a separate
`GigRadar — Error Handler`: an Error Trigger → Slack node that posts the failing workflow, node,
and message to `#gigradar`. So a scraper breaking (OLJ changing its HTML, an Apify actor failing)
surfaces as a Slack alert instead of a silent dead run.

---

## Gotchas & lessons

- **n8n sandboxes Node built-ins** — `require('crypto')` and `cheerio` both throw "module disallowed"
  in Code nodes. Split HTML on comment markers; hash with hand-rolled cyrb53.
- **The OpenAI node drops your input fields** — always keep a way to re-join its output to the
  source item (here, by index off a stably-named upstream node).
- **Parsed JSON lands at `output[0].content[0].text`** on this OpenAI node — the Attach nodes dig
  there defensively (string-or-object).
- **Dedup belongs *before* the AI** — put it after the fetch and you pay to re-score seen jobs every
  run; put it before and a daily run only scores what's genuinely new.
- **Native dedup + a Sheets ledger** beat a Sheets-lookup-and-filter: the earlier cross-node-
  reference approach kept breaking on node-name mismatches; the native node is robust, and the sheet
  survives as the auditable record.
- **Temperature 0 for anything you compare** — at default temperature the same job's score drifted
  across the 70 threshold between runs.
- **Apify bills per result saved** — dedup only stops re-scoring, not the Apify charge, so keep
  `maxItems` modest and cap spend at the account level once a card is attached.
