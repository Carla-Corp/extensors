local json = morgana.require 'json'
local core = morgana.require 'core'
local symbols = morgana.require 'symbols'

local current_function_id = 0;
local stack = 0;
local pos = 0;

local os = core.getos();
local archsz = 8


local registers
if os == core.os.linux or os == core.os.macos then
    registers = {
        {"%rdi", "%edi", "%di",  "%dil"},
        {"%rsi", "%esi", "%si",  "%sil"},
        {"%rdx", "%edx", "%dx",  "%dl"},
        {"%rcx", "%ecx", "%cx",  "%cl"},
        {"%r8",  "%r8d", "%r8w", "%r8b"},
        {"%r9",  "%r9d", "%r9w", "%r9b"}
    }
elseif os == core.os.windows then
    registers = {
        {"%rcx", "%ecx", "%cx",  "%cl"},
        {"%rdx", "%edx", "%dx",  "%dl"},
        {"%r8",  "%r8d", "%r8w", "%r8b"},
        {"%r9",  "%r9d", "%r9w", "%r9b"},
    }
end

function mov(bytes)
    if     bytes == 1 then return "movb"
    elseif bytes == 2 then return "movw"
    elseif bytes == 4 then return "movl"
    elseif bytes == 8 then return "movq"
    else error("Unsupported size") end
end

function lea(bytes)
    if     bytes == 1 then return "leab"
    elseif bytes == 2 then return "leaw"
    elseif bytes == 4 then return "leal"
    elseif bytes == 8 then return "leaq"
    else error("Unsupported size") end
end

function parse(ctx, entries)
    local code = ""

    local append = function(str)
        if entries then code = code .. '\t' end
        code = code .. str
    end

    for i, data in ipairs(ctx) do
        local kind = data.kind

        -- function definition
        if kind == core.kind._function and not entries then
            if data.body[1].kind ~= core.kind.desconstructor then error("Function body must start with a desconstructor") end

            local desconstructor = data.body[1]
            symbols:newScope();

            append "\n.text\n"
            append(".global " .. data.name .. "\n")

            -- type directives
            if os == core.os.linux or os == core.os.macos then append(".type " .. data.name .. ", @function\n") end

            append(data.name .. ":\n")
            append(".LFP" .. current_function_id .. ":\n")

            -- function prologue
            append "\tpush %rbp\n"
            append "\tmov %rsp, %rbp\n"
            local params = data.params
            for _, param in ipairs(params) do stack = stack + param.bytes end

            if stack <= 16 then stack = 16
            elseif stack > 16 then stack = math.ceil(stack / 16) * 16 end
            append("\tsub $" .. stack .. ", %rsp\n")

            for j, param in ipairs(params) do
                pos = pos + param.bytes

                if j >= #registers then break end
                append("\t" .. mov(param.bytes) .. " " .. registers[j][param.matrix] .. ", " .. -pos .. "(%rbp)\n")

                symbols:add(desconstructor.id[j].string, { type = param, offset = -pos, kind = "Unloaded" })
            end

            -- function body
            append(parse(data.body, true))

            -- function epilogue
            append("\n.LFE" .. current_function_id .. ":\n")
            current_function_id = current_function_id + 1

            append "\tmov %rbp, %rsp\n"
            append "\tpop %rbp\n"
            append "\tret\n"

            goto continue
        end

        -- load variables from stack
        if kind == core.kind.load and entries then
            local what = data.what
            local var = symbols:lookup(what)
            append(mov(var.type.bytes) .. " " .. var.offset .. "(%rbp), " .. registers[1][var.type.matrix] .. "\n")
        end

        -- store data on the allocated place in stack
        if kind == core.kind.store and entries then
            local src = data.src
            local dest = data.dest
            local var = symbols:lookup(dest)

            append(mov(var.type.bytes) .. " $" .. src .. ", " .. var.offset .. "(%rbp)\n")
            goto continue
        end

        -- just return the last load
        if kind == core.kind.ret and entries then
            append "movq %rdi, %rax\n"
            append("jmp .LFE" .. current_function_id .. "\n")
            goto continue
        end

        ::continue::
    end

    return code
end

function codegen(str)
    local code = ""

    local append = function(x)
        code = code .. x
    end

    if os == core.os.linux then
        append ".text\n"
        append ".globl _start\n"
        append "_start:\n"
        append "\tcall main\n"
        append "\tmov %rax, %rdi\n"
        append "\tmov $60, %rax\n"
        append "\tsyscall\n"
    end

    symbols:newScope();

    -- core.mprint(str);

    local mainctx = json.decode(str)
    append(parse(mainctx.data, false))
    return code
end
