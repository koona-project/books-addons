# Limits, and what a script does not have

Every cap the app puts on an add-on, in one place, and what happens when a script meets one. The
tables marked as generated are printed from the app's own constants, so they are the numbers the
app you run uses.

Each point (a place where the app calls a script, see [README.md](README.md#rules-that-hold-everywhere))
has caps of its own on what a script answers; those are on the point's page (see
[Limits of each point](#limits-of-each-point)).

## A call

One call into your script (one `check`, one `pull`, one `run`, and so on) runs with this much
memory and time:

<!-- generated:limits-sandbox -->
| Limit | Value |
| --- | --- |
| Memory of one call | 32 MiB |
| Time of one call | 10 seconds |
| A call into a reading sync | 2 minutes |
| A call into an import source | 60 seconds |
| A call into book information | 60 seconds |
| A call into a list exporter or importer | 96 MiB, 60 seconds |
| An error's text that is kept | 2,000 characters |
<!-- /generated -->

- The memory is your script's: its tables, its texts, and what the app's functions build for it
  (a parsed XML tree, CSV rows).
- The time is the call's, and it counts what the app does for your script: a request's wait, a
  document's parsing. It does not count a request's wait for its turn under a pace, or an upload's
  own time (see [host-api.md](host-api.md#koonahttpupload)).
- The kept error text is what the developer's view shows of an error your script raised; the rest
  of it is cut.

## Values

What crosses between your script and the app is plain data: `nil`, booleans, finite numbers, UTF-8
text, and tables that are a list (keys 1 to n) or a map with text keys, never both. A function, a
table inside itself, a key that is neither text nor a list position, NaN or `math.huge`, and text
that is not UTF-8 are not plain data. Every value is read raw (no metatable is asked) and copied:
the app keeps no reference into your script.

<!-- generated:limits-values -->
| Limit | Value |
| --- | --- |
| Nesting of tables | 16 deep |
| Values in all, tables included | 50,000 |
| One text | 1 MiB |
| All text together, keys included | 4 MiB |
<!-- /generated -->

Lua cannot tell an empty list from an empty map, so the app reads `{}` as either. Where these caps
hold, and where others do:

- **A table your script gives a `koona` function** (the argument of `koona.http.request` and
  `koona.http.upload`, the value of `koona.json.encode`): these caps.
- **A text your script gives a `koona` function**: one text, as above. The one exception is the text
  of `koona.csv.decode`, which has a cap of its own ([CSV and dates](#csv-and-dates)).
  `koona.csv.encode` reads its rows cell by cell under the CSV caps, not under these: its rows may
  hold more values than the count above.
- **What a `koona` function gives back**: a text of one text at most, except the text
  `koona.csv.encode` writes (its own cap). A server's JSON read by `koona.json.decode` is held to
  these caps. The rows of `koona.csv.decode` and the tree of `koona.xml.parse` are built in your
  script's memory and are held only to their own caps and to the call's memory.
- **What your function answers**: these caps, at every point but two. The answer of a list exporter
  and of a list importer has the caps below.
- **What the app hands your function** (`ctx`, the books, a picked file's text, a book to send) is
  not held to these caps: each point's page says what it hands over and its caps.

The answer of a list exporter or a list importer ([tools.md](tools.md)) crosses under these caps
instead:

<!-- generated:limits-list-answers -->
| The answer of | Values in all | One text | All text together |
| --- | --- | --- | --- |
| Any other function | 50,000 | 1 MiB | 4 MiB |
| A list exporter | 50,000 | 8 MiB | 9 MiB |
| A list importer | 481,000 | 1 MiB | 28 MiB |
<!-- /generated -->

So a list importer may read a CSV file as long as a picked file may be, but `koona.json.decode` and
`koona.xml.parse` take one text: a JSON or XML file longer than that raises `text_too_long`, and
cannot be read whole.

When a value of yours is over a cap, the code says which: `too_deep`, `too_many_values`,
`text_too_long`, `too_much_text`, `not_utf8`, `not_finite`, `cyclic`, `not_data`, `list_and_map`,
`key_not_text`. In an argument, the function raises it (your script may catch it with `pcall`); in
your function's answer, the call is `broken`, except for a book action, a list exporter and a list
importer, where an answer over a cap is `too_long` and one that is not UTF-8 is `not_text`.

## The network

<!-- generated:limits-network -->
| Limit | Value |
| --- | --- |
| Requests in one call | 100 |
| An address | 2,000 bytes |
| Headers of a request | 32 |
| One header's value | 4,000 bytes |
| A request's body | 1 MiB |
| An answer's body | 1 MiB |
| Redirects followed | 5 |
| `timeout` when none is given | 30 seconds |
| The longest `timeout` | 2 minutes |
| An upload with no byte moving | 30 seconds |
| The longest wait for a request's turn | 60 seconds |
| All waits for a turn in one call | 150 seconds |
| Book information, whatever the manifest's pace | 60 requests a minute, 5 at once |
<!-- /generated -->

The rules of where a request may go (schemes, hosts, addresses, redirects, the sign-in's token, the
pace) are under [`koona.http.request`](host-api.md#koonahttprequest).

## The log

<!-- generated:limits-log -->
| Limit | Value |
| --- | --- |
| Lines of `koona.log` in one call | 200 |
| One line as a script writes it | 2,000 characters |
| One line as it is kept | 1,000 characters |
| Lines kept for an add-on | 500 |
| All lines kept for an add-on | 128 KiB |
<!-- /generated -->

A line longer than its cap is cut; lines past the number one call may write are dropped, with no
error. The add-on's log keeps its newest lines: when it is over its caps, the oldest go first. See
[testing.md](testing.md) for where the log is read.

## The package

<!-- generated:limits-package -->
| Limit | Value |
| --- | --- |
| The package (`.kbooksaddon`) | 2 MiB |
| Files | 64 |
| One `.lua` file | 256 KiB |
| Any other file | 1 MiB |
| All files together, unpacked | 4 MiB |
| A file of reader profiles | 64 KiB |
| Keys in one locale file | 500 |
| One text in a locale file | 500 characters |
<!-- /generated -->

A package over one of these caps is refused when it is installed or loaded. See
[manifest.md](manifest.md) for the caps of `addon.json` itself.

## CSV and dates

<!-- generated:limits-csv-date -->
| Limit | Value |
| --- | --- |
| `koona.csv.decode`, the text | 12 MiB |
| `koona.csv.encode`, the text it writes | 8 MiB |
| Rows, besides the header | 20,000 |
| Columns | 200 |
| One cell | 64 KiB |
| A date's text for `koona.date` | 64 bytes |
| A pattern for `koona.date` | 64 bytes |
<!-- /generated -->

`koona.csv.decode` and `koona.csv.encode` raise `too_large` past a cap. `koona.date.parse` and
`koona.date.format` return `nil` for a date's text over its cap, and raise `bad_pattern` for a
pattern over its cap.

## More limits of the functions

| Limit | Value |
| --- | --- |
| `koona.xml.parse`: namespace addresses written into attribute names, all together | eight times the document's length, and 64 KiB more |
| `koona.http.request`, `koona.http.upload`: one header's name | 64 bytes |
| An answer: one header's name | 64 bytes |
| An answer: one header's value, joined ones too | as one header's value of a request |
| An answer: all its `set-cookie` lines together | four times one header's value |
| `koona.http.request`: the shortest `timeout` | 1 millisecond (a shorter one is taken as this) |
| `koona.http.upload`: one value of `fields` | as one header's value of a request |
| A `Retry-After` that names no seconds (a `429` without one, or a date) | 60 seconds |

<!-- generated:limits-functions -->
| Limit | Value |
| --- | --- |
| `koona.xml.parse`: elements inside one another, the root counted | 32 |
| `koona.xml.parse`: elements in one document | 20,000 |
| `koona.xml.parse`: attributes of one element, namespace declarations counted | 64 |
| `koona.xml.parse`: one name of an element or an attribute, with its prefix | 256 bytes |
| `koona.lang.tag`, `koona.lang.code3`: the text read | 35 bytes |
| An answer: header names handed to the script | 64 |
| `koona.http.upload`: the name of `field`, of `filename`, of each of `fields` | 255 bytes |
| `koona.http.upload`: `fields` | 16 |
| `koona.http.upload`: its own time | 60 seconds, and one second more for each 32 KiB of the file; 1 hour at most |
| The longest `Retry-After` believed | 24 hours |
| `koona.progress`: reports reaching the app | one each 50 milliseconds, the first and the last always |
<!-- /generated -->

## Limits of each point

- The manifest, `addon.json`: [manifest.md](manifest.md).
- A send target's answers: [send-target.md](send-target.md).
- A reading sync's rows and results: [reading-sync.md](reading-sync.md).
- An import source's pages: [import-source.md](import-source.md).
- Book information's candidates and covers: [book-info.md](book-info.md).
- Book actions, list exporters and list importers: [tools.md](tools.md).

## What happens at a limit

| What your script did | What happens | What the person sees |
| --- | --- | --- |
| Gave a `koona` function an argument it cannot take (too long, not UTF-8, over a CSV cap) | the function raises a code; your script may catch it | nothing, unless the error is not caught |
| Ran out of time or memory | the call ends; `pcall` cannot catch it | `limits` |
| Raised an error it did not catch, has a syntax error, has no function the point needs, answered something that is not plain data or not the table the point asks for, or answered one of the app's own codes | the call ends | `broken` |
| Reached outside its permissions: a host it does not name, a scheme other than `http` and `https`, more requests than a call may make, `koona.secret.get` without `secrets` | the call ends at once, caught or not | `denied` (`not_on_your_network`, `server_moved` for a device or a server that moved) |
| Was stopped by the person | the call ends at its next step | `cancelled` |
| Wrote more log lines than a call may | the lines past the cap are dropped | nothing |

The app's own codes and how each is worded are in [words.md](words.md).

## What a script does not have

Your script runs in Luau (see [luau.org](https://luau.org)) with these libraries and global
functions, and nothing else:

<!-- generated:globals -->
| Library | What it holds |
| --- | --- |
| `bit32` | `arshift`, `band`, `bnot`, `bor`, `btest`, `bxor`, `byteswap`, `countlz`, `countrz`, `extract`, `lrotate`, `lshift`, `replace`, `rrotate`, `rshift` |
| `math` | `abs`, `acos`, `asin`, `atan`, `atan2`, `ceil`, `clamp`, `cos`, `cosh`, `deg`, `e`, `exp`, `floor`, `fmod`, `frexp`, `huge`, `isfinite`, `isinf`, `isnan`, `ldexp`, `lerp`, `log`, `log10`, `map`, `max`, `min`, `modf`, `nan`, `noise`, `phi`, `pi`, `pow`, `rad`, `random`, `randomseed`, `round`, `sign`, `sin`, `sinh`, `sqrt`, `sqrt2`, `tan`, `tanh`, `tau` |
| `string` | `byte`, `char`, `find`, `format`, `gmatch`, `gsub`, `len`, `lower`, `match`, `pack`, `packsize`, `rep`, `reverse`, `split`, `sub`, `unpack`, `upper` |
| `table` | `clear`, `clone`, `concat`, `create`, `find`, `foreach`, `foreachi`, `freeze`, `getn`, `insert`, `isfrozen`, `maxn`, `move`, `pack`, `remove`, `sort`, `unpack` |
| `utf8` | `char`, `charpattern`, `codepoint`, `codes`, `len`, `offset` |

Global functions: `assert`, `error`, `getmetatable`, `ipairs`, `next`, `pairs`, `pcall`, `rawequal`, `rawget`, `rawlen`, `rawset`, `select`, `setmetatable`, `tonumber`, `tostring`, `type`, `typeof`, `unpack`, `xpcall`.
<!-- /generated -->

These globals of Luau are taken away:

<!-- generated:removed-globals -->
`require`, `loadstring`, `getfenv`, `setfenv`, `collectgarbage`, `newproxy`, `print`, `gcinfo`
<!-- /generated -->

There is no `os`, `io`, `debug`, `coroutine`, `buffer` or `package` library.

<!-- sample:returns [true, true, true, true, true, true, true] -->
```lua
return {
  os == nil,
  io == nil,
  require == nil,
  loadstring == nil,
  print == nil,
  coroutine == nil,
  string.dump == nil,
}
```

### No clock, no date of today

There is no `os.time`, `os.clock` or `os.date`, and `koona.date` reads and writes dates but never
says what day it is. Your script cannot know the time or measure how long something took. A date a
point needs (when a book was read) comes in the call's arguments.

### Random numbers: only `math.random`

`math.random` works. The app seeds it from the system's randomness for each call, so two calls get
different numbers. `math.randomseed` sets your own seed, and the same seed gives the same numbers.
It is not for anything secret: there is no random source meant for keys or tokens.

<!-- sample:returns true -->
```lua
math.randomseed(7)
local first = math.random(1, 1000)
math.randomseed(7)
return first == math.random(1, 1000)
```

### No files

There is no `io` and no `os`: your script reads and writes no file. A send target's book reaches
the reader through a handle that only `koona.http.upload` can use, and your script never sees its
path or its bytes (see [send-target.md](send-target.md)). A list importer is handed the text of the
file the person picked (see [tools.md](tools.md)).

### No way to wait

There is no `sleep`, no `coroutine` and no clock to wait on. A loop that waits for something only
spends the call's time until it runs out. When a service asks for a slower pace, the app does the
waiting (see the pace under [`koona.http.request`](host-api.md#koonahttprequest)).

### No code shared between files

There is no `require`, `loadstring` or `load`. The app runs a point's entry file, the one the
manifest names in `entry`, and only that file: another `.lua` file in the package is never run, and
one file cannot read another. Each entry file is whole by itself, so a helper two entry files need
is written in each of them.

### No state kept between calls

Every call runs in a fresh VM: the entry file is run from its top, then the function the point
calls. A global or a table your script set in one call is not there in the next one, not even
within one job of many calls. What a point lets carry over is passed in the arguments and the
answers (a reading sync's cursor `next`, see [reading-sync.md](reading-sync.md)).

### Frozen tables

`koona`, every table inside it, and the standard libraries (`string`, `table`, `math` and the
others) are read-only: setting a field raises an error, and `rawset` and `setmetatable` do not help. Your
script's own globals are its own. A table the app hands your script (`ctx`, the arguments, a parsed
document, an answer) is a fresh copy: your script may change it, and nothing of the app changes.

<!-- sample:returns [false, true, true, 2] -->
```lua
local replaced = pcall(function() koona.log = nil end)
local mine = koona.json.decode('{"a":1}')
mine.a = 2
return { replaced, table.isfrozen(koona), table.isfrozen(string), mine.a }
```

### Text is UTF-8

A Luau string is bytes; the app takes only UTF-8 text. A text argument that is not UTF-8 raises
`not_utf8`, an answer that holds one is `broken`, and an HTTP answer that is not text is not handed
over. `#text` counts bytes, not characters: use the `utf8` library to count characters.

<!-- sample:returns [12, 6, "not_utf8"] -->
```lua
local title = "Мастер"
local ok, err = pcall(koona.json.encode, { "\255" })
return { #title, utf8.len(title), string.match(tostring(err), "koona%.[%w_.]+: ([%w_]+)") }
```

### How Luau differs from Lua 5.1

Luau starts from Lua 5.1. What an author meets first:

- There is one kind of number, a double: whole numbers are exact up to 2^53. `koona.json.encode`
  writes a whole number without a fraction.
- `continue` in a loop, compound assignment (`+=`, `..=`), floor division `//`, `if` with `then`
  and `else` as an expression (`if count > 20 then "many" else "few"`), and text with values in it
  between backticks (`` `{count} odd` ``).
- Type annotations (`local count: number = 0`) are allowed and checked by nothing at run time.
- `typeof` gives a value's type, as `type` does for plain values.
- There are no bitwise operators: use `bit32`.

<!-- sample:returns [25, "many", "25 odd", 3, "string", true, 4] -->
```lua
local count: number = 0
for i = 1, 10 do
  if i % 2 == 0 then continue end
  count += i
end
local label = if count > 20 then "many" else "few"
return {
  count,
  label,
  `{count} odd`,
  7 // 2,
  typeof(label),
  2^53 + 1 == 2^53,
  bit32.band(12, 6),
}
```
