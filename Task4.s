/*
 * dsp.s
 * EEE3096S 2026 - Practical 1B, Task 4
 * Cycle-counted ADC to DAC loop with a 45 degree phase delay
 *
 * Student 1 : Valencia Phiri  PHRVAL001
 * Student 2 : Bokani  Makhwaje  MHKBOK008
 */

    .syntax unified
    .thumb
    .cpu    cortex-m0
    .fpu    softvfp

    .global DSP_Loop
    .type   DSP_Loop, %function

@ ---------------------------------------------------------------------------
@ Peripheral addresses
@ ---------------------------------------------------------------------------
    .equ ADC_DR,      0x40012440
    .equ DAC_DHR12R1, 0x40007408

    .section .text.DSP_Loop, "ax", %progbits

@ ===========================================================================
@ ENTRY POINT
@ ===========================================================================
DSP_Loop:
    @ Setup registers outside the timed loop
    LDR R0, =ADC_DR
    LDR R1, =DAC_DHR12R1

loop:
    @ --- SAMPLE AND OUTPUT ------------------------------------------------
    @ TODO 1: Read the current ADC conversion from the Data Register.
    LDR R2, [R0]     @ R0 already points at ADC_DR -> R2 = latest sample
    @ TODO 2: Write the value straight out to the DAC Data Register.
    STR R2, [R1]     @ R1 already points at DAC_DHR12R1 -> push it out
    @ --- DELAY SETUP ------------------------------------------------------
    @ TODO 3: Calculate the required cycle target for a 45-degree phase 
    @         delay on a 1 kHz sine wave running at an 8 MHz system clock.
    @         Load your inner loop counter and insert any NOP padding 
    @         needed to hit your exact target.
	    @ Target: 1000 cycles/loop for a 45 deg (1/8 period) delay at
    @ 1 kHz on an 8 MHz clock (8000 cycles/period / 8 = 1000 cycles).
    MOVS R3, #248            @ 1 cycle  - inner loop counter, N = 248
    NOP                      @ 1 cycle  - padding to hit exact target
    NOP                      @ 1 cycle  - padding to hit exact target

delay_loop:
    @ --- INNER LOOP -------------------------------------------------------
    @ TODO 4: Implement the counted delay loop.
    @         (Remember to use flag-updating arithmetic so your branch works).
	SUBS R3, R3, #1          @ 1 cycle  - flag-updating decrement
    BNE  delay_loop          @ 3 cycles taken / 1 cycle not taken (last pass)
    @ --- REPEAT -----------------------------------------------------------
    @ TODO 5: Branch back to the start of the main 'loop'.
    B loop                    @ 3 cycles
    .size DSP_Loop, .-DSP_Loop
    @ ----------------------------------------------------------------------
    @ NOTE: You must calculate your exact cycle budget, showing the cost 
    @ of every instruction and loop iteration, and document it in your report.
    @ ----------------------------------------------------------------------

    .size DSP_Loop, .-DSP_Loop
