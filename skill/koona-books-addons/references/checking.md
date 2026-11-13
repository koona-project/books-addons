# Getting an add-on on Koona's checked list

Anyone can hand a person a `.kbooksaddon` file, and the app will add it behind the switch "Add-ons from a
file", marked "Not checked by Koona". The checked list is the other way: add-ons that Koona has read and
offers from its own server, under Find add-ons, with updates.

"Checked by Koona" means three things and no more: Koona read every line of that version, it does what
its page says and nothing else, and Koona signed the list that names its bytes. It does not mean that
Koona wrote it, tested it on every device, or answers for the service it reaches.

Koona pays nothing for an add-on and an author pays nothing to be listed. Koona does not have to list an
add-on, keep it listed, or check a later version.

## Write it so that it passes

An add-on written against this page arrives closer to passing. The rules a tool checks are first; what a
person reads for is second.

### What the tool checks

The add-on must load as any add-on does ([testing.md](testing.md)), and also:

1. **Its `id` is your own**: not `app.koona`, not under `app.koona.`, not the id of an add-on that comes
   with the app.
2. **Neither its `name` (in any language) nor `author.name` says "Koona"**, in any spelling.
3. **Its name does not read the same as the name of an add-on that comes with the app**, or of another
   add-on on the list.
4. **It signs in under its own `client_id`**, never one that an add-on of Koona's uses.
5. **Its `license` is exactly one of these**, spelled exactly so. A choice such as `MIT OR Apache-2.0`,
   a custom license, a copyleft license (GPL, AGPL, LGPL, MPL) and a public-domain dedication are not
   taken. Nobody weighs a license's text: the list decides.

<!-- generated:checked-licenses -->
`MIT`, `MIT-0`, `Apache-2.0`, `BSD-2-Clause`, `BSD-3-Clause`, `ISC`, `0BSD`
<!-- /generated -->

6. **It carries the text of its license** at the top of the add-on's folder, in a file named exactly:

<!-- generated:license-file -->
`LICENSE.md`, over 100 bytes once the white space at both ends is trimmed
<!-- /generated -->

7. **That text is filled in**, not a template: the year and the holder's name are written, and none of
   these placeholders is left in it (matched in any case), nor the word `TODO`:

<!-- generated:license-placeholders -->
`[year]`, `[fullname]`, `[name]`, `[owner]`, `[copyright holder]`, `[copyright holders]`, `<year>`, `<owner>`, `<name>`, `<copyright holder>`, `<copyright holders>`, `<organization>`, `[yyyy]`, `[name of copyright owner]`
<!-- /generated -->

   The complete Apache-2.0 text keeps `[yyyy]` and `[name of copyright owner]` in its appendix and
   passes as it is. The short Apache notice alone must have the year and the owner filled in.

The starters in `../templates/` carry an MIT text with `[year]` and `[fullname]` left in on purpose:
fill them in, or replace the file with your license's text.

8. **Its scripts use only names of `koona` that its `api` level gives.** The tool reads every `.lua`
   file for the `koona.` names it uses; a name that is no function of `koona` (`api_unknown`), or one
   of a higher level than the manifest's `api` (`api_above_level`), is a problem to fix
   ([host-api.md](host-api.md#the-api-level-koonaapi)).

An author cannot run this tool today. Loading the add-on from a folder checks the package and the
manifest, and rules 1, 2 and 4, and writes a warning line in the add-on's log for each name rule 8
finds ([testing.md](testing.md#the-api-check)); it does not check rule 3 against the list, or rules 5
to 7. Check those by hand against this page.

### What a person reads for

The sandbox already holds an add-on to its permissions. The review is for what the sandbox cannot see.

1. **Every line of every `.lua` file.** Keep them short and plain. Nothing packed, nothing built from
   text and run, no table indexed by text that came from the network to pick what to do.
2. **Each host, and why.** A host that is not the service's own, a wildcard (`*.example.org`), a second
   host "for statistics" will be asked about. What goes to each host must be what `privacy` says and what
   the add-on's page says.
3. **Passwords and the sign-in.** A secret is sent only to the service it is for, never in an address,
   never to the log. It goes over `https` wherever the address is on the internet; over plain `http`
   only to a server on the person's own network, the one place the app allows `http`
   ([permissions.md](permissions.md)). A script may refuse to send it over `http` at all. A sign-in is under your own client id, with the fewest scopes
   that do the work.
4. **What leaves.** Every request is read: titles, authors, ISBNs, reading state, search words. Anything
   `privacy` does not name is a refusal. Nothing that identifies the person or the computer beyond what
   the service needs.
5. **What comes back.** A reply must not be able to steer the add-on to another host: a "next page"
   address, a redirect followed by hand, a cover's address.
6. **The words.** The name, the summary, `README.md` and the locale files say what it does, promise
   nothing it does not do, and do not pass for Koona's or for the service's own app.
7. **It is tried.** The reviewer loads the folder, runs each thing it adds once, and reads its log.
8. **The service's terms.** The service must allow a client like this one.

## How to submit

There is no way to submit from inside the app. Submit the add-on at https://addme.dev/books/.

The form there is not an upload. It asks what the add-on does and for the GitHub address of its
repository. It checks that the repository is there and that its `addon.json` passes the manifest's
schema ([manifest.md](manifest.md#the-schema)), and only then can it be sent. Sending it takes you to
GitHub, to an issue already written out for the public repository `koona-project/books-addons`. **The
add-on is submitted when you file that issue there**, signed in to your own GitHub account; until then
nobody has been asked anything. The rest is said and answered on the issue. A person at Koona reads the
code before anything is signed. The form's own page says what it asks for; where it differs from this
paragraph, the form is right.

The reviewer needs all of this, in the form or in the issue:

- the address of a **public repository** and the **commit** to check. Not a `.kbooksaddon` file: the
  package is built from the source that was read, so nobody has to trust a file somebody else packed;
- the folder of the add-on in that repository. The add-on must sit in a folder of its own, holding
  nothing but the add-on: a package may hold only `.lua`, `.json` and `.md` files, and a repository's own
  files (`.git`, `.gitignore`) are refused in an add-on's folder ([testing.md](testing.md));
- the license, as the SPDX name in `addon.json`, and that the code is your own work;
- what it reaches and why: each host, the sign-in if it has one, each setting;
- how to try it: a device, a test account, or a server to point it at;
- a way to reach you when the service changes.

## What you agree to

This is a draft that a lawyer has not yet read; the final words may differ. You agree to it in writing
(a comment on the issue that quotes it is enough).

> I wrote this add-on, or hold the rights to everything in it. It is not a port made by reading code
> under the GPL, the AGPL or the LGPL, and holds no such code.
>
> It is under the license named in its `addon.json`, which is one of the licenses Koona's list takes. It
> stays mine: Koona does not relicense it and does not change it.
>
> Koona may distribute the versions it has checked from its server, unchanged, to people who use Koona
> Books, with my name and the license shown; and may stop offering a version, or turn it off in the app
> with a reason, at any time and without asking me.
>
> Koona pays nothing for it and I pay nothing to be listed. Koona does not have to list it, keep it
> listed, or check a later version.
>
> I will say so when the service it reaches changes its terms in a way that no longer allows it.

## A new version

Submit the new version through the same form. The reviewer reads what changed since the commit that
was checked. Raise `version`,
and say what changed in the locale key `changes` ([words.md](words.md)).

- A version that asks for nothing new installs quietly on people's computers.
- A version that asks for more waits for each person's yes ([permissions.md](permissions.md) lists what
  counts as more).
- Older versions stay offered for apps that cannot run the newest, so `min_app` and `api` decide who
  gets which.
- A version that has a fault is mended by a new version with a higher number. The same version is never
  issued twice with other contents.

## When a version is taken back

Koona can withdraw a version: because the service changed and broke it, because it is broken, or because
it is unsafe. Apps turn the withdrawn versions off at their next check and offer a good version when
the list has one. An add-on can also leave the list with nothing wrong: it is no longer offered, the
copies people have keep working, and they get no more updates.
