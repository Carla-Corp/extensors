<img align="right" src="./assets/icon_nobg.png" alt="Morgana Logo" width="120px" height="120px">
<br><br>

# 🔗 [Morgana IR language](https://github.com/lucasFelixSilveira/morgana) Extensors

How can i create my own extensors?

You can create your own extensors by following these steps:

1. Create a github directory for your extensors.
2. Code your extensor file to generate the assembly code.

### How to code an extensor file?
You will need to write the file using lua, all extensors have a `morgana` table that contains the following fields:
  - `require`: Import directives from the Morgana kernel.
  - `next`: Collect the next node in the iterator. ([More about nodes](./nodes.md))
  - `reset`: Reset the current index of the iterator.

Before import something, you need to know why native modules Morgana has. They are:
  - `json`: Decode the JSON input
  - `core`: Provides basic functionalities for the extensor
  - `symbols`: Provides a symbol table for the extensor

### How can i REALLY write the file?
```lua
local json = morgana.require 'json'
local core = morgana.require 'core'
local symbols = morgana.require 'symbols'

-- that is the entry point for the Morgana compiler
function codegen()
    return "return here the assembly code"
end
```

3. On the main branch, put your exetensor file.
4. Put your repository link in the `target.toml` file.

```toml
[target]
name = "default"
sources = "src/main.crl"

[extensors]
# You can add extensors from an external git repository!
repositories = [ "git@github.com:Carla-Corp/extensors.git", "your repository link here" ]
```

5. Install the extensor using the `morgana` command line tool.
```sh-session
$ morgana install <extensor_name> <branch - optional>
```
