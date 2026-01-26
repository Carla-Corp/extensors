local json = morgana.require 'json'
local core = morgana.require 'core'
local symbols = morgana.require 'symbols'

local sample = false

function parse(entries)
    local code = ""

    local append = function(str)
        if not sample then
            if entries then code = code .. '\t' end
            code = code .. str
        end
    end

    while true do
        local data = morgana.next()
        if not data then break end

        ::continue::
    end

    return code
end

function codegen()
    local code = ""

    local append = function(x)
        code = code .. x
    end

    symbols:newScope()

    append(parse(false))
    return code
end
