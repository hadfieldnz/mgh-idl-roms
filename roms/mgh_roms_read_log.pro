;+
; NAME:
;   MGH_ROMS_READ_LOG
;
; PURPOSE:
;   Read info from a ROMS log (standard output) file.
;
; CATEGORY:
;   ROMS
;
; CALLING SEQUENCE:
;   Result = MGH_ROMS_READ_LOG(file)
;
; POSITIONAL PARAMETERS:
;   file (input, scalar string)
;     Input file name (read-only)
;
; RETURN VALUE:
;   The function returns a structure with a whole load of different tags.
;
; MODIFICATION HISTORY:
;   Mark Hadfield, 2001-04:
;     Written.
;   Mark Hadfield, 2008-04:
;     Modified to handle the new time format, described here:
;       https://www.myroms.org/projects/src/ticket/144
;   Mark Hadfield, 2010-02:
;     The function has been made more robust by removing references to
;     the stage variable, which determined what lines we were
;     expecting to encounter at any point in the file. Ordering
;     inconsistencies in some files led to these expectations being
;     violated.
;   Mark Hadfield, 2010-10:
;     Time-step data are now accumulated in a list object (new to IDL 8)
;     rather than an mgh_vector object.
;   Mark Hadfield, 2010-11:
;     Now attempts to read float-source info.
;   Mark Hadfield, 2011-06:
;     Now reads Courant-number info at each time step, if available. At
;     the moment the way this is done does not relate the CFL info to
;     the corresponding time-step info as tightly as I'd like.
;   Mark Hadfield, 2011-08:
;     Now reads selected physical parameter info.
;   Mark Hadfield, 2013-01:
;     Removed NO_COPY keyword from calls to the list's ToArray method: not
;     supported in IDL 8.0.
;   Mark Hadfield, 2013-03:
;     Added (rudimentary) support for ROMS-COAWST and multiple grids.
;-
function mgh_roms_read_log, file

  compile_opt DEFINT32
  compile_opt STRICTARR
  compile_opt STRICTARRSUBS
  compile_opt LOGICAL_PREDICATE

  if n_elements(file) eq 0 then $
    message, BLOCK='mgh_mblk_motley', NAME='mgh_m_undefvar', 'file'

  if n_elements(file) gt 1 then $
    message, BLOCK='mgh_mblk_motley', NAME='mgh_m_wrgnumelem', 'file'

  if size(file, /TYPE) ne 7 then $
    message, BLOCK='mgh_mblk_motley', NAME='mgh_m_wrongtype', 'file'

  if ~ file_test(file, /READ) then $
    message, 'The input file cannot be read: '+file

  openr, lun, file, /GET_LUN, COMPRESS=strmatch(file, '*.gz')

  prm_info = {dstart: 0D}
  src_info = {g: 0, c: 0, n: 0, $
    ft0: 0D, fx0: 0D, fy0: 0D, fz0: 0D, $
    fdt: 0D, fdx: 0D, fdy: 0D, fdz: 0D}
  step_info = {grid: 0, step: 0, time: 0D, $
    ke: 0D, pe: 0D, te: 0D, nv: 0D}
  cfl_info = {cu: 0D, cv: 0D, cw: 0D, smax: 0D}

  src_list = list()
  step_list = list()
  cfl_list = list()

  process_prm = 0B
  process_src = 0B
  process_step = 0B

  result = {n_line: 0, version: '', date0: !values.d_nan, date1: !values.d_nan, $
    dt: !values.d_nan, n_flt: 0, prm: prm_info}

  line = ''

  while ~ eof(lun) do begin

    readf, lun, line
    result.n_line += 1

    ;; Search for various lines with summary info

    if strmatch(line, string(replicate(32B, 20))+'*-*-* ?M') then begin
      result.date0 = mgh_roms_parse_date(strmid(line, 20))
      continue
    endif

    if strmatch(line, '*ROMS/TOMS version*') then begin
      result.version = strtrim(strmid(line, 44), 2)
      continue
    endif

    if strmatch(line, '*ROMS/TOMS: DONE*') then begin
      result.date1 = mgh_roms_parse_date(strmid(line, 20))
      continue
    endif

    ;; Search for lines indicating what sort of info we can expect

    if strmatch(line, '*Physical Parameters, Grid:*', /FOLD_CASE) then begin
      process_prm = 1B
      process_src = 0B
      process_step = 0B
      continue
    endif

    if strmatch(line, '*Floats Initial Locations*', /FOLD_CASE) then begin
      process_prm = 0B
      process_src = 1B
      process_step = 0B
      continue
    endif

    if process_src && strmatch(line, '*Nfloats*Number of float trajectories to compute*') then begin
      s = strsplit(line, /EXTRACT)
      result.n_flt = long(s[0])
      process_src = 0B
      continue
    endif

    if strmatch(line, '*STEP*KINETIC*POTEN*TOTAL*NET*', /FOLD_CASE) then begin
      process_prm = 0B
      process_src = 0B
      process_step = 1B
      continue
    endif

    ;; Process physical parameters info

    if process_prm then begin

      ;; Split the line into substrings at spans of white space.
      s = strsplit(line, /EXTRACT)

      ;; If there are at least 2 elements and the first is numeric, then
      ;; look for numeric data
      if n_elements(s) ge 2 && mgh_str_isnumber(s[0]) then begin
        if strmatch(s[1], 'dstart', /FOLD_CASE) then $
          result.prm.dstart = double(s[0])
        continue
      endif

    endif

    ;; Process float-source info

    if process_src then begin

      ;; Split the line into substrings at spans of white space.
      s = strsplit(line, /EXTRACT)

      ;; If there are 11 elements, all numeric, then we have
      ;; single-line float-source data
      if n_elements(s) eq 11 && min(mgh_str_isnumber(s)) gt 0 then begin
        reads, line, src_info
        src_list->Add, src_info
        continue
      endif

      ;; If there are 7 elements, all numeric, then we have
      ;; double-line float-source data
      if n_elements(s) eq 7 && min(mgh_str_isnumber(s)) gt 0 then begin
        line_save = line
        readf, lun, line
        result.n_line += 1
        reads, line_save+line, src_info
        src_list->Add, src_info
        continue
      endif

    endif

    ;; Process time-step info

    if process_step then begin

      ;; Split the line into substrings at spans of white space.
      s = strsplit(line, /EXTRACT)

      ;; If there are 7 elements, the third (index 2) matches
      ;; "??:??:??", and the others are all numeric, then we have time
      ;; step data with time in "day hh:mm:ss" format.

      if n_elements(s) ge 7 && $
        strmatch(s[2], '??:??:??') && $
        min(mgh_str_isnumber([s[0:1],s[3:*]])) gt 0 then begin
        dd = 0 & hh = 0 & mm = 0 & ss = 0
        reads, s[1], dd
        reads, s[2], hh, mm, ss, FORMAT='(I2,X,I2,X,I2)'
        line = strjoin(['0',s[0],string(dd+(hh+(mm+ss/60D)/60D)/24D),s[3:*]], ' ')
        reads, line, step_info
        step_list->Add, step_info
        continue
      endif

      ;; If there are 8 elements, the fourth (index 3) matches
      ;; "??:??:??", and the others are all numeric, then we have time
      ;; step data with time in "day hh:mm:ss" format, but with a
      ;; leading grid number (COAWST)

      if n_elements(s) ge 8 && $
        strmatch(s[3], '??:??:??') && $
        min(mgh_str_isnumber([s[0:2],s[4:*]])) gt 0 then begin
        dd = 0 & hh = 0 & mm = 0 & ss = 0
        reads, s[2], dd
        reads, s[3], hh, mm, ss, FORMAT='(I2,X,I2,X,I2)'
        line = strjoin([s[0:1],string(dd+(hh+(mm+ss/60D)/60D)/24D),s[4:*]], ' ')
        reads, line, step_info
        step_list->Add, step_info
        continue
      endif

      ;; If there are 5 elements, the first (index 0) matches
      ;; "(*,*,*)", and the others are all numeric, then we have
      ;; CFL data.

      if n_elements(s) ge 5 && $
        strmatch(s[0], "(*,*,*)") then begin
        reads, strjoin(s[1:*], ' '), cfl_info
        cfl_list->Add, cfl_info
        continue
      endif

      ;; If there are 6 elements, all numeric, then we have time
      ;; step data with time in numeric format

      if n_elements(s) ge 6 && min(mgh_str_isnumber(s)) gt 0 then begin
        reads, line, step_info
        step_list->Add, step_info
        continue
      endif

    endif

  endwhile

  free_lun, lun

  if result.n_line eq 0 then $
    message, 'File is empty: '+file

  ;; Post-process header info

  result.dt = double(result.date1-result.date0)*24*3600

  ;; Append float-source and time-step info, if available

  if src_list.Count() gt 0 then $
    result = create_struct(result, 'src', src_list->ToArray())

  if step_list.Count() gt 0 then $
    result = create_struct(result, 'step', step_list->ToArray())

  if cfl_list.Count() gt 0 then $
    result = create_struct(result, 'cfl', cfl_list->ToArray())

  ;; We're done here

  return, result

end

