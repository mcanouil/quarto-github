# GitHub Extension For Quarto

`github` is an extension for [Quarto](https://quarto.org) to automatically shortens and converts [GitHub references](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/autolinked-references-and-urls) into links.

## Installing

```bash
quarto add mcanouil/quarto-github
```

This will install the extension under the `_extensions` subdirectory.
If you're using version control, you will want to check in this directory.

## Using

You can reference GitHub issues, pull requests, and commits in your content using GitHub short references.
This Quarto extension automatically shortens and converts GitHub references into links.

To activate the filter, add the following to your YAML front matter:

- Old:

  ```yml
  filters:
    - quarto
    - github
  ```

- New (*Not functioning due to a Quarto bug*):

  ```yml
  filters:
    - path: github
      at: post-quarto
  ```

> [!IMPORTANT]
> The extension must be run after Quarto's processing (*i.e.*, `at: post-quarto`) to ensure that references (*e.g.*, `@fig-my-beautiful-figure`) are processed first by Quarto, then by the GitHub filter to avoid conflicts.

Some references require a default repository to be set. Use the extension configuration structure:

```yml
extensions:
  github:
    base-url: https://github.com # optional, defaults to https://github.com
    repository-name: jlord/sheetsee.js
```

> [!WARNING]
>
> The old top-level `repository-name` syntax is deprecated but still supported:
>
> ```yml
> repository-name: jlord/sheetsee.js  # deprecated
> ```

## Configuration

### `repository-name`

Specifies the default GitHub repository in the format `owner/repository`.
This is required for references that don't include the repository name (like `#123` or `GH-123`).

### `base-url`

Specifies the base URL for GitHub or GitHub Enterprise instances.
Defaults to `https://github.com`.

For GitHub Enterprise Server installations, you can use:

```yml
extensions:
  github:
    base-url: https://github.mycompany.com
    repository-name: myorg/myrepo
```

## References

Source: [Autolinked references and URLs - GitHub Docs](https://docs.github.com/en/get-started/writing-on-github/working-with-advanced-formatting/autolinked-references-and-urls).

### Mentioning users

| User/Organisation    | Raw reference  | Short link    |
|----------------------|----------------|---------------|
| User mention         | `@mcanouil`    | `@mcanouil`   |
|----------------------|----------------|---------------|
| Organisation mention | `@quarto-dev`  | `@quarto-dev` |

### Issues and pull requests

| Reference type                                                                             | Raw reference                                    | Short link                      |
|--------------------------------------------------------------------------------------------|--------------------------------------------------|---------------------------------|
| Issue, discussion, or pull request URL (***`repository-name` is optional!***)              | `https://github.com/jlord/sheetsee.js/issues/26` | `#26` or `lord/sheetsee.js#26`  |
| `#` and issue, discussion, or pull request number (***`repository-name` is required!***)   | `#26`                                            | `#26`                           |
| `GH-` and issue, discussion, or pull request number (***`repository-name` is required!***) | `GH-26`                                          | `GH-26`                         |
| `Username/Repository#` and issue, discussion, or pull request number                       | `jlord/sheetsee.js#26`                           | `jlord/sheetsee.js#26`          |
| `Organization_name/Repository#` and issue, discussion, or pull request number              | `github-linguist/linguist#4039`                  | `github-linguist/linguist#4039` |

## Commit SHAs

| Reference type                                    | Raw reference                                                                          | Short link                               |
|---------------------------------------------------|----------------------------------------------------------------------------------------|------------------------------------------|
| Commit URL (***`repository-name` is optional!***) | `https://github.com/jlord/sheetsee.js/commit/a5c3785ed8d6a35868bc169f07e40e889087fd2e` | `a5c3785` or `jlord/sheetsee.js@a5c3785` |
| SHA (***`repository-name` is required!***)        | `a5c3785ed8d6a35868bc169f07e40e889087fd2e`                                             | `a5c3785`                                |
| `User@SHA` (***Not supported!*** )                | `jlord@a5c3785ed8d6a35868bc169f07e40e889087fd2e`                                       | ***Not supported!***                     |
| `Username/Repository@SHA`                         | `jlord/sheetsee.js@a5c3785ed8d6a35868bc169f07e40e889087fd2e`                           | `jlord/sheetsee.js@a5c3785`              |

## Example

Here is the source code for a minimal example: [example.qmd](example.qmd).
