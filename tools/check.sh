#!/bin/sh
# Type-check all Luau sources.
cd "$(dirname "$0")/.."
~/.rokit/bin/rojo sourcemap default.project.json -o tools/dev/lsp/sourcemap.json >/dev/null &&
~/.rokit/bin/luau-lsp analyze --definitions=tools/dev/lsp/globalTypes.d.luau --sourcemap=tools/dev/lsp/sourcemap.json --no-strict-dm-types "${@:-src}"
