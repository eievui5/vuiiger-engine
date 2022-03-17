IF !DEF(TEXTFMT_INC)
DEF TEXTFMT_INC EQU 1

INCLUDE "res/charmap.inc"

MACRO fmttable ; name, strings
    ASSERT _NARG > 0
    FOR I, _NARG
        dw .s{d:I}
    ENDR
    FOR I, _NARG
.s{d:I} db \1, TEXT_END
    SHIFT
    ENDR
ENDM

MACRO textjump ; dest
    db TEXT_JUMP, BANK(\1)
    dw \1
ENDM

ENDC