# Add-ons for Koona Books

The add-ons that come with [Koona Books](https://koona.app), the starters for writing one, and the place where an add-on is offered for Koona's checked list.

- **The list** of add-ons, and the form that opens an issue here: <https://addme.dev/books/>
- **How to write an add-on**, and what the checked list asks of one: <https://addons.koona.app/books/docs/>

## What is here

| Folder | What |
| --- | --- |
| [`examples/`](examples) | The nine add-ons that come with Koona Books, as the app ships them. Read them as models; do not copy one: its `id`, `name` and `author` are Koona's, and an add-on that keeps them is refused |
| [`starters/`](starters) | One small working add-on for each category (`send`, `import`, `sync`, `info`, `tools`). Copy a folder, rename it, and make it yours |
| [`skill/koona-books-addons/`](skill/koona-books-addons) | The skill that teaches a coding agent to write an add-on: see below |
| Issues | Each open issue offers one add-on, in its author's own repository, for Koona's checked list |

The folders are a copy and are not edited here: [SOURCE.md](SOURCE.md) says which state of Koona Books they are. A pull request that changes them cannot be taken; a fault in one is best reported as an issue.

Each add-on's `addon.json` names its license.

## Writing an add-on with a coding agent

`skill/koona-books-addons/` is an agent skill: instructions for the agent ([`SKILL.md`](skill/koona-books-addons/SKILL.md)), the authors' pages as its reference, the examples, the starters and the manifest's schema, in one folder that works on its own.

1. Get the folder: clone this repository, or download [the zip](https://addons.koona.app/books/docs/download/koona-books-addons-skill.zip), which holds the same folder.
2. Put `koona-books-addons` where your agent keeps its skills. For Claude Code:

   ```sh
   git clone https://github.com/koona-project/books-addons
   cp -r books-addons/skill/koona-books-addons ~/.claude/skills/
   ```

   `~/.claude/skills/` serves every project; `.claude/skills/` inside a project serves that one.
3. Ask for what you want in plain words, for example "write a Koona Books add-on that sends books to my reader". The agent picks the skill up by itself.

An agent without a skills folder can be told to read `skill/koona-books-addons/SKILL.md` first.

The agent cannot run an add-on: only Koona Books can. It writes the folder and tells you how to load it; [trying an add-on](https://addons.koona.app/books/docs/) is described in the pages for authors.

## How a submission goes

1. **You offer it.** The form at <https://addme.dev/books/submit> asks what the add-on does and where it is on GitHub. It checks, straight from GitHub, that the repository is public, that `addon.json` is there and passes the manifest's rules, and that the license is one the list takes. Then it opens a new issue here, filled in, and you press GitHub's own button. You can also open the issue by hand with the "Offer an add-on" form.
2. **A person at Koona reads it.** The check on the page is a courtesy and decides nothing. A reviewer reads every line of the add-on at the commit the issue names, against [what the checked list asks](https://addons.koona.app/books/docs/checking), and answers in the issue: questions, things to change, or a yes. Commits made after the one named are not part of the review; a changed add-on is a new commit to name.
3. **After a yes**, Koona signs that version. It then appears in Koona Books under Find add-ons, and in the list at <https://addme.dev/books/>. A later version is offered the same way and read again.

A no is possible, and so is a withdrawal later: Koona can take a checked add-on off the list, by id and version.

## What does not belong here

- Your add-on's code, as a pull request or an attachment. It stays in your repository; the issue names it.
- Questions about writing an add-on that the pages for authors answer.
- Secrets of any kind. Issues are public.

## One issue, one add-on, one version

The title is the add-on's name and version. Offer a new version in a new issue.
