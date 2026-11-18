# Lab project

A small Salesforce DX project for running the generated CI/CD pipelines end to end (backlog row 1B.7). It is kept in the toolkit's `test/` folder, so `.vscodeignore` leaves it out of the VSIX, and `test/labProject.test.js` checks it on every `npm test`.

## What it holds

- `Lab_Order__c` with four fields: `Amount__c`, `Discount__c`, `Status__c` and `Approved_Date__c`.
- `LabOrderService`, called by `LabOrderTrigger` before insert and update to default the status and discount.
- `Lab_Order_Approved_Date`, a before-save record-triggered flow that stamps `Approved_Date__c` when an order is approved.
- `LabLegacyFormatter`, which nothing else uses. The second commit deletes it.
- Three test classes: `LabOrderServiceTest`, `LabOrderTriggerTest` (runs the trigger and the flow) and `LabLegacyFormatterTest`.
- `Lab_Order_Access`, a permission set for the object and its fields.
- `manifests/package.xml`, which the pipelines dry-run on a feature branch push, and `config/project-scratch-def.json` for scratch-org validation.

## Using it

1. Copy this folder out of the toolkit's repository, then run `git init` and commit it there as the first commit.
1. Push it to the provider's repository and let the pipeline deploy it.
1. Run `node scripts/delete-class.js` in the copy. It deletes `LabLegacyFormatter` and its test, drops both from `manifests/package.xml`, and commits. It refuses to run inside a larger repository (such as the toolkit's), outside Git, or on a tree with uncommitted changes.
1. Push again. The delta now carries a destructive manifest, which runs the deletion path when `deployOptions.destructiveChanges` is on.

## Setting it up with the script

`tools/lab/setup.js` (row 1B.18) does the first step for one provider: it checks the Developer Edition orgs logged in to the CLI, copies this folder, writes `ci-config.json` mapping them to Dev, SIT, QA and a production stand-in (the last alias), generates the provider's files, and commits with one branch per environment. It pushes nothing and prints the steps left. In Git Bash in the toolkit folder:

```bash
node tools/lab/setup.js --provider github --out D:/lab-github --orgs dev,SFDD
```

Add `--scratch --dev-hub <alias>` for scratch-org validation, `--destructive` to apply deletions, and `--agent-pool <name>` for an Azure self-hosted pool.
