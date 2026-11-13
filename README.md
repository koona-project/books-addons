# Add-ons for Koona Books

[Koona Books](https://koona.app) is an e-book library for Windows and Mac. An add-on teaches it one more thing: send books to a reader over Wi-Fi, bring books in from a catalog, keep reading progress in step with a service, look up a cover. An add-on is a folder of text files (a manifest, Luau scripts, translations) that the app runs in a sandbox.

This repository is for people who write add-ons:

| You want to | Go to |
| --- | --- |
| Have a coding agent write an add-on for you | [Install the skill](#install-the-skill), below |
| Write one yourself | [The pages for authors](https://addons.koona.app/books/docs/) and a folder from [`starters/`](starters) |
| See how a real one is made | [`examples/`](examples): the nine add-ons that come with the app |
| Offer yours for Koona's checked list | [The form](https://addme.dev/books/submit) |
| See which add-ons there are | [The list](https://addme.dev/books/) |

## Install the skill

The skill teaches a coding agent to write, fix or review an add-on for Koona Books. It carries the authors' reference, the examples, the starters and the manifest's schema, so the agent works from what the app really does.

**Claude Code**, one command in a terminal:

```sh
claude plugin install koona-books-addons --marketplace koona-project/books-addons
```

On a Claude Code older than 2.1.292, two commands do the same:

```sh
claude plugin marketplace add koona-project/books-addons
claude plugin install koona-books-addons@koona-books
```

**Codex, Cursor, Gemini CLI and other agents**, one command, with Node.js on the computer:

```sh
npx skills add koona-project/books-addons --skill koona-books-addons -g -y
```

**By hand**, with nothing installed: download [the zip](https://addons.koona.app/books/docs/download/koona-books-addons-skill.zip) and unpack it where your agent keeps its skills. For Claude Code that is `~/.claude/skills/` for every project, or `.claude/skills/` inside one project. An agent without a skills folder can be told to read [`skill/koona-books-addons/SKILL.md`](skill/koona-books-addons/SKILL.md) first.

Then ask for what you want in plain words:

> Write a Koona Books add-on that sends books to my reader over Wi-Fi

The agent picks the skill up by itself and writes the add-on's folder. It cannot run an add-on: only Koona Books can. [Trying an add-on](https://addons.koona.app/books/docs/) in the app is described in the pages for authors.

## What is here

| Folder | What |
| --- | --- |
| [`examples/`](examples) | The nine add-ons that come with Koona Books, as the app ships them. Read them as models; do not copy one: its `id`, `name` and `author` are Koona's, and an add-on that keeps them is refused |
| [`starters/`](starters) | One small working add-on for each category (`send`, `import`, `sync`, `info`, `tools`). Copy a folder, rename it, and make it yours |
| [`skill/koona-books-addons/`](skill/koona-books-addons) | The agent skill, whole: its instructions, the authors' pages, the examples, the starters and the schema, in one folder that works on its own |
| Issues | Each open issue offers one add-on, in its author's own repository, for Koona's checked list |

The folders are a copy and are not edited here: [SOURCE.md](SOURCE.md) says which state of Koona Books they are. A pull request that changes them cannot be taken; a fault in one is best reported as an issue.

## Offer an add-on for the checked list

1. **You offer it.** The form at <https://addme.dev/books/submit> asks what the add-on does and where it is on GitHub. It checks, straight from GitHub, that the repository is public, that `addon.json` is there and passes the manifest's rules, and that the license is one the list takes. Then it opens a new issue here, filled in, and you press GitHub's own button. You can also open the issue by hand with the "Offer an add-on" form.
2. **A person at Koona reads it.** The check on the page is a courtesy and decides nothing. A reviewer reads every line of the add-on at the commit the issue names, against [what the checked list asks](https://addons.koona.app/books/docs/checking), and answers in the issue: questions, things to change, or a yes. Commits made after the one named are not part of the review; a changed add-on is a new commit to name.
3. **After a yes**, Koona signs that version. It then appears in Koona Books under Find add-ons, and in the list at <https://addme.dev/books/>. A later version is offered the same way and read again.

A no is possible, and so is a withdrawal later: Koona can take a checked add-on off the list, by id and version.

One issue is one add-on in one version: the title is the add-on's name and version, and a new version is a new issue.

## What does not belong here

- Your add-on's code, as a pull request or an attachment. It stays in your repository; the issue names it.
- Questions about writing an add-on that the pages for authors answer.
- Secrets of any kind. Issues are public.

## License

The add-ons in `examples/` and `starters/`, and the copies of them in the skill's folder, are under the MIT license: [LICENSE](LICENSE). Each add-on's `addon.json` names it too.
