alias -l _mBeamPro.IRCWrite {
  var %Cid = $gettok($1, 2, 95), %Error

  ;; Validate the inputs
  if (!$regex(cid, $1, /^mBeamPro_(\d+)_ClientAuthed$/i) || $0 < 2) {
    return
  }
  elseif (!$sock($1)) {
    %Error = INTERNAL_ERROR Connection no longer exists
  }

  ;; Add \r\n to the end of the specified data and append it to the send
  ;; buffer the call the send-buffer processing alias
  else {
    bset -tc &mBeamPro_IRCSendBuffer $calc($hget($1, IRC_SENDBUFFER, &mBeamPro_IRCSendBuffer) + 1) $2- $+ $crlf
    hadd -b $1 IRC_SENDBUFFER &mBeamPro_IRCSendBuffer
    bunset &mBeamPro_IRCSendBuffer
    _mBeamPro.IRCSend $1
  }

  ;; Handle Errors
  :error
  bunset &mBeamPro_IRCSendBuffer
  if ($error || %Error) {
    %Error = $v1
    _mBeamPro.Debug -e IRC AUTH SEND( $+ %Cid $+ )~ $+ %Error
    _mBeamPro.Cleanup -a %Cid
  }
}

alias -l _mBeamPro.IRCSend {
  bunset &mBeamPro_IRCSendBuffer

  var %Cid = $gettok($1, 2, 95), %Error, %Space, %Size

  ;; Validate sock
  if (!$regex(cid, $1, /^mBeamPro_(\d+)_ClientAuthed$/i)) {
    return
  }
  elseif (!$sock($1)) {
    %Error = INTERNAL_ERROR Connection no longer exists
  }

  ;; Check if the connection should be closed
  elseif (!$hget($sockname, IRC_SENDBUFFER, &mBeamPro_IRCSendBuffer) && !$sock($1).sq && $sock($1).mark == CLOSING) {
    _mBeamPro.Debug -i2 IRC AUTH SEND( $+ %Cid $+ )~All data sent, closing the connection.
    _mBeamPro.Cleanup -a %Cid
  }

  ;; Determine if there's room in mIRC's internal write buffer for more
  ;; data
  elseif ($bvar(&mBeamPro_IRCSendBuffer, 0) && $calc(16384 - $sock($1).sq) > 0) {
    %Space = $v1
    %Size = $bvar(&mBeamPro_IRCSendBuffer, 0)

    ;; If the internal buffer cannot contain all pending data
    if (%Size > %Space) {

      ;; add as much as the internal buffer can hold, remove the data from
      ;; the scripted buffer, store the scripted buffer, and output a
      ;; debug message
      sockwrite -b $1 %Space &mBeamPro_IRCSendBuffer
      bcopy -c &mBeamPro_IRCSendBuffer 1 &mBeamPro_IRCSendBuffer $calc(%Space +1) -1
      hadd -b $1 IRC_SENDBUFFER &mBeamPro_IRCSendBuffer
      _mBeamPro.Debug -u IRC AUTH SEND( $+ %Cid $+ )~Added %Space bytes to the internal write buffer
    }

    ;; If the internal buffer can contain all pending data, add the data
    ;; to the internal buffer then clear the scripted buffer
    else {
      sockwrite $1 &mBeamPro_IRCSendBuffer
      hdel $1 IRC_SENDBUFFER
      _mBeamPro.Debug -i2 IRC AUTH SEND( $+ %Cid $+ )~All pending data added to internal socket buffer
    }
  }

  :error
  bunset &mBeamPro_IRCSendBuffer
  if ($error || %Error) {
    %Error = $v1
    _mBeamPro.Debug -e IRC AUTH SEND( $+ %Cid $+ )~ $+ %Error
    _mBeamPro.Cleanup -a %Cid
  }
}

;; /_mBeamPro.Ping <sockname>
alias _mBeamPro.Ping {
  if ($sock($1)) {
    _mBeamPro.IRCWrite $1 PING :TimeOutCheck
    $+(.timer, $1, _PINGTimeout) -o 1 30 _mBeamPro.PingTimeout $1
  }
}
alias -l _mBeamPro.PingTimeout {
  if ($sock($1)) {
    sockmark $1 CLOSING
    sockwrite -n $1 :mirc.beam.pro NOTICE * :Pong not returned; closing connection.
  }
}

on $*:SOCKWRITE:/^mBeamPro_\d+_ClientAuthed$/:{
  var %Cid = $gettok($sockname, 2, 95), %Error

  ;; Validate sock state
  if (!$scid(%Cid).cid) {
    %Error = STATUS_CLOSED No matching connection for the client
  }
  elseif (!$hget($sockname)) {
    %Error = INTERNAL_ERROR Hashtable for client no longer exists
  }

  ;; Check for sock errors
  elseif ($sockerr) {
    %Error = SOCK_ERROR SockClose Error: $sock($sockname).wsmsg
  }

  ;; Attempt to move more data from the scripted write buffer to the
  ;; internal socket's send buffer
  elseif {
    _mBeamPro.IRCSend $sockname
  }

  ;; Handle Errors
  :error
  if ($error || %Error) {
    _mBeamPro.Debug -e IRC AUTH WRITE( $+ %Cid $+ )~ $+ $v1
    _mBeamPro.Cleanup -a %Cid
  }
}

on $*:SOCKREAD:/^mBeamPro_\d+_ClientAuthed$/:{
  var %Cid = $gettok($sockname, 2, 95), %Error, %AuthToken, %UserName, %UserId, %UserHost, %Data

  ;; Validate sock state
  if (!$scid(%Cid).cid) {
    %Error = STATUS_CLOSED No matching connection for the client
  }
  elseif (!$hget($sockname)) {
    %Error = INTERNAL_ERROR Hashtable for client no longer exists
  }
  elseif (!$hget($sockname, Beampro_AuthToken)) {
    %Error = INTERNAL_ERROR Hashtable does not contain an auth token
  }
  elseif (!$hget($sockname, Beampro_Username)) {
    %Error = INTERNAL_ERROR Hashtable does not contain a username
  }
  elseif (!$hget($sockname, Beampro_UserId)) {
    %Error = INTERNAL_ERROR Hashtable does not contain a userid
  }

  ;; Check for sock errors
  elseif ($sockerr) {
    %Error = SOCK_ERROR SockClose Error: $sock($sockname).wsmsg
  }
  else {
    %AuthToken = $hget($sockname, BeamPro_AuthToken)
    %Username = $hget($sockname, BeamPro_Username)
    %UserId = $hget($sockname, BeamPro_UserId)
    %UserHost = $+(%UserName, !u, %UserId, @, %UserName, .user.beam.pro)

    ;; Read, line by line, from the sockets read buffer
    while ($sock($sockname).mark !== CLOSING) {
      sockread %Data
      if (!$sockbr) {
        break
      }

      ;; Reset the ping timer
      $+(.timer, $sockname, _PING) 1 30 _mBeamPro.Ping $sockname

      ;; Trim excess whitespace; if no data is left, continue to the next
      ;; line in the buffer
      if (!$regsubex(%Data, /^(?:^\s+)|(?:\s+$)/g, )) {
        continue
      }

      ;; Tokenize the data to make it easier to handle, and output a debug message
      tokenize 32 %Data
      _mBeamPro.Debug -i IRC AUTH READ( $+ %Cid $+ )~ $+ $1-

      ;; PING/PONG handling
      if ($1 === PING) {
        _mBeamPro.IRCWrite $sockname PONG $2-
      }
      elseif ($1 == PONG) {
        $+(.timer, $sockname, _PINGTimeout) off
      }

      ;; The client is attempting to re-register
      elseif ($1 == PASS || $1 == NICK || $1 == USER) {
        _mBeamPro.IRCWrite $sockname :mirc.beam.pro 462 %Username :You may not re-register
      }

      ;; /QUIT
      elseif ($1 == QUIT) {
        _mBeamPro.Debug -i2 IRC AUTH READ( $+ %Cid $+ )~Quit recieved; closing connection
        sockmark $sockname CLOSING
        sockpause $sockname
        break
      }

      ;; /JOIN
      elseif ($1 == JOIN) {


      }

      ;; /PART
      elseif ($1 == PART) {
      }

      ;; /PRIVMSG
      elseif ($1 == PRIVMSG) {
      }

      ;; /TOPIC
      elseif ($1 == TOPIC) {
      }

      ;; Unknown command
      else {
        _mBeamPro.IRCWrite $sockname :mirc.beam.pro 421 %Username :Unknown command: $1-
      }
    }
  }

  ;; Handle Errors
  :error
  if ($error || %Error) {
    _mBeamPro.Debug -e IRC AUTH READ( $+ %Cid $+ )~ $+ $v1
    _mBeamPro.Cleanup -a %Cid
  }
}

on $*:SOCKCLOSE:/^mBeamPro_\d+_ClientAuthed$/:{
  var %Cid = $gettok($sockname, 2, 95), %Error

  ;; Validate sock state
  if (!$scid(%Cid).cid) {
    %Error = STATUS_CLOSED No matching connection for the client
  }
  elseif (!$hget($sockname)) {
    %Error = INTERNAL_ERROR Hashtable for client no longer exists
  }

  ;; Check for sock errors
  elseif ($sockerr) {
    %Error = SOCK_ERROR SockClose Error: $sock($sockname).wsmsg
  }
  else {
    _mBeamPro.Debug -i2 IRC AUTH CLOSE( $+ %Cid $+ )~Connection closed
  }

  ;; Handle Errors
  :error
  if ($error || %Error) {
    _mBeamPro.Debug -e IRC AUTH CLOSE( $+ %Cid $+ )~ $+ $v1
  }
  _mBeamPro.Cleanup -a %Cid
}