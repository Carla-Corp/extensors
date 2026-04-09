<img align="right" src="./assets/icon_nobg.png" alt="Morgana Logo" width="120px" height="120px">
<br><br>

# 🔗 [Morgana IR language](https://github.com/lucasFelixSilveira/morgana) Extensors

How can i create my own extensors?

You can create your own extensors by following these steps:

1. Create a github directory for your extensors.
2. Code your extensor file to generate the assembly code.

### How to code an extensor file?
You will need to write the file using lua ([Runa (ルナ)](https://github.com/lucasFelixSilveira/runa)), all extensors have some functions to be used to create the assembly file. They are:
  - `write`: Write a assembly code in the output file.
  - `writeln`: Write a assembly line of code in the output file.
  - `tabs`: Define how many tabs should be placed before all lines of Assembly code.

All this functions are defined into the Morgana Compiler. You don't need worry about expressions optimizations. Morgana will care that for you. 

All you need to do is generate assembly for the correct architecture, or emit assembly as needed for each case.
For example, when handling Assembly structures not supported by the official extensors.

### How can i REALLY write the file?
```lua
function codegen(node)
    -- You need to write the assembly generator using IFs.
    -- For example:
     
    if node.kind == 10 then
         local name, stack, id = node.name, node.stack, node.id
         tabs(0)
         writeln(".LFE" .. id .. ":")
         tabs(1)
         writeln(".size " .. name .. ", .LFE" .. id .. " - " .. name)
         writeln("movq %rdi, %rax")
         writeln("leave")
         writeln("ret")
         tabs(0)
         return 0
    end
 
    if node.kind == 101 then
         local name, id = node.name, node.id
         writeln(".globl " .. name)
         writeln(name .. ":")
         writeln(".LFP" .. id .. ":")
         tabs(1)
         writeln("pushq %rbp")
         writeln("movq %rsp, %rbp")
         return 0
    end
end
```

3. On the main branch, put your exetensor file.
4. Link your repository to `target.toml` file.

```toml
[target]
name = "default"
sources = "src/main.crl"

[extensors]
# You can add extensors from an external git repository!
repositories = [ "your repository here", "git@github.com:Carla-Corp/extensors.git" ]
```

5. Install the extensor using the `morgana` command line tool.
```sh-session
$ morgana install <extensor_name> <branch - optional>
```
