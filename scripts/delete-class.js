#!/usr/bin/env node
// Makes the lab project's second commit: deletes LabLegacyFormatter and its
// test, drops them from manifests/package.xml, and commits, so the next
// pipeline run's delta carries a destructive manifest.
//
// Run it in a copy of the lab project that is its own Git repository, with a
// clean working tree:  node scripts/delete-class.js
'use strict';

const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const CLASSES = ['LabLegacyFormatter', 'LabLegacyFormatterTest'];
const CLASS_DIR = 'force-app/main/default/classes';
const MANIFEST = 'manifests/package.xml';
const MESSAGE = 'Delete LabLegacyFormatter so the delta carries a destructive manifest';

function git(root, args) {
  return execFileSync('git', args, { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
}

function samePath(a, b) {
  const norm = (p) => {
    const real = fs.realpathSync.native(path.resolve(p));
    return process.platform === 'win32' ? real.toLowerCase() : real;
  };
  return norm(a) === norm(b);
}

function classFiles() {
  return CLASSES.flatMap((name) => [`${CLASS_DIR}/${name}.cls`, `${CLASS_DIR}/${name}.cls-meta.xml`]);
}

// Throws with a message for the user when the folder is not a lab copy ready
// for the commit. The top-level check keeps the commit out of the toolkit's
// own repository, where the lab project's source is kept.
function check(root) {
  if (!fs.existsSync(path.join(root, 'sfdx-project.json'))) {
    throw new Error(`${root} has no sfdx-project.json, so it is not the lab project.`);
  }
  let top;
  try {
    top = git(root, ['rev-parse', '--show-toplevel']);
  } catch {
    throw new Error(`${root} is not in a Git repository. Copy the lab project out, run git init there and commit it first.`);
  }
  if (!samePath(top, root)) {
    throw new Error(`${root} is inside the Git repository at ${top}. Run this in a copy of the lab project that is its own repository.`);
  }
  const missing = classFiles().filter((f) => !fs.existsSync(path.join(root, f)));
  if (missing.length) {
    throw new Error(`Already deleted or never there: ${missing.join(', ')}.`);
  }
  if (git(root, ['status', '--porcelain'])) {
    throw new Error('The working tree has uncommitted changes. Commit or discard them, so the commit holds only the deletion.');
  }
}

function dropFromManifest(xml) {
  return CLASSES.reduce((text, name) => text.replace(new RegExp(`^[ \\t]*<members>${name}</members>\\r?\\n`, 'm'), ''), xml);
}

function deleteClass(root) {
  check(root);
  git(root, ['rm', '--quiet', '--', ...classFiles()]);
  const manifest = path.join(root, MANIFEST);
  if (fs.existsSync(manifest)) {
    fs.writeFileSync(manifest, dropFromManifest(fs.readFileSync(manifest, 'utf8')));
    git(root, ['add', '--', MANIFEST]);
  }
  git(root, ['commit', '--quiet', '-m', MESSAGE]);
  return git(root, ['rev-parse', 'HEAD']);
}

module.exports = { CLASSES, classFiles, check, dropFromManifest, deleteClass };

if (require.main === module) {
  try {
    const sha = deleteClass(path.resolve(__dirname, '..'));
    console.log(`Committed ${sha.slice(0, 7)}: deleted ${CLASSES.join(' and ')}. Push it to run the destructive path.`);
  } catch (err) {
    console.error(err.message);
    process.exit(1);
  }
}
