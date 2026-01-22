local json = morgana.require 'json'
local core = morgana.require 'core'
local symbols = morgana.require 'symbols'

local current_function_id = 0
local archsz = 8;
local archmat = 1;
local stack = 0;
local pos = 0;

local os = core.getos()
local sample = false
local lastemp = {}

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

function stackfix()
    if stack <= 16 then stack = 16
    elseif stack > 16 then stack = math.ceil(stack / 16) * 16 end
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

        local kind = data.kind

        if kind == core.kind.sample and entries and not sample then
            sample = true

            goto continue
        end

        -- function definition
        if kind == core.kind._function and not entries then
            local desconstructor = morgana.next();
            if desconstructor.kind ~= core.kind.desconstructor then error("Function body must start with a desconstructor") end

            -- local desconstructor = data.body[1]
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
            local params = json.decode(data.params).data
            for _, param in ipairs(params) do stack = stack + param.bytes end

            stackfix();
            append("\tsub $" .. stack .. ", %rsp\n")

            -- function parameters
            local identifiers = json.decode(desconstructor.identifiers)
            for j, param in ipairs(params) do
                pos = pos + param.bytes

                if j >= #registers then break end
                append("\t" .. mov(param.bytes) .. " " .. registers[j][param.matrix] .. ", " .. -pos .. "(%rbp)\n")
                symbols:add(identifiers.data[j].string, { type = param, offset = -pos, kind = "Variable" })
            end

            -- function body
            append(parse(true))

            -- function epilogue
            append("\n.LFE" .. current_function_id .. ":\n")
            current_function_id = current_function_id + 1

            append "\tmov %rbp, %rsp\n"
            append "\tpop %rbp\n"
            append "\tret\n"

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

    if os == core.os.linux then
        append ".text\n"
        append ".globl _start\n"
        append "_start:\n"
        append "\tcall main\n"
        append "\tmov %rax, %rdi\n"
        append "\tmov $60, %rax\n"
        append "\tsyscall\n"
    end

    symbols:newScope()

    append(parse(false))
    return code
end
