''Score Notation
''Pete Hemery
''22/4/2012

CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

  '512x384
  tiles = gr#tiles

  threshold = 2000

OBJ

  fft  : "heater_fft_hamming"
  aud  : "sampler"
  gr   : "scrolling_note_gui"
  pst  : "Parallax Serial Terminal"

VAR

  long  pst_on
  long  colors_ptr

  long  notes, sharps

  'cos and sin parts of the signal to be analysed
  'Result is written back to here.
  'Just write input sammles to bx and zero all by.
  long bx[fft#FFT_SIZE]
  long by[fft#FFT_SIZE]

  'Mailbox interface to fft
  long fft_mailbox_cmd        'Command
  long fft_mailbox_bxp        'Address of x buffer
  long fft_mailbox_byp        'Address of y buffer


  'pointers for audio sampler cog
  long  audio_flag
  long  audio_time
  long  array_size

  word  audio_buffer_1[fft#FFT_SIZE]
  word  audio_buffer_2[fft#FFT_SIZE]
  word  audio_buffer_3[fft#FFT_SIZE]

PUB start | x,y,i,k,startTime, endTime, flag_copy, first_trigger, audio_endTime,audio_startTime, total_startTime,total_endTime

  if ina[31] == 1                                       'Check if we're connected via USB
    pst_on := 1
    pst.Start(115200)                                   'Start the Parallax Serial Terminal cog
    pst.NewLine
  else
    pst_on := 0

  if pst_on == 1
    pst.str(string(pst#NL,"Start"))
  gr.start                      'starts 3 cogs - vga driver, graphics driver & scrolling plotter

  audio_flag := 3               'will be set to 0 on initialisation
  array_size := fft#FFT_SIZE * 2

  first_trigger := 8

  fft.start(@fft_mailbox_cmd)   '1 heater fft

  aud.start(@audio_flag)        '1 sampler


  repeat

    if flag_copy <> long[@audio_flag]
      total_startTime := cnt
      flag_copy := long[@audio_flag]
      audio_endTime := long[@audio_time]

      endTime := cnt
      if pst_on == 1
        pst.str(string(pst#NL,"main loop wait time = "))
        pst.dec((endTime - startTime) / (clkfreq / 1000))
        pst.str(string("ms",pst#NL))

{
        pst.str(string("sampler cog 512 samples run time = "))
        pst.dec((audio_endTime - audio_startTime) / (clkfreq / 1000))
        pst.str(string("ms",pst#NL))
        audio_startTime := audio_endTime
}
        pst.dec(flag_copy)
        pst.newline
'        pst.dec(word[@audio_time])
'        pst.newline

      if first_trigger <> 0
        first_trigger--

      if first_trigger <> 0
        if pst_on == 1
          pst.newline
        next

      startTime := cnt
      case flag_copy
        0 : repeat k from 0 to 1023
              long[@bx][k] := ~~word[@audio_buffer_2][k]

        2 : repeat k from 0 to 1023
              long[@bx][k] := ~~word[@audio_buffer_1][k]
        other :
            total_endTime := cnt

            if pst_on == 1
              pst.str(string("main loop run time = "))
              pst.dec((total_endTime - total_startTime) / (clkfreq / 1000))
              pst.str(string("ms",pst#NL))
              startTime := cnt
            next

      endTime := cnt
{
      if pst_on == 1
        pst.str(string("data copying run time = "))
        pst.dec((endTime - startTime) / (clkfreq / 1000))
        pst.str(string("ms",pst#NL))
}

      'The Fourier transform, including bit-reversal reordering and magnitude converstion
      startTime := cnt
      fft.butterflies(fft#CMD_DECIMATE | fft#CMD_BUTTERFLY | fft#CMD_MAGNITUDE, @bx, @by)'| fft#CMD_HAMMING
      endTime := cnt

{
      if pst_on == 1
        pst.str(string("1024 point FFT plus magnitude calculation run time = "))
        pst.dec((endTime - startTime) / (clkfreq / 1000))
        pst.str(string("ms",pst#NL))
}
      startTime := cnt
      notes := sharps := 0

      repeat x from 24 to 495   'full range
'      repeat x from 41 to 226   'kalimba range
        if ||bx[x] > threshold        'absolute value
          case x
            24       : notes  |= (or00)               'D3
            26       : sharps |=   (or00)               'D#
            27,28    : notes  |= (or01)               'E
            29       : notes  |= (or02)               'F
            31       : sharps |=   (or01)               'F#
            32,33    : notes  |= (or03)               'G
            34,35    : sharps |=   (or02)               'G#
            36,37    : notes  |= (or04)               'A
            39       : sharps |=   (or03)               'A#
            41       : notes  |= (or05)               'B

            43..44   : notes  |= (or06)               'C4
            47       : sharps |=   (or04)               'C#
            49      : notes  |= (or07)               'D
            52      : sharps |=   (or05)               'D#
            55      : notes  |= (or08)               'E
            58      : notes  |= (or09)               'F
            61..62   : sharps |=   (or06)               'F#
            65..66   : notes  |= (or10)              'G
            69..70   : sharps |=   (or07)               'G#
            73..74   : notes  |= (or11)              'A
            77..78   : sharps |=   (or08)               'A#
            81..82   : notes  |= (or12)              'B

            87       : notes  |= (or13)              'C5
            92..93   : sharps |=   (or09)               'C#
            98       : notes  |= (or14)              'D
            103..104 : sharps |=   (or10)              'D#
            109..110 : notes  |= (or15)              'E
            116..117 : notes  |= (or16)              'F
            123..124 : sharps |=   (or11)              'F#
            130..131 : notes  |= (or17)              'G
            138..139 : sharps |=   (or12)              'G#
            146..147 : notes  |= (or18)              'A
            155..156 : sharps |=   (or13)              'A#
            164..166 : notes  |= (or19)              'B

            173..175 : notes  |= (or20)              'C6
            184..186 : sharps |=   (or14)              'C#
            195..197 : notes  |= (or21)              'D
            206..209 : sharps |=   (or15)              'D#
            219..221 : notes  |= (or22)              'E

            232..234 : notes  |= (or23)              'F
            245..248 : sharps |=   (or16)              'F#
            260..263 : notes  |= (or24)              'G
            276..278 : sharps |=   (or17)              'G#
            292..295 : notes  |= (or25)              'A
            309..312 : sharps |=   (or18)              'A#
            328..331 : notes  |= (or26)              'B

            347..350 : notes  |= (or27)              'C7
            368..371 : sharps |=   (or19)              'C#
            390..393 : notes  |= (or28)              'D
            413..417 : sharps |=   (or20)              'D#
            438..441 : notes  |= (or29)              'E
            464..467 : notes  |= (or30)              'F
            491..495 : sharps |=   (or21)              'F#
{
          pst.dec(x)
          pst.char(":")
          pst.dec(||bx[x])
          pst.newline
}
      endTime := cnt

      if pst_on == 1
        pst.str(string("Finding notes and sharps took = "))
        pst.dec((endTime - startTime) / (clkfreq / 1000))
        pst.str(string("ms",pst#NL))

      gr.copy_notes(notes,sharps)

      if pst_on == 1
        pst.str(string("notes:  "))
        pst.hex(notes,8)
        pst.newline
        pst.str(string("sharps: "))
        pst.hex(sharps,8)
        pst.newline


      'Print resulting spectrum
      'printSpectrum


      longfill(@by,0,fft#FFT_SIZE)

      startTime := cnt
      total_endTime := cnt

      if pst_on == 1
        pst.str(string("main loop run time = "))
        pst.dec((total_endTime - total_startTime) / (clkfreq / 1000))
        pst.str(string("ms",pst#NL))



PUB printSpectrum  | i, real, imag, magnitude
'Spectrum is available in first half of the buffers after FFT.
  if pst_on == 1
    pst.str(string("Freq. Magnitude"))
    pst.newline
    repeat i from 0 to (fft#FFT_SIZE / 2)
        pst.dec(i)
        pst.str(string(" "))
'        pst.hex(real, 8)
'        pst.str(string(" "))
'        pst.hex(imag, 8)
'        pst.str(string(" "))
        pst.dec(bx[i])
        pst.newline

'----------------------------------------------------------------------------------------------------------------------
DAT

or31          long      $80000000
or30          long      $40000000
or29          long      $20000000
or28          long      $10000000
or27          long      $08000000
or26          long      $04000000
or25          long      $02000000
or24          long      $01000000
or23          long      $00800000
or22          long      $00400000
or21          long      $00200000
or20          long      $00100000
or19          long      $00080000
or18          long      $00040000
or17          long      $00020000
or16          long      $00010000
or15          long      $00008000
or14          long      $00004000
or13          long      $00002000
or12          long      $00001000
or11          long      $00000800
or10          long      $00000400
or09          long      $00000200
or08          long      $00000100
or07          long      $00000080
or06          long      $00000040
or05          long      $00000020
or04          long      $00000010
or03          long      $00000008
or02          long      $00000004
or01          long      $00000002
or00          long      $00000001

{
          case x
            24,25    : notes  |= ($1 << 0)               'D3
            26       : sharps |=   ($1 << 0)               'D#
            27,28    : notes  |= ($1 << 1)               'E
            29       : notes  |= ($1 << 2)               'F
            30,31    : sharps |=   ($1 << 1)               'F#
            32,33    : notes  |= ($1 << 3)               'G
            34,35    : sharps |=   ($1 << 2)               'G#
            36,37    : notes  |= ($1 << 4)               'A
            38,39    : sharps |=   ($1 << 3)               'A#
            40..42   : notes  |= ($1 << 5)               'B

            43..44   : notes  |= ($1 << 6)               'C4
            45..47   : sharps |=   ($1 << 4)               'C#
            48..50   : notes  |= ($1 << 7)               'D
            51..53   : sharps |=   ($1 << 5)               'D#
            54..56   : notes  |= ($1 << 8)               'E
            57..59   : notes  |= ($1 << 9)               'F
            60..63   : sharps |=   ($1 << 6)               'F#
            64..67   : notes  |= ($1 << 10)              'G
            68..71   : sharps |=   ($1 << 7)               'G#
            72..75   : notes  |= ($1 << 11)              'A
            76..79   : sharps |=   ($1 << 8)               'A#
            80..84   : notes  |= ($1 << 12)              'B

            85..89   : notes  |= ($1 << 13)              'C5
            90..95   : sharps |=   ($1 << 9)               'C#
            96..100  : notes  |= ($1 << 14)              'D
            101..106 : sharps |=   ($1 << 10)              'D#
            107..113 : notes  |= ($1 << 15)              'E
            114..119 : notes  |= ($1 << 16)              'F
            120..126 : sharps |=   ($1 << 11)              'F#
            127..134 : notes  |= ($1 << 17)              'G
            135..142 : sharps |=   ($1 << 12)              'G#
            143..150 : notes  |= ($1 << 18)              'A
            151..159 : sharps |=   ($1 << 13)              'A#
            160..169 : notes  |= ($1 << 19)              'B

            170..179 : notes  |= ($1 << 20)              'C6
            180..190 : sharps |=   ($1 << 14)              'C#
            170..179 : notes  |= ($1 << 21)              'D
            180..190 : sharps |=   ($1 << 15)              'D#
            170..179 : notes  |= ($1 << 22)              'E
}
