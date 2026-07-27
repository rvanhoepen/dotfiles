# Neovim

Personal [LazyVim](https://www.lazyvim.org/) configuration for PHP, Go, JavaScript/TypeScript, and Elixir development.

## Requirements

- Neovim 0.11 or newer
- Git and a Nerd Font
- `ripgrep` and `fd` for searching and file discovery
- The `opencode` CLI for the opencode.nvim integration
- Language runtimes and project dependencies needed by each project

This directory must be available as Neovim's configuration directory, normally `~/.config/nvim`. Plugins are installed automatically on first launch and pinned in `lazy-lock.json`.

Useful maintenance commands:

- `:Lazy` manages and updates plugins.
- `:Mason` manages language servers and development tools.
- `:checkhealth` diagnoses Neovim and plugin dependencies.
- `:checkhealth opencode` checks the opencode integration.

## Languages

The enabled LazyVim extras provide Go and PHP support. PHP defaults to phpactor; the local LSP configuration also adds Blade support and contains an inactive Intelephense configuration. `oxlint` is enabled directly and therefore expects an `oxlint` executable in the project or on `PATH`.

The custom neotest setup supports:

- Vitest through the project's Node.js dependencies
- Pest through `vendor/bin/pest`
- ExUnit through `mix test`
- Go through `go test`

## Related Tests

`<leader>tR` runs the current test file or its first existing related test. `<leader>tG` opens an existing related test or prompts for a location and creates it from `test-templates/` when a template is available.

Source-to-test conventions:

| Source | Candidate tests |
| --- | --- |
| `src/path/name.ts` | `src/path/name.test.ts`, `src/path/name.spec.ts`, then equivalent paths under `tests/` |
| `lib/path/name.ex` | `test/path/name_test.exs`, with a fallback that removes the first path component |
| `app/path/Name.php` | `tests/Feature/path/NameTest.php`, `tests/Unit/path/NameTest.php`, or `tests/path/NameTest.php` |
| `src/path/Name.php` | Equivalent paths under `tests/`, `tests/Unit/`, or `tests/Feature/` |
| `path/name.go` | `path/name_test.go` or `path/tests/name_test.go` |

Vitest files under `e2e/` and `componentTests/` are intentionally excluded.

## opencode

opencode.nvim is lazy-loaded by its mappings:

| Mapping | Action |
| --- | --- |
| `<C-a>` | Ask opencode about the current context |
| `<C-x>` | Select an opencode action |
| `<C-.>` | Toggle opencode |
| `go` / `goo` | Send a selected range / current line |
| `<S-C-u>` / `<S-C-d>` | Scroll the opencode session |
| `<A-a>` | Send the selected Snacks picker item |

These mappings replace native `<C-a>`, `<C-x>`, and `go` behavior. `+` and `-` are mapped to Vim's increment and decrement operations as replacements.
