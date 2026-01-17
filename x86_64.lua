local json = morgana.require 'json'
local core = morgana.require 'core'

local current_function_id = 0;
local stack = 0;
local pos = 0;

local os = core.getos();

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
            append "\n.text\n"
            append(".global " .. data.name .. "\n")

            -- type directives
            if os == core.os.linux or os == core.os.macos then append(".type " .. data.name .. ", @function\n") end

            append(data.name .. ":\n")
            append(".LFP" .. current_function_id .. ":\n")

            -- function prologue
            append "\tpush %rbp\n"
            append "\tmov %rsp, %rbp\n"
            append "\tsub $16, %rsp\n"
            stack = stack + 16

            local registers
            if os == core.os.linux or os == core.os.macos then registers = { "%rdi", "%rsi", "%rdx", "%rcx", "%r8", "%r9" }
            elseif os == core.os.windows then registers = { "%rcx", "%rdx", "%r8", "%r9" } end

            local params = data.params
            for j, param in ipairs(params) do
                pos = pos - param.bytes
                if j >= #registers then break end
                append("\tmov " .. registers[j] .. ", " .. pos .. "(%rbp)\n")
            end

            -- function body
            parse(data.body, true)

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


    local mainctx = json.decode(str)
    append(parse(mainctx.data, false))
    return code
end
