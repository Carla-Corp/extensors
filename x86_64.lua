local json = morgana.require 'json'
local core = morgana.require 'core'
local symbols = morgana.require 'symbols'

local sample = false
local function_id = 0
local stack = 0;

local linux_start = [[
.text
.type _start, @function
.globl _start
_start:
    pushq %rbp
    movq %rsp, %rbp
    call main
    movl %eax, %edi
    movl $60, %eax
    syscall
    leave
]]

function typedmov(bytes)
    if bytes == 1 then return 'movb'
    elseif bytes == 2 then return 'movw'
    elseif bytes == 4 then return 'movl'
    elseif bytes == 8 then return 'movq'
    end
end

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

        if data.kind == 11 then
            append '.text\n'
            append('.globl ' .. data.name .. '\n')
            append('.type ' .. data.name .. ', @function\n')
            append(data.name .. ':\n')
            append('.LFP' .. function_id .. ':\n');
            append('\t.cfi_startproc\n')

            symbols:newScope();
            append(parse(true))
            symbols:endScope();

            append('.LFE' .. function_id .. ':\n');
            append('\t.size ' .. data.name .. ', .LFE' .. function_id .. ' - ' .. data.name .. '\n')
            append('\t.cfi_endproc\n')
            append('\tmovq %rdi, %rax\n');
            append('\tret\n');
            function_id = function_id + 1
            goto continue
        end

        if data.kind == 40 then
            local type = json.decode(data.type);
            stack = stack - type.bytes;
            symbols:add(data.identifier, { stack_position = stack, data = type })
        end

        if data.kind == 41 then
            local value = data.value
            local identifier = data.identifier
            local symbol = symbols:lookup(identifier)
            local stack_position = symbol.stack_position
            local symbol_data = symbol.data;
            local size = symbol_data.bytes

            append(typedmov(size) .. ' $' .. value .. ', ' .. stack_position .. '(%rbp)\n')
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

    if core.getos() == core.os.linux then
        append(linux_start);
    end

    symbols:newScope()

    append(parse(false))
    return code
end
