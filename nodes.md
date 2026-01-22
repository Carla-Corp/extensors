# How Nodes looks like?

When you get an node using the morgana internal iterator, you can parse it. But, for that, you need to know how nodes looks like.

Nodes are tables that contains the following field `kind`. But for what kind is used?
- the `kind` (`integer`) is literally the kind of the node. You can parse it using a simple if statement, like that:
```lua
-- import the core for the kind enumerator
local core = morgana.require 'core'
function codegen() 
    while true do
       local node = morgana.next()
       if node == nil then break end
       
       -- u can compre like that
       if node.kind == core.kind._function then
           -- assembly generator for function
       elseif node.kind == core.kind.desconstructor then
           -- assembly generator for desconstructor
       end
    end
end
```

Now, you have to know how to parse the other node fields. Each node has fields like `name`, `type`, `value`, `children`, etc. You can access these fields using `node.field_name`. But some kinds have special fields or, just dont have no one field, just even `kind`.

Some nodes, like `_function` have special fields, like `params` who are a `string`. But isn't just a `string`, it's a JSON. Who you need parse using `json.decode` 

You can import the `json` module using 

```lua
local json = morgana.require 'json'
```

And can usage like that

```lua
if kind == core.kind._function and not entries then
  local params = json.decode(data.params).data

  for _, param in ipairs(params) do
  end

  -- function body
  append(parse(true))

  goto continue
end
```
