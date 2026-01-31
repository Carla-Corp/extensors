local json = morgana.require 'json'
local core = morgana.require 'core'
local symbols = morgana.require 'symbols'

local current_function = ''
local sample = false
local loop = 0;

function getPinMask(pin)
    if pin < 0 or pin > 7 then error("Pin must be between 0 and 7") end
    return 1 << pin
end

function ms_to_registers(ms)
    local value = ms % 65536
    local low = value % 256
    local high = math.floor(value / 256)

    local hex_low = string.format("0x%02X", low)
    local hex_high = string.format("0x%02X", high)

    return hex_low, hex_high, low, high
end

local already_defined_gpios = {};

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
            if not already_defined_gpios[data.pin] then
                already_defined_gpios[data.pin] = true
                append('sbi 0x0A, ' .. data.pin .. '\n')
            end

            if data.toggle then append('sbi 0x0B, ' .. data.pin .. '\n')
            else                append('cbi 0x0B, ' .. data.pin .. '\n') end

            goto continue
        end

        if data.kind == 1003 and entries then
            if not already_defined_gpios[data.pin] then
                already_defined_gpios[data.pin] = true
                append('cbi 0x0A, ' .. data.pin .. '\n')
                append('sbi 0x0B, ' .. data.pin .. '\n')
            end

            append 'in r24, 0x09\n'
            append('andi r24, ' .. getPinMask(data.pin) .. '\n')
            -- for i = 0, (data.pin - 1) do append 'lsr r24\n' end

            -- append 'st X+, r24\n'
            goto continue
        end

        if data.kind == 1 and not entries then
            append '.section .text\n'
            append('.global ' .. data.name .. '\n')
            append(data.name .. ':\n')
            current_function = data.name;
            append(parse(true))
            goto continue
        end

        if data.kind == 5 and entries then
            code = code .. '.LOOP' .. loop .. ':\n'
            code = code .. parse(true)
            append('rjmp .LOOP' .. loop .. '\n')
            loop = loop + 1;
            goto continue
        end

        if data.kind == 6 or data.kind == 7 then
            local r24, r25 = ms_to_registers(data.ms)
            append('ldi r24, ' .. r24 .. '\n')
            append('ldi r25, ' .. r25 .. '\n')
            append('rcall morgana_delay_ms\n')
            goto continue
        end

        if data.kind == 10 and entries then
            code = code .. '.' .. current_function .. '_' .. data.identifier .. ':\n'
            goto continue
        end

        if data.kind == 8 and entries then
            -- needs make a good stack yet
            -- append('ld r24, X+\n')
            append('cpi r24, 0\n')
            append('brne .' .. current_function .. '_' .. data.label .. '\n')
            goto continue
        end

        if data.kind == 9 and entries then
            -- needs make a good stack yet
            append('rjmp .' .. current_function .. '_' .. data.label .. '\n')
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
    append '\n'

    symbols:newScope()

    append(parse(false))
    return code
end
