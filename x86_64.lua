local json = morgana.require 'json'
local core = morgana.require 'core'
local symbols = morgana.require 'symbols'

local sample = false
local function_id = 0
local current_function = ""
local stack = 0;

local rax_ocupped = false
local rbx_ocupped = false

local rax_array = { "%al", "%ax", "%eax", "%rax" }
local rbx_array = { "%bh", "%bx", "%ebx", "%rbx" }

local function size_extension(bytes, size)
    if bytes == 1 and size == 4 then
        return 'movzx %al, %eax'
    elseif bytes == 2 and size == 4 then
        return 'movzx %ax, %eax'
    end
end

local function is_identifier(str)
    return type(str) == "string"
       and str:match("^[A-Za-z_][A-Za-z0-9_]*$") ~= nil
end

local function is_number(str)
    return type(str) == "string"
       and str:match("^%-?%d+$") ~= nil
end

local linux_start = [[
.text
.type _start, @function
.globl _start
_start:
    pushq %rbp
    movq %rsp, %rbp
    sub $16, %rsp
    call main
    movq %rax, %rdi
    movq $60, %rax
    syscall
]]

function typedmov(bytes)
    if bytes == 1 then return 'movb'
    elseif bytes == 2 then return 'movw'
    elseif bytes == 4 then return 'movl'
    elseif bytes == 8 then return 'movq'
    end
end

local function sufix(bytes)
    if bytes == 1 then return 'b'
    elseif bytes == 2 then return 'w'
    elseif bytes == 4 then return 'l'
    elseif bytes == 8 then return 'q'
    end
    return 'error'
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
            current_function = data.name

            -- Prologue of function
            append '.text\n'
            append('.globl ' .. data.name .. '\n')
            append('.type ' .. data.name .. ', @function\n')
            append(data.name .. ':\n')
            append('.LFP' .. function_id .. ':\n');
            append('\tpushq %rbp\n')
            append('\tmovq %rsp, %rbp\n')

            -- Body of function
            symbols:newScope();
            local code = parse(true);
            symbols:endScope();

            -- Epilogue of function
            append('\tsub $' .. math.ceil(-stack / 16) * 16 .. ', %rsp\n')
            append(code)
            append('.LFE' .. function_id .. ':\n');
            append('\t.size ' .. data.name .. ', .LFE' .. function_id .. ' - ' .. data.name .. '\n')
            append('\tmovq %rdi, %rax\n');
            append('\tleave\n');
            append('\tret\n');

            function_id = function_id + 1
            stack = 0;
            goto continue
        end

        if data.kind == 13 then
            append('movq %rax, %rdi\n')
            -- append('jmp .LFP' .. function_id .. '\n')
        end

        if data.kind == 30 and entries then
            code = code .. '.' .. current_function .. '_' .. data.identifier .. ':\n'
            goto continue
        end

        if data.kind == 31 and entries then
            append('jmp .' .. current_function .. '_' .. data.label .. '\n')
            goto continue
        end

        if data.kind == 32 and entries then
            local label = data.label
            local identifier = data.identifier
            local symbol = symbols:lookup(identifier).symbol
            local stack_position = symbol.stack_position
            local symbol_data = symbol.data;
            local bytes = symbol_data.bytes;

            append('cmp' .. sufix(bytes) .. ' $0, ' .. stack_position .. '(%rbp)\n')
            append('jne .' .. current_function .. '_' .. label .. '\n')
            goto continue
        end

        if data.kind == 40 then
            local identifier = data.identifier
            local type = json.decode(data.type)
            stack = stack - type.bytes;
            symbols:add(identifier, { stack_position = stack, data = type })
            goto continue
        end

        if data.kind == 41 then
            local value = data.value
            local identifier = data.identifier
            local symbol = symbols:lookup(identifier)
            local stack_position = symbol.stack_position
            local symbol_data = symbol.data;
            local size = symbol_data.bytes

            append(typedmov(size) .. ' $' .. value .. ', ' .. stack_position .. '(%rbp)\n')
            goto continue
        end

        if data.kind == 42 then
            local identifier = data.identifier
            local source = data.source
            local symbol = symbols:lookup(source)
            symbols:add(identifier, { symbol = symbol })
            goto continue
        end

        if data.kind == 50 then
            local identifier = data.identifier
            local instruction = data.instruction
            local lhs = data.lhs
            local rhs = data.rhs

            append('movq $0, %rax\n')

            if is_number(lhs) and is_number(rhs) then
                local result
                if instruction == "add" then result = tonumber(lhs) + tonumber(rhs)
                elseif instruction == "sub" then result = tonumber(lhs) - tonumber(rhs)
                elseif instruction == "mul" then result = tonumber(lhs) * tonumber(rhs)
                elseif instruction == "div" then result = tonumber(lhs) // tonumber(rhs) end
                stack = stack - 8;
                append('movq $' .. result .. ', ' .. stack .. '(%rbp)\n')
                symbols:add(identifier, { symbol = { stack_position = stack, data = { bytes = 8, matrix = 4, ptr = false } } })
            end

            local first
            local second
            local bytes = 0
            local matrix = 4
            if is_identifier(lhs) then
                local info = symbols:lookup(lhs)
                local symbol = info.symbol
                bytes = symbol.data.bytes
                matrix = symbol.data.matrix
                first = symbol.stack_position .. '(%rbp)'
            else
                bytes = 8
                first = '$' .. lhs
            end

            append(typedmov(bytes) .. ' ' .. first .. ', ' .. rax_array[matrix] .. '\n')
            if bytes == 1 or bytes == 2 then
                append(size_extension(bytes, 4) .. '\n')
            end

            bytes = 0
            if is_identifier(rhs) then
                local info = symbols:lookup(rhs)
                local symbol = info.symbol
                bytes = symbol.data.bytes
                second = symbol.stack_position .. '(%rbp)'
            else
                bytes = 8
                second = '$' .. rhs
            end

            matrix = math.floor(math.log(bytes * 8, 2) - 2);
            if instruction == "mul"  then instruction = 'i' .. instruction end
            append(instruction .. sufix(bytes) .. ' ' .. second .. ', ' .. rax_array[matrix] .. '\n');

            if bytes == 1 or bytes == 2 then
                append(size_extension(bytes, 4) .. '\n')
            end

            stack = stack - 8;
            append('movq %rax, ' .. stack .. '(%rbp)\n')
            symbols:add(identifier, { symbol = { stack_position = stack, data = { bytes = 8, matrix = 4, ptr = false } } })

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

    if core.getos() == core.os.linux then
        append(linux_start);
    end

    symbols:newScope()

    append(parse(false))
    return code
end
