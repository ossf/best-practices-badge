# bestpractices.json

If a project repository has either a `.bestpractices.json` file at its
top level or a `.project.d/bestpractices.json` file, that information is
used to fill in proposed answers.

## Building on other projects

It's common for one repo in an organization to be similar to another.
You can use this mechanism to simplify copying information from one
repo to another.

A useful approach is to work to earn a badge for one project
in an organization.
You can then download its status as
`https://bestpractices.dev/projects/NUMBER.json`.
Edit the result to record just what's true, and put it in your other project.

In a `.bestpractices.json` file,
a status `?` or `"unknown"` means **"I don't know the answer"**
and are **ignored entirely**.
This lets you safely reuse JSON files containing placeholder `?` values
That means that if you forget to remove a `?` placeholder, no problem,
it will be ignored.

## Triggering automation

Whenever you *first* edit a project for a given section, we run automations
to try to fill in information.

After that, if you want to trigger full automation, click on
"Save (and continue) 🤖". The robot icon 🤖 is a hint that this is the
way to re-trigger full automation analysis. You'll need to do that
if you've already saved some answers and have changed the
`.bestpractices.json` file.

## Related Documentation

- `docs/api.md` - General documentation on the API, including the
  `as=edit` URL lookup for automation proposals.
- `criteria/criteria.yml` - Metal series criteria definitions.
- `criteria/baseline_criteria.yml` - Baseline (OSPS) criteria
  definitions.
