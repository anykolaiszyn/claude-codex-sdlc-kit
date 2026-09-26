# Agent SDLC Kit

**Two AI coding assistants, checking each other's work, so you don't have to.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Claude Code plugin](https://img.shields.io/badge/Claude%20Code-plugin-d97757)](docs/setup-guide.md#install)
[![Built on superpowers](https://img.shields.io/badge/built%20on-superpowers-5319e7)](https://github.com/obra/superpowers)

## The problem this solves

If you've used an AI coding assistant, you've probably had this experience: it writes some code, tells you it works, and you have to just... trust it. Sometimes that trust is well placed. Sometimes the AI missed something obvious, because the same mind that wrote the code is the one checking it — and nobody is great at catching their own blind spots, human or otherwise.

This kit's answer is simple: **don't let one AI mark its own homework.**

## How it actually works

Think of it like having two careful, slightly different-minded colleagues instead of one:

- **Claude** is the one you talk to. It plans the work with you, writes the code, and is the only one allowed to actually commit anything or open a pull request.
- **Codex** (a separate AI, from OpenAI) is the second pair of eyes. It reviews Claude's work independently, and can also take on small, well-defined coding tasks to save time.

Because they're different systems built by different companies, they tend to catch different mistakes. And critically: **Codex's opinion is never taken on faith.** Every issue it flags gets tested and confirmed before anyone acts on it. If it's wrong, it's told so, with the evidence. If it's right, it gets fixed — or, if it's a minor thing outside the current scope, it's logged for later instead of derailing the work.

Real problems get fixed. Real disagreements get resolved with evidence. Nothing gets swept under the rug, and nothing ships without a person looking at it first.

## The one rule that never bends

**You merge everything.** Not Claude, not Codex — you. The two AI systems can design, build, argue with each other, and prepare a change down to the last detail, but the final "yes, ship it" is always a human decision. Even when the whole process runs unattended overnight, it stops and waits for you at that last step, every time.

## Why bother with two AIs instead of one?

Because the checking is the point. A single system reviewing its own work will always share its own blind spots. Two independent ones, with a real process for resolving disagreements between them, genuinely catch more — and you get a paper trail (what was found, what was fixed, what was decided, and why) instead of just a green checkmark you have to take on faith.

This isn't a theory. The process here was built and battle-tested on a real piece of software, across dozens of real changes and reviews. Every rule in it exists because something specific went wrong before the rule was added.

## It's flexible about cost

Running two AI systems isn't free, so the kit is careful about it: cheap, low-stakes changes get a light touch, and only the changes that actually matter — the risky, ambiguous, or high-impact ones — get the full two-AI treatment. You can also swap in different AI models for different jobs, including one running on your own computer, or turn a reviewer off entirely if you're using its quota somewhere else. Nothing about the safety net requires spending more than the work is worth.

## Want to actually use it?

This page is the pitch. The how-to lives in **[docs/setup-guide.md](docs/setup-guide.md)** — prerequisites, install steps, and everything else you'd need if you're setting this up in a real project.

## License

[MIT](LICENSE)
