function argument(node)
    if node.typeof == "integer" then
        local register
        if node.index == 0 then register = "%rdi" end
        if node.index == 1 then register = "%rsi" end
        writeln("movq $" .. node.value .. ", " .. register)
    end

    if node.typeof == "whatever" then
        local register
        if node.index == 0 and node.bits == 64 then register = "%rdi" end
        if node.index == 1 and node.bits == 64 then register = "%rsi" end
        writeln("movq -" .. node.value .. "(%rbp), " .. register)
    end
end

function codegen(node)
    if node.kind == 0 then
        local length, addr, fn = node.length, node.addr, node.fn
        writeln("movq $1, %rax")
        writeln("movq $1, %rdi")
        writeln("movq $.fn" .. fn .. "." .. addr .. ", %rsi")
        writeln("movq $" .. length .. ", %rdx")
        writeln("syscall")
        return 0
    end

    if node.kind == 1 then
        writeln(node.identifier .. ": .string " .. node.value)
        return 0
    end

    if node.kind == 2 then
        tabs(0)
        writeln(".data")
        tabs(1)
        return 0
    end

    if node.kind == 3 then
        tabs(0)
        writeln(".text")
        tabs(1)
        return 0
    end

    if node.kind == 4 then
        if node.instruction == "_start" then
            writeln(".text")
            writeln(".globl _start")
            writeln("_start:")
            tabs(1)
            writeln("call main")
            writeln("movq %rax, %rdi")
            writeln("movq $60, %rax")
            writeln("syscall")
            writeln("")
            tabs(0)
        end
        return 0
    end

    if node.kind == 100 then
        local name, id = node.name, node.id
        writeln(".text")
        writeln(".globl " .. name)
        writeln(name .. ":")
        writeln(".LFP" .. id .. ":")
        tabs(1)
        writeln("pushq %rbp")
        writeln("movq %rsp, %rbp")
        return 0
    end

    if node.kind == 101 then
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

    -- valueted return
    if node.kind == 102 and node.is_empty == 0 then
        local id, value, literal = node.id, node.value, node.is_literal
        if literal == 1 then
            writeln("movq $" .. value .. ", %rdi")
        end

        if literal ~= 1 then
            writeln("movq -" .. value .. "(%rbp)")
        end

        writeln("jmp .LFE" .. id .. "")
        return 0
    end

    -- void return
    if node.kind == 102 and node.is_empty == 1 then
        local id = node.id
        writeln("jmp .LFE" .. id .. "")
        return 0
    end

    if node.kind == 103 then
        local identifier = node.identifier
        writeln("call " .. identifier)
        return 0
    end

    if node.kind == 201 then
        local dest, src = node.dest, node.src
        writeln("movq $" .. src .. ", -" .. dest .. "(%rbp)")
        return 0
    end
end
