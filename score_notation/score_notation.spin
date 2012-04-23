''Score Notation
''Pete Hemery
''22/4/2012

CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000

  '512x384
  tiles = gr#tiles

  fft_size = fft#FFT_SIZE

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

  word  audio_buffer[fft#FFT_SIZE * 2]


PUB start | x,y,i,k,startTime, endTime, flag_copy, first_trigger, audio_endTime,audio_startTime

  if ina[31] == 1                            'Check if we're connected via USB
    pst_on := 1
    pst.Start(115200)             'Start the Parallax Serial Terminal cog
    pst.NewLine
  else
    pst_on := 0

  pst.str(string(pst#NL,"here"))
  gr.start


  audio_flag := 3               'will be set to 0 on initialisation
  array_size := fft#FFT_SIZE * 2

  first_trigger := 6

  fft.start(@fft_mailbox_cmd)

  aud.start(@audio_flag)


  repeat

    if flag_copy <> long[@audio_flag]
      flag_copy := long[@audio_flag]
      audio_endTime := long[@audio_time]

      endTime := cnt

      pst.str(string(pst#NL,"main loop wait time = "))
      pst.dec((endTime - startTime) / (clkfreq / 1000))
      pst.str(string("ms",pst#NL))


      pst.str(string("sampler cog 512 samples run time = "))
      pst.dec((audio_endTime - audio_startTime) / (clkfreq / 1000))
      pst.str(string("ms",pst#NL))
      audio_startTime := audio_endTime

      pst.dec(flag_copy)
      pst.newline
      pst.dec(word[@audio_time])
      pst.newline

      if first_trigger <> 0
        first_trigger--

      if first_trigger <> 0
        pst.newline
        next

      startTime := cnt
      case flag_copy
        0 : repeat k from 0 to 1023
              long[@bx][k] := ((~~word[@audio_buffer][k+1024]) * hamming_window[k]) / 1000
{
              pst.dec(k)
              pst.char(" ")
              pst.dec(~~word[@audio_buffer][k+1024])

              pst.char(" ")
              pst.dec(hamming_window[k])
              pst.char(" ")
              pst.dec(long[@bx][k])
              pst.newline
}
{        1 : repeat k from 0 to 511
              long[@bx][k] := ~~word[@audio_buffer][k+1536]
              long[@bx][k+512] := ~~word[@audio_buffer][k]
}
        2 : repeat k from 0 to 1023
              long[@bx][k] := ((~~word[@audio_buffer][k]) * hamming_window[k]) / 1000
{
              pst.dec(k)
              pst.char(" ")
              pst.dec(~~word[@audio_buffer][k])

              pst.char(" ")
              pst.dec(hamming_window[k])
              pst.char(" ")
              pst.dec(long[@bx][k])
              pst.newline
}
{        3 : repeat k from 0 to 1023
              long[@bx][k] := ~~word[@audio_buffer][k+512]
}
        other :
              startTime := cnt
              next

      endTime := cnt

      pst.str(string("data copying run time = "))
      pst.dec((endTime - startTime) / (clkfreq / 1000))
      pst.str(string("ms",pst#NL))


      'The Fourier transform, including bit-reversal reordering and magnitude converstion
      startTime := cnt
      fft.butterflies(fft#CMD_DECIMATE | fft#CMD_BUTTERFLY | fft#CMD_MAGNITUDE, @bx, @by)'| fft#CMD_HAMMING
      endTime := cnt

      notes := sharps := 0

'      repeat x from 24 to 495   'full range
      repeat x from 41 to 226   'kalimba range
        if ||bx[x] > threshold        'absolute value

          case x
            24       : notes  |= ($1 << 0)               'D3
            26       : sharps |=   ($1 << 0)               'D#
            27,28    : notes  |= ($1 << 1)               'E
            29       : notes  |= ($1 << 2)               'F
            31       : sharps |=   ($1 << 1)               'F#
            32,33    : notes  |= ($1 << 3)               'G
            34,35    : sharps |=   ($1 << 2)               'G#
            36,37    : notes  |= ($1 << 4)               'A
            39       : sharps |=   ($1 << 3)               'A#
            41       : notes  |= ($1 << 5)               'B

            43..44   : notes  |= ($1 << 6)               'C4
            47       : sharps |=   ($1 << 4)               'C#
            49      : notes  |= ($1 << 7)               'D
            52      : sharps |=   ($1 << 5)               'D#
            55      : notes  |= ($1 << 8)               'E
            58      : notes  |= ($1 << 9)               'F
            61..62   : sharps |=   ($1 << 6)               'F#
            65..66   : notes  |= ($1 << 10)              'G
            69..70   : sharps |=   ($1 << 7)               'G#
            73..74   : notes  |= ($1 << 11)              'A
            77..78   : sharps |=   ($1 << 8)               'A#
            81..82   : notes  |= ($1 << 12)              'B

            87       : notes  |= ($1 << 13)              'C5
            92..93   : sharps |=   ($1 << 9)               'C#
            98       : notes  |= ($1 << 14)              'D
            103..104 : sharps |=   ($1 << 10)              'D#
            109..110 : notes  |= ($1 << 15)              'E
            116..117 : notes  |= ($1 << 16)              'F
            123..124 : sharps |=   ($1 << 11)              'F#
            130..131 : notes  |= ($1 << 17)              'G
            138..139 : sharps |=   ($1 << 12)              'G#
            146..147 : notes  |= ($1 << 18)              'A
            155..156 : sharps |=   ($1 << 13)              'A#
            164..166 : notes  |= ($1 << 19)              'B

            173..175 : notes  |= ($1 << 20)              'C6
            184..186 : sharps |=   ($1 << 14)              'C#
            195..197 : notes  |= ($1 << 21)              'D
            206..209 : sharps |=   ($1 << 15)              'D#
            219..221 : notes  |= ($1 << 22)              'E

            232..234 : notes  |= ($1 << 23)              'F
            245..248 : sharps |=   ($1 << 16)              'F#
            260..263 : notes  |= ($1 << 24)              'G
            276..278 : sharps |=   ($1 << 17)              'G#
            292..295 : notes  |= ($1 << 25)              'A
            309..312 : sharps |=   ($1 << 18)              'A#
            328..331 : notes  |= ($1 << 26)              'B

            347..350 : notes  |= ($1 << 27)              'C7
            368..371 : sharps |=   ($1 << 19)              'C#
            390..393 : notes  |= ($1 << 28)              'D
            413..417 : sharps |=   ($1 << 20)              'D#
            438..441 : notes  |= ($1 << 29)              'E
            464..467 : notes  |= ($1 << 30)              'F
            491..495 : sharps |=   ($1 << 21)              'F#
{
          pst.dec(x)
          pst.char(":")
          pst.dec(||bx[x])
          pst.newline
}
      'if notes <> 0 OR sharps <> 0
      gr.copy_notes(notes,sharps)
      pst.str(string("notes:  "))
      pst.hex(notes,8)
      pst.newline
      pst.str(string("sharps: "))
      pst.hex(sharps,8)
      pst.newline

      notes |= $8000
      'Print resulting spectrum
      'printSpectrum
      longfill(@bx,0,fft#FFT_SIZE*2)

      pst.str(string("1024 point FFT plus magnitude calculation run time = "))
      pst.dec((endTime - startTime) / (clkfreq / 1000))
      pst.str(string("ms",pst#NL))

      startTime := cnt


PUB printSpectrum  | i, real, imag, magnitude
'Spectrum is available in first half of the buffers after FFT.
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
'For testing define 16 samples  of an input wave form here.
input long 4096, 3784, 2896, 1567, 0, -1567, -2896, -3784, -4096, -3784, -2896, -1567, 0, 1567, 2896, 3784

hamming_window
        long  80, 80, 80, 80, 80, 80, 80, 80, 81, 81, 81, 81, 81, 81, 82, 82
        long  82, 83, 83, 83, 83, 84, 84, 85, 85, 85, 86, 86, 87, 87, 88, 88
        long  89, 89, 90, 91, 91, 92, 92, 93, 94, 95, 95, 96, 97, 97, 98, 99
        long  100, 101, 102, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114
        long  115, 116, 117, 118, 120, 121, 122, 123, 124, 125, 127, 128, 129, 130, 132, 133
        long  134, 136, 137, 138, 140, 141, 143, 144, 146, 147, 149, 150, 152, 153, 155, 156
        long  158, 159, 161, 162, 164, 166, 167, 169, 171, 172, 174, 176, 178, 179, 181, 183
        long  185, 186, 188, 190, 192, 194, 196, 197, 199, 201, 203, 205, 207, 209, 211, 213
        long  215, 217, 219, 221, 223, 225, 227, 229, 231, 233, 236, 238, 240, 242, 244, 246
        long  248, 251, 253, 255, 257, 260, 262, 264, 266, 269, 271, 273, 275, 278, 280, 282
        long  285, 287, 290, 292, 294, 297, 299, 301, 304, 306, 309, 311, 314, 316, 319, 321
        long  324, 326, 329, 331, 334, 336, 339, 341, 344, 346, 349, 351, 354, 357, 359, 362
        long  364, 367, 370, 372, 375, 378, 380, 383, 386, 388, 391, 394, 396, 399, 402, 404
        long  407, 410, 412, 415, 418, 421, 423, 426, 429, 432, 434, 437, 440, 443, 445, 448
        long  451, 454, 456, 459, 462, 465, 468, 470, 473, 476, 479, 482, 484, 487, 490, 493
        long  496, 498, 501, 504, 507, 510, 512, 515, 518, 521, 524, 527, 529, 532, 535, 538
        long  541, 544, 546, 549, 552, 555, 558, 560, 563, 566, 569, 572, 575, 577, 580, 583
        long  586, 589, 591, 594, 597, 600, 603, 605, 608, 611, 614, 617, 619, 622, 625, 628
        long  631, 633, 636, 639, 642, 644, 647, 650, 653, 655, 658, 661, 663, 666, 669, 672
        long  674, 677, 680, 682, 685, 688, 690, 693, 696, 698, 701, 704, 706, 709, 712, 714
        long  717, 719, 722, 725, 727, 730, 732, 735, 737, 740, 743, 745, 748, 750, 753, 755
        long  758, 760, 763, 765, 768, 770, 772, 775, 777, 780, 782, 785, 787, 789, 792, 794
        long  796, 799, 801, 803, 806, 808, 810, 813, 815, 817, 819, 822, 824, 826, 828, 830
        long  833, 835, 837, 839, 841, 843, 845, 848, 850, 852, 854, 856, 858, 860, 862, 864
        long  866, 868, 870, 872, 874, 876, 878, 880, 882, 883, 885, 887, 889, 891, 893, 894
        long  896, 898, 900, 902, 903, 905, 907, 908, 910, 912, 913, 915, 917, 918, 920, 922
        long  923, 925, 926, 928, 929, 931, 932, 934, 935, 937, 938, 939, 941, 942, 944, 945
        long  946, 948, 949, 950, 951, 953, 954, 955, 956, 958, 959, 960, 961, 962, 963, 964
        long  965, 967, 968, 969, 970, 971, 972, 973, 974, 974, 975, 976, 977, 978, 979, 980
        long  981, 981, 982, 983, 984, 984, 985, 986, 987, 987, 988, 988, 989, 990, 990, 991
        long  991, 992, 992, 993, 993, 994, 994, 995, 995, 996, 996, 996, 997, 997, 997, 998
        long  998, 998, 998, 999, 999, 999, 999, 999, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000
        long  1000, 1000, 1000, 1000, 1000, 1000, 1000, 1000, 999, 999, 999, 999, 999, 998, 998, 998
        long  998, 997, 997, 997, 996, 996, 996, 995, 995, 994, 994, 993, 993, 992, 992, 991
        long  991, 990, 990, 989, 988, 988, 987, 987, 986, 985, 984, 984, 983, 982, 981, 981
        long  980, 979, 978, 977, 976, 975, 974, 974, 973, 972, 971, 970, 969, 968, 967, 965
        long  964, 963, 962, 961, 960, 959, 958, 956, 955, 954, 953, 951, 950, 949, 948, 946
        long  945, 944, 942, 941, 939, 938, 937, 935, 934, 932, 931, 929, 928, 926, 925, 923
        long  922, 920, 918, 917, 915, 913, 912, 910, 908, 907, 905, 903, 902, 900, 898, 896
        long  894, 893, 891, 889, 887, 885, 883, 882, 880, 878, 876, 874, 872, 870, 868, 866
        long  864, 862, 860, 858, 856, 854, 852, 850, 848, 845, 843, 841, 839, 837, 835, 833
        long  830, 828, 826, 824, 822, 819, 817, 815, 813, 810, 808, 806, 803, 801, 799, 796
        long  794, 792, 789, 787, 785, 782, 780, 777, 775, 772, 770, 768, 765, 763, 760, 758
        long  755, 753, 750, 748, 745, 743, 740, 737, 735, 732, 730, 727, 725, 722, 719, 717
        long  714, 712, 709, 706, 704, 701, 698, 696, 693, 690, 688, 685, 682, 680, 677, 674
        long  672, 669, 666, 663, 661, 658, 655, 653, 650, 647, 644, 642, 639, 636, 633, 631
        long  628, 625, 622, 619, 617, 614, 611, 608, 605, 603, 600, 597, 594, 591, 589, 586
        long  583, 580, 577, 575, 572, 569, 566, 563, 560, 558, 555, 552, 549, 546, 544, 541
        long  538, 535, 532, 529, 527, 524, 521, 518, 515, 512, 510, 507, 504, 501, 498, 496
        long  493, 490, 487, 484, 482, 479, 476, 473, 470, 468, 465, 462, 459, 456, 454, 451
        long  448, 445, 443, 440, 437, 434, 432, 429, 426, 423, 421, 418, 415, 412, 410, 407
        long  404, 402, 399, 396, 394, 391, 388, 386, 383, 380, 378, 375, 372, 370, 367, 364
        long  362, 359, 357, 354, 351, 349, 346, 344, 341, 339, 336, 334, 331, 329, 326, 324
        long  321, 319, 316, 314, 311, 309, 306, 304, 301, 299, 297, 294, 292, 290, 287, 285
        long  282, 280, 278, 275, 273, 271, 269, 266, 264, 262, 260, 257, 255, 253, 251, 248
        long  246, 244, 242, 240, 238, 236, 233, 231, 229, 227, 225, 223, 221, 219, 217, 215
        long  213, 211, 209, 207, 205, 203, 201, 199, 197, 196, 194, 192, 190, 188, 186, 185
        long  183, 181, 179, 178, 176, 174, 172, 171, 169, 167, 166, 164, 162, 161, 159, 158
        long  156, 155, 153, 152, 150, 149, 147, 146, 144, 143, 141, 140, 138, 137, 136, 134
        long  133, 132, 130, 129, 128, 127, 125, 124, 123, 122, 121, 120, 118, 117, 116, 115
        long  114, 113, 112, 111, 110, 109, 108, 107, 106, 105, 104, 103, 102, 102, 101, 100
        long  99, 98, 97, 97, 96, 95, 95, 94, 93, 92, 92, 91, 91, 90, 89, 89
        long  88, 88, 87, 87, 86, 86, 85, 85, 85, 84, 84, 83, 83, 83, 83, 82
        long  82, 82, 81, 81, 81, 81, 81, 81, 80, 80, 80, 80, 80, 80, 80, 80


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
