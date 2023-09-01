## 0.4.2

 - Bump `ansi` to `0.4.0`

## 0.4.1

 - Bump `ansi` to `0.3.0`

## 0.4.0

> Note: This release has breaking changes.

 - **BREAKING** **CHORE**: Change minSdk to `2.18.0`
 - **BREAKING** **REFACTOR**: Refactor `git` and `workflow`.
 - **FEAT**: Simplify step message.

## 0.3.0

> Note: This release has breaking changes.

 - **Fix**: Skip stash when nothing to stash.(fix #5)
 - **BREAKING** **FEAT**: Replace support of `DEBUG=true` env to `VERBOSE=true` by using package [`verbose`](https://pub.dev/packages/verbose).
 - **FEAT**: Use `SpinnerProgress` when step is running.

## 0.2.0

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**: Use [glob](https://github.com/dart-lang/glob) to support pattern in config.
 - **FEAT**: Support DEBUG=true in env to print verbose log. 

## 0.1.5

- Fix no `.dart` file staged when script containing `<file>` placholder. 

## 0.1.4

- Shrink reduant running when script containing `<file>` placholder. 

## 0.1.3

- Support `<file>` placholder in script, so script can run on parent directory. 

## 0.1.2

- Fix loadConfig

## 0.1.1

- Change minSdkVersion to 2.12.0

## 0.1.0

- Basiclly support lint all staged `.dart` files
