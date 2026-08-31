/*
 * lcd.s
 * EEE3096S 2026 - Practical 1B, Task 5
 * 4-bit bit-banged HD44780 driver, and the level shifter timing fault
 *
 * Student 1 : Valencia Phiri  PHRVAL001
 * Student 2 : Bokani  Makhwaje  MHKBOK008
 */

    .syntax unified
    .thumb
    .cpu    cortex-m0
    .fpu    softvfp

    .global LCD_Run
    .type   LCD_Run, %function

@ ---------------------------------------------------------------------------
@ Register addresses. BSRR is at offset 0x18 from each port base.
@ ---------------------------------------------------------------------------
    .equ GPIOA_BSRR, 0x48000018
    .equ GPIOB_BSRR, 0x48000418
    .equ GPIOC_BSRR, 0x48000818

@ ---------------------------------------------------------------------------
@ PIN MAP
@   PC15  Enable (E)     -> PC15_S on the 5 V side
@   PC14  Register Select (RS)
@   PB8   D4      PB9   D5      PA12  D6      PA15  D7
@   R/W is tied to ground. The LCD is write only.
@ ---------------------------------------------------------------------------

    .section .text.LCD_Run, "ax", %progbits

@ ===========================================================================
@ ENTRY POINT
@ ===========================================================================
LCD_Run:
    PUSH {LR}

    @ TODO 1: Wait for the LCD power rail to settle (consult datasheet).
    BL   LCD_DelayLong          @ HD44780 requires Vcc stable > 40 ms before
                                 @ the first command is issued

    @ TODO 2: Call the 4-bit initialization sequence.
    BL   LCD_Init

    @ TODO 3: Write the character 'A' (0x41) to the display.
    MOVS R0, #0x41
    BL   LCD_WriteData

hang:
    B    hang

    .size LCD_Run, .-LCD_Run

@ ===========================================================================
@ LCD_Init
@ Puts the controller into 4-bit mode and readies the display.
@ ===========================================================================
    .type LCD_Init, %function
LCD_Init:
    PUSH {R0, LR}

    @ TODO 4: Send the 4-bit initialization sequence.
    @ Reference the HD44780 datasheet flowchart.
    @ Send commands with RS low using LCD_WriteCmd.

    @ Force into a known state: send the upper nibble 0x3 three times,
    @ with the datasheet's mandated delays between each
    MOVS R0, #0x3
    BL   LCD_SendNibble
    BL   LCD_Pulse
    BL   LCD_DelayLong          @ > 4.1 ms

    MOVS R0, #0x3
    BL   LCD_SendNibble
    BL   LCD_Pulse
    BL   LCD_DelayShort         @ > 100 us

    MOVS R0, #0x3
    BL   LCD_SendNibble
    BL   LCD_Pulse
    BL   LCD_DelayShort         @ > 100 us

    @ Switch the controller to the 4-bit interface
    MOVS R0, #0x2
    BL   LCD_SendNibble
    BL   LCD_Pulse
    BL   LCD_DelayShort

    @ Function set: 4-bit interface, 2 line display, 5x8 font
    MOVS R0, #0x28
    BL   LCD_WriteCmd
    BL   LCD_DelayShort

    @ Display ON, cursor off, blink off
    MOVS R0, #0x0C
    BL   LCD_WriteCmd
    BL   LCD_DelayShort

    @ Clear display - needs a longer settle time than a normal command
    MOVS R0, #0x01
    BL   LCD_WriteCmd
    BL   LCD_DelayLong          @ > 1.6 ms

    @ Entry mode set: increment cursor, no display shift
    MOVS R0, #0x06
    BL   LCD_WriteCmd
    BL   LCD_DelayShort

    POP {R0, PC}

@ ===========================================================================
@ LCD_WriteCmd   R0 = command byte, RS low
@ LCD_WriteData  R0 = data byte,    RS high
@ Both send the high nibble first, then the low nibble.
@ ===========================================================================
    .type LCD_WriteCmd, %function
LCD_WriteCmd:
    PUSH {R0, LR}
    @ TODO 5: Drive RS (PC14) LOW, then fall through to the shared sender.
    LDR  R2, =GPIOC_BSRR
    MOVS R3, #1
    LSLS R3, R3, #30            @ bit (14+16) -> reset RS = command mode
    STR  R3, [R2]
    B    LCD_Send8

    .type LCD_WriteData, %function
LCD_WriteData:
    PUSH {R0, LR}
    @ TODO 6: Drive RS (PC14) HIGH, then fall through.
    LDR  R2, =GPIOC_BSRR
    MOVS R3, #1
    LSLS R3, R3, #14            @ bit 14 -> set RS = data mode
    STR  R3, [R2]
    @ falls through into LCD_Send8

LCD_Send8:
    @ TODO 7: Send the upper nibble of R0, pulse Enable,
    @         then the lower nibble of R0, pulse Enable again.
    MOVS R1, R0                 @ save the full byte - R1/R2/R3 survive the
                                 @ calls below since each callee saves/restores
                                 @ its own scratch registers
    LSRS R0, R1, #4             @ upper nibble
    BL   LCD_SendNibble
    BL   LCD_Pulse

    MOVS R2, #0x0F
    ANDS R2, R2, R1             @ lower nibble
    MOVS R0, R2
    BL   LCD_SendNibble
    BL   LCD_Pulse

    POP {R0, PC}

@ ===========================================================================
@ LCD_SendNibble   R0 bits 3:0 -> the four data lines
@ ===========================================================================
    .type LCD_SendNibble, %function
LCD_SendNibble:
    PUSH {R1, R2, R3, LR}

    @ TODO 8: Map the four bits of R0 onto the four data pins (across 3 ports).
    @ R0 bit 0 -> PB8   (D4)
    @ R0 bit 1 -> PB9   (D5)
    @ R0 bit 2 -> PA12  (D6)
    @ R0 bit 3 -> PA15  (D7)
    MOVS R1, #0                 @ GPIOB_BSRR accumulator (D4=PB8, D5=PB9)
    MOVS R2, #0                 @ GPIOA_BSRR accumulator (D6=PA12, D7=PA15)

    @ --- D4 -> PB8 (bit 0) ---
    MOVS R3, #1
    ANDS R3, R3, R0
    BEQ  d4_low
    MOVS R3, #1
    LSLS R3, R3, #8              @ set bit  (BSRR[8])
    ORRS R1, R1, R3
    B    d4_done
d4_low:
    MOVS R3, #1
    LSLS R3, R3, #24             @ reset bit (BSRR[8+16])
    ORRS R1, R1, R3
d4_done:

    @ --- D5 -> PB9 (bit 1) ---
    MOVS R3, #2
    ANDS R3, R3, R0
    BEQ  d5_low
    MOVS R3, #1
    LSLS R3, R3, #9
    ORRS R1, R1, R3
    B    d5_done
d5_low:
    MOVS R3, #1
    LSLS R3, R3, #25
    ORRS R1, R1, R3
d5_done:

    @ --- D6 -> PA12 (bit 2) ---
    MOVS R3, #4
    ANDS R3, R3, R0
    BEQ  d6_low
    MOVS R3, #1
    LSLS R3, R3, #12
    ORRS R2, R2, R3
    B    d6_done
d6_low:
    MOVS R3, #1
    LSLS R3, R3, #28
    ORRS R2, R2, R3
d6_done:

    @ --- D7 -> PA15 (bit 3) ---
    MOVS R3, #8
    ANDS R3, R3, R0
    BEQ  d7_low
    MOVS R3, #1
    LSLS R3, R3, #15
    ORRS R2, R2, R3
    B    d7_done
d7_low:
    MOVS R3, #1
    LSLS R3, R3, #31
    ORRS R2, R2, R3
d7_done:

    LDR  R3, =GPIOB_BSRR
    STR  R1, [R3]
    LDR  R3, =GPIOA_BSRR
    STR  R2, [R3]

    POP {R1, R2, R3, PC}

@ ===========================================================================
@ LCD_Pulse
@ ===========================================================================
    .type LCD_Pulse, %function
LCD_Pulse:
    PUSH {R0, R1, R2, LR}

    LDR  R0, =GPIOC_BSRR

    @ TODO 9: Set PC15 HIGH.
    MOVS R1, #1
    LSLS R1, R1, #15
    STR  R1, [R0]

    @ -----------------------------------------------------------------
    @ TODO 10: THE TIMING FIX
    @   measured rise time to 3.5V (PC15_S):  t_rise  = 37 ns
    @   required hold time above threshold:    t_hold  = 450 ns
    @   total high time required:              t_total = 37 + 450 = 487 ns
    @   clock period @ 8 MHz:                   T_clk   = 125 ns/cycle
    @   N = ceil(t_total / T_clk) = ceil(487/125) = ceil(3.896) = 4 NOPs
    @   -> 4 NOPs gives 500 ns actual high time, clearing the 487 ns
    @      requirement with 13 ns of margin.
    @
    @   Straight-line NOPs used (not a SUBS/BNE loop) - the loop's 3-cycle
    @   branch-taken cost makes it hard to hit a small target this exactly.
    @ -----------------------------------------------------------------
    /*NOP                          @ 1  (125 ns)
    NOP                          @ 2  (250 ns)
    NOP                          @ 3  (375 ns)
    NOP                          @ 4  (500 ns)  -> meets 487 ns requirement*/

    @ TODO 11: Set PC15 LOW.
    MOVS R2, #1
    LSLS R2, R2, #31
    STR  R2, [R0]

    @ TODO 12: Hold Enable low long enough to meet the LCD cycle time.
    BL   LCD_DelayShort          @ HD44780 min instruction cycle ~37-40 us

    POP {R0, R1, R2, PC}

@ ===========================================================================
@ Delay helpers
@ ===========================================================================
    .type LCD_DelayLong, %function
LCD_DelayLong:
    @ TODO 13: Millisecond-scale delay, sized for the longest wait needed
    @ (the >40 ms power-on settle / init sequence's >4.1 ms and >1.6 ms
    @ steps - this single routine is reused for all of them, so it's
    @ sized to the largest: ~40 ms).
    @   Loop cost (from dsp.s method): total = 4N + 6
    @   Target: 40 ms @ 8 MHz = 40e-3 * 8e6 = 320,000 cycles
    @   4N + 6 = 320,000  ->  N = 79,998.5 -> N = 79999 (rounds up, safe)
    PUSH {R0, LR}
    LDR  R0, =79999
delay_long_loop:
    SUBS R0, R0, #1
    BNE  delay_long_loop
    POP  {R0, PC}

    .type LCD_DelayShort, %function
LCD_DelayShort:
    @ TODO 14: Microsecond-scale delay, sized for the ~100 us init steps
    @ and the ~40 us HD44780 command cycle time.
    @   Target: 100 us @ 8 MHz = 100e-6 * 8e6 = 800 cycles
    @   4N + 6 = 800  ->  N = 198.5 -> N = 199 (rounds up, safe)
    PUSH {R0, LR}
    LDR  R0, =199
delay_short_loop:
    SUBS R0, R0, #1
    BNE  delay_short_loop
    POP  {R0, PC}
