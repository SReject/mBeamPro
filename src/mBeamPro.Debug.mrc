;;------------------------------------------------------------------------------------------------------------------------------------
;;--------------------------------------------------------------------------------------------------------------------- /mBeamProDebug
;;------------------------------------------------------------------------------------------------------------------------------------
;; $mBeamProDebug
;;   Returns $true if debugging is enabled
;;
;; /mBeamProDebug [state]
;;   Toggles debugging status
;;
;;   state - (optional)
;;     if on or enable debugging will be enabled
;;     if off or disable debugging will be disabled
alias mBeamProDebug {
  var %Error, %State = $iif($group(#_mBeamPro_Debug) == on, $true, $false)

  ;; If used as an identifier, return the debug state
  if ($isid) {
    return %State
  }

  ;; Validate inputs
  elseif ($0 > 1) {
    %Error = Excessive parameters
  }
  elseif ($0 && !$regex($1, /^(?:on|off|enable|disable)$/i)) {
    %Error = Invalid parameter specified
  }
  else {

    ;; Toggle debug state according to state input
    if ($1 == on || $1 == enable) {
      .enable #_mBeamPro_Debug
    }
    elseif ($1 == off || $1 == disable) {
      .disable #_mBeamPro_Debug
    }
    else {
      $iif(%State, .disable, .enable) #_mBeamPro_Debug
    }

    ;; spawn debug window if debug state is on but the window doesn't exist
    if ($group(#_mBeamPro_Debug) == on && !$window(@mBeamProDebug)) {
      window -nzk0 @mBeamProDebug
    }
  }

  ;; handle errors
  :error
  if ($error || %Error) {
    echo -sg * /mBeamProDebug: $v1
    halt
  }
}

;; If this group is on the contained debug alias will be used to handle
;; debug messages. Otherwise the debug alias outside of the group (below)
;; will be used; which does nothing.
#_mBeamPro_Debug on
;; /_mBeamPro.Debug -e|w|i[2]|s prefix~msg
;;   Outputs a debug message to the debug window
;;
;;  -e : message is an error
;;  -w : message is a warning
;;  -i : message is info type 1 (defaul)
;;  -i2: message is info type 2
;;  -s : message is a success
;;
;;  prefix - (optional)
;;    The prefix of the debug message; defaults to mBeamPro
;;
;;  msg - (required)
;;    The debug message to output
alias -l _mBeamPro.Debug {

  ;; if the window got closed, disable debug outputting
  if (!$window(@mBeamProDebug)) {
    mBeamProDebug off
    return
  }

  var %Color = 03, %Prefix = mBeamPro, %Msg

  ;; Deduce prefix coloring; and remove the switch from the parameters
  if (-* iswm $1) {
    if ($1 == -e) {
      %Color = 04
    }
    elseif ($1 == -w) {
      %Color = 07
    }
    elseif ($1 == -i2) {
      %Color = 10
    }
    elseif ($1 == -s) {
      %Color = 12
    }
    tokenize 32 $2-
  }

  ;; Deduce title and message
  if (~ !isin $1-) {
    %Msg = $1-
  }
  elseif (~* iswm $1-) {
    %Msg = $mid($1-, 2-)
  }
  else {
    %Prefix = $gettok($1-, 1, 126)
    %Msg = $gettok($1-, 2-, 126)
  }

  ;; Output message to debug window
  echo @mBeamProDebug $+($chr(3), %color, [, %Prefix, ], $chr(15)) %Msg
}
#_mBeamPro.Debug end
alias -l _mBeamPro.Debug

;; Debug window menu
menu @mBeamProDebug {
  $iif($group(#_mBeamPro_Debug) == on, Disable, Enable): mBeamProDebug
  -
  Clear: clear @mBeamProDebug
  Save: noop
  -
  Close: mBeamProDebug off | close -@ @mBeamProDebug
}