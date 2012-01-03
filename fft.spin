CON

  _clkmode = xtal1+pll16x
  _xinfreq = 5_000_000

  BITS_NN= 10
  BITS_NNM1=BITS_NN-1
  NN= |<BITS_NN                 'Nifty bitwise decode
  BITS_DIFF=3

VAR
  long flag_ptr
  long time_ptr
  long real_ptr
  long imag_ptr
  long scrn_ptr

    'hann window multiplier
'  word  window[NN / 2]


PUB start(in_flag_ptr,in_time_ptr,in_real_ptr,in_imag_ptr,in_scrn_ptr) : okay

  flag_ptr := in_flag_ptr
  time_ptr := in_time_ptr
  real_ptr := in_real_ptr
  imag_ptr := in_imag_ptr
  scrn_ptr := in_scrn_ptr

  okay := cognew(@init, @flag_ptr) + 1

PUB stop(cog)
'' stop fft engine and release the cog

  if cog
    cogstop(cog~ - 1)


    
DAT 
' http://propeller.wikispaces.com/FFT

' Converted to Propeller Assembler by Pacito.Sys, based on int_fft.c by Tom Roberts
' with portability by Malcolm Slaney.
' Distributed under the terms of the GNU GPL v2.0.
'
' Integer FFT
' 16 bit signed values are used

' Modified by Pete Hemery - Oct, Nov, Dec 2011 
                        org     0
 
init                    mov     fft_n,#1
                        shl     fft_n,#BITS_NN          '1024 point fft

                        mov     in_ptr,PAR
                        rdlong  asm_flag_ptr,in_ptr     'Flag Pointer

                        add     in_ptr,#4
                        rdlong  asm_time_ptr,in_ptr     'Time Keeping Pointer

                        add     in_ptr,#4
                        rdlong  fft_fr,in_ptr           'Real Buffer Pointer  - 2048 bytes

                        add     in_ptr,#4
                        rdlong  fft_fi,in_ptr           'Imaginary Buffer Pointer - 2048 bytes

                        add     in_ptr,#4
                        rdlong  cnt_bitmap_ptr,in_ptr   'VGA Screen Bitmap Pointer

                        mov     peak_ptr,asm_flag_ptr
                        add     peak_ptr,#4             'Peak Value Array Pointer

flag_wait               rdlong  temp,asm_flag_ptr   wz  'wait until flag changes before looping again
              if_nz     jmp     #flag_wait
                        mov     asm_cnt,cnt
                        wrlong  asm_cnt,asm_time_ptr    'keep track of the time

loop                    call    #decimate
                        call    #lets_rock
                        call    #calc_abs
                        call    #plot

                        add     one,#1
                        wrlong  one,asm_flag_ptr        'ack
                        mov     asm_cnt,cnt
                        wrlong  asm_cnt,asm_time_ptr    'keep track of the time

                        jmp     #flag_wait
{{
'inserted cog stop instead of infinite loop
                        cogid   cog_id
                        cogstop cog_id
'end

 init_end               jmp     #init_end               ' end
}}
' bit-reversal, uses the nice rev instruction
decimate                mov     fft_ii,#1
                        mov     fft_ll,fft_n
ldecimate               mov     fft_jj,fft_ii
                        rev     fft_jj,#32-BITS_NN     ' BITS_NN will be reversed
                        cmp     fft_ii,fft_jj   wc
              if_nc     jmp     #ldecimate_5
                        mov     fft_fr_ii,fft_ii
                        mov     fft_fr_jj,fft_jj
                        shl     fft_fr_ii,#1
                        add     fft_fr_ii,fft_fr
                        rdword  fft_tr,fft_fr_ii
                        shl     fft_fr_jj,#1
                        add     fft_fr_jj,fft_fr
                        rdword  fft_result,fft_fr_jj
                        wrword  fft_tr,fft_fr_jj
                        wrword  fft_result,fft_fr_ii
ldecimate_5             add     fft_ii,#1
                        cmp     fft_ii,fft_ll   wc, wz
              if_c_or_z jmp     #ldecimate
decimate_ret            ret
 
' Calcs the 1024 point-FFT using 16 bit signed integers, some calculations
' are don with 32 bits
 
lets_rock               mov     fft_ll,#1
                        mov     fft_k,#BITS_NNM1
 
lets_rock_while         cmp     fft_ll,fft_n      wc
              if_nc     jmp     #lets_rock_while_e
 
                        mov     fft_is,fft_ll
                        shl     fft_is,#1
                        mov     fft_m,#0
lets_rock_for_1         cmp     fft_m,fft_ll      wc
              if_nc     jmp     #lets_rock_for_1_e
 
                        mov     fft_jj,fft_m
                        shl     fft_jj,fft_k
 
                        call    #get_sincos
                        mov     fft_ii,fft_m
lets_rock_for_2         cmp     fft_ii,fft_n      wc
              if_nc     jmp     #lets_rock_for_2_e
 
                        mov     fft_jj,fft_ii
                        add     fft_jj,fft_ll
 
                        mov     fft_fi_jj,fft_jj
                        shl     fft_fi_jj,#1      ' word access
                        mov     fft_fr_jj,fft_fi_jj
                        add     fft_fr_jj,fft_fr
                        add     fft_fi_jj,fft_fi
 
                        rdword  fft_result,fft_fr_jj
                        call    #lets_mul_wr
                        mov     fft_tr,fft_result
                        rdword  fft_result,fft_fi_jj
                        call    #lets_mul_wi
                        subs    fft_tr,fft_result     ' 32 bit signed value
 
                        rdword  fft_result,fft_fi_jj
                        call    #lets_mul_wr
                        mov     fft_ti,fft_result
                        rdword  fft_result,fft_fr_jj
                        call    #lets_mul_wi
                        adds    fft_ti,fft_result     ' 32 bit signed value
 
                        mov     fft_fi_ii,fft_ii
                        shl     fft_fi_ii,#1          ' word access
                        mov     fft_fr_ii,fft_fi_ii
                        add     fft_fr_ii,fft_fr
                        add     fft_fi_ii,fft_fi
 
                        rdword  fft_qr,fft_fr_ii      ' qr = fr[i]
                        shl     fft_qr,#16
                        sar     fft_qr,#1             ' scales to 32 bit signed value
                        mov     fft_result,fft_tr
                        rdword  fft_qi,fft_fi_ii      ' qi = fi[i]
                        shl     fft_qi,#16
                        sar     fft_qi,#1             ' scales to 32 bit signed value
                        adds    fft_result,fft_qr     ' res = tr + qr
                        subs    fft_qr,fft_tr         ' qr = qr - tr
                        shr     fft_result,#16        ' scales down
                        wrword  fft_result,fft_fr_ii  ' fr[i] = res = tr + qr
 
                        mov     fft_result,fft_ti
                        adds    fft_result,fft_qi     ' res = ti + qi
                        shr     fft_qr,#16            ' scales down
                        wrword  fft_qr,fft_fr_jj      ' fr[j] = qr = qr - tr
                        subs    fft_qi,fft_ti         ' qi = qi - ti
                        shr     fft_result,#16        ' scales down
                        wrword  fft_result,fft_fi_ii  ' fi[i] = ti + qi
                        shr     fft_qi,#16            ' scales down
                        add     fft_ii,fft_is
                        wrword  fft_qi,fft_fi_jj      ' fi[j] = qi = qi - ti
                        jmp     #lets_rock_for_2
lets_rock_for_2_e
                        add     fft_m,#1
                        jmp     #lets_rock_for_1
lets_rock_for_1_e       sub     fft_k,#1
                        mov     fft_ll,fft_is
                        jmp     #lets_rock_while
lets_rock_while_e
lets_rock_ret           ret
 
 
lets_mul_wi             mov     fft_sgn,fft_result
                        and     fft_sgn,cnt_sgn     wz
                        shl     fft_result,#16
                        negnz   fft_result,fft_result
                        shr     fft_result,#15
 
                        shr     fft_result,#1       wc
              if_c      add     fft_result,fft_wi   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wi   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wi   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wi   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wi   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wi   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wi   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wi   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wi   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wi   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wi   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wi   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wi   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wi   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wi   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wi   wc
                        rcr     fft_result,#1       wc
                        xor     fft_sgn,fft_sgnwi   wz
                        negnz   fft_result,fft_result
lets_mul_wi_ret         ret
 
lets_mul_wr             mov     fft_sgn,fft_result
                        and     fft_sgn,cnt_sgn     wz
                        shl     fft_result,#16
                        negnz   fft_result,fft_result
                        shr     fft_result,#15
                        shr     fft_result,#1       wc
              if_c      add     fft_result,fft_wr   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wr   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wr   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wr   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wr   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wr   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wr   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wr   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wr   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wr   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wr   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wr   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wr   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wr   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wr   wc
                        rcr     fft_result,#1       wc
              if_c      add     fft_result,fft_wr   wc
                        rcr     fft_result,#1       wc
                        xor     fft_sgn,fft_sgnwr   wz
                        negnz   fft_result,fft_result
lets_mul_wr_ret         ret
 
' Uses the ROM table to get the sine and cosine of jj
 
get_sincos              mov     fft_wr,fft_jj
                        shl     fft_wr,#BITS_DIFF
                        mov     fft_wi,fft_wr
                        add     fft_wr,cnt_sin_90
                        test    fft_wi,cnt_sin_90     wc
                        test    fft_wi,cnt_sin_180    wz
                        negc    fft_wi,fft_wi
                        or      fft_wi,cnt_sin_table
                        shl     fft_wi,#1
                        rdword  fft_wi,fft_wi
              if_z      mov     fft_sgnwi,cnt_sgn        ' they are inverted
              if_nz     mov     fft_sgnwi,#0
                        test    fft_wr,cnt_sin_90     wc
                        test    fft_wr,cnt_sin_180    wz
                        negc    fft_wr,fft_wr
                        or      fft_wr,cnt_sin_table
                        shl     fft_wr,#1
                        rdword  fft_wr,fft_wr
              if_nz     mov     fft_sgnwr,cnt_sgn        ' they are not inverted
              if_z      mov     fft_sgnwr,#0
 
                        shl     fft_wr,#14
                        shl     fft_wi,#14
get_sincos_ret          ret
 
lets_mul_qr             mov     fft_result,fft_qr
                        shl     fft_result,#16
                        abs     fft_result,fft_result
                        mov     fft_qr,fft_result
                        shr     fft_result,#16
 
                        shr     fft_result,#1        wc
              if_c      add     fft_result,fft_qr    wc
                        rcr     fft_result,#1        wc
              if_c      add     fft_result,fft_qr    wc
                        rcr     fft_result,#1        wc
              if_c      add     fft_result,fft_qr    wc
                        rcr     fft_result,#1        wc
              if_c      add     fft_result,fft_qr    wc
                        rcr     fft_result,#1        wc
              if_c      add     fft_result,fft_qr    wc
                        rcr     fft_result,#1        wc
              if_c      add     fft_result,fft_qr    wc
                        rcr     fft_result,#1        wc
              if_c      add     fft_result,fft_qr    wc
                        rcr     fft_result,#1        wc
              if_c      add     fft_result,fft_qr    wc
                        rcr     fft_result,#1        wc
              if_c      add     fft_result,fft_qr    wc
                        rcr     fft_result,#1        wc
              if_c      add     fft_result,fft_qr    wc
                        rcr     fft_result,#1        wc
              if_c      add     fft_result,fft_qr    wc
                        rcr     fft_result,#1        wc
              if_c      add     fft_result,fft_qr    wc
                        rcr     fft_result,#1        wc
              if_c      add     fft_result,fft_qr    wc
                        rcr     fft_result,#1        wc
              if_c      add     fft_result,fft_qr    wc
                        rcr     fft_result,#1        wc
              if_c      add     fft_result,fft_qr    wc
                        rcr     fft_result,#1        wc
              if_c      add     fft_result,fft_qr    wc
                        rcr     fft_result,#1
lets_mul_qr_ret         ret
 
lets_sqrt_qi            mov     fft_result,#0
                        mov     fft_m,#0
                        mov     fft_jj,#16
lets_sqrt_qi_l          shl     fft_qi,#1   wc
                        rcl     fft_m,#1
                        shl     fft_qi,#1   wc
                        rcl     fft_m,#1
                        shl     fft_result,#2
                        or      fft_result,#1
                        cmpsub  fft_m,fft_result   wc, wr
                        shr     fft_result,#2
                        rcl     fft_result,#1
                        djnz    fft_jj,#lets_sqrt_qi_l
lets_sqrt_qi_ret        ret
 
calc_abs                mov      fft_ii,#511
                        mov      fft_fr_ii,fft_fr
                        mov      fft_fi_ii,fft_fi
calc_abs_5              rdword   fft_qr,fft_fr_ii
                        call     #lets_mul_qr
                        mov      fft_qi,fft_result
                        rdword   fft_qr,fft_fi_ii
                        add      fft_fi_ii,#2          ' next word
                        call     #lets_mul_qr
                        add      fft_qi,fft_result
                        call     #lets_sqrt_qi
                        wrword   fft_result,fft_fr_ii
                        add      fft_fr_ii,#2          ' next word
                        djnz     fft_ii,#calc_abs_5
calc_abs_ret            ret
 
' This routine will draw the spectrum in a 1bpp 320x240 bitmap
 
plot                    mov      fft_ii,#40
                        mov      fft_jj,#0
 
                        mov      fft_fr_ii,fft_fr
plot_8p                 mov      fft_k,#$80
                        rdword   fft_qr,fft_fr_ii
                        add      fft_fr_ii,#2
                        call     #putpix
                        shr      fft_k,#1
                        rdword   fft_qr,fft_fr_ii
                        add      fft_fr_ii,#2
                        call     #putpix
                        shr      fft_k,#1
                        rdword   fft_qr,fft_fr_ii
                        add      fft_fr_ii,#2
                        call     #putpix
                        shr      fft_k,#1
                        rdword   fft_qr,fft_fr_ii
                        add      fft_fr_ii,#2
                        call     #putpix
                        shr      fft_k,#1
                        rdword   fft_qr,fft_fr_ii
                        add      fft_fr_ii,#2
                        call     #putpix
                        shr      fft_k,#1
                        rdword   fft_qr,fft_fr_ii
                        add      fft_fr_ii,#2
                        call     #putpix
                        shr      fft_k,#1
                        rdword   fft_qr,fft_fr_ii
                        add      fft_fr_ii,#2
                        call     #putpix
                        shr      fft_k,#1
                        rdword   fft_qr,fft_fr_ii
                        add      fft_fr_ii,#2
                        call     #putpix
                        add      fft_jj,#1
                        djnz     fft_ii,#plot_8p
 
plot_ret                ret
 
putpix                  mov      fft_qi,#239
                        max      fft_qi,fft_qr
                        mov      fft_qr,#239
                        sub      fft_qr,fft_qi
                        shl      fft_qr,#3
                        mov      fft_qi,fft_qr
                        shl      fft_qr,#2
                        add      fft_qr,fft_qi
                        add      fft_qr,cnt_bitmap_ptr
                        add      fft_qr,fft_jj
                        rdbyte   fft_ll,fft_qr
                        or       fft_ll,fft_k
                        wrbyte   fft_ll,fft_qr
putpix_ret              ret

' constants
cnt_sgn                 long    $8000
cnt_sin_90              long    $0800
cnt_sin_180             long    $1000
cnt_sin_table           long    $7000
cnt_bitmap_ptr          long    $4000
cnt_add_ptr             long    512
 
' Variables
 
fft_ii                  long    0
fft_is                  long    0
fft_jj                  long    0
fft_k                   long    0
fft_ll                  long    0
fft_m                   long    0
fft_n                   long    0
 
fft_qr                  long    0
fft_qi                  long    0
fft_fr                  long    0
fft_fi                  long    0
fft_tr                  long    0
fft_ti                  long    0
fft_wr                  long    0
fft_wi                  long    0
fft_fi_ii               long    0
fft_fr_ii               long    0
fft_fi_jj               long    0
fft_fr_jj               long    0
fft_result              long    0
fft_sgn                 long    0
fft_sgnwr               long    0  ' sign of wr
fft_sgnwi               long    0  ' sign of wi


peak_ptr                long    0
peak_1                  long    0
peak_2                  long    0
peak_3                  long    0
peak_4                  long    0

timer_val               long    0

in_ptr                  long    0
asm_flag_ptr            long    0
asm_time_ptr            long    0
asm_cnt                 long    0

asm_window_ptr          long    0
cog_id                  long    0        
temp                    long    0
zero                    long    0
one                     long    0
windowing               res     256
