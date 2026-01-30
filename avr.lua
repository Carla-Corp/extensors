local json = morgana.require 'json'
local core = morgana.require 'core'
local symbols = morgana.require 'symbols'

local sample = false
local loop = 0;

function ms_to_registers(ms)
    local value = ms % 65536
    local low = value % 256
    local high = math.floor(value / 256)

    local hex_low = string.format("0x%02X", low)
    local hex_high = string.format("0x%02X", high)

    return hex_low, hex_high, low, high
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

        if data.kind == 1002 and entries then
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

        if data.kind == 4 and entries then
            code = code .. '.LOOP' .. loop .. ':\n'
            code = code .. parse(true)
            append('rjmp .LOOP' .. loop .. '\n')
            loop = loop + 1;
            goto continue
        end

        if data.kind == 5 or data.kind == 6 then
            local r24, r25 = ms_to_registers(data.ms)
            append('ldi r24, ' .. r24 .. '\n')
            append('ldi r25, ' .. r25 .. '\n')
            append('rcall morgana_delay_ms\n')
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

    append [[.global morgana_delay_ms
morgana_delay_ms:
    movw r30, r24
    or r30, r31
    breq morgana_delay_end

morgana_delay_loop:
    ldi r18, 200
1:  ldi r19, 10
2:  nop
    dec r19
    brne 2b
    dec r18
    brne 1b
    sbiw r24, 1
    brne morgana_delay_loop
morgana_delay_end:
    ret
]]

    symbols:newScope()

    append(parse(false))
    return code
end
