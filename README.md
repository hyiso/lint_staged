# lint_staged

[![Pub Version](https://img.shields.io/pub/v/lint_staged?color=blue)](https://pub.dev/packages/lint_staged)
[![popularity](https://img.shields.io/pub/popularity/lint_staged?logo=dart)](https://pub.dev/packages/lint_staged/score)
[![likes](https://img.shields.io/pub/likes/lint_staged?logo=dart)](https://pub.dev/packages/lint_staged/score)
[![CI](https://github.com/hyiso/lint_staged/actions/workflows/ci.yml/badge.svg)](https://github.com/hyiso/lint_staged/actions/workflows/ci.yml)

Run linters on git staged files for your Flutter and Dart projects.

Inspired by Javascript [lint-staged](https://github.com/okonet/lint-staged)

## Why

Linting makes more sense when run before committing your code. By doing so you can ensure no errors go into the repository and enforce code style. But running a lint process on a whole project is slow, and linting results can be irrelevant. Ultimately you only want to lint files that will be committed.

This project contains a script that will run arbitrary shell tasks with a list of staged files as an argument, filtered by a specified glob pattern.
> If you've written one, please submit a PR with the link to it!

## Installation and setup

To install *lint_staged* in the recommended way, you need to:

1. Install *lint_staged* itself:
   - `dart pub add --dev lint_staged`
1. Set up the `pre-commit` git hook to run *lint_staged*
   - [Husky](https://github.com/hyiso/husky) is a popular choice for configuring git hooks
   - Read more about git hooks [here](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks)
1. Configure *lint_staged* to run linters and other tasks:
   - for example add following in `pubspec.yaml`: 
   ```yaml
   lint_staged:
     .dart: dart format --fix && dart fix --apply
   ```
   to automatically format & fix all staged dart files.
   - See [Configuration](#Configuration) for more info

Don't forget to commit changes to `pubspec.yaml` and `.husky` to share this setup with your team!

Now change a few files, `git add` or `git add --patch` some of them to your commit, and try to `git commit` them.

See [examples](#examples) and [configuration](#configuration) for more information.

## Changelog

See [CHANGELOG.md](https://github.com/hyiso/lint_staged/blob/main/CHANGELOG.md).

## Command line flags

```
❯ dart lint_staged --help
Usage: lint_staged [options]

Options:
  --allow-empty                      allow empty commits when tasks revert all staged changes (default: false)
  --diff [string]                    override the default "--staged" flag of "git diff" to get list of files. Implies
                                     "--no-stash".
  --diff-filter [string]             override the default "--diff-filter=ACMR" flag of "git diff" to get list of files
  --no-stash                         disable the backup stash, and do not revert in case of errors
```

- **`--allow-empty`**: By default, when linter tasks undo all staged changes, lint_staged will exit with an error and abort the commit. Use this flag to allow creating empty git commits.
- **`--diff`**: By default linters are filtered against all files staged in git, generated from `git diff --staged`. This option allows you to override the `--staged` flag with arbitrary revisions. For example to get a list of changed files between two branches, use `--diff="branch1...branch2"`. You can also read more from about [git diff](https://git-scm.com/docs/git-diff) and [gitrevisions](https://git-scm.com/docs/gitrevisions). This option also implies `--no-stash`.
- **`--diff-filter`**: By default only files that are _added_, _copied_, _modified_, or _renamed_ are included. Use this flag to override the default `ACMR` value with something else: _added_ (`A`), _copied_ (`C`), _deleted_ (`D`), _modified_ (`M`), _renamed_ (`R`), _type changed_ (`T`), _unmerged_ (`U`), _unknown_ (`X`), or _pairing broken_ (`B`). See also the `git diff` docs for [--diff-filter](https://git-scm.com/docs/git-diff#Documentation/git-diff.txt---diff-filterACDMRTUXB82308203).
- **`--no-stash`**: By default a backup stash will be created before running the tasks, and all task modifications will be reverted in case of an error. This option will disable creating the stash, and instead leave all modifications in the index when aborting the commit. Can be re-enabled with `--stash`

## Configuration

*Lint_staged* can be configured in ways:

- `lint_staged` map in your `pubspec.yaml`

#### `pubspec.yaml` example:

```yaml
lint_staged":
  ".dart": "your-cmd"
```

This config will execute `your-cmd` with the list of currently staged files passed as arguments.

So, considering you did `git add file1.ext file2.ext`, lint_staged will run the following command:

`your-cmd file1.ext file2.ext`

## What commands are supported?

Supported are any executables installed locally or globally via `dart` as well as any executable from your \$PATH.

> Using globally installed scripts is discouraged, since lint_staged may not work for someone who doesn't have it installed.

`lint_staged` uses Process.run to locate locally installed scripts.

Pass arguments to your commands separated by space as you would do in the shell. See [examples](#examples) below.

## Running multiple commands in a sequence

You can run multiple commands in a sequence on every glob. To do so, pass a list of commands joined with ` && `. This is useful for running autoformatting tools like `dart format` or `dart analyze` but can be used for any arbitrary sequences.

For example:

```yaml
lint_staged:
  .dart: dart format --fix && dart fix --apply
```

going to execute `dart format --fix` and if it exits with `0` code, it will execute `dart fix --apply` on all staged `.dart` files.

## Examples

All examples assume you've already set up lint_staged in the `pubspec.yaml` file and [husky](https://github.com/hyiso/husky) in its own config file.

```yaml
  lint_staged:
```

In `.husky/pre-commit`

```shell
#!/usr/bin/env sh
. "$(dirname "$0")/_/husky.sh"

dart run lint_staged
```

_Note: we don't pass a path as an argument for the runners. This is important since lint_staged will do this for you._

### Automatically fix analyze issues for `.dart` running as a pre-commit hook

<details>
  <summary>Click to expand</summary>

```yaml
lint_staged:
  .dart: dart fix --apply
```

</details>

### Automatically fix code format and add to commit

<details>
  <summary>Click to expand</summary>

```yaml
lint_staged:
  .dart: dart format --fix
```

This will run `dart format --fix` and automatically add changes to the commit.

</details>

## Frequently Asked Questions

### Can I use `lint_staged` via dart code?

<details>
  <summary>Click to expand</summary>

Yes!

```dart
import 'package:lint_staged/lint_staged.dart';

try {
  final success = await lintStaged()
  print(success ? 'Linting was successful!' : 'Linting failed!')
} catch (e) {
  print(e);
}
```

Parameters to `lintStaged` are equivalent to their CLI counterparts:

```js
const success = await lintStaged({
  allowEmpty: false,
  stash: true,
})
```

</details>

### Using with JetBrains IDEs _(WebStorm, PyCharm, IntelliJ IDEA, RubyMine, etc.)_

<details>
  <summary>Click to expand</summary>

_**Update**_: The latest version of JetBrains IDEs now support running hooks as you would expect.

When using the IDE's GUI to commit changes with the `precommit` hook, you might see inconsistencies in the IDE and command line. This is [known issue](https://youtrack.jetbrains.com/issue/IDEA-135454) at JetBrains so if you want this fixed, please vote for it on YouTrack.

Until the issue is resolved in the IDE, you can use the following config to work around it:

```json
{
  "husky": {
    "hooks": {
      "pre-commit": "lint_staged",
      "post-commit": "git update-index --again"
    }
  }
}
```

_Thanks to [this comment](https://youtrack.jetbrains.com/issue/IDEA-135454#comment=27-2710654) for the fix!_

</details>

### Can I run `lint_staged` in CI, or when there are no staged files?

<details>
  <summary>Click to expand</summary>

Lint_staged will by default run against files staged in git, and should be run during the git pre-commit hook, for example. It's also possible to override this default behaviour and run against files in a specific diff, for example
all changed files between two different branches. If you want to run *lint_staged* in the CI, maybe you can set it up to compare the branch in a _Pull Request_/_Merge Request_ to the target branch.

Try out the `git diff` command until you are satisfied with the result, for example:

```
git diff --diff-filter=ACMR --name-only master...my-branch
```

This will print a list of _added_, _changed_, _modified_, and _renamed_ files between `master` and `my-branch`.

You can then run lint_staged against the same files with:

```
dart run lint_staged --diff="master...my-branch"
```

</details>