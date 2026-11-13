# The host API: `koona`

Your script runs in a sandbox with the standard Luau libraries the app keeps (see
[limits.md](limits.md#what-a-script-does-not-have)) and one table of its own, `koona`. Everything
your script does outside its own memory goes through `koona`: the network, JSON, XML, CSV, dates,
addresses, the add-on's secrets, the progress bar and the add-on's log.

These are all of its functions:

<!-- generated:host-functions -->
| Function | Since API level |
| --- | --- |
| `koona.http.request` | 1 |
| `koona.http.upload` | 1 |
| `koona.json.decode` | 1 |
| `koona.json.encode` | 1 |
| `koona.xml.parse` | 1 |
| `koona.lang.tag` | 1 |
| `koona.lang.code3` | 1 |
| `koona.csv.decode` | 1 |
| `koona.csv.encode` | 1 |
| `koona.date.parse` | 1 |
| `koona.date.format` | 1 |
| `koona.url.encode` | 1 |
| `koona.url.join` | 1 |
| `koona.base64.encode` | 1 |
| `koona.base64.decode` | 1 |
| `koona.hash.sha256` | 1 |
| `koona.hash.md5` | 1 |
| `koona.secret.get` | 1 |
| `koona.progress` | 1 |
| `koona.log` | 1 |
<!-- /generated -->

Values cross between your script and the app as plain data: `nil`, booleans, numbers, UTF-8 text,
and tables that are either a list (keys 1 to n) or a map with text keys. The caps on such a value
are in [limits.md](limits.md#values).

## The API level: `koona.api`

`koona.api` is a number: the `api` your manifest names (see [manifest.md](manifest.md)). Your script
sees the functions of that level and of the levels below it, and nothing of a later level: a table
with no function at your level is not there at all, so `koona.csv` would be `nil` at a level below
the one `csv` came with. A function, once added at a level, is never removed or moved.

<!-- sample:returns [1, true] -->
```lua
return { koona.api, koona.csv ~= nil }
```

The app can read every `.lua` file for the `koona.` names it uses. A name the manifest's level does
not give is reported as `api_above_level`, a name that is no function of `koona` as `api_unknown`.
This reading is made in two places only:

- When you load a developer's folder, and each time you load it again: each finding is a warning
  line in the add-on's log, and the add-on is still offered ([testing.md](testing.md)).
- In Koona's review for the checked list, where a finding is a problem to fix before it is listed
  ([checking.md](checking.md)).

An add-on added from a `.kbooksaddon` file, or installed from the checked list, is not read this way.
That reading skips comments and strings, and does not see a name built while the script runs
(`koona["http"]`): it catches mistakes, it is not a gate.

## Rules for every function

### When a function cannot take what it was given

A function given something it cannot take raises an error. Your script may catch it with `pcall`.
What `pcall` hands you is not text: use `tostring` on it. That text holds
`koona.<table>.<function>: <code>` (or `koona.<function>: <code>` for `koona.progress` and
`koona.log`), always with the function's whole name, such as `koona.csv.decode: bad_option`. Match
the code out of it; the rest of the text is not part of the contract.

<!-- sample:returns [false, "koona.json.decode", "not_json"] -->
```lua
local ok, err = pcall(koona.json.decode, "{")
local name, code = string.match(tostring(err), "(koona%.[%w_.]+): ([%w_]+)")
return { ok, name, code }
```

An error you do not catch ends the call, and the person sees `broken` (see
[words.md](words.md)).

A function raises `bad_argument` for an argument of a type it does not take, or a missing one;
`koona.http.request` and `koona.http.upload`, which take one table, raise `bad_request` instead. A
text argument may also be a number: it is read as its text (`2026` is `"2026"`).

### A reader of a whole document raises; a reader of one small value returns nil

`koona.json.decode`, `koona.xml.parse` and `koona.csv.decode` read a whole document: one that is
not what they read raises, with a code that says why. `koona.lang.tag`, `koona.lang.code3`,
`koona.date.parse` and `koona.date.format` read one small value: a value that is not one returns
`nil`. They still raise for an argument of the wrong type, and the date functions for a pattern
that is not one.

### Text

Text that goes into the app, and text that comes back, is UTF-8. A text argument that is not
UTF-8 raises `not_utf8`. The exceptions take any bytes: `koona.url.encode`,
`koona.base64.encode`, `koona.hash.sha256` and `koona.hash.md5`. A text argument longer than one
text may be raises `text_too_long`, and so does a function whose answer would be longer than that
(the cap is in [limits.md](limits.md#values)). `koona.csv.decode` and `koona.csv.encode` are the
exceptions: the text read and the text written have caps of their own
([limits.md](limits.md#csv-and-dates)), and over them is `too_large`.

### Reaching outside the permissions

Some reaches are not a mistake to catch: a request to a host your manifest does not name, a
request past the number one call may make, `koona.secret.get` without the `secrets` permission.
The first such reach ends the call at once. `pcall` catches an error, but the call is over all the
same: every later call into `koona` fails, the script is stopped at its next step, and whatever it
returns is thrown away. The person sees `denied` (or `not_on_your_network` or `server_moved`, see
[permissions.md](permissions.md)). Your script learns nothing about the rule it broke.

### Time

Every function of `koona` looks at the call's clock first. Once the call's time is over, each one
fails, also inside a `pcall`, and the call ends as out of time; the person sees `limits`. The
call's time includes what the app does for it (a request's wait, parsing), except where this page
says otherwise.

## The network

### `koona.http.request`

```text
koona.http.request{ method = "GET", url = "https://...", headers = { ... }, body = "...", timeout = 30 }
  -> { status = 200, headers = { ["content-type"] = "...", ... }, body = "..." }
  -> { status = 200, headers = { ... }, error = "not_text" }
  -> { status = 0, error = "<code>" }
```

One HTTP request, made by the app. The argument is one table; keys other than these are ignored.

| Key | Type | Default | What is refused |
| --- | --- | --- | --- |
| `url` | text | none: it is required | not text (`bad_url`); not an address, a user name or password in it, a host ending in a dot, too long (`bad_address`) |
| `method` | text, any case | `GET` | anything but `GET`, `HEAD`, `POST`, `PUT`, `PATCH`, `DELETE` (`bad_method`) |
| `headers` | map of name to text | none | not a map, a value that is not text (`bad_headers`); a header named below (`bad_request`) |
| `body` | text | none | not text (`bad_body`); not UTF-8 (`not_utf8`); too long (`text_too_long`) |
| `timeout` | number of seconds | see [limits.md](limits.md#the-network) | zero, below zero, not a number (`bad_timeout`); `math.huge` or NaN (`not_finite`) |

The argument is read raw, as plain data: a metatable is never asked. So it raises any code a
value can be refused with (`not_utf8`, `too_deep` and the others in
[limits.md](limits.md#values)), and `bad_request` when it is not a table.

<!-- sample:reply {"title":"Dune","year":1965} -->
<!-- sample:returns {"status":200,"title":"Dune","year":1965} -->
```lua
local r = koona.http.request{
  url = "https://api.example.org/books/" .. koona.url.encode("dune"),
  headers = { Accept = "application/json" },
  timeout = 10,
}
-- status 0 is no answer at all; r.error says why.
if r.status ~= 200 or r.body == nil then
  return { error = r.error or "unreachable" }
end
local book = koona.json.decode(r.body)
return { status = r.status, title = book.title, year = book.year }
```

**Methods.** `GET`, `HEAD`, `POST`, `PUT`, `PATCH` and `DELETE`, in any case (`"post"` is
`POST`).

**Headers.** A map of name to text. A name is made of letters, digits and
``!#$%&'*+-.^_`|~``; a value is visible ASCII, spaces and tabs. Names go out in lower case, values
with the spaces at both ends trimmed. The app sets these headers itself,
and a script that names one is refused with `bad_request`: `Host`, `User-Agent`,
`Content-Length`, `Transfer-Encoding`, `Connection`, `Upgrade`, `TE`, `Trailer`, `Keep-Alive`,
`Expect`, and any name that starts with `Proxy-`. An add-on with a sign-in may not set
`Authorization` or `Cookie` either (see below). The most headers, the longest name and the longest
value are in [limits.md](limits.md#the-network) and [below it](limits.md#more-limits-of-the-functions);
over them is `bad_request`.

**Body.** Text, sent as it is. Your script cannot send bytes that are not UTF-8. Name a
`Content-Type` in `headers` when the service needs one.

<!-- sample:returns 200 -->
```lua
local r = koona.http.request{
  method = "POST",
  url = "https://api.example.org/progress",
  headers = { ["Content-Type"] = "application/json" },
  body = koona.json.encode({ document = "abc", percentage = 0.5 }),
}
return r.status
```

**Timeout.** Seconds, a number above zero. With none the request waits the default; a longer one
than the longest is cut to the longest (both are in [limits.md](limits.md#the-network)). No
request waits past the time the call has left. The time covers the request and every redirect it
follows, the name's lookup included.

**Where a request may go.** These rules are the app's, whatever the script asks:

- `http` and `https` only. Any other scheme (`file:`, `ftp:`) is a reach outside the permissions:
  the call ends as `denied`.
- **Internet hosts** are the names in `permissions.network.hosts` (see
  [permissions.md](permissions.md)), on the usual port only: 443 for `https`, 80 for `http`. An
  address written as numbers is never one of them. The name is looked up again for every request,
  and the request goes to the address that was checked. If any address the name answers with is not
  on the internet (a private, loopback, link-local or reserved address), the request is refused.
- **A device on the person's network** (a send target's reader) is the one host the person typed,
  on the ports the manifest names, and only at an address on their own network. When its name
  leads anywhere else, the person sees `not_on_your_network`.
- **A server the person names** (a reading sync, an import source) is one host and port, and stays
  the kind of place it was when the person agreed to it ("on the internet", "on your network").
  When its name leads somewhere else, the person sees `server_moved`.
- Never reached, by any add-on: the app's own site and license service (`koona.app` and every name
  under it), and this computer (`localhost`, a loopback address in any spelling).

A request outside these rules ends the call as `denied`, caught or not. A malformed address is
different: it raises `bad_address`, which your script may catch.

**Redirects.** The app follows `301`, `302`, `303`, `307` and `308` with a `Location`, up to the
number in [limits.md](limits.md#the-network), and only inside the rule the request started in:
from a listed host to a listed host, from the device to the device, from the named server to
itself. A redirect anywhere else, or to a listed name whose address is not on the internet, is not
followed: your script gets the redirect itself, with its `status` and `headers.location`, and the
call goes on. As a browser does, `303` becomes a `GET` (a `HEAD` stays one), `301` and `302` turn
a `POST` into a `GET`, and `307` and `308` repeat the request as it was. When a redirect leads to
another host, scheme or port, your script's headers are not sent there, and a request that would
repeat its body there is not made: your script gets the redirect instead. Each request a redirect
leads to counts as a request of the call; when the call's requests run out in the middle of a
server's redirects, your script gets the last redirect. Too many redirects is `too_many_redirects`.

**Cookies.** The app keeps none: every request starts with no cookie, and no connection outlives
it. A `set-cookie` header is handed to your script; it may send a `Cookie` header of its own
(unless the add-on has a sign-in).

**The User-Agent** is the app's: `KoonaBooks/` and the app's version. A request of book information
says `Koona Books (https://koona.app)` instead.

**The answer.** A table:

```text
{ status = 200,                    -- the HTTP status, a number
  headers = { ["content-type"] = "application/json", ["set-cookie"] = "a=1\nb=2", ... },
  body = "..." }                   -- the body as text
```

- Header names are in lower case. A header sent more than once is joined with `, `, as HTTP reads
  it; `set-cookie` is the exception, one cookie a line, because a cookie's date holds a comma. A
  header whose value holds a line break, or whose name or value is over its cap, is left out, and
  so is every header past the most an answer hands over; a line that would take `set-cookie` past
  its cap is left out too (the caps are in [limits.md](limits.md#more-limits-of-the-functions)).
- An answer must be UTF-8 text. One that is not (a picture, a book's file) is not handed over: the
  table has `status` and `headers`, no `body`, and `error = "not_text"`. Book files and covers are
  the app's to fetch.
- A body longer than the cap in [limits.md](limits.md#the-network) is `too_large`.
- A status that is not `2xx` is still an answer: `status` says it, and the body is there.

When there was no answer at all, the table is `{ status = 0, error = "<code>" }`, with one of these
codes:

<!-- generated:http-codes -->
`unreachable`, `timeout`, `tls`, `too_large`, `too_many_redirects`, `not_text`, `file`, `signed_out`, `limited`
<!-- /generated -->

| Code | Why |
| --- | --- |
| `unreachable` | no such name, nothing listening, the connection dropped |
| `timeout` | no answer within the request's time |
| `tls` | the secure connection failed |
| `too_large` | the answer is longer than a script may take |
| `too_many_redirects` | more redirects than the app follows |
| `not_text` | the answer's body is not UTF-8 text (beside `status` and `headers`) |
| `file` | `koona.http.upload` only: the file could not be read to its end |
| `signed_out` | the add-on has a sign-in and the person is not signed in any more |
| `limited` | the service asked to wait longer than a call waits (see "The pace") |

These codes are not the app's own: your script may answer one of them as its `{ error = "<code>" }`,
and the app has words for the common ones (see [words.md](words.md)).

<!-- sample:returns [0, "unreachable"] -->
```lua
-- A name that has no address: the request was allowed, but nothing answered.
local r = koona.http.request{ url = "https://offline.example.org/" }
return { r.status, r.error }
```

**What it raises.** `bad_request`, `bad_url`, `bad_method`, `bad_headers`, `bad_body`,
`bad_timeout`, `bad_address`, and the codes of a value that is not plain data. All of them may be
caught; nothing was sent.

<!-- sample:returns [false, "bad_request", "bad_method"] -->
```lua
local function code(err)
  return string.match(tostring(err), "koona%.[%w_.]+: ([%w_]+)")
end
local ok, why = pcall(koona.http.request, {
  url = "https://api.example.org/",
  headers = { ["User-Agent"] = "mine" },
})
local _, other = pcall(koona.http.request, { url = "https://api.example.org/", method = "TRACE" })
return { ok, code(why), code(other) }
```

**The sign-in token.** An add-on with a sign-in (a reading sync, see
[permissions.md](permissions.md) and [reading-sync.md](reading-sync.md)) never holds the person's
token. The app adds `Authorization: Bearer <token>` to every request that goes to the sign-in's own
host by `https` on the usual port, and to no other: not another port, not a name that only starts
like it. Your script may not send an `Authorization` or a `Cookie` header of its own, to any host
(`bad_request`). When the service answers `401`, the app gets a new token once a call and makes
that request again; a later `401` reaches your script as it is. When the person is no longer
signed in, the request is not made and the answer is `{ status = 0, error = "signed_out" }`. An
answer that echoes a token back has every copy of it, in the body and in header values, replaced
by `[token]`.

**The pace.** An add-on whose manifest names `permissions.network.pace` (see
[manifest.md](manifest.md#permissionsnetwork)), and every book-information add-on, has its requests
paced: each waits for its turn, and so does each request a redirect leads to. The pace is a bucket of
`burst` turns, refilled at `per_minute` turns a minute: up to `burst` requests go at once, up to
`burst + per_minute` in the first minute, then `per_minute` a minute. The wait is the app's, not your
script's: it does not count against the call's time.

How long a pace lasts depends on the kind:

| Kind | The pace is kept |
| --- | --- |
| A reading sync | For the add-on, across all its calls and jobs, while the app runs |
| Book information | For the add-on, across all its calls and the covers fetched for it, while the app runs (a new version of the add-on starts a new one) |
| An import source | For one call only: each page and each search starts with a full bucket |

A send target and a tools add-on have no pace.

A `429` answer still reaches your script as it is, with its status and headers; what changes is the
next turns, which wait for its `Retry-After` in seconds (a fixed wait when it names none, or names a
date). A `503` does the same when it names seconds. The app believes such a wait up to a cap (both in
[limits.md](limits.md#more-limits-of-the-functions)). A turn that would wait longer
than the app waits for one, or longer than the call's waits may take in all (both in
[limits.md](limits.md#the-network)), is not taken: the answer is `{ status = 0, error = "limited" }`.
When the person stops the job while a request waits for its turn, the request is not sent and the
call ends as cancelled.

**How many.** One call may make the number of requests in [limits.md](limits.md#the-network),
redirects and uploads counted. The request past it is a reach outside the permissions: the call
ends as `denied`.

### `koona.http.upload`

```text
koona.http.upload{
  url = ctx.base .. "/upload",     -- where the file goes
  file = item.file,                -- the handle the app handed the call
  filename = item.name,            -- the file's name in the form
  field = "file",                  -- the form field of the file
  fields = { path = "/Books" },    -- other form fields, text
  headers = { ... },
}
  -> the same answer as koona.http.request
```

Sends one file the app handed your script, as a `multipart/form-data` `POST`. It is for a send
target (see [send-target.md](send-target.md)): the app hands `send(ctx, item)` a handle in
`item.file`, and your script passes the handle on. Your script never sees the file's path or a byte
of it; the app opens it for reading only. It cannot be run in a sample on this page, because only a
send target's call is handed a file; the [send target starter](../templates/send/addon.json) shows
it at work.

| Key | Type | Default | What is refused |
| --- | --- | --- | --- |
| `url` | text | none: it is required | as for `koona.http.request` (`bad_url`, `bad_address`) |
| `file` | text, a handle | none: it is required | missing, not text, or no handle of this call (`bad_file`) |
| `filename` | text | none: it is required | empty, a control character, a `/` or `\`, `.` or `..`, too long (`bad_filename`) |
| `field` | text | `file` | empty, a control character, too long (`bad_field`) |
| `fields` | map of name to text | none | not a map, a value that is not text, a name as for `field`, a value too long, too many fields (`bad_fields`) |
| `headers` | map of name to text | none | as for `koona.http.request`, and `Content-Type` too (`bad_request`) |

The caps of names, values and fields are in [limits.md](limits.md#more-limits-of-the-functions).

- The form's other `fields` come first, then the file's part, with the type
  `application/octet-stream`. A quote in a name is written `%22`, a line break `%0D` or `%0A`. The
  boundary between the parts is the app's own, random, and your script never sees it; the app sets
  the body's `Content-Type` with it.
- No redirect is followed: a book's bytes are sent once, to the address that was asked for. Your
  script gets the answer as it came.
- The address follows the rules of `koona.http.request` for where a request may go; an upload
  counts as one request of the call.
- The upload's time is its own, not your script's: a fixed time to start and end, and more for a
  larger file (the rule is in [limits.md](limits.md#more-limits-of-the-functions)). It ends when no
  byte has moved for the time in [limits.md](limits.md#the-network). The call's clock stops while
  the file goes.
- The app shows the person how far the file has gone; your script does not need `koona.progress`
  for it.
- A file that could not be read to its end (gone, locked, changed while it was sent) answers
  `{ status = 0, error = "file" }`.

It raises `bad_request`, `bad_url`, `bad_file`, `bad_filename`, `bad_field`, `bad_fields`,
`bad_headers`, `bad_address`, `no_randomness` (the system gave the app no random boundary), and the
codes of a value that is not plain data. It answers with the codes of `koona.http.request`.

## Data

### `koona.json.decode`

`koona.json.decode(text)` reads JSON text into plain data: objects become maps, arrays lists,
numbers Luau numbers. JSON's `null` is `nil`: gone from a map, and a hole in the middle of a list.
White space around the value is fine; anything after it is not JSON.

<!-- sample:returns {"title":"Dune","year":1965,"series":true,"first":"sf","second":true,"third":"classic"} -->
```lua
local book = koona.json.decode('{"title":"Dune","year":1965,"tags":["sf",null,"classic"],"series":null}')
return {
  title = book.title,
  year = book.year,
  series = book.series == nil,
  first = book.tags[1],
  second = book.tags[2] == nil,
  third = book.tags[3],
}
```

A server's answer is read under the same caps as your script's own values
([limits.md](limits.md#values)). It raises:

| Code | Why |
| --- | --- |
| `not_json` | the text is not JSON (`NaN` and a number too large for a double are not JSON either) |
| `too_deep` | nested deeper than a value may be |
| `too_many_values` | more values than a value may hold |
| `text_too_long` | one text in it, or the argument itself, is longer than one text may be |
| `too_much_text` | all its text together is more than a value may hold |
| `not_utf8` | the argument is not UTF-8 |
| `bad_argument` | the argument is not text |

### `koona.json.encode`

`koona.json.encode(value)` writes plain data as JSON text, with no spaces. Map keys are written in
sorted order. A whole number is written without a fraction (`3`, not `3.0`): a script has no other
way to say "integer". An empty table is `[]`, since Luau cannot tell an empty list from an empty
map. `nil` given alone is `null`.

**A `null` inside a map cannot be written from a table.** In Luau a field set to `nil` is no field at
all, so `{ series = nil }` is written without `series`. When a service needs an explicit `null` (to
clear a field, say), write the rest with `koona.json.encode` and put the `null` into the text
yourself:

<!-- sample:returns ["null", "{\"title\":\"Dune\"}", "{\"title\":\"Dune\",\"series\":null}"] -->
```lua
local plain = koona.json.encode({ title = "Dune", series = nil })
-- The map's text ends with "}": the null goes in before it. (An empty map is written "[]",
-- so start from a map with one field at least.)
local cleared = plain:sub(1, -2) .. ',"series":null}'
return { koona.json.encode(nil), plain, cleared }
```

<!-- sample:returns "{\"none\":[],\"rating\":4.5,\"tags\":[\"sf\"],\"title\":\"Dune\",\"year\":1965}" -->
```lua
return koona.json.encode({ title = "Dune", year = 1965, rating = 4.5, tags = { "sf" }, none = {} })
```

It raises when the value is not plain data, with the codes of [limits.md](limits.md#values):
`not_finite` (NaN, `math.huge`), `not_data` (a function), `cyclic` (a table inside itself),
`list_and_map` (a table with both list items and named keys), `key_not_text`, `not_utf8`,
`too_deep`, `too_many_values`, `too_much_text`; and `text_too_long` when a text in it, or the JSON
written, is longer than one text may be.

### `koona.xml.parse`

`koona.xml.parse(text)` reads a whole XML document, strictly, and returns its root element. Each
element is a fresh table of your script's own:

```text
{ name = "entry",                          -- the name without its prefix
  ns = "http://www.w3.org/2005/Atom",      -- its namespace's address; absent when it has none
  attrs = { href = "/a", ["xml:lang"] = "en", ["{urn:x}id"] = "7" },   -- absent when it has none
  text = "...",                            -- the character data before its first child; always there
  tail = "...",                            -- the character data after it, inside its parent; absent when none
  [1] = { ... }, [2] = { ... }, ... }      -- the elements inside it, in the document's order
```

- Names come with their namespace's address, whatever prefix the document chose, so ask for
  `entry` in Atom's namespace, not for `atom:entry`.
- An attribute with no prefix is its own name; `xml:lang` (and any `xml:` name) stays as it is;
  any other prefixed attribute is `{address}local`. Namespace declarations are not attributes.
- `text` and `tail` keep mixed content in order: `<p>a <b>b</b> c</p>` is `p` with the text `a `,
  and `b` with the text `b` and the tail ` c`. Text that is only white space before a child, or as a
  tail, is `""` or absent. CDATA is text. Line ends are `\n`; a line end or a tab inside an
  attribute's value is a space.
- References are read: the five of XML, numbers (`&#233;`, `&#xE9;`), and the XHTML names (feeds
  use `&nbsp;` without declaring it).
- `#element` is the number of elements inside it; walk them with `ipairs`.

<!-- sample:returns {"root":"feed","ns":"http://www.w3.org/2005/Atom","lang":"en","children":2,"title":"Books & more","href":"/get/1.epub"} -->
```lua
local feed = koona.xml.parse([[<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns="http://www.w3.org/2005/Atom" xml:lang="en">
  <title>Books &amp; more</title>
  <entry><title>Dune</title><link href="/get/1.epub" type="application/epub+zip"/></entry>
</feed>]])
local ATOM = "http://www.w3.org/2005/Atom"
local out = { root = feed.name, ns = feed.ns, lang = feed.attrs["xml:lang"], children = #feed }
for _, child in ipairs(feed) do
  if child.name == "title" and child.ns == ATOM then out.title = child.text end
  if child.name == "entry" then
    for _, part in ipairs(child) do
      if part.name == "link" then out.href = part.attrs.href end
    end
  end
end
return out
```

<!-- sample:returns {"text":"a ","inner":"b","tail":" c","attrs":{"{urn:x}id":"7","plain":"1"}} -->
```lua
local p = koona.xml.parse('<p xmlns:x="urn:x" x:id="7" plain="1">a <b>b</b> c</p>')
return { text = p.text, inner = p[1].text, tail = p[1].tail, attrs = p.attrs }
```

A document with a document type (`<!DOCTYPE`) is refused whole, so nothing in it is declared,
expanded or fetched. The caps on depth, elements, attributes and names are in
[limits.md](limits.md#more-limits-of-the-functions). It raises:

| Code | Why |
| --- | --- |
| `dtd` | the document has a document type, or another `<!` declaration |
| `malformed` | it is not well-formed XML (or it is empty) |
| `too_deep` | elements nested deeper than the cap |
| `too_many` | more elements in the document, or attributes on one element, than the cap; a name too long |
| `entity` | a reference that names nothing known |
| `character` | a character XML does not allow (`&#0;`) |
| `namespace` | a prefix that was never declared, or a declaration that is not one |
| `not_utf8` | the text is not UTF-8 |
| `text_too_long` | the text is longer than one text may be |
| `bad_argument` | the argument is not text |

### `koona.csv.decode`

`koona.csv.decode(text, options)` reads CSV text (RFC 4180) and returns two values: the rows, and
the names of the header's columns in the file's order.

| Option | Type | Default | What it does |
| --- | --- | --- | --- |
| `header` | boolean | `true` | `true`: the first row names the columns, and each row is a map by those names. `false`: each row is a list of cells, and the second value is `nil`. |
| `delimiter` | text | picked | one of `,`, `;`, a tab, `\|`. With none, the app picks: of `,`, `;` and a tab, the one that stands most often in the first line outside quotes; a tie or none is `,`. `\|` is used only when you name it. |

Any other key, a delimiter that is not one of the four, a `header` that is not a boolean, or
options that are not a table raise `bad_option`.

- A field in double quotes may hold the delimiter, line breaks and quotes (doubled).
- A line ends with CRLF, LF or CR, mixed as they come; the last line may have none. A UTF-8
  byte-order mark at the start is dropped. A blank line is not a row, wherever it stands.
- Header names are taken as written, not trimmed. A row shorter than the header is fine: its
  missing cells are `nil`. Every cell is text: `1965` is `"1965"`.
- Reading is not evaluating: `=1+1` comes back as `=1+1`.

<!-- sample:returns {"rows":[{"Title":"Dune","Year":"1965"},{"Title":"Emma"}],"names":["Title","Year"]} -->
```lua
local rows, names = koona.csv.decode("Title;Year\r\nDune;1965\r\nEmma\r\n")
return { rows = rows, names = names }
```

<!-- sample:returns [["a","b,c"],["say \"hi\"",""]] -->
```lua
return (koona.csv.decode('a,"b,c"\r\n"say ""hi""",', { header = false }))
```

It raises:

| Code | Why |
| --- | --- |
| `bad_format` | not CSV: a quote inside an unquoted field, text after a closing quote, a quote never closed, a NUL anywhere; an empty or repeated header name; a row with more cells than the header |
| `too_large` | over a cap of [limits.md](limits.md#csv-and-dates): the text, the rows, the columns, one cell |
| `bad_option` | an option that is not one (above) |
| `not_utf8` | the text is not UTF-8 |
| `bad_argument` | the text is not text |

**There is no lenient mode.** A file with a stray quote (`1,x"y`), a quote never closed, or, with a
header, a row longer than the header is refused whole as `bad_format`; nothing of it is read. A row
shorter than the header is fine. Without a header (`header = false`) rows of any length are read, so
a script that must take a file with ragged rows reads it that way and names the columns itself. A
stray quote cannot be read either way: a list importer catches the error and answers `not_a_list`
([tools.md](tools.md)).

<!-- sample:returns [false, "bad_format", 2, 3, false] -->
```lua
local ragged = "Title,Year\r\nDune,1965,extra\r\n"
local ok, err = pcall(koona.csv.decode, ragged)
local rows = koona.csv.decode(ragged, { header = false })
local stray = pcall(koona.csv.decode, 'Title,Year\r\nDu"ne,1965\r\n')
return { ok, string.match(tostring(err), "koona%.[%w_.]+: ([%w_]+)"), #rows[1], #rows[2], stray }
```

The text may be longer than one text: its cap is the CSV one, so a list importer reads a picked
file of any length the app takes. The rows are built inside your script's memory and are not
counted as values: a file at the caps with many tiny cells may not fit the call's memory, and then
the call ends as out of memory.

### `koona.csv.encode`

`koona.csv.encode(rows, options)` writes rows as CSV text: CRLF after every row, the last one too.

| Option | Type | Default | What it does |
| --- | --- | --- | --- |
| `header` | list of names | none | the header line; each row is then read as a map by these names: a missing cell is written empty, any other key is ignored. With none (or `false`), each row is a list of cells. |
| `delimiter` | text | `,` | one of `,`, `;`, a tab, `\|` |

So `koona.csv.encode(rows, { header = names })` writes back what `koona.csv.decode` read.

- A cell is text, a finite number or a boolean. A whole number is written without a fraction, any
  number never with an exponent (`1e21` is `1000000000000000000000`).
- A cell that holds any of `,` `;` a tab `|`, a quote or a line break is written in quotes, whatever
  the delimiter: a spreadsheet may split the file by another.
- A text cell a spreadsheet would run (it starts with `=`, `+`, `-`, `@`, a tab or a CR) is written
  with an apostrophe in front, inside the quotes when it is quoted. A header name is treated the
  same. Numbers never are: `-5` is `-5`.
- A row whose only cell is empty is written `""`, so the line is not blank.
- Rows, cells and options are read raw: no metatable is asked. A row's key `1` is not the name
  `"1"`.
- The rows are read cell by cell under the CSV caps, not under the caps of a value, and the text
  written may be longer than one text, up to its own cap: what a list exporter needs for its whole
  file.

<!-- sample:returns "Title,Year\r\nDune,1965\r\n'=HYPERLINK(1),\r\n\"War, and Peace\",1869\r\n" -->
```lua
return koona.csv.encode({
  { Title = "Dune", Year = 1965 },
  { Title = "=HYPERLINK(1)" },
  { Title = "War, and Peace", Year = 1869 },
}, { header = { "Title", "Year" } })
```

It raises `bad_value` (a row that is not a table, a cell that is not text, a finite number or a
boolean, a text cell that is not UTF-8), `too_large` (over a cap of
[limits.md](limits.md#csv-and-dates), the text written included), `bad_option` (an unknown key, a
delimiter that is not one, a `header` that is not a list of distinct, non-empty names) and
`bad_argument` (the rows are not a table).

### `koona.date.parse`

`koona.date.parse(text, pattern)` reads a day as a service writes it and returns ISO text of what is
known: `"2026-11-07"`, `"2026-11"` or `"2026"`. There are no times, no time zones and no clock.

A pattern is text with letters for the parts of a date:

| Letters | Part | Read | Written by `koona.date.format` |
| --- | --- | --- | --- |
| `yyyy` | year | exactly four digits, 0001 to 9999 | four digits, zeros in front |
| `MM` | month | exactly two digits | two digits |
| `M` | month | one or two digits (two when there are two) | no zero in front |
| `MMM` | month | `Jan` to `Dec`, any case | `Jan` |
| `MMMM` | month | `January` to `December`, any case | `January` |
| `dd` | day | exactly two digits | two digits |
| `d` | day | one or two digits (two when there are two) | no zero in front |

Every other character is itself, read exactly (case too) and written as it is, also a letter
outside ASCII (`yyyy г.`). Month names are English only. A pattern is not one, and raises
`bad_pattern`, when it has an ASCII letter that is none of the above (`YYYY`, `mm`, `yy`, `D`, `T`),
names a part twice, has a day without a month, has no year, or is longer than the cap in
[limits.md](limits.md#csv-and-dates).

It returns `nil` for text that does not fit the pattern, that has anything left after it, that is
not a real day (30 February, month 13, year 0; leap years by the Gregorian rule), that is not UTF-8
or that is longer than the cap. Nothing is trimmed.

<!-- sample:returns ["2026-11-07", "2026-11-07", "1869-09", "2026", true, true] -->
```lua
return {
  koona.date.parse("07.11.2026", "dd.MM.yyyy"),
  koona.date.parse("Nov 7, 2026", "MMM d, yyyy"),
  koona.date.parse("September 1869", "MMMM yyyy"),
  koona.date.parse("2026", "yyyy"),
  koona.date.parse("2026-02-30", "yyyy-MM-dd") == nil,
  koona.date.parse(" 2026-11-07", "yyyy-MM-dd") == nil,
}
```

It raises `bad_pattern` and `bad_argument` (an argument that is neither text nor a number).

<!-- sample:returns "bad_pattern" -->
```lua
local ok, err = pcall(koona.date.parse, "2026-11-07", "YYYY-MM-DD")
return string.match(tostring(err), "koona%.[%w_.]+: ([%w_]+)")
```

### `koona.date.format`

`koona.date.format(iso, pattern)` writes ISO text (`yyyy`, `yyyy-MM` or `yyyy-MM-dd`, a real day)
the way a service wants it, with the pattern letters of `koona.date.parse`. It returns `nil` for
text that is not ISO in one of the three shapes, and when the pattern needs a part the date lacks
(a day of `"1869-05"`). It raises `bad_pattern` and `bad_argument` as `koona.date.parse` does.

<!-- sample:returns ["7 November 2026", "07.11.2026", "May 1869", true] -->
```lua
return {
  koona.date.format("2026-11-07", "d MMMM yyyy"),
  koona.date.format("2026-11-07", "dd.MM.yyyy"),
  koona.date.format("1869-05", "MMM yyyy"),
  koona.date.format("1869", "d MMMM yyyy") == nil,
}
```

### `koona.url.encode`

`koona.url.encode(text)` escapes text for a part of an address: every byte but letters, digits and
`-._~` becomes `%XX`, so the result is safe in a path part and in a query value alike. It takes any
bytes.

### `koona.url.join`

`koona.url.join(base, relative)` resolves a relative address against a base, as a browser does.
Both are UTF-8 text. It raises `bad_address` when the base is not an address or the two do not make
one.

<!-- sample:returns ["War%20%26%20Peace%2F%D0%9C%D0%B8%D1%80", "https://api.example.org/covers/5.jpg", "https://example.org/b"] -->
```lua
return {
  koona.url.encode("War & Peace/Мир"),
  koona.url.join("https://api.example.org/works/OL1W?x=1", "../covers/5.jpg"),
  koona.url.join("https://api.example.org/a", "//example.org/b"),
}
```

### `koona.base64.encode`

`koona.base64.encode(text)` writes any bytes as standard Base64, with padding.

### `koona.base64.decode`

`koona.base64.decode(text)` reads standard Base64. It raises `not_base64` for text that is not
Base64, and `not_utf8` when what it holds is not UTF-8 text: bytes that are not text do not enter a
script this way either.

<!-- sample:returns ["bWU6c2VjcmV0", "me:secret"] -->
```lua
return { koona.base64.encode("me:secret"), koona.base64.decode("bWU6c2VjcmV0") }
```

### `koona.lang.tag`

`koona.lang.tag(code)` turns what a catalog calls a language into a BCP 47 tag, as the app speaks
them: `rus`, `ger`, `deu` and `RU` are `ru`, `pt_br` is `pt-BR`, `zh-hant` is `zh-Hant`. The
language part is the two-letter code where there is one, else the three-letter one as it is
(`grc`). It returns `nil` for what is not a language code, and for a code that names no single
language (`und`, `mul`, `zxx`, `mis`), and for text over the cap in
[limits.md](limits.md#more-limits-of-the-functions). Spaces at both ends are trimmed. Nothing is guessed: a code
that is not one is never taken as a neighbor.

### `koona.lang.code3`

`koona.lang.code3(tag, which)` gives the three-letter code of a tag's language: `rus` for `ru` and
for `ru-RU`. With `which` left out (or `"t"`) it is the terminology code (`deu`), which is also the
ISO 639-3 one; with `"b"` it is the bibliographic code where a language has one (`ger`), as library
catalogs speak. It returns `nil` for what is not a language. `which` other than `"b"` or `"t"`
raises `bad_argument`.

<!-- sample:returns ["ru", "de", "pt-BR", true, "deu", "ger", "rus"] -->
```lua
return {
  koona.lang.tag("rus"),
  koona.lang.tag("ger"),
  koona.lang.tag("pt_br"),
  koona.lang.tag("und") == nil,
  koona.lang.code3("de"),
  koona.lang.code3("de", "b"),
  koona.lang.code3("ru-RU"),
}
```

### `koona.hash.sha256`

`koona.hash.sha256(text)` gives the SHA-256 of any bytes, as 64 lower-case hex digits.

### `koona.hash.md5`

`koona.hash.md5(text)` gives the MD5 of any bytes, as 32 lower-case hex digits. It is there for
services that ask for it (a document's id in a sync protocol), never for safety.

<!-- sample:returns ["ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad", "900150983cd24fb0d6963f7d28e17f72"] -->
```lua
return { koona.hash.sha256("abc"), koona.hash.md5("abc") }
```

## The app

### `koona.secret.get`

`koona.secret.get(key)` gives the value of one of the add-on's `secret` settings, from the system's
keychain, or `nil` when the person has not set it. A secret is never in `ctx.settings`; this is the
one way to it. The app asks the keychain only when your script asks.

The manifest must ask for `permissions.secrets` (see [permissions.md](permissions.md)), which only
a reading sync and an import source may. Without it, `koona.secret.get` ends the call as `denied`,
and the keychain is not asked. A key that is not text raises `bad_argument`, one that is not UTF-8
`not_utf8`.

<!-- sample:returns ["s3cret", true] -->
```lua
local token = koona.secret.get("token")
local unset = koona.secret.get("not_set")
return { token, unset == nil }
```

Keep a secret out of `koona.log` and out of an `error` code: both are shown to people.

### `koona.progress`

`koona.progress(done, total)` says how far the job is. Both are numbers, finite and not below zero;
`total` left out (or 0) means your script does not know. Anything else raises `bad_number`. The
first report goes to the app at once, then no more often than the interval in
[limits.md](limits.md#more-limits-of-the-functions); the last report held
back goes when the app next waits on the network and when the call ends, so the bar ends where
your script last said it was. Report as often as you like. The app shows it only during a reading
sync; at every other point it is taken and not shown (a send target's upload has its own progress,
see [send-target.md](send-target.md)).

### `koona.log`

`koona.log(level, text)` writes a line to the add-on's own log, which the person sees in the
developer's view of Add-ons (see [testing.md](testing.md)), under the add-on's name and never as
the app's words. `level` is `"info"`, `"warn"` or `"error"`; anything else raises `bad_level`. The
text is UTF-8 (`not_utf8`). A line longer than the cap is cut, and lines past the number one call
may write are dropped without an error (the caps are in [limits.md](limits.md#the-log)). When the
app keeps a line, a line break or a tab in it becomes a space.

<!-- sample:returns "bad_level" -->
```lua
for page = 1, 3 do
  koona.progress(page, 3)
end
koona.log("info", "read 3 pages")
koona.log("warn", "page 2 had no title")
local ok, err = pcall(koona.log, "debug", "x")
return string.match(tostring(err), "koona%.[%w_.]+: ([%w_]+)")
```
