'----------------------------------------------------------------------------------------------------------------------
'
' In place Radix-2 Decimation In Time FFT
'
' Michael Rychlik. 2011-1-25
'
' This file is relesed under the terms of the MIT license. See below.
'
' This FFT was developed from the description by Douglas L. Jones at
' http://cnx.org/content/m12016/latest/.
' It is written as a direct implementation of the discussion and diagrams on that page
' with an emphasis on clarity and ease of understanding rather than speed.
'
' There are two implementations here. The initial version in Spin and a PASM version derived from it.
' Use #define SPIN_BUTTERFLIES or PASM_BUTTERFLIES to select them
'
' The PASM verson does a 1024 FFT in 34ms on the demo test data.
'
' WARNING: I have written this, my first ever FFT implememtation, as a challenge to myself to understand
' Cooley-Tookey from the maths to the code without peeking at the example code on the above page or any other.
' So be warned it may not be accurate.
'
' Credits:
'
'     A big thank you to Dave Hein for clearing up some issues during a great FFT debate on
'     the Parallax Inc Propller discussion forum:
'     http://forums.parallax.com/showthread.php?127306-Fourier-for-dummies-under-construction
'
'     Thanks to Lonesock for the multiply routines.
'
'     Another big thank you to Lonesock for suggesting and implementing the W0 optimization.
'
' Instructions:
'
'     0) Define PASM_BUTTERFLIES or SPIN_BUTTERFLIES, see below.
'     1) Application should reserve two 1024 arrays of LONGs for input and output data, x and y
'     2) Place input signal into the x array, max value 4095
'     3) Clear the x array.
'     4) Call buuterflies giving a command and addresses of the arrays as parameters.
'     5) The command is one or more of the following bits set:
'               CMD_DECIMATE   - Perform bit-reversal reordering on the data, results in x and y
'               CMD_BUTTERFLY  - Perform the actuall FFT butterfly calculations, results in x and y
'               CMD_MAGNITUDE  - Convert resulting x and y values to frequency magnitudes in x
'
'     6) For some applications it may be as well to write the input data directly into x LONG by LONG
'        in the correct bit-reversed order. Then drop the CMD_DECIMATE for the butterfly call.
'        This could move 10 percent or so of the processing time to the input COG.
'
' History:
'
' 2010-12-16    v0.1  Initial draft.
'
' 2010-12-18    v0.2  First working version.
'
' 2010-12-18    v0.3  Optimized butterfly from 4 multiplies to 3
'                     Reduced twiddle tables from longs to words
'
' 2010-12-21    v0.4  A few simple optimizations
'                     First PASM implementation.
'                     Split out test harness.
'
' 2010-12-28    v0.5  Added getsin and getcos fuctions, not taken into use yet.
'
' 2011-01-14    v1.0  Total rewrite of Spin butterflies method.
'                     Now uses pointers into data arrays rather than array indexing.
'                     Total rewrite of the PASM butterflies to match the above.
'                     This speeds the PASM butterflies by about 25%.
'                     Added copyright and MIT licence statemets.
'
' 2011-01-14    v1.1  Optimization by Lonesock. For each "flight" the first butterfly has "twiddle factor"
'                     wx = 1 (The cos part) and wy = 0 (The sine part). So we can avoid doing the
'                     multiplies in this case. This is only implemented in the PASM version so as to keep
'                     the original Spin code clean.
'
' 2011-01-22    v2.0  Further optimization by Lonesock for the case when the "twiddle factor" is wx=0, wy=-1
'                     Chopped out half of the wy table as it's thes ame as the second half of wx.
'                     Moved x and y buffers out of heater_fft.
'                     Added a mailbox interface to PASM.
'                     Added bit-reversal step as an option.
'                     Added magnitude calculation as an option.
'                     Thanks again to Lonesock for the faster square root routine.
'
' 2011-01-25    v2.1  Change to using Props in-built trig table.
'                     Sorry, now about 10% slower as a result but much smaller.
'                     Also the Spin version no longer works.
'
'----------------------------------------------------------------------------------------------------------------------
' 2011-08-27
' Modifications by Andrey Demenev:
'   - getsin and getcos moved to subroutines
'   - added Hamming window options
'   - changed behavior of CMD_MAGNITUDE
'   - added CMD_POWER
'----------------------------------------------------------------------------------------------------------------------
' 2012-06-18
' Modifications by Pete Hemery:
'   - commented out #defined sections so PropellerTool can compile object
'   - renamed 'mul' subroutine to multi to stop compiler error
'----------------------------------------------------------------------------------------------------------------------
'User optimization controls
''#define PASM_BUTTERFLIES       'Set this for fast PASM FFT, about 30ms
'#define SPIN_BUTTERFLIES      'THIS DOES NOT WORK SINCE v2.1. Or set this for slow Spin FFT, about 1800ms!!

''#define USE_FASTER_MULT        'Set this for faster multiply
'#define USE_FASTER_SQRT       'Set this for faster but much bigger square root.
'----------------------------------------------------------------------------------------------------------------------

'----------------------------------------------------------------------------------------------------------------------
CON
    'Specify size of FFT buffer here with length and log base 2 of the length.
    'N.B. Changing this will require changing the "twiddle factor" tables.
    '     and may also require changing the fixed point format (if going bigger)
    FFT_SIZE      = 1024
    LOG2_FFT_SIZE = 10

    CMD_DECIMATE  = $01
    CMD_BUTTERFLY = $02
    CMD_POWER     = $04
    CMD_TEST      = $08
    CMD_HAMMING   = $10
    CMD_MAGNITUDE = $20
    CMD_COMPLEX   = $40
'----------------------------------------------------------------------------------------------------------------------

'----------------------------------------------------------------------------------------------------------------------
VAR
    long mailboxp
'----------------------------------------------------------------------------------------------------------------------

'----------------------------------------------------------------------------------------------------------------------
PUB start (mailp)
''#ifdef PASM_BUTTERFLIES
    mailboxp := mailp
    LONG[mailboxp] := 0
    cognew (@bfly, mailp)     'Check error?
''#endif
'----------------------------------------------------------------------------------------------------------------------

'----------------------------------------------------------------------------------------------------------------------
{{#ifdef SPIN_BUTTERFLIES
VAR
    long level
    long flight_max
    long flight
    long butterflySpan
    long butterfly_max
    long butterfly
    long temp
    long flightSkip
    long wSkip

    long b0x_ptr
    long b0y_ptr
    long b1x_ptr
    long b1y_ptr
    long wx_ptr
    long wy_ptr

    long a
    long b
    long c
    long d
    long k1
    long k2
    long k3
    long tx
    long ty
'----------------------------------------------------------------------------------------------------------------------

'----------------------------------------------------------------------------------------------------------------------
PUB  butterflies (cmd, bxp, byp)
    if cmd & CMD_DECIMATE                          'Data bit-reversal reordering required?
        decimate(bxp, byp)
    if cmd & CMD_BUTTERFLY                         'FFT butterfly required?
        bfly (bxp, byp)
    if cmd & CMD_MAGNITUDE                         'Convert to magnitude required?
        magnitude (bxp, byp)
'----------------------------------------------------------------------------------------------------------------------

'----------------------------------------------------------------------------------------------------------------------
PUB decimate (bxp, byp) | i, revi, tx1, ty1
'Radix-2 decimation in time.
'Moves every sample of bx and by to a postion given by
'reversing the bits of its original array index.
    repeat i from 0 to FFT_SIZE - 1
        revi := i >< LOG2_FFT_SIZE
        if i < revi
            tx1 := long[bxp + i * 4]
            ty1 := long[byp + i * 4]

            long[bxp + i * 4] := long[bxp + revi * 4]
            long[byp + i * 4] := long[byp + revi * 4]

            long[bxp + revi * 4] := tx1
            long[byp + revi * 4] := ty1
'----------------------------------------------------------------------------------------------------------------------

'----------------------------------------------------------------------------------------------------------------------
PUB magnitude (bxp, byp) | i, real, imag
    repeat i from 0 to (FFT_SIZE / 2)
        'Scale down by half FFT size, back to original signal input range
        real := long[bxp + i * 4] / (FFT_SIZE / 2)
        imag := long[byp + i * 4] / (FFT_SIZE / 2)

        'Frequency magnitude is square root of cos part sqaured plus sin part squared
        long[bxp + i * 4] := ^^((real * real) + (imag * imag))
'----------------------------------------------------------------------------------------------------------------------

'----------------------------------------------------------------------------------------------------------------------
'Apply FFT butterflies to N complex samples in x, in time decimated order !
'Resulting FFT is in x in the correct order.
PUB bfly (bxp, byp)
    flight_max := FFT_SIZE >> 1 ' / 2              'Initial number of flights in a level
    wSkip := FFT_SIZE                              'But we advance w pointer by 2 bytes per entry
    butterflySpan := 4                             'Span measured in bytes
    butterfly_max := 1                             '1 butterfly per flight initially
    flightSkip := 4                                'But we advance pointer by 4 bytes per butterfly

    'Loop through all the decimation levels
    repeat LOG2_FFT_SIZE
        b0x_ptr := bxp
        b0y_ptr := byp

        b1x_ptr := b0x_ptr + butterflySpan
        b1y_ptr := b0y_ptr + butterflySpan

        'Loop though all the flights in a level
        repeat flight_max
            wx_ptr := @wx
            wy_ptr := @wy

            'Loop through all the butterflies in a flight
            repeat butterfly_max
                'At last...the butterfly.
                '----------------------
                a := LONG[b1x_ptr]                 'Get X[b1]
                b := LONG[b1y_ptr]

                c := ~~WORD[wx_ptr]                'Get W[wIndex]
                d := ~~WORD[wy_ptr]

                k1 := (a * (c + d)) ~> 12 ' / 4096 'Somewhat optimized complex multiply
                k2 := (d * (a + b)) ~> 12 ' / 4096 '   T = X[b1] * W[wIndex]
                k3 := (c * (b - a)) ~> 12 ' / 4096
                tx := k1 - k2
                ty := k1 + k3

                k1 := LONG[b0x_ptr]                'bx[b0]
                k2 := LONG[b0y_ptr]                'by[b0]
                LONG[b1x_ptr] := k1 - tx           'X[b1] = X[b0] - T
                LONG[b1y_ptr] := k2 - ty

                LONG[b0x_ptr] := k1 + tx           'X[b0] = X[b0] + T
                LONG[b0y_ptr] := k2 + ty
                '---------------------

                b0x_ptr += 4                       'Advance to next butterfly in flight,
                b0y_ptr += 4                       'skiping 4 bytes for each.

                b1x_ptr += 4
                b1y_ptr += 4

                wx_ptr += wSkip                    'Advance to next w
                wy_ptr += wSkip

            b0x_ptr += flightSkip                  'Advance to first butterfly of next flight
            b0y_ptr += flightSkip
            b1x_ptr += flightSkip
            b1y_ptr += flightSkip

        butterflySpan <<= 1                        'On the next level butterflies are twice as wide
        flightSkip <<= 1                           'and so is the flight skip

        flight_max >>= 1                           'On the next level there are half as many flights
        wSkip >>= 1                                'And w's are half as far apart
        butterfly_max <<= 1                        'On the next level there are twice the butterflies per flight
'----------------------------------------------------------------------------------------------------------------------

'----------------------------------------------------------------------------------------------------------------------
#endif   }}
'#ifdef PASM_BUTTERFLIES
PUB butterflies(cmd, bxp, byp)
    LONG[mailboxp + 4] := bxp                          'Address of x buffer
    LONG[mailboxp + 8] := byp                          'Address of y buffer
    LONG[mailboxp + 0] := cmd                          'Do butterflies and/or decimation
    repeat while LONG[mailboxp + 0] <> 0
'----------------------------------------------------------------------------------------------------------------------

'----------------------------------------------------------------------------------------------------------------------
DAT
              org       0
bfly          mov       mb_ptr, par
              rdlong    command, mb_ptr wz                 'Wait for run command in mailbox
        if_z  jmp       #bfly

              add       mb_ptr, #4                         'Fetch x array address from mbox
              rdlong    bx_ptr, mb_ptr

              add       mb_ptr, #4                         'Fetch y array address from mbox
              rdlong    by_ptr, mb_ptr
              sub       mb_ptr, #8

              
              test      command, #CMD_HAMMING wz         'Apply Hamming window?
        if_z  jmp       #:no_hamming

              mov       b0x_ptr, bx_ptr
              mov       b0y_ptr, by_ptr
              mov       b, #0
              mov       c, fft_size_
:hamming_loop mov       d, b
              call      #getcos
              add       b, # ($4000 >> LOG2_FFT_SIZE)
              mov       m1, :c_046
              mov       m2, d
              call      #multi
              sar       m1, #16
              add       m1, :c_054
              mov       k1, m1
              rdlong    m2, b0x_ptr
              call      #multi
              sar       m1, #16
              wrlong    m1, b0x_ptr
              add       b0x_ptr, #4

              test      command, #CMD_COMPLEX wz
    if_z      jmp       #:no_complex
              rdlong    m2, b0y_ptr
              mov       m1, k1
              call      #multi
              sar       m1, #16
              wrlong    m1, b0y_ptr
              add       b0y_ptr, #4
              
:no_complex   djnz      c, #:hamming_loop

              jmp       #:no_hamming
:c_046        long      -30147 ' -0.46 * 2^16
:c_054        long      35389 ' 0.54 * 2^16

:no_hamming
              test      command, #CMD_DECIMATE wz          'Bit reversal required on data?
        if_z  jmp       #:no_decimate

'Radix-2 decimation in time. (The bit reversal satge)
'Moves every sample of bx to a postion given by reversing the bits of its original array index.
'This is a direct translation of the Spin decimate above, original Spin code used as comments.
'N.B. Only the x array is bit-reversed it is up to the app to clear y.

              mov       c, fft_size_                       'repeat i from 0 to FFT_SIZE - 1
              mov       b, #0

:dloop        mov       a, b                               'revi := i >< LOG2_FFT_SIZE
              mov       rev_a, a
              rev       rev_a, #32 - LOG2_FFT_SIZE

              cmp       a, rev_a wc                        'if i < revi
        if_nc jmp       #:skip_rev

              shl       a, #2                              'Times 4 as we are reading longs
              shl       rev_a, #2

              mov       hub_ptr, bx_ptr                    'tx1 := long[bxp + i * 4]
              add       hub_ptr, a
              rdlong    tx, hub_ptr

              mov       hub_rev_ptr, bx_ptr                'long[bxp + i * 4] := long[bxp + revi * 4]
              add       hub_rev_ptr, rev_a
              rdlong    ty, hub_rev_ptr
              wrlong    ty, hub_ptr

              wrlong    tx, hub_rev_ptr                    'long[bxp + revi * 4] := tx1

:skip_rev     add       b, #1
              djnz      c, #:dloop

:no_decimate
              test      command, #CMD_BUTTERFLY wz         'Perform buterflies?
        if_z  jmp       #:no_butterfly

'Apply FFT butterflies to N complex samples in buffers bx and by, in time decimated order!
'Resulting FFT is produced in bx and by in the correct order.
'This is a direct translation from the Spin code above, original Spin code in comments.

              mov       flight_max, fft_size_              'flight_max := FFT_SIZE / 2
              sar       flight_max, #1
              mov       wangleSkip, fft_size_              'wangleSkip := FFT_SIZE * 4
              shl       wangleSkip, #2

              mov       butterflySpan, #4                  'butterflySpan := 4
              mov       butterfly_max, #1                  'butterfly_max := 1
              mov       flightSkip, #4                     'flightSkip := 4

              'Loop through all the decimation levels
              mov       level, #LOG2_FFT_SIZE              'level := LOG2_FFT_SIZE
:lloop                                                     'repeat
              mov       b0x_ptr, bx_ptr                    'b0x_ptr := @bx
              mov       b0y_ptr, by_ptr                    'b0y_ptr := @by

              mov       b1x_ptr, b0x_ptr                   'b1x_ptr := b0x_ptr + butterflySpan
              add       b1x_ptr, butterflySpan

              mov       b1y_ptr, b0y_ptr                   'b1y_ptr := b0y_ptr + butterflySpan
              add       b1y_ptr, butterflySpan

              'Loop though all the flights in a level
              mov       flight, flight_max                 'flight := flight_max
:floop                                                     'repeat
{new}         mov       wangle, #0

              'Loop through all the butterflies in a flight
              mov       butterfly, butterfly_max           'butterfly := butterfly_max

              'Do the initial pass optimization, when W = [1,0] we don't need to multiply.
              ' c = 1 (well, 4096/4096), d = 0
              mov       k2, #0                             'k2 := (d * (a + b)) / 4096
              rdlong    a, b1x_ptr                         'a := LONG[b1x_ptr]
              mov       k1, a                              'k1 := (a * (c + d)) / 4096
              neg       k3, a                              'k3 := (c * (b - a)) / 4096 
              rdlong    b, b1y_ptr                         'b := LONG[b1y_ptr]
              add       k3, b                              'k3 := (c * (b - a)) / 4096 (cont.)              
              jmp       #:continue_bloop
              
:bloop        ' repeat                                     'At last...the butterfly.
              rdlong    a, b1x_ptr                         'a := LONG[b1x_ptr]

              'Precompute the optimization for c=0, d=-1
              neg       k1, a                              'k1 := (a * (c + d)) / 4096
              neg       k2, a                              'k2 := (d * (a + b)) / 4096

              rdlong    b, b1y_ptr                         'b := LONG[b1y_ptr]

              'Precompute the optimization for c=0, d=-1
              sub       k2, b                              'k2 := (d * (a + b)) / 4096 (cont.)
              mov       k3, #0                             'k3 := (c * (b - a)) / 4096

              mov       d, wangle
              call      #getcos
              mov       c, d
              sar       c, #4 wz                           'Scale to +/- 4095

        if_z  jmp       #:continue_bloop                   ' if c==0, we already kave k1, k2, k3 calculated

              mov       d, wangle
              call      #getsin
              sar       d, #4                              'Scale to +/- 4095
              neg       d, d                               'We want -cos

              mov       m1, c                              'k1 := (a * (c + d)) / 4096
              add       m1, d
              mov       m2, a
              call      #multi
              mov       k1, m1
              sar       k1, #15 - 3

              mov       m1, a                              'k2 := (d * (a + b)) / 4096
              add       m1, b
              mov       m2, d
              call      #multi
              mov       k2, m1
              sar       k2, #15 - 3

              mov       m1, b                              'k3 := (c * (b - a)) / 4096
              sub       m1, a
              mov       m2, c
              call      #multi
              mov       k3, m1
              sar       k3, #15 - 3

:continue_bloop

              mov       tx, k1                             'tx := k1 - k2 (part I)
              mov       ty, k1                             'ty := k1 + k3 (part I)

              rdlong    k1, b0x_ptr                        'k1 := LONG[b0x_ptr]

              sub       tx, k2                             ' (part II) moved from above to take advantage of the hub wait times
              add       ty, k3                             ' ditto

              rdlong    k2, b0y_ptr                        'k2 := LONG[b0y_ptr]

              mov       a, k1                              'LONG[b1x_ptr] := k1 - tx
              sub       a, tx
              wrlong    a, b1x_ptr

              mov       a, k2                              'LONG[b1y_ptr] := k2 - ty
              sub       a, ty
              wrlong    a, b1y_ptr

              mov       a, k1                              'LONG[b0x_ptr] := k1 + tx
              add       a, tx
              wrlong    a, b0x_ptr

              mov       a, k2                              'LONG[b0y_ptr] := k2 + ty
              add       a, ty
              wrlong    a, b0y_ptr

              add       b0x_ptr, #4                        'b0x_ptr += 4
              add       b0y_ptr, #4                        'b0y_ptr += 4

              add       b1x_ptr, #4                        'b1x_ptr += 4
              add       b1y_ptr, #4                        'b1y_ptr += 4

              add       wangle, wangleSkip                 'wangle += wangleSkip

              djnz      butterfly, #:bloop                 'while --butterfly <> 0

              add       b0x_ptr, flightSkip                'b0x_ptr += flightSkip
              add       b0y_ptr, flightSkip                'b0y_ptr += flightSkip
              add       b1x_ptr, flightSkip                'b1x_ptr += flightSkip
              add       b1y_ptr, flightSkip                'b1y_ptr += flightSkip
              djnz      flight, #:floop                    'while --flight <> 0

              shl       butterflySpan, #1                  'butterflySpan <<= 1
              shl       flightSkip, #1                     'flightSkip <<= 1

              shr       flight_max, #1                     'flight_max >>= 1

              shr       wangleSkip, #1
              shr       wSkip, #1                          'wSkip >>= 1
              shl       butterfly_max, #1                  'butterfly_max <<= 1
              djnz      level, #:lloop                     'while --level <> 0
:no_butterfly
              test      command, #CMD_POWER wz         'Calculate magnitudes?
        if_z  jmp       #:no_power

'Calculate magnitudes from the complex results in x and y. Results placed into x

              mov       c, fft_size_                       'repeat i from 0 to FFT_SIZE
              add       c, #1                              'That is one more than half FFT_SIZE so as
                                                           'to include the Nyquist frequency
              mov       b0x_ptr, bx_ptr
              mov       b0y_ptr, by_ptr

:mloop        rdlong    m1, b0x_ptr
              sar       m1, #LOG2_FFT_SIZE - 1
              mov       m2, m1
              call      #multi
              mov       input, m1

              rdlong    m1, b0y_ptr
              sar       m1, #LOG2_FFT_SIZE - 1
              mov       m2, m1
              call      #multi
              add       input, m1

              test      command, #CMD_MAGNITUDE wz         'Calculate magnitudes?
        if_nz call      #sqrt
        if_z  mov       root, input

              wrlong    root, b0x_ptr                      'Write result to x array

              add       b0x_ptr, #4                        'Next x and y element and loop
              add       b0y_ptr, #4
              djnz      c, #:mloop

:no_power

              mov       command, #0
              wrlong    command, mb_ptr
              jmp       #bfly
'----------------------------------------------------------------------------------------------------------------------

'----------------------------------------------------------------------------------------------------------------------
multi         'Account for sign
'#ifdef USE_FASTER_MULT
              abs       m1, m1 wc
              negc      m2, m2
              abs       m2, m2 wc
              'Make t2 the smaller of the 2 unsigned parameters
              mov       m3, m1
              max       m3, m2
              min       m2, m1
              'Correct the sign of the adder
              negc      m2, m2
{{#else
              abs       m3, m1 wc
              negc      m2, m2
#endif}}
              'My accumulator
              mov       m1, #0
              'Do the work
:mul_loop     shr       m3, #1 wc,wz                       'Get the low bit of t2
        if_c  add       m1, m2                             'If it was a 1, add adder to accumulator
              shl       m2, #1                             'Shift the adder left by 1 bit
        if_nz jmp       #:mul_loop                         'Continue as long as there are no more 1's
multi_ret     ret

m1            long      0
m2            long      0
m3            long      0


getcos     add    d,sin_90       'for cosine, add 90°
getsin     test   d,sin_90    wc 'get quadrant 2|4 into c
           test   d, sin_180   wz 'get quadrant 3|4 into nz
           negc   d,d          'if quadrant 2|4, negate offset
           or     d,sin_table    'or in sin table address >> 1
           shl    d,#1           'shift left to get final word address
           rdword d,d          'read word sample from $E000 to $F000
           negnz d,d               'if quadrant 3|4, negate sample
getsin_ret
getcos_ret ret                     '39..54 clocks
                                   '(variance due to HUB sync on RDWORD)

'----------------------------------------------------------------------------------------------------------------------

'----------------------------------------------------------------------------------------------------------------------
''#ifdef USE_FASTER_SQRT
'Faster code for square root (Chip Gracey after discussion with lonesock on Propeller Forums):
sqrt          mov       root, h40000000
              cmpsub    input, root  wc
              sumnc     root, h40000000
              shr       root, #1

              or        root, h10000000
              cmpsub    input, root  wc
              sumnc     root, h10000000
              shr       root, #1

              or        root, h04000000
              cmpsub    input, root  wc
              sumnc     root, h04000000
              shr       root, #1

              or        root, h01000000
              cmpsub    input, root  wc
              sumnc     root, h01000000
              shr       root, #1

              or        root, h00400000
              cmpsub    input, root  wc
              sumnc     root, h00400000
              shr       root, #1

              or        root, h00100000
              cmpsub    input, root  wc
              sumnc     root, h00100000
              shr       root, #1

              or        root, h00040000
              cmpsub    input, root  wc
              sumnc     root, h00040000
              shr       root, #1

              or        root, h00010000
              cmpsub    input, root  wc
              sumnc     root, h00010000
              shr       root, #1

              or        root, h00004000
              cmpsub    input, root  wc
              sumnc     root, h00004000
              shr       root, #1

              or        root, h00001000
              cmpsub    input, root  wc
              sumnc     root, h00001000
              shr       root, #1

              or        root, h00000400
              cmpsub    input, root  wc
              sumnc     root, h00000400
              shr       root, #1

              or        root, #$100
              cmpsub    input, root  wc
              sumnc     root, #$100
              shr       root, #1

              or        root, #$40
              cmpsub    input,root  wc
              sumnc     root, #$40
              shr       root, #1

              or        root, #$10
              cmpsub    input,root  wc
              sumnc     root, #$10
              shr       root, #1

              or        root, #$4
              cmpsub    input,root  wc
              sumnc     root, #$4
              shr       root, #1

              or        root, #$1
              cmpsub    input,root  wc
              sumnc     root, #$1
              shr       root, #1
sqrt_ret      ret

h10000000     long      $10000000
h04000000     long      $04000000
h01000000     long      $01000000
h00400000     long      $00400000
h00100000     long      $00100000
h00040000     long      $00040000
h00010000     long      $00010000
h00004000     long      $00004000
h00001000     long      $00001000
h00000400     long      $00000400

{{#else

'Faster code for square root (Chip Gracey after discussion with lonesock on Propeller Forums):
sqrt          mov       root, #0                           'Reset root
              mov       mask, h40000000                    'Reset mask (constant in register)
:sqloop       or        root, mask                         'Set trial bit
              cmpsub    input, root wc                     'Subtract root from input if fits
              sumnc     root, mask                         'Cancel trial bit, set root bit if fit
              shr       root, #1                           'Shift root down
              shr       mask, #2                           'Shift mask down
              tjnz      mask, #:sqloop                     'Loop until mask empty
sqrt_ret      ret
#endif}}
h40000000     long      $40000000
'----------------------------------------------------------------------------------------------------------------------

'----------------------------------------------------------------------------------------------------------------------
'Large constants
fft_size_     long      FFT_SIZE
sin_90        long      $0800
sin_180       long      $1000
sin_table     long      $E000 >> 1                         'ROM sin table base shifted right

'COG variables
level         long      0
flight        long      0
butterfly     long      0
flight_max    long      0
wSkip         long      0
butterflySpan long      0
butterfly_max long      0
flightSkip    long      0
k1            long      0
k2            long      0
k3            long      0
a             long      0
b             long      0
c             long      0
d             long      0
tx            long      0
ty            long      0
b0x_ptr       long      0
b0y_ptr       long      0
b1x_ptr       long      0
b1y_ptr       long      0
mb_ptr        long      0
bx_ptr        long      0
by_ptr        long      0
wangle        long      0
wangleSkip    long      0

rev_a         long      0
hub_ptr       long      0
hub_rev_ptr   long      0
command       long      0
root          long      0
mask          long      0
input         long      0
'----------------------------------------------------------------------------------------------------------------------
              fit       496 
'#endif
'----------------------------------------------------------------------------------------------------------------------

'----------------------------------------------------------------------------------------------------------------------
'    This file is distributed under the terms of the The MIT License as follows:
'
'    Copyright (c) 2011 Michael Rychlik
'
'    Permission is hereby granted, free of charge, to any person obtaining a copy
'    of this software and associated documentation files (the "Software"), to deal
'    in the Software without restriction, including without limitation the rights
'    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
'    copies of the Software, and to permit persons to whom the Software is
'    furnished to do so, subject to the following conditions:
'
'    The above copyright notice and this permission notice shall be included in
'    all copies or substantial portions of the Software.
'
'    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
'    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
'    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
'    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
'    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
'    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
'    THE SOFTWARE.
'----------------------------------------------------------------------------------------------------------------------

'----------------------------------------------------------------------------------------------------------------------
'The end.