alias -l _mBeamPro.IRCWrite {
  var %Cid, %Switches, %Error

  if (-* iswm $1) {
    %Switches = $mid($1, 2)
    tokenize 32 $2-
  }
  %Cid = $gettok($1, 2, 95)

  ;; Validate the inputs
  if (!$regex(cid, $1, /^mBeamPro_(\d+)_ClientAuthed$/i) || $0 < 2) {
    return
  }
  elseif (!$sock($1)) {
    %Error = INTERNAL_ERROR Connection no longer exists
  }

  ;; validate switches
  elseif ($regex(%Switches, /([^t])/)) {
    %Error = INTERNAL_ERROR Unknown switch specified: $regml(1)
  }
  elseif ($regex(%Switches, /([^t]).*?\1/)) {
    %Error = INTERNAL_ERROR Duplicate switch specified: $regml(1)
  }

  ;; Handle specified bvar
  elseif (t !isincs %Switches && $0 == 2 && &?* iswm $2 && $bvar($2,0)) {
    bcopy -c &mBeamPro_IRCSendBuffer $calc($hget($1, IRC_SENDBUFFER, &mBeamPro_IRCSendBuffer) +1) $2 1 -1
    hadd -b $1 IRC_SENDBUFFER &mBeamPro_IRCSendBuffer
    bunset &mBeamPro_IRCSendBuffer
    _mBeamPro.IRCSend $1
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
  elseif (!$hget($1, IRC_SENDBUFFER, &mBeamPro_IRCSendBuffer) && !$sock($1).sq && $sock($1).mark == CLOSING) {
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

;; $_mBeamPro.URLEncode
alias -l _mBeamPro.URLEncode {
  return $regsubex($1-, /([^a-z\d_\-])/g, % $+ $base( $asc(\t), 10, 16, 2))
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
  else {
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
    scid %Cid

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
        var %Index = 2, %Chan

        ;; loop over each channel in the list
        while (%index <= $0) {
          %Chan = $($+($, %Index), 2)

          ;; validate the channel and make sure the user is not already on it
          if (#?* iswm %Chan && !$WebSock(mBeamPro_ $+ %Cid $+ _Chat $+ %Chan)) {

            ;; Attempt to join the channel or output error message
            if ($_mBeamPro.JoinChat(%Cid, $mid(%Chan, 2), %AuthToken)) {
              _mBeamPro.IRCWrite $sockname :mirc.beam.pro NOTICE %Username : $+ $v1
            }
          }
          inc %index
        }
      }

      ;; /PART
      elseif ($1 == PART) {
        ;; check to make sure the 2nd parameter is a channel
        if (#?* iswm $2) {

          ;; if there's a websocket open for the channel, close it
          if ($sock(_WebSocket_mBeamPro_ $+ %Cid $+ _Chat $+ $2)) {
            WebSockClose $gettok($v1, 2-, 95)
          }

          ;; if the user is currently on the channel, send a PART message
          ;; to the irc client
          if ($me ison $2) {
            _mBeamPro.IRCWrite $sockname : $+ %UserHost PART $2 :Leaving
          }
        }
      }

      ;; /PRIVMSG
      elseif ($1 == PRIVMSG) {
        var %_Target, %_Msg, %_Ws

        ;; Validate command format, then get target and message
        if ($regex($1-, /^PRIVMSG (#\S+) :(.*)/i)) {
          %_Target = $regml(1)
          %_Msg = $regml(2)

          ;; Check to make sure a websocket to the specified channel is
          ;; open
          if ($WebSock(mBeamPro_ $+ %Cid $+ _Chat $+ $2)) {
            %_Ws = $v1
            
            
            if ($hget(_WebSocket_mBeamPro_ $+ %Cid $+ _Chat $+ $2, BeamPro_Joined)) {
              ;; If an action send the message prefixed with '/me' through
              ;; the websock
              if ($regex(%_Msg, /^\x01ACTION (.+)\x01/i)) {
                noop $_mBeamPro.WebSockSend(%_Ws, msg, /me $regml(1))
              }

              ;; If not an action send the message, as-in, trhough the
              ;; websocket
              else {
                noop $_mBeamPro.WebSockSend(%_Ws, msg, %_Msg)
              }
            }
            else {
              _mBeamPro.IRCWrite $sockname :mirc.beam.pro NOTICE %UserName :Please wait for the connection to $2's chat to establish
            }
          }

          ;; Handle not being on the specified stream's channel
          else {
            _mBeamPro.IRCWrite $sockname :mirc.beam.pro NOTICE %UserName :You are not on $2
          }
        }

        ;; Handle invalid parameters
        else {
          _mBeamPro.IRCWrite $sockname :mirc.beam.pro NOTICE %UserName :Invalid message parameters; if you were trying to whisper use: /notice #stream user message
        }
      }

      ;; /NOTICE
      elseif ($1 == NOTICE) {
        var %_Target, %_User, %_Msg, %_Ws
        if ($regex($1-, /^NOTICE (#\S+) :(\S+) (.+)$/i)) {
          %_Target = $regml(1)
          %_User = $regml(2)
          %_Msg = $regml(3)
          if ($WebSock(mBeamPro_ $+ %Cid $+ _Chat $+ %_Target)) {
            %_Ws = $v1
            if ($hget(_mbeamPro_ $+ %Cid $+ _Chat $+ %_Target, BeamPro_Joined)) {
              noop $_mBeamPro.WebSockSend(%_Ws, whisper, %_User, %_Msg)._mBeamPro.OnWhisperReply
            }
            else {
              _mBeamPro.IRCWrite $sockname :mirc.beam.pro NOTICE %UserName :Please wait for the connection to $2's chat to establish
            }
          }
          else {
            _mBeamPro.IRCWrite $sockname :mirc.beam.pro NOTICE %USerName :You must be on the specified stream chat to send whispers to it's users.
          }
        }
        else {
          _mBeamPro.IRCWrite $sockname :mirc.beam.pro NOTICE %UserName :Invalid whisper parameters: /notice #stream user message.
        }
      }

      ;; /MODE
      elseif ($1 == MODE) {
        if (#?* iswm $2 && $WebScok(mBeamPro_ $+ %Cid $+ _Chat $+ $2)) {
          _mBeamPro.IRCWrite $sockname :mirc.beam.pro MODE $2 +nt
        }
        elseif ($2 == %Username) {
          ;; user mode
        }
        else {

        }
      }

      ;; /USERHOST
      elseif ($1 == USERHOST && $2- == %Username) {
        _mBeamPro.IRCWrite $sockname :mirc.beam.pro 302 %UserName $+(:, %Username, =+u, %UserId, @, %Username, .user.beam.pro)
      }

      ;; /TOPIC
      elseif ($1 == TOPIC) {
      }

      ;; Ignore:
      ;;   /PROTOCTL
      elseif ($1 == PROTOCTL) {
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