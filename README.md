# DataMonster Playbooks

Step-by-step guides for things set up once on a client project and needed again: data platforms, tools, client admin and workflows. Each one is written for someone doing it for the first time, explains the reason behind every step and keeps a dated learning log of field notes.

By [Pablo Gomez](https://data.monster) · DataMonster

**Read them as a website:** [pablodatamonster.github.io/datamonster-playbooks](https://pablodatamonster.github.io/datamonster-playbooks/)

## Playbooks

| Playbook | Category | Time needed | Last checked |
| --- | --- | --- | --- |
| [Snowflake: set up an account for a client project](snowflake/set_up_account_for_client_project.md) | Data platform | About 45 minutes, plus about 30 minutes for a first test load | 4 Nov 2026 |
| [dbt: set up dbt Core with Snowflake for a client project](dbt/set_up_dbt_core_with_snowflake.md) | Data platform | About 1 hour | 10 Nov 2026 |

More to come (GitHub organisation and repo for a client, password manager for a client project).

## Standard layout

Every playbook follows the same parts, in this order:

1. **What and when:** what it sets up and when to use it
2. **Before you start:** accounts, access and decisions (anything permanent is flagged)
3. **Big picture:** a diagram of how the pieces fit
4. **Steps:** numbered, with the reason behind each one
5. **Gotchas:** what tripped us up and how to avoid it
6. **Checklist for next time:** a short tick list
7. **Used on:** the kind of project it was used on (client details are kept out)
8. **Learning log:** a dated notebook of things learnt along the way, newest first

Diagrams are [Mermaid](https://mermaid.js.org/) blocks, so GitHub draws them and they stay editable as text. SQL scripts sit next to the playbook that uses them.

## The website

The site is served by GitHub Pages straight from `main` (no build step). `index.html` lists the playbooks in [`playbooks.json`](playbooks.json); `playbook.html?p=<file>.md` shows a playbook by reading its Markdown file, so the Markdown is the only copy to edit. To add a playbook: add its `.md` file in a folder per tool and one entry to `playbooks.json`.

## A note on client details

These playbooks are generic. Names such as `CLIENT_PILOT`, `ITADMIN` and `itadmin@client.example` are placeholders: replace them with your own. No account identifiers, logins, emails or figures from real client projects are published here.

## Using them

Screens and prices change. Check the "Last checked" date before following a playbook, and sense-check anything older than six months against the vendor's current documentation. Nothing here is legal, security or financial advice for your situation.

## Licence

These playbooks are shared under [Creative Commons Attribution 4.0 International (CC BY 4.0)](LICENSE). You may copy, share and adapt them, for any purpose, as long as you credit Pablo Gomez (DataMonster) with a link to this repository and say if you made changes.
