INCLUDE "defines.inc"
INCLUDE "dungeon.inc"
INCLUDE "entity.inc"
INCLUDE "hardware.inc"
INCLUDE "item.inc"

SECTION "Init dungeon", ROM0
; Switch to the dungeon state.
; @clobbers: bank
InitDungeon::
	; Null init
	xor a, a
	ld c, SIZEOF("dungeon BSS")
	ld hl, STARTOF("dungeon BSS")
	call MemSetSmall

	; Null out all entities.
	ld hl, wEntity0
	ld b, NB_ENTITIES
.clearEntities
	ld [hl], a
	inc h
	dec b
	jr nz, .clearEntities

	ld [wSkipAllyTurn], a

	lb bc, BANK(xLuvui), 5
	ld de, xLuvui
	ld h, HIGH(wEntity0)
	call SpawnEntity

	lb bc, BANK(xAris), 6
	ld de, xAris
	ld h, HIGH(wEntity1)
	call SpawnEntity

	ld a, 1
	ld [wDungeonCurrentFloor], a
	call DungeonGenerateFloor
; Re-initializes some aspects of the dungeon, such as rendering the map.
; @clobbers: bank
SwitchToDungeonState::
	ld a, GAMESTATE_DUNGEON
	ld [wGameState], a
	xor a, a
	ld [wIsDungeonFading], a
	ld hl, wWindowMode
	ld [hli], a
	ld [hli], a

	call InitUI

	ld h, HIGH(wEntity0)
.loop
	ld l, LOW(wEntity0_Bank)
	ld a, [hli]
	and a, a
	call nz, LoadEntityGraphics
.next
	inc h
	ld a, h
	cp a, HIGH(wEntity0) + NB_ENTITIES
	jp nz, .loop

	; Load the active dungeon.
	ld hl, wActiveDungeon
	ld a, [hli]
	rst SwapBank
	; Deref pointer
	ld a, [hli]
	ld h, [hl]
	ld l, a
	push hl
		; Deref tileset
		ASSERT Dungeon_Tileset == 0
		ld a, [hli]
		ld h, [hl]
		ld l, a
		ld bc, 20 * 16
		ld de, $8000 + BLANK_METATILE_ID * 16
		call VRAMCopy
	pop hl

	call FadeIn

	; Deref palette if on CGB
	ldh a, [hSystem]
	and a, a
	jp z, .skipCGB
		; Set palettes
		ld a, %11111111
		ld [wBGPaletteMask], a
		ld a, %11111111
		ld [wOBJPaletteMask], a

		ASSERT Dungeon_Palette == 2
		inc hl
		inc hl
		ld a, [hli]
		ld h, [hl]
		ld l, a

		push hl
		ld c, 3
		ld de, wBGPaletteBuffer + 3 * 12
		call MemCopySmall
		pop hl

		push hl
		ld c, 3
		ld de, wBGPaletteBuffer + 4 * 12
		call MemCopySmall
		pop hl

		push hl
		ld c, 3
		ld de, wBGPaletteBuffer + 5 * 12
		call MemCopySmall
		pop hl

		push hl
		ld c, 3
		ld de, wBGPaletteBuffer + 6 * 12
		call MemCopySmall
		pop hl

		; Load first 3 palettes
		ld c, 3 * 12
		ld de, wBGPaletteBuffer
		call MemCopySmall

		ld hl, wActiveDungeon + 1
		ld a, [hli]
		ld h, [hl]
		ld l, a
		inc hl
		inc hl
		inc hl
		inc hl
		ASSERT Dungeon_Items == 4
		; Push each item onto the stack :)
		ld b, DUNGEON_ITEM_COUNT
	.pushItems
		ld a, [hli]
		push af
		ld a, [hli]
		ld e, a
		ld a, [hli]
		ld d, a
		push de
		dec b
		jr nz, .pushItems

	.color
		; Now pop each in order and load their palettes and graphics
		ld b, DUNGEON_ITEM_COUNT
		ld de, wBGPaletteBuffer + 6 * 12 + 3
	.copyItemColor
		pop hl
		pop af
		rst SwapBank
		ASSERT Item_Palette == 0
		ld a, [hli]
		ld h, [hl]
		ld l, a
		ld c, 9
		call MemCopySmall
		ld a, e
		sub a, 21
		ld e, a
		ld a, d
		sbc a, 0
		ld d, a
		dec b
		jr nz, .copyItemColor
.skipCGB
	ld hl, wActiveDungeon
	ld a, [hli]
	rst SwapBank
	ld a, [hli]
	ld h, [hl]
	ld l, a
	inc hl
	inc hl
	inc hl
	inc hl
	ASSERT Dungeon_Items == 4
	; Push each item onto the stack :)
	ld b, DUNGEON_ITEM_COUNT
.pushItems2
	ld a, [hli]
	push af
	ld a, [hli]
	ld e, a
	ld a, [hli]
	ld d, a
	push de
	dec b
	jr nz, .pushItems2

.items
	; And finally, copy the graphics
	ld b, DUNGEON_ITEM_COUNT
	ld de, $8000 + (ITEM_METATILE_ID + 3 * 4) * 16
.copyItemGfx
	pop hl
	pop af
	rst SwapBank
	inc hl
	inc hl
	ASSERT Item_Graphics == 2
	ld a, [hli]
	ld h, [hl]
	ld l, a
	ld c, 16 * 4
	call VRAMCopySmall
	ld a, e
	sub a, 128
	ld e, a
	ld a, d
	sbc a, 0
	ld d, a
	dec b
	jr nz, .copyItemGfx

	; Initialize previous health
	ld hl, wPreviousHealth
	ld de, wEntity0_Bank
	ld a, [de]
	and a, a
	jr z, :+
	ld e, LOW(wEntity0_Health)
	ld a, [de]
	inc e
	ld [hli], a
	ld a, [de]
	ld [hli], a
:
	ld de, wEntity1_Bank
	ld a, [de]
	and a, a
	jr z, :+
	ld e, LOW(wEntity0_Health)
	ld a, [de]
	inc e
	ld [hli], a
	ld a, [de]
	ld [hli], a
:
	call DrawAttackWindow

	ld a, BANK(xFocusCamera)
	rst SwapBank
	call xFocusCamera
	ld a, [wDungeonCameraX + 1]
	ld [wLastDungeonCameraX], a
	ld a, [wDungeonCameraY + 1]
	ld [wLastDungeonCameraY], a
	ld a, BANK(xUpdateScroll)
	rst SwapBank
	call xUpdateScroll
	ld a, BANK(xDrawDungeon)
	rst SwapBank
	jp xDrawDungeon

SECTION "Dungeon State", ROM0
DungeonState::
	; If fading out, do nothing but animate entities and wait for the fade to
	; complete.
	ld a, [wIsDungeonFading]
	and a, a
	jr z, .notFading
	ld a, [wFadeSteps]
	and a, a
	jr nz, .dungeonRendering
		ld hl, wDungeonFadeCallback
		ld a, [hli]
		ld h, [hl]
		ld l, a
		jp hl
.notFading
	ld hl, wEntityAnimation.pointer
	ld a, [hli]
	or a, [hl]
	jr nz, .playAnimation
		bankcall xMoveEntities
		call ProcessEntities
		jr :+
.playAnimation
		bankcall xUpdateAnimation
:

.dungeonRendering
	; Scroll the map after moving entities.
	bankcall xHandleMapScroll
	bankcall xFocusCamera
	bankcall xUpdateScroll

	; Render entities after scrolling.
	bankcall xRenderEntities
	call UpdateEntityGraphics

	ld a, [wPrintString]
	and a, a
	call nz, DrawPrintString

	ld hl, wPreviousHealth
	ld de, wEntity0_Bank
	ld a, [de]
	and a, a
	jr z, :+
	ld e, LOW(wEntity0_Health)
	ld a, [de]
	inc e
	cp a, [hl]
	jr nz, .updateStatus
	inc hl
	ld a, [de]
	inc e
	cp a, [hl]
	jr nz, .updateStatus
	inc hl
:
	ld de, wEntity1_Bank
	ld a, [de]
	and a, a
	jr z, .skipUpdateStatus
	ld e, LOW(wEntity0_Health)
	ld a, [de]
	inc e
	cp a, [hl]
	jr nz, .updateStatus
	inc hl
	ld a, [de]
	cp a, [hl]
	jr z, .skipUpdateStatus
.updateStatus
	call DrawStatusBar
	; Update health cache
	ld hl, wPreviousHealth
	ld de, wEntity0_Health
	ld a, [de]
	inc e
	ld [hli], a
	ld a, [de]
	ld [hli], a

	ld de, wEntity1_Bank
	ld a, [de]
	and a, a
	jr z, :+
	ld e, LOW(wEntity0_Health)
	ld a, [de]
	inc e
	ld [hli], a
	ld a, [de]
	ld [hli], a
:
.skipUpdateStatus

	; Wait after a level up for the next check.
	ld a, [wLevelUpMessageLifetime]
	and a, a
	jr z, .checkForLevelUp
	dec a
	ld [wLevelUpMessageLifetime], a
	jr .skipLevelUp

.checkForLevelUp
	; Iterate through each party member to check if their XP has changed.
	ld de, wPartyLastXp
	ld h, HIGH(wEntity0)
.levelUpLoop
	ld l, LOW(wEntity0_Bank)
	ld a, [hl]
	and a, a
	jr z, .levelUpNext
	ld l, LOW(wEntity0_Experience)
	ld a, [de]
	cp a, [hl]
	jr nz, .callCheck
	inc de
	inc l
	ld a, [de]
	dec de
	cp a, [hl]
	jr z, .levelUpNext
.callCheck
	; If XP has changed, check if we can level up
	ld a, BANK(xCheckForLevelUp)
	rst SwapBank
	push hl
		push de
			call xCheckForLevelUp
		pop de
	pop hl
	ld a, c
	and a, a
	jr z, .levelUpNext
	; If we leveled up, delay the next check
	ld a, 255
	ld [wLevelUpMessageLifetime], a
	ld hl, wPreviousHealth
	ld [hli], a
	ld [hli], a
	ld [hli], a
	ld [hli], a
	jr .skipLevelUp

.levelUpNext
	inc de
	inc de
	inc h
	ld a, h
	cp a, HIGH(wEntity0) + NB_ALLIES
	jr nz, .levelUpLoop
.skipLevelUp
	ld a, BANK(xUpdateAttackWindow)
	rst SwapBank
	jp xUpdateAttackWindow

OpenPauseMenu::
	ld b, BANK(xPauseMenu)
	ld de, xPauseMenu
	call AddMenu
	ld a, GAMESTATE_MENU
	ld [wGameState], a
	xor a, a
	ld [wSTATTarget], a
	ld [wSTATTarget + 1], a
	ret

SECTION "Dungeon complete!", ROM0
DungeonComplete::
	ld hl, wActiveDungeon
	ld a, [hli]
	rst SwapBank
	ld a, [hli]
	ld h, [hl]
	add a, Dungeon_CompletionFlag
	ld l, a
	adc a, h
	sub a, l
	ld h, a
	ld c, [hl]
	call GetFlag
	or a, [hl]
	ld [hl], a

	call FadeToBlack

	ld hl, wFadeCallback
	ld a, LOW(InitMap)
	ld [hli], a
	ld [hl], HIGH(InitMap)
	ret

SECTION "Get Item", ROM0
; Get a dungeon item given an index in b
; @param b: Item ID
; @return b: Item bank
; @return hl: Item pointer
; @clobbers bank
GetDungeonItem::
	ld hl, wActiveDungeon
	ld a, [hli]
	rst SwapBank
	ld a, [hli]
	ld h, [hl]
	ld l, a
	ASSERT Dungeon_Items == 4
	inc hl
	inc hl
	inc hl
	inc hl
	ld a, b
	add a, b
	add a, b
	add a, l
	ld l, a
	adc a, h
	sub a, l
	ld h, a
	ld a, [hli]
	ld b, a
	ld a, [hli]
	ld h, [hl]
	ld l, a
	ret

SECTION "Focus Camera", ROMX
xFocusCamera::
	ld bc, wEntity0_SpriteY
	ld a, [bc]
	inc c
	ld l, a
	ld a, [bc]
	inc c
	ld h, a
	ld de, (SCRN_Y - 34) / -2 << 4
	add hl, de
	bit 7, h
	jr nz, :+
	ld a, h
	cp a, 64 - 9
	jr nc, :+
	ld a, l
	ld [wDungeonCameraY], a
	ld a, h
	ld [wDungeonCameraY + 1], a
:   ld a, [bc]
	inc c
	ld l, a
	ld a, [bc]
	inc c
	ld h, a
	ld de, (SCRN_X - 24) / -2 << 4
	add hl, de
	bit 7, h
	ret nz
	ld a, h
	cp a, 64 - 10
	ret nc
	ld a, l
	ld [wDungeonCameraX], a
	ld a, h
	ld [wDungeonCameraX + 1], a
	ret

SECTION "Generate Floor", ROM0
; Generate a new floor
; @clobbers bank
DungeonGenerateFloor::
	ld a, TILE_WALL
	ld bc, DUNGEON_WIDTH * DUNGEON_HEIGHT
	ld hl, wDungeonMap
	call MemSet
	ld hl, wEntity{d:NB_ALLIES}
	xor a, a
	ld b, NB_ENEMIES
.clearEnemies
	ld [hl], a
	inc h
	dec b
	jr nz, .clearEnemies

	ld hl, wActiveDungeon
	ld a, [hli]
	rst SwapBank
	ld a, [hli]
	add a, Dungeon_GenerationType
	ld h, [hl]
	ld l, a
	adc a, h
	sub a, l
	ld h, a
	ld a, [hl]
	ld b, a
	add a, b
	add a, b
	add a, LOW(.jumpTable)
	ld l, a
	adc a, HIGH(.jumpTable)
	sub a, l
	ld h, a
	ld a, [hli]
	rst SwapBank
	ld a, [hli]
	ld h, [hl]
	ld l, a
	ld de, wScriptPool
	call ExecuteScript
	ld hl, wActiveDungeon
	ld a, [hli]
	rst SwapBank
	ld a, [hli]
	ld h, [hl]
	ld l, a
	ld bc, Dungeon_ItemsPerFloor
	add hl, bc
	ld b, [hl]

.generateItem
	ld a, BANK(xGenerateItems)
	rst SwapBank
	ld hl, xGenerateItems
	push bc
		call ExecuteScript
	pop bc
	dec b
	jr nz, .generateItem
	ld a, NB_ENEMIES
.spawnEnemies
	push af
	call SpawnEnemy
	pop af
	dec a
	jr nz, .spawnEnemies
	ret

.jumpTable
	ASSERT DUNGEON_TYPE_SCRAPER == 0
	farptr xGenerateScraper
	ASSERT DUNGEON_TYPE_HALLS == 1
	farptr xGenerateHalls

SECTION "Update Scroll", ROMX
xUpdateScroll:
	ld a, [wDungeonCameraX + 1]
	ld b, a
	ld a, [wDungeonCameraX]
	REPT 4
		srl b
		rra
	ENDR
	ldh [hShadowSCX], a
	ld a, [wDungeonCameraY + 1]
	ld b, a
	ld a, [wDungeonCameraY]
	REPT 4
		srl b
		rra
	ENDR
	ldh [hShadowSCY], a
	ret

; Variables which must be accessible from all states.
SECTION "dungeon globals", WRAM0
; A far pointer to the current dungeon. Bank, Low, High.
wActiveDungeon:: ds 3

SECTION UNION "State variables", WRAM0, ALIGN[8]
; This map uses 4096 bytes of WRAM, but is only ever used in dungeons.
; If more RAM is needed for other game states, it should be unionized with this
; map.
wDungeonMap:: ds DUNGEON_WIDTH * DUNGEON_HEIGHT
wDungeonCameraX:: dw
wDungeonCameraY:: dw
; Only the neccessarily info is saved; the high byte.
wLastDungeonCameraX:: db
wLastDungeonCameraY:: db
wIsDungeonFading:: db
wDungeonCurrentFloor:: db

wMapgenLoopCounter: db

wDungeonFadeCallback:: dw

wPreviousHealth::
.player dw
.partner dw

wSkipAllyTurn:: db

SECTION FRAGMENT "dungeon BSS", WRAM0
wPartyLastXp: ds 6
; Ticks remaining to show levelup menu.
wLevelUpMessageLifetime: db
