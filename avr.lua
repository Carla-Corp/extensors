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

        if data.kind == 5 and entries then
            append('sbi 0x0A, ' .. data.pin .. '\n')

            if data.toggle then append('sbi 0x0B, ' .. data.pin .. '\n')
            else                append('cbi 0x0B, ' .. data.pin .. '\n') end

            goto continue
        end

        if data.kind == 1 and not entries then
            append '.section .text\n'
            append('.global ' .. data.name .. '\n')
            append(data.name .. ':\n')

            append(parse(true))

            goto continue
        end

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
