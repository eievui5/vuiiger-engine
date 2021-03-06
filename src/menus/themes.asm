INCLUDE "defines.inc"
INCLUDE "menu.inc"

; These two helper macros define the themes and palettes, automatically turning
; them into a circular linked list. You're welcome :3

MACRO themes
	DEF FIRST_NAME EQUS "\1MenuTheme"
	REPT _NARG / 2
		DEF CUR_NAME EQUS "\1"
		SECTION "\1 Theme", ROMX
		\1MenuTheme::
			IF _NARG > 2
				db BANK(\3MenuTheme)
				dw \3MenuTheme
			ELSE
				db BANK(FIRST_NAME)
				dw FIRST_NAME
			ENDC
			INCBIN "res/ui/\2_cursor.2bpp"
			dw .end - .emblem, .emblem, .map
			db "{CUR_NAME}", 0
		.emblem INCBIN "res/ui/\2_emblem.2bpp"
		.end
		.map INCBIN "res/ui/\2_emblem.map"
			SHIFT 2
		PURGE CUR_NAME
	ENDR
	PURGE FIRST_NAME
ENDM

MACRO colors
	DEF FIRST_NAME EQUS "\1MenuPalette"
	REPT _NARG / 13
		DEF CUR_NAME EQUS "\1"
		SECTION "\1 Theme", ROMX
		\1MenuPalette::
			IF _NARG > 13
				SHIFT 13
				db BANK(\1MenuPalette)
				dw \1MenuPalette
				SHIFT -13
			ELSE
				db BANK(FIRST_NAME)
				dw FIRST_NAME
			ENDC
			SHIFT 1
			rgb \1, \2, \3
			SHIFT 3
			rgb \1, \2, \3
			SHIFT 3
			rgb \1, \2, \3
			SHIFT 3
			rgb \1, \2, \3
			SHIFT 3
			db "{CUR_NAME}", 0
		PURGE CUR_NAME
	ENDR
	PURGE FIRST_NAME
ENDM

	themes Pawprint, paw, Explorer, explorer, Heart, heart

	colors \
Pink,   255, 160, 255,\
        255,  24, 255,\
        128,   0, 128,\
          0,   0,   0,\
Red,    255, 160, 160,\
        255,  24,  24,\
        128,   0,   0,\
          0,   0,   0,\
Orange, 255, 238, 204,\
        230, 153,  16,\
        150, 102,   0,\
          0,   0,   0,\
Yellow, 255, 255, 160,\
        255, 255,  24,\
        128, 128,   0,\
          0,   0,   0,\
Green,  160, 255, 160,\
         24, 255,  24,\
          0, 128,   0,\
          0,   0,   0,\
Blue,   160, 160, 255,\
         24,  24, 255,\
          0,   0, 128,\
          0,   0,   0,\
Black,    0,   0,   0,\
         64,  64,  64,\
        128, 128, 128,\
        255, 255, 255,\

SECTION "Active Theme", WRAM0
wActiveMenuPalette:: ds 3
wActiveMenuTheme:: ds 3
