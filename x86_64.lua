local json = morgana.require 'json'
local core = morgana.require 'core'
local symbols = morgana.require 'symbols'

local sample = false
local function_id = 0
local current_function = ""
local stack = 0;

local rax_ocupped = false
local rbx_ocupped = false

local header = "";

local rax_array = { "%al", "%ax", "%eax", "%rax" }
local rbx_array = { "%bl", "%bx", "%ebx", "%rbx" }

local registers = { "%rax", "%rdi", "%rsi", "%rdx", "%rcx", "%r8", "%r9" }

local function size_extension(bytes, size, array)
    local i = math.floor(math.log(size * 8, 2) - 2);

    if bytes == 1 and size == 4 then
        return 'movzx ' .. array[1] .. ', ' .. array[i]
    elseif bytes == 2 and size == 4 then
        return 'movzx ' .. array[2] .. ', ' .. array[i]
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

local linux_alert_bool = false
local linux_alert = [[
.data
    morgana_alert_msg_asciz: .asciz "Alert\r"
    morgana_alert_nine_plus: .asciz "[9+] "
.text
.type __morgana_alert, @function
.globl __morgana_alert
__morgana_alert:
    push %rbp
    movq %rsp, %rbp
    subq $16, %rsp

    cmpq $9, %r15
    ja .nine_plus

    movq %rsp, %rsi
    movb $'0', %al
    addb %r15b, %al
    movb $'[', (%rsi)
    movb %al, 1(%rsi)
    movb $']', 2(%rsi)
    movb $' ', 3(%rsi)
    movb $0, 4(%rsi)

    movq $1, %rax
    movq $1, %rdi
    movq $5, %rdx
    syscall
    jmp .done

.nine_plus:
    movq $1, %rax
    movq $1, %rdi
    movq $morgana_alert_nine_plus, %rsi
    movq $5, %rdx
    syscall

.done:
    movq $1, %rax
    movq $1, %rdi
    movq $morgana_alert_msg_asciz, %rsi
    movq $7, %rdx
    syscall
    leave
    ret
]]

local linux_start_bool = false
local linux_start_break_line = [[
.text
.type _start, @function
.globl _start
_start:
    pushq %rbp
    movq %rsp, %rbp
    sub $16, %rsp
    call main
    movq %rax, %rcx

    movq $1, %rax
    movq $1, %rdi
    movq %rsp, %rsi
    movb $'\n', (%rsi)
    movb $0, 1(%rsi)
    movq $2, %rdx
    syscall

    movq %rcx, %rdi
    movq $60, %rax
    syscall
]]

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
    if bytes == 1 then
        return 'movb'
    elseif bytes == 2 then
        return 'movw'
    elseif bytes == 4 then
        return 'movl'
    elseif bytes == 8 then
        return 'movq'
    else
        return 'error'
    end
end

local function sufix(bytes)
    if bytes == 1 then
        return 'b'
    elseif bytes == 2 then
        return 'w'
    elseif bytes == 4 then
        return 'l'
    elseif bytes == 8 then
        return 'q'
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

        if data.kind == 101 then
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

        if data.kind == 103 then
            append('movq %rax, %rdi\n')
            -- append('jmp .LFP' .. function_id .. '\n')
        end

        if data.kind == 300 and entries then
            code = code .. '\n.' .. current_function .. '_' .. data.identifier .. ':\n'
            goto continue
        end

        if data.kind == 301 and entries then
            append('jmp .' .. current_function .. '_' .. data.label .. '\n')
            goto continue
        end

        if (data.kind == 302 or data.kind == 303) and entries then
            local label = data.label
            local identifier = data.identifier
            local symbol = symbols:lookup(identifier).symbol
            local stack_position = symbol.stack_position
            local symbol_data = symbol.data;
            local bytes = symbol_data.bytes;

            local instruction
            if data.kind == 302 then
                instruction = "jne"
            elseif data.kind == 303 then
                instruction = "je"
            end

            append('cmp' .. sufix(bytes) .. ' $0, ' .. stack_position .. '(%rbp)\n')
            append(instruction .. ' .' .. current_function .. '_' .. label .. '\n')
            goto continue
        end

        if (data.kind >= 304 and data.kind <= 307) and entries then
            local label = data.label
            local first = data.first
            local second = data.second

            local first_symbol = symbols:lookup(first).symbol
            local first_position = first_symbol.stack_position

            local second_symbol = symbols:lookup(second).symbol
            local second_position = second_symbol.stack_position

            local first_bytes = first_symbol.data.bytes;
            local second_bytes = second_symbol.data.bytes;

            local instruction
            if data.kind == 304 then
                instruction = "jg"
            elseif data.kind == 305 then
                instruction = "jl"
            elseif data.kind == 306 then
                instruction = "jge"
            elseif data.kind == 307 then
                instruction = "jle"
            end

            append(typedmov(first_bytes) ..
                ' ' .. first_position .. '(%rbp), ' .. rax_array[first_symbol.data.matrix] .. '\n')
            if first_bytes == 1 or first_bytes == 2 then
                append(size_extension(first_bytes, 4, rax_array) .. '\n')
            end

            append(typedmov(second_bytes) ..
                ' ' .. first_position .. '(%rbp), ' .. rbx_array[second_symbol.data.matrix] .. '\n')
            if second_bytes == 1 or second_bytes == 2 then
                append(size_extension(second_bytes, 4, rbx_array) .. '\n')
            end

            append('cmpq %rax, %rbx\n')
            append(instruction .. ' .' .. current_function .. '_' .. label .. '\n')
            goto continue
        end

        if data.kind == 400 then
            local identifier = data.identifier
            local type = json.decode(data.type)
            local start = stack;
            stack = stack - type.bytes;
            symbols:add(identifier, { stack_position = stack, data = type, start = start })
            goto continue
        end

        if data.kind == 401 then
            local value = data.value
            local identifier = data.identifier
            local symbol = symbols:lookup(identifier)
            local stack_position = symbol.stack_position
            local symbol_data = symbol.data
            local size = symbol_data.bytes
            local matrix = symbol_data.matrix

            if is_identifier(value) then
                symbol = symbols:lookup(value).symbol
                local source = symbol.stack_position
                append(typedmov(size) .. ' ' .. source .. '(%rbp), ' .. rax_array[matrix] .. '\n')
                append(typedmov(size) .. ' ' .. rax_array[matrix] .. ', ' .. stack_position .. '(%rbp)\n')
                goto continue
            end

            append(typedmov(size) .. ' $' .. value .. ', ' .. stack_position .. '(%rbp)\n')
            goto continue
        end

        if data.kind == 402 then
            local identifier = data.identifier
            local source = data.source
            local symbol = symbols:lookup(source)
            symbols:add(identifier, { symbol = symbol })
            goto continue
        end

        if data.kind == 500 then
            local identifier = data.identifier
            local instruction = data.instruction
            local lhs = data.lhs
            local rhs = data.rhs

            append('movq $0, %rax\n')

            if is_number(lhs) and is_number(rhs) then
                local result
                if instruction == "add" then
                    result = tonumber(lhs) + tonumber(rhs)
                elseif instruction == "sub" then
                    result = tonumber(lhs) - tonumber(rhs)
                elseif instruction == "mul" then
                    result = tonumber(lhs) * tonumber(rhs)
                elseif instruction == "div" then
                    result = tonumber(lhs) // tonumber(rhs)
                end
                stack = stack - 8;
                append('movq $' .. result .. ', ' .. stack .. '(%rbp)\n')
                symbols:add(identifier,
                    { symbol = { stack_position = stack, data = { bytes = 8, matrix = 4, ptr = false } } })
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
                append(size_extension(bytes, 4, rax_array) .. '\n')
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
            if instruction == "mul" then instruction = 'i' .. instruction end
            append(instruction .. sufix(bytes) .. ' ' .. second .. ', ' .. rax_array[matrix] .. '\n');

            if bytes == 1 or bytes == 2 then
                append(size_extension(bytes, 4, rax_array) .. '\n')
            end

            stack = stack - 8;
            append('movq %rax, ' .. stack .. '(%rbp)\n')
            symbols:add(identifier,
                { symbol = { stack_position = stack, data = { bytes = 8, matrix = 4, ptr = false } } })

            goto continue
        end

        if data.kind == 501 then
            if not linux_alert_bool and core.getos() == core.os.linux then
                header = header .. linux_alert .. '\n'
                linux_alert_bool = true
            end

            append('incq %r15\n')
            append('call __morgana_alert\n')
            goto continue
        end

        if data.kind == 800 then
            local identifier = data.identifier
            local address = data.address
            local offset = data.offset

            local symbol = symbols:lookup(address);
            local start = symbol.start
            local symbol_data = symbol.data;

            local bytes = symbol_data.tuple[offset + 1];

            local steps = 0
            for i, b in ipairs(symbol_data.tuple) do
                steps = steps + b
                if i == offset + 1 then goto stop end
            end
            ::stop::

            local position = start - steps;
            symbols:add(identifier,
                { stack_position = position, data = { bytes = bytes, matrix = math.floor(math.log(bytes * 8, 2) - 2) } })

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

    if not linux_start_bool and core.getos() == core.os.linux then
        if linux_alert_bool then
            append(linux_start_break_line .. '\n')
        else
            append(linux_start .. '\n')
        end
        linux_start_bool = true
    end

    return header .. code
end
