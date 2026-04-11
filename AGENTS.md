# AGENTS.md

## Scope
These instructions apply to the entire repository tree rooted at this directory.

## Development approach
- Start by checking that the local branch is up to date with the remote. If there are incoming changes that materially change the plan, stop and report back
- Use red/green TDD with *manual* testing. This repo is about configuring a dev environment so we can't unit test realistically, but you still need to follow a red/green pattern with your manual tests. It can also make sense to write a TESTS.md file where you record which manual tests should run to verify changes.
- Commit your changes each time you complete a step in a list.
- If on `main`, checkout a feature branch before making commits. Keep using the existing branch if not on `main`
- Push to origin before reporting back at the end of the turn
- Do not create PRs unless asked. PRs should be opened in published, not draft form

