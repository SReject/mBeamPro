;;------------------------------------------------------------------------------------------------------------------------------------
;;-------------------------------------------------------------------------------------------------------------- Commands for Beam.pro
;;------------------------------------------------------------------------------------------------------------------------------------
;; /Vote [#channel] option
;;   Casts a vote in an active poll
;;
;;   #channel - (optional)
;;     The channel to cast your vote in
;;
;;   option - (optional)
;;     The numerical index of the option you choose to vote for
alias vote {
  var %Chan, %Option

  ;; Validate connection
  if ($status !== connected) {
    echo $color(info) -age * /vote: Not connected to a server
  }
  elseif ($network !== beam.pro) {
    echo $color(info) -age * /vote: Not connected to a beam.pro server
  }
  elseif ($0 < 1) {
    echo $color(info) -age * /vote: Missing parameters
  }
  elseif ($0 > 2) {
    echo $color(info) -age * /vote: Excessive parameters
  }
  else {

    ;; validate option
    %Option = $($ $+ $0, 2)
    if (%Option !isnum 0- || . isin %Option) {
      echo $color(info) -age * /vote: Invalid option specified
    }
    else {

      ;; seperate channel parameter from option parameter
      if (#?* iswm $1) {
        %Chan = $1
      }
      elseif ($active ischan && $me ison $active) {
        %Chan = $active
      }
      else {
        echo $color(info) -age * /vote: Active window is not a channel
        halt
      }

      msg %Chan VOTE:OPTION[ $+ %Option $+ ]
    }
  }
}