function codegen(node)
    if node.kind == 1 then
        local identifier = node.identifier

        if identifier == "_start" then
            tabs(0)
            writeln(".globl _start")
            writeln("_start:")
            tabs(1)
            writeln("movq %rsp, %rbp")
            writeln("call main")
            writeln("leave")
            writeln("")
            writeln("movq %rax, %rdi")
            writeln("movq $60, %rax")
            writeln("syscall")
            writeln("")
            tabs(0)
        end

    end

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

    if node.kind == 103 then
        local id, value, literal = node.id, node.value, node.is_literal
        if literal == 1 then
            writeln("movq $" .. value .. ", %rdi")
        end
        writeln("jmp .LFE" .. id .. "")
    end

    if node.kind == 300 then
        local name, fn = node.name, node.fn
        tabs(0)
        writeln(".morg." .. name .. "_" .. fn .. ":")
        tabs(1)
        return 0
    end

    if node.kind == 301 then
        local name, fn = node.name, node.fn
        writeln("jmp .morg." .. name .. "_" .. fn)
        return 0
    end

    if node.kind == 401 then
        local dest, value, stack, literal, lhs, rhs = node.dest, node.value, node.stack, node.is_literal, node.lhs, node.rhs

        if literal == 1 then
            if rhs == 1 then writeln("movb $" .. value .. ", -" .. dest .. "(%rbp)") end
            if rhs == 2 then writeln("movw $" .. value .. ", -" .. dest .. "(%rbp)") end
            if rhs == 4 then writeln("movl $" .. value .. ", -" .. dest .. "(%rbp)") end
            if rhs == 8 then writeln("movq $" .. value .. ", -" .. dest .. "(%rbp)") end
        end

        if literal ~= 1 then
            if lhs == 1 then writeln("movb -" .. stack .. "(%rbp), %al")  end
            if lhs == 2 then writeln("movw -" .. stack .. "(%rbp), %ax")  end
            if lhs == 4 then writeln("movl -" .. stack .. "(%rbp), %eax") end
            if lhs == 8 then writeln("movq -" .. stack .. "(%rbp), %rax") end

            if rhs == 1 then writeln("movb %al, -"  .. dest .. "(%rbp)")  end
            if rhs == 2 then writeln("movw %ax, -"  .. dest .. "(%rbp)")  end
            if rhs == 4 then writeln("movl %eax, -" .. dest .. "(%rbp)")  end
            if rhs == 8 then writeln("movq %rax, -" .. dest .. "(%rbp)")  end
        end

        return 0
    end
end
