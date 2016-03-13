on $*:SOCKLISTEN:/^mBeamPro_\d+_IRCListen$/:{
  var %Cid, %Error, %Sock

  ;; get connection id from sockname, and tokenize the sockmark
  %Cid = $gettok($sockname, 2, 95)
  tokenize 32 $sock($sockname).mark

  ;; Output debug message
  _mBeamPro.Debug -i IRC LISTEN( $+ %Cid $+ )~Incoming connection

  ;; validate state
  if ($scid(%Cid).cid !== %Cid) {
    _mBeamPro.Cleanup -a %Cid
    %Error = STATE_ERROR No matching status window for connection
  }
  elseif ($0 !== 3) {
    %Error = INTERNAL_ERROR Sock state lost
  }
  elseif ($sockerr) {
    %Error = SOCK_ERROR $sock($sockname).wsmsg
  }
  elseif ($scid(%Cid).status !== loggingon || $scid(%Cid).port !== $sock($sockname).port) {
    _mBeamPro.Debug -w IRC LISTEN( $+ %Cid $+ )~Unsolicated incoming connection; ignoring.
  }
  else {

    ;; Accept the connection temporarily
    %Sock = mBeamPro_ $+ %Cid $+ _Tmp
    sockaccept %Sock

    ;; Connection is from a remote host: output debug message and then
    ;; close the connection.
    if ($sock(%Sock).ip !== 127.0.0.1) {
      _mBeamPro.Debug -w IRC LISTEN( $+ %Cid $+ )~Incoming connection was from a remote host( $+ $v1 $+ ); Closing
      sockclose %Sock
    }
    else {

      ;; rename the socket away from the temporary name
      %Sock = $_mBeamPro.GetLogonSock(%Cid)
      sockrename $+(mBeamPro_, %Cid, _Tmp) %Sock

      ;; Store default state information, including login creditentials
      ;; the client must specify and a default state for the client
      sockmark %Sock $1-3 $false $false $false $false

      ;; Start a timeout that will close the connection if the client does
      ;; not login and output a debug message
      $+(.timer, %Sock, _Timeout) -oi 1 30 _mBeamPro.LogonTimeout %Sock
      _mBeamPro.Debug -i2 IRC LISTEN( $+ %Cid $+ )~Accepted connection from $sock(%sock).ip
    }
  }

  ;; Handle Errors
  :error
  if ($error || %Error) {
    %Error = $v1
    sockclose $sockname

    ;; if there was a sockerr, restart the connection
    if ($gettok(%Error, 1, 32) == SOCK_ERROR) {
      scid %Cid
      $+(.timer, $sockname) 1 0 socklisten $sockname $sock($sockname).port $(|) sockmark $sockname $_mBeamPro.Safe($sock($sockname).mark)
      _mBeamPro.Debug -e IRC LISTEN( $+ %Cid $+ )~ $+ %Error $+ ; Restarting listener
    }
    else {
      _mbeamPro.Debug -e IRC LISTEN( $+ %Cid $+ )~ $+ %Error
    }
  }
}

;; $_mBeamPro.GetLogonSock(cid)
;;   Returns a ClientLogon sockname that is not currently in use
;;
;;   cid - (required)
;;     The connection id($cid) for which the logon sock should be created
;;     for
alias -l _mBeamPro.GetLogonSock {
  var %Sock = $ticks $+ 000
  while ($sock($+(mBeamPro_, $1, _ClientLogon $+ %Sock))) {
    inc %Sock
  }
  return $+(mBeamPro_, $1, _ClientLogon, %Sock)
}

;; /_mBeamPro.LogonTimeout sock
;;   Closes the specified sock if the client has not logged on with the
;;   first 30 seconds of being connected.
;;
;;   sock - (required)
;;     The sock name to close
alias -l _mBeamPro.LogonTimeout {
  if ($sock($1)) {
    var %Cid = $gettok($1, 2, 95)
    _mBeamPro.Debug -w IRC LOGON( $+ %Cid $+ )~Client failed to logon within 30 seconds after connecting; Closing
    sockclose $1
  }
}