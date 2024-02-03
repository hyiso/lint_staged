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

## Installation and setup

To install *lint_staged* in the recommended way, you need to:

1. Install *lint_staged* itself:
   - `dart pub add --dev lint_staged`
1. Set up the `pre-commit` git hook to run *lint_staged*
   - [Husky](https://github.com/hyiso/husky) is a recommended choice for configuring git hooks
   - Read more about git hooks [here](https://git-scm.com/book/en/v2/Customizing-Git-Git-Hooks)
1. Configure *lint_staged* to run linters and other tasks:
   - for example, add following in `pubspec.yaml`: 
   ```yaml
   lint_staged:
     'lib/**.dart': dart format --fix && dart fix --apply
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

*Lint_staged* must be configured in your `pubspec.yaml`

#### `pubspec.yaml` example:

```yaml
lint_staged:
  'lib/**.dart': your-cmd
```

This config will execute `your-cmd` with staged dart files passed as arguments.

## Filtering files

Linter commands work on a subset of all staged files, defined by a _glob pattern_. lint_staged uses [glob](https://github.com/dart-lang/glob) for matching files with the following [syntax](https://github.com/dart-lang/glob/blob/master/README.md#syntax):
### Match any characters in a filename: `*`

The `*` character matches zero or more of any character other than `/`. This
means that it can be used to match all files in a given directory that match a
pattern without also matching files in a subdirectory. For example, `lib/*.dart`
will match `lib/glob.dart` but not `lib/src/utils.dart`.

### Match any characters across directories: `**`

`**` is like `*`, but matches `/` as well. It's useful for matching files or
listing directories recursively. For example, `lib/**.dart` will match both
`lib/glob.dart` and `lib/src/utils.dart`.

If `**` appears at the beginning of a glob, it won't match absolute paths or
paths beginning with `../`. For example, `**.dart` won't match `/foo.dart`,
although `/**.dart` will. This is to ensure that listing a bunch of paths and
checking whether they match a glob produces the same results as listing that
glob. In the previous example, `/foo.dart` wouldn't be listed for `**.dart`, so
it shouldn't be matched by it either.

This is an extension to Bash glob syntax that's widely supported by other glob
implementations.

### Match any single character: `?`

The `?` character matches a single character other than `/`. Unlike `*`, it
won't match any more or fewer than one character. For example, `test?.dart` will
match `test1.dart` but not `test10.dart` or `test.dart`.

### Match a range of characters: `[...]`

The `[...]` construction matches one of several characters. It can contain
individual characters, such as `[abc]`, in which case it will match any of those
characters; it can contain ranges, such as `[a-zA-Z]`, in which case it will
match any characters that fall within the range; or it can contain a mix of
both. It will only ever match a single character. For example,
`test[a-zA-Z_].dart` will match `testx.dart`, `testA.dart`, and `test_.dart`,
but not `test-.dart`.

If it starts with `^` or `!`, the construction will instead match all characters
_not_ mentioned. For example, `test[^a-z].dart` will match `test1.dart` but not
`testa.dart`.

This construction never matches `/`.

### Match one of several possibilities: `{...,...}`

The `{...,...}` construction matches one of several options, each of which is a
glob itself. For example, `lib/{*.dart,src/*}` matches `lib/glob.dart` and
`lib/src/data.txt`. It can contain any number of options greater than one, and
can even contain nested options.

This is an extension to Bash glob syntax, although it is supported by other
layers of Bash and is often used in conjunction with globs.

### Escaping a character: `\`

The `\` character can be used in any context to escape a character that would
otherwise be semantically meaningful. For example, `\*.dart` matches `*.dart`
but not `test.dart`.

### Syntax errors

Because they're used as part of the shell, almost all strings are valid Bash
globs. This implementation is more picky, and performs some validation to ensure
that globs are meaningful. For instance, unclosed `{` and `[` are disallowed.

### Reserved syntax: `(...)`

Parentheses are reserved in case this package adds support for Bash extended
globbing in the future. For the time being, using them will throw an error
unless they're escaped.

### Exclude pattern: `!`

For any files you wish to exclude, use the same glob pattern but prepend it with `!`

```
lint_staged:
  'lib/**.dart': your-cmd
  '!lib/**.g.dart': your-cmd
```

This would include all .dart files, but exclude .g.dart files.


## What commands are supported?

Supported are any executables installed locally or globally via `pub` as well as any executable from your \$PATH.

> Using globally installed scripts is discouraged, since lint_staged may not work for someone who doesn't have it installed.

`lint_staged` uses `Process.run` to locate locally installed scripts.

Pass arguments to your commands separated by space as you would do in the shell. See [examples](#examples) below.

## Running multiple commands in a sequence

You can run multiple commands in a sequence on every glob. To do so, pass a list of commands joined with ` && `. This is useful for running autoformatting tools like `dart format` or `dart analyze` but can be used for any arbitrary sequences.

For example:

```yaml
lint_staged:
  'lib/**.dart': dart format --fix && dart fix --apply
```

going to execute `dart format --fix` and if it exits with `0` code, it will execute `dart fix --apply` on all staged dart files.

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
  'lib/**.dart': dart fix --apply
```

</details>

### Automatically fix code format and add to commit

<details>
  <summary>Click to expand</summary>

```yaml
lint_staged:
  'lib/**.dart': dart format --fix
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

### The output of commit hook looks weird (no colors, duplicate lines, verbose output on Windows, …)

<details>
  <summary>Click to expand</summary>

Git 2.36.0 introduced a change to hooks where they were no longer run in the original TTY.
This was fixed in 2.37.0:

https://raw.githubusercontent.com/git/git/master/Documentation/RelNotes/2.37.0.txt

> - In Git 2.36 we revamped the way how hooks are invoked. One change
>   that is end-user visible is that the output of a hook is no longer
>   directly connected to the standard output of "git" that spawns the
>   hook, which was noticed post release. This is getting corrected.
>   (merge [a082345372](https://github.com/git/git/commit/a082345372) ab/hooks-regression-fix later to maint).

If updating Git doesn't help, you can try to manually redirect the output in your Git hook; for example:

```shell
# .husky/pre-commit

#!/usr/bin/env sh
. "$(dirname -- "$0")/_/husky.sh"

if sh -c ": >/dev/tty" >/dev/null 2>/dev/null; then exec >/dev/tty 2>&1; fi

dart run lint_staged
```

</details>