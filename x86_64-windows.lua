function argument(node)
    local register

    if node.index == 0 then register = "%rcx" end
    if node.index == 1 then register = "%rdx" end

    if node.typeof == "integer" then
        writeln("movq $" .. node.value .. ", " .. register)
    end

    if node.typeof == "whatever" then
        writeln("movq -" .. node.value .. "(%rbp), " .. register)
    end
end


function codegen(node)

    -- =========================
    -- PRINT (printf)
    -- =========================
    if node.kind == 0 then
        local addr, fn = node.addr, node.fn
        writeln("lea .fn" .. fn .. "." .. addr .. "(%rip), %rcx")
        writeln("call printf")
        return 0
    end


    -- =========================
    -- STRING
    -- =========================
    if node.kind == 1 then
        writeln(node.identifier .. ": .asciz " .. node.value)
        return 0
    end


    -- =========================
    -- .data
    -- =========================
    if node.kind == 2 then
        tabs(0)
        writeln(".data")
        tabs(1)
        return 0
    end


    -- =========================
    -- .text
    -- =========================
    if node.kind == 3 then
        tabs(0)
        writeln(".text")
        tabs(1)
        return 0
    end


    -- =========================
    -- Macros
    --      ENTRY (WinMain)
    -- =========================
    if node.kind == 4 then
        if node.instruction == "_start" then
            writeln(".text")
            writeln(".globl WinMain")
            writeln("WinMain:")
            tabs(1)

            writeln("call main")

            writeln("ret")
            writeln("")
            tabs(0)
        end
        return 0
    end


    -- =========================
    -- FUNCTION START
    -- =========================
    if node.kind == 100 then
        local name, id = node.name, node.id

        writeln(".text")
        writeln(".globl " .. name)
        writeln(name .. ":")
        writeln(".LFP" .. id .. ":")

        tabs(1)
        writeln("pushq %rbp")
        writeln("movq %rsp, %rbp")

        -- reserva shadow/local
        writeln("subq $32, %rsp")

        return 0
    end


    -- =========================
    -- FUNCTION END
    -- =========================
    if node.kind == 101 then
        local name, id = node.name, node.id

        tabs(0)
        writeln(".LFE" .. id .. ":")
        tabs(1)

        writeln("leave")
        writeln("ret")

        tabs(0)
        return 0
    end


    -- =========================
    -- RETURN (valor)
    -- =========================
    if node.kind == 102 and node.is_empty == 0 then
        local id, value, literal = node.id, node.value, node.is_literal

        if literal == 1 then
            writeln("movq $" .. value .. ", %rax")
        else
            writeln("movq -" .. value .. "(%rbp), %rax")
        end

        writeln("jmp .LFE" .. id)
        return 0
    end


    -- =========================
    -- RETURN (void)
    -- =========================
    if node.kind == 102 and node.is_empty == 1 then
        local id = node.id
        writeln("jmp .LFE" .. id)
        return 0
    end


    -- =========================
    -- CALL
    -- =========================
    if node.kind == 103 then
        local identifier = node.identifier

        writeln("subq $32, %rsp")
        writeln("call " .. identifier)
        writeln("addq $32, %rsp")

        return 0
    end


    -- =========================
    -- STORE LOCAL
    -- =========================
    if node.kind == 201 then
        local dest, src = node.dest, node.src
        writeln("lea " .. src .. "(%rip), %rcx")
        writeln("movq %rcx, -" .. dest .. "(%rbp)")
        return 0
    end
end
