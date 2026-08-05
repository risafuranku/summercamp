# Beeternet Pages

Create new pages as plain `.html` files in this folder.

## URL routing

- `home://start` -> `home.html`
- `camp://downloads` -> `downloads.html`
- `camp://<slug>` -> `<slug>.html` (automatic fallback)
- `page://<slug>` -> `<slug>.html` (automatic fallback)

Examples:

- `camp://news` -> `news.html`
- `page://faq/install` -> `faq/install.html`

## Supported HTML

Renderer supports lightweight tags:

- `h1`, `h2`, `h3`
- `p`, `br`, `hr`
- `ul`, `li`
- `strong`, `b`, `em`, `i`, `code`
- `a href="..."`
- `span class="ok|warn|muted|alert"`

## Template placeholders

- `{{URL}}`
- `{{REQUESTED_URL}}`
- `{{PROGRAM_LIST}}`
- `{{GUEST_REVIEWS}}`
- `{{MIRROR_STATUS}}`
- `{{DOWNLOAD_COUNT}}`
