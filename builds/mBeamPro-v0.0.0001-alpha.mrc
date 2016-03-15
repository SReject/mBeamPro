alias mBeamPro {
  if ($isid) {
    return
  }
  var %Switches, %Error, %Port, %Username, %UserId, %Sock
  _mBeamPro.Debug Calling~/mBeamPro $1-
  if (-* iswm $1) {
    %Switches = $mid($1, 2-)
    tokenize 32 $2-
  }
  if ($regex(%Switches, /([^m])/)) {
    %Error = Unknown switch specified: $regml(1)
  }
  elseif ($regex(%Switches, /([m]).*?\1/)) {
    %Error = Duplicate switch specified: $regml(1)
  }
  elseif ($0 < 1) {
    %Error = Missing parameters.
  }
  elseif ($0 > 2) {
    %Error = Excessive parameters
  }
  else {
    if (m isincs %Switches || !$sock(_mBeamPro_ $+ $cid $+ _IRCListen)) {
      if ($0 == 2) {
        if ($2 !isnum 1-65535 || . isin $2) {
          %Error = Invalid port specified; must be an integer between 1 and 65535
        }
        elseif (!$portfree($2)) {
          %Error = Specified port is in use by another script or program
        }
        else {
          %Port = $2
        }
      }
      elseif ($_mBeamPro.RandPort(10)) {
        %Port = $v1
      }
      else {
        %Error = Unable to locate a free port to use.
      }
      if (%Error) {
        goto error
      }
    }
    JSONOpen -uw mBeamPro_Auth https://beam.pro/api/v1/users/current
    JSONUrlHeader mBeamPro_Auth Authorization Bearer $1
    JSONGet mBeamPro_Auth
    if ($JSONError) {
      %Error = Unable to validate OAuth Token due to a JSON error: $v1
    }
    else {
      %Username = $JSON(mBeamPro_Auth, username)
      %UserId   = $JSON(mBeamPro_Auth, id)
      if (!$len(%Username) || %Userid !isnum) {
        %Error = Unable to retrieve Username and UserID for oauth token(incorrect?)
      }
      else {
        if (m isincs %Switches) {
          server -n
          scid $activecid
        }
        %Sock = $+(mBeamPro_, $cid, _IRCListen)
        if (!$Sock(%Sock)) {
          socklisten -d 127.0.0.1 %Sock %Port
          _mBeamPro.Debug -s IRC~Now listening for local connections on port $2.
        }
        sockmark %Sock $1 %Username %UserId
        _mBeamPro.Debug -i IRC~Attempting to connect to localhost: $+ $sock(%Sock).port as %Username
        server localhost: $+ $sock(%Sock).port $1 -i %Username %Username _ %Userid
      }
    }
    JSONClose mBeamPro_Auth
  }
  :error
  if ($error || %Error) {
    %Error = $v1
    reseterror
    _mBeamPro.Debug -e /mBeamPro~ $+ %Error
    echo $color(info) -s * /mBeamPro: %Error
    halt
  }
}
alias -l _mBeamPro.RandPort {
  if ($isid) {
    var %Attempts = 1, %End = $iif($1, $1, 10), %Port, %Ports
    while (%Attempts < %End) {
      %Port = $rand(1, 65535)
      while ($istok(%Ports, %Port, 32)) {
        %Port = $rand(1, 65535)
      }
      if ($portfree(%port)) {
        return %port
      }
      %Ports = $addtok(%ports, %Port, 32)
      inc %Attempts
    }
  }
}
alias _mBeamPro.Cleanup {
  if ($isid) {
    return
  }
  var %Error, %Switches, %Name
  _mBeamPro.Debug -i Calling~/_mbeamPro.Cleanup $1-
  if (-* iswm $1) {
    %Switches = $mid($1, 2)
    tokenize 32 $2-
  }
  if (!$0) {
    %Error = Missing parameters
  }
  elseif ($regex(%Switches, /([^aAc])/)) {
    %Error = Unknown switch specified: $regml(1)
  }
  elseif ($regex(%Switches, /([aAc]).*?\1/)) {
    %Error = Duplicate switch specified: $regml(1)
  }
  elseif ($regex(%Switches, /([aAc]).*?([aAc])/)) {
    %Error = Conflicting switches specified: $regml(1) $regml(2)
  }
  elseif (%Switches && ($1 !isnum 1- || . isin $1)) {
    %Error = Invalid connection id specified
  }
  elseif (a isincs %Switches) {
    %Name = mBeamPro_ $+ $1 $+ _*
    WebSockClose -fw %name
    sockclose %Name
    hfree -w %Name
    $+(.timer, %Name) off
    _mBeamPro.Debug -s /mBeamPro.Cleanup~All resources freed for $1 $iif($0 > 1, $+($chr(40), $2-, $chr(41)))
  }
  elseif (A isincs %Switches) {
    WebSockClose -fw mBeamPro_ $+ $1 $+ _*
    %Name = mBeamPro_ $+ $1 $+ _ClientAuthed
    sockclose %Name
    hfree -w %Name
    $+(.timer, %Name) off
    _mBeamPro.Debug -s /mBeamPro.Cleanup~All authorized-client resources freed for $1 $iif($0 > 1, $+($chr(40), $2-, $chr(41)))
  }
  elseif (c isincs %Switches) {
    WebSockClose -fw mBeamPro_ $+ $1 $+ _*
    %Name = mBeamPro_ $+ $1 $+ _Client*
    sockclose %Name
    hfree -w %Name
    $+(.timer, %Name) off
    _mBeamPro.Debug -s /mBeamPro.Cleanup~All client resources freed for $1 $iif($0 > 1, $+($chr(40), $2-, $chr(41)))
  }
  else {
    sockclose $1
    hfree -w $1
    $+(.timer, %Name, _?*) off
    _mBeamPro.Debug -s /mBeamPro.Cleanup~All resources freed for $1 $iif($0 > 1, $+($chr(40), $2-, $chr(41)))
  }
  :error
  if ($error || %Error) {
    %Error = $v1
    _mBeamPro.Debug -e /mBeamPro.Cleanup~ $+ %Error
    echo $color(info) -sge * /_mBeamPro.Cleanup: %Error
  }
}
alias mBeamProDebug {
  var %Error, %State = $iif($group(#_mBeamPro_Debug) == on, $true, $false)
  if ($isid) {
    return %State
  }
  elseif ($0 > 1) {
    %Error = Excessive parameters
  }
  elseif ($0 && !$regex($1, /^(?:on|off|enable|disable)$/i)) {
    %Error = Invalid parameter specified
  }
  else {
    if ($1 == on || $1 == enable) {
      .enable #_mBeamPro_Debug
    }
    elseif ($1 == off || $1 == disable) {
      .disable #_mBeamPro_Debug
    }
    else {
      $iif(%State, .disable, .enable) #_mBeamPro_Debug
    }
    if ($group(#_mBeamPro_Debug) == on && !$window(@mBeamProDebug)) {
      window -nzk0 @mBeamProDebug
    }
  }
  :error
  if ($error || %Error) {
    echo -sg * /mBeamProDebug: $v1
    halt
  }
}
#_mBeamPro_Debug on
alias -l _mBeamPro.Debug {
  if (!$window(@mBeamProDebug)) {
    mBeamProDebug off
    return
  }
  var %Color = 03, %Prefix = mBeamPro, %Msg
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
  echo @mBeamProDebug $+($chr(3), %color, [, %Prefix, ], $chr(15)) %Msg
}
#_mBeamPro.Debug end
alias -l _mBeamPro.Debug
menu @mBeamProDebug {
  $iif($group(#_mBeamPro_Debug) == on, Disable, Enable): mBeamProDebug
  -
  Clear: clear @mBeamProDebug
  Save: noop
  -
  Close: mBeamProDebug off | close -@ @mBeamProDebug
}
alias -l _mBeamPro.IRCWrite {
  var %Cid, %Switches, %Error
  if (-* iswm $1) {
    %Switches = $mid($1, 2)
    tokenize 32 $2-
  }
  %Cid = $gettok($1, 2, 95)
  if (!$regex(cid, $1, /^mBeamPro_(\d+)_ClientAuthed$/i) || $0 < 2) {
    return
  }
  elseif (!$sock($1)) {
    %Error = INTERNAL_ERROR Connection no longer exists
  }
  elseif ($regex(%Switches, /([^t])/)) {
    %Error = INTERNAL_ERROR Unknown switch specified: $regml(1)
  }
  elseif ($regex(%Switches, /([^t]).*?\1/)) {
    %Error = INTERNAL_ERROR Duplicate switch specified: $regml(1)
  }
  elseif (t !isincs %Switches && $0 == 2 && &?* iswm $2 && $bvar($2,0)) {
    bcopy -c &mBeamPro_IRCSendBuffer $calc($hget($1, IRC_SENDBUFFER, &mBeamPro_IRCSendBuffer) +1) $2 1 -1
    hadd -b $1 IRC_SENDBUFFER &mBeamPro_IRCSendBuffer
    bunset &mBeamPro_IRCSendBuffer
    _mBeamPro.IRCSend $1
  }
  else {
    bset -tc &mBeamPro_IRCSendBuffer $calc($hget($1, IRC_SENDBUFFER, &mBeamPro_IRCSendBuffer) + 1) $2- $+ $crlf
    hadd -b $1 IRC_SENDBUFFER &mBeamPro_IRCSendBuffer
    bunset &mBeamPro_IRCSendBuffer
    _mBeamPro.IRCSend $1
  }
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
  if (!$regex(cid, $1, /^mBeamPro_(\d+)_ClientAuthed$/i)) {
    return
  }
  elseif (!$sock($1)) {
    %Error = INTERNAL_ERROR Connection no longer exists
  }
  elseif (!$hget($1, IRC_SENDBUFFER, &mBeamPro_IRCSendBuffer) && !$sock($1).sq && $sock($1).mark == CLOSING) {
    _mBeamPro.Debug -i2 IRC AUTH SEND( $+ %Cid $+ )~All data sent, closing the connection.
    _mBeamPro.Cleanup -a %Cid
  }
  elseif ($bvar(&mBeamPro_IRCSendBuffer, 0) && $calc(16384 - $sock($1).sq) > 0) {
    %Space = $v1
    %Size = $bvar(&mBeamPro_IRCSendBuffer, 0)
    if (%Size > %Space) {
      sockwrite -b $1 %Space &mBeamPro_IRCSendBuffer
      bcopy -c &mBeamPro_IRCSendBuffer 1 &mBeamPro_IRCSendBuffer $calc(%Space +1) -1
      hadd -b $1 IRC_SENDBUFFER &mBeamPro_IRCSendBuffer
      _mBeamPro.Debug -u IRC AUTH SEND( $+ %Cid $+ )~Added %Space bytes to the internal write buffer
    }
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
alias -l _mBeamPro.URLEncode {
  return $regsubex($1-, /([^a-z\d_\-])/g, % $+ $base( $asc(\t), 10, 16, 2))
}
on $*:SOCKWRITE:/^mBeamPro_\d+_ClientAuthed$/:{
  var %Cid = $gettok($sockname, 2, 95), %Error
  if (!$scid(%Cid).cid) {
    %Error = STATUS_CLOSED No matching connection for the client
  }
  elseif (!$hget($sockname)) {
    %Error = INTERNAL_ERROR Hashtable for client no longer exists
  }
  elseif ($sockerr) {
    %Error = SOCK_ERROR SockClose Error: $sock($sockname).wsmsg
  }
  else {
    _mBeamPro.IRCSend $sockname
  }
  :error
  if ($error || %Error) {
    _mBeamPro.Debug -e IRC AUTH WRITE( $+ %Cid $+ )~ $+ $v1
    _mBeamPro.Cleanup -a %Cid
  }
}
on $*:SOCKREAD:/^mBeamPro_\d+_ClientAuthed$/:{
  var %Cid = $gettok($sockname, 2, 95), %Error, %AuthToken, %UserName, %UserId, %UserHost, %Data
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
  elseif ($sockerr) {
    %Error = SOCK_ERROR SockClose Error: $sock($sockname).wsmsg
  }
  else {
    %AuthToken = $hget($sockname, BeamPro_AuthToken)
    %Username = $hget($sockname, BeamPro_Username)
    %UserId = $hget($sockname, BeamPro_UserId)
    %UserHost = $+(%UserName, !u, %UserId, @, %UserName, .user.beam.pro)
    while ($sock($sockname).mark !== CLOSING) {
      sockread %Data
      if (!$sockbr) {
        break
      }
      $+(.timer, $sockname, _PING) 1 30 _mBeamPro.Ping $sockname
      if (!$regsubex(%Data, /^(?:^\s+)|(?:\s+$)/g, )) {
        continue
      }
      tokenize 32 %Data
      _mBeamPro.Debug -i IRC AUTH READ( $+ %Cid $+ )~ $+ $1-
      if ($1 === PING) {
        _mBeamPro.IRCWrite $sockname PONG $2-
      }
      elseif ($1 == PONG) {
        $+(.timer, $sockname, _PINGTimeout) off
      }
      elseif ($1 == PASS || $1 == NICK || $1 == USER) {
        _mBeamPro.IRCWrite $sockname :mirc.beam.pro 462 %Username :You may not re-register
      }
      elseif ($1 == QUIT) {
        _mBeamPro.Debug -i2 IRC AUTH READ( $+ %Cid $+ )~Quit recieved; closing connection
        sockmark $sockname CLOSING
        sockpause $sockname
        break
      }
      elseif ($1 == JOIN) {
        var %Index = 2, %Chan
        while (%index <= $0) {
          %Chan = $($+($, %Index), 2)
          if (#?* iswm %Chan && !$WebSock(mBeamPro_ $+ %Cid $+ _Chat $+ %Chan)) {
            if ($_mBeamPro.JoinChat(%Cid, $mid(%Chan, 2), %AuthToken)) {
              _mBeamPro.IRCWrite $sockname :mirc.beam.pro NOTICE %Username : $+ $v1
            }
          }
          inc %index
        }
      }
      elseif ($1 == PART) {
        scid %Cid
        if (#?* iswm $2) {
          if ($sock(_WebSocket_mBeamPro_ $+ %Cid $+ _Chat $+ $2)) {
            WebSockClose $gettok($v1, 2-, 95)
          }
          if ($me ison $2) {
            _mBeamPro.IRCWrite $sockname : $+ %UserHost PART $2 :Leaving
          }
        }
      }
      elseif ($1 == PRIVMSG) {
      }
      elseif ($1 == TOPIC) {
      }
      elseif ($1 == USERHOST && $2- == %Username) {
        _mBeamPro.IRCWrite $sockname :mirc.beam.pro 302 %UserName $+(:, %Username, =+u, %UserId, @, %Username, .user.beam.pro)
      }
      elseif ($regex($1-, /^MODE #(\S+)$/i)) {
        if ($WebSock(mBeamPro_ $+ %Cid $+ _Chat# $+ $regml(1))) {
          _mBeamPro.IRCWrite $sockname :mirc.beam.pro MODE # $+ $regml(1) +nt
        }
      }
      elseif ($1-2 == MODE %UserName || $1 == PROTOCTL) {
      }
      else {
        _mBeamPro.IRCWrite $sockname :mirc.beam.pro 421 %Username :Unknown command: $1-
      }
    }
  }
  :error
  if ($error || %Error) {
    _mBeamPro.Debug -e IRC AUTH READ( $+ %Cid $+ )~ $+ $v1
    _mBeamPro.Cleanup -a %Cid
  }
}
on $*:SOCKCLOSE:/^mBeamPro_\d+_ClientAuthed$/:{
  var %Cid = $gettok($sockname, 2, 95), %Error
  if (!$scid(%Cid).cid) {
    %Error = STATUS_CLOSED No matching connection for the client
  }
  elseif (!$hget($sockname)) {
    %Error = INTERNAL_ERROR Hashtable for client no longer exists
  }
  elseif ($sockerr) {
    %Error = SOCK_ERROR SockClose Error: $sock($sockname).wsmsg
  }
  else {
    _mBeamPro.Debug -i2 IRC AUTH CLOSE( $+ %Cid $+ )~Connection closed
  }
  :error
  if ($error || %Error) {
    _mBeamPro.Debug -e IRC AUTH CLOSE( $+ %Cid $+ )~ $+ $v1
  }
  _mBeamPro.Cleanup -a %Cid
}
on $*:SOCKREAD:/^mBeamPro_\d+_ClientLogon\d+$/:{
  var %Cid, %Error, %Data, %AuthToken, %UserName, %UserId, %UserHost, %GotPass, %GotNick, %GotUser, %InCap, %Sock
  %Cid = $gettok($sockname, 2, 95)
  tokenize 32 $sock($sockname).mark
  if (!$scid(%Cid).cid) {
    _mBeamPro.Cleanup -a %Cid
    %Error = STATUS_CLOSED No matching connection id for client
  }
  elseif ($0 !== 7 && $1- !== CLOSING) {
    %Error = INTERNAL_ERROR Login information lost
  }
  elseif ($sockerr) {
    %Error = SOCK_ERROR $sock($sockname).wsmsg
  }
  elseif ($1- !== CLOSING) {
    %AuthToken = $1
    %Username = $2
    %UserId = $3
    %GotPass = $4
    %GotNick = $5
    %GotUser = $6
    %InCap = $7
    while ($sock($sockname).mark !== CLOSING && (!%GotPass || !%GotNick || !%GotUser || %InCap)) {
      sockread %Data
      if (!$sockbr) {
        break
      }
      if ($regsubex(%Data, /(?:^\s+)|(?:\s+$)/g, ) == $null) {
        continue
      }
      tokenize 32 $v1
      if ($1- == CAP LS) {
        if (%InCap) {
          sockwrite -n $sockname :m.beam.pro NOTICE * :Cap negociations already started
          sockmark $sockname CLOSING
          _mBeamPro.Debug -w IRC CLIENT( $+ %Cid $+ )~Cap list requested after CAP has already started
        }
        else {
          %InCap = $true
          sockwrite -n $sockname :mirc.beam.pro CAP * LS :multi-prefix userhost-in-names
          _mBeamPro.Debug -i IRC CLIENT( $+ %Cid $+ )~Cap list requested; responding with :multi-prefix userhost-in-names
        }
      }
      elseif ($1 == CAP && !%InCap) {
        sockwrite -n $sockname :m.beam.pro NOTICE * :Not in CAP negociations
        sockmark $sockname CLOSING
        _mBeamPro.Debug -w IRC CLIENT( $+ %Cid $+ )~Cap command specified while not in negociates
      }
      elseif ($1-2 == CAP REQ) {
        sockwrite -n $sockname :m.beam.pro CAP * ACK $3-
        _mBeamPro.Debug -i IRC CLIENT( $+ %Cid $+ )~Cap ACK recieved; acknowledging: $3-
      }
      elseif ($1-2 == CAP END) {
        %InCap = $false
        _mBeamPro.Debug -i IRC CLIENT( $+ %Cid $+ )~CAP negociates done( %GotPass %GotNick %GotUser )
      }
      elseif ($1 == CAP) {
        sockwrite -n $sockname :m.beam.pro NOTICE * :Unknown CAP command
        sockmark $sockname CLOSING
        _mBeamPro.Debug -i IRC CLIENT( $+ %Cid $+ )~Unknown CAP command received
      }
      elseif ($1 == QUIT) {
        _mBeamPro.Debug -i IRC CLIENT( $+ %Cid $+ )~Client sent a QUIT command; closing connection
        sockclose $sockname
        return
      }
      elseif ($1 == PASS) {
        if (%GotPass) {
           _mBeamPro.Debug -w IRC CLIENT( $+ %Cid $+ )~Client sent an auth token twice; closing connection
           sockwrite -n $sockname :m.beam.pro NOTICE * :You may not attempt to authorize multiple times
           sockmark $sockname CLOSING
        }
        elseif ($2- !== %AuthToken) {
          _mBeamPro.Debug -w IRC CLIENT( $+ %Cid $+ )~Client sent an invalid auth token; closing connection
          sockwrite -n $sockname :m.beam.pro NOTICE * :Invalid auth token
          sockmark $sockname CLOSING
        }
        else {
          %GotPass = $true
        }
      }
      elseif (!%GotPass) {
        _mBeamPro.Debug -w IRC CLIENT( $+ %Cid $+ )~Client failed to send an auth token as the first command
        sockwrite -n $sockname :m.beam.pro NOTICE * :Auth token not recieved
        sockmark $sockname CLOSING
      }
      elseif ($1 == NICK) {
        if (%GotNick) {
           _mBeamPro.Debug -w IRC CLIENT( $+ %Cid $+ )~Client sent a username twice; closing connection.
           sockwrite -n $sockname :m.beam.pro NOTICE * :You may not attempt to authorize multiple times
           sockmark $sockname CLOSING
        }
        elseif ($2- !== %Username) {
          _mBeamPro.Debug -w IRC CLIENT( $+ %Cid $+ )~Client sent an invalid username; closing connection.
          sockwrite -n $sockname :m.beam.pro NOTICE * :Invalid username
          sockmark $sockname CLOSING
        }
        else {
          %GotNick = $true
        }
      }
      elseif (!%GotNick) {
        _mBeamPro.Debug -w IRC CLIENT( $+ %Cid $+ )~Client failed to send a username as the second command; closing connection.
        sockwrite -n $sockname :m.beam.pro NOTICE * :Username not recieved
        sockmark $sockname CLOSING
      }
      elseif ($1 == USER) {
        if (%GotUser) {
           _mBeamPro.Debug -w IRC CLIENT( $+ %Cid $+ )~Client sent a userid twice; closing connection.
           sockwrite -n $sockname :m.beam.pro NOTICE * :You may not attempt to authorize multiple times
           sockmark $sockname CLOSING
        }
        elseif (!$regex(userid, $2-, /^\S+ . . :(\d+)$/i) || $regml(userid, 1) !== %UserId) {
          _mBeamPro.Debug -w IRC CLIENT( $+ %Cid $+ )~Client sent an invalid userid; closing connection.
          sockwrite -n $sockname :m.beam.pro NOTICE * :Invalid userid
          sockmark $sockname CLOSING
        }
        else {
          %GotUser = $true
        }
      }
      elseif (!%GotUser) {
        _mBeamPro.Debug -w IRC CLIENT( $+ %Cid $+ )~Client failed to send a userid as the third command
        sockwrite -n $sockname :mirc.beam.pro NOTICE * :userid not received
        sockmark $sockname CLOSING
      }
      else {
        _mBeamPro.Debug -w IRC CLIENT( $+ %Cid $+ )~Client sent an unknown command; closing connection
        sockwrite -n $sockname :m.beam.pro NOTICE * :Unknown command recieved
        sockmark $sockname CLOSING
      }
    }
    if ($sock($sockname).mark === CLOSING) {
      sockpause $sockname
    }
    elseif (%GotPass && %GotNick && %GotUser && !%InCap) {
      _mBeamPro.Debug -s IRC CLIENT( $+ %Cid $+ )~Client has successfully authorized.
      _mBeamPro.Cleanup -A %Cid
      %Sock = $+(mBeamPro_, %Cid, _ClientAuthed)
      sockrename $sockname %Sock
      hadd -m $sockname BeamPro_AuthToken %AuthToken
      hadd $sockname BeamPro_Username %UserName
      hadd $sockname BeamPro_Userid %UserId
      sockmark $sockname
      _mBeamPro.IRCWrite %Sock :mirc.beam.pro 001 %UserName :Welcome to beam.pro chat interface for mIRC, %UserName
      _mBeamPro.IRCWrite %Sock :mirc.beam.pro 002 %UserName :Your host is mirc.beam.pro
      _mBeamPro.IRCWrite %Sock :mirc.beam.pro 004 %UserName mirc.beam.pro $mBeamProVer i ntqaohvb
      _mBeamPro.IRCWrite %Sock :mirc.beam.pro 005 %UserName UHNAMES NAMESX NETWORK=beam.pro CHANMODES=b,,,nt PREFIX=(qaohv)~&@%+ CHANTYPES=# :Are supported on this network
      _mBeamPro.IRCWrite %Sock :mirc.beam.pro 375 %UserName :- mirc.beam.pro Message of the day -
      _mBeamPro.IRCWrite %Sock :mirc.beam.pro 372 %UserName :- Welcome to mBeamPro, an mIRC implementation of https://beam.pro stream
      _mBeamPro.IRCWrite %Sock :mirc.beam.pro 372 %UserName :- chat, developed and maintained by SReject.
      _mBeamPro.IRCWrite %Sock :mirc.beam.pro 372 %UserName :-
      _mBeamPro.IRCWrite %Sock :mirc.beam.pro 372 %UserName :- If you encouter bugs, would like to request features, see the readable
      _mBeamPro.IRCWrite %Sock :mirc.beam.pro 372 %UserName :- source or would simply like to get involved you can do so by visting
      _mBeamPro.IRCWrite %Sock :mirc.beam.pro 372 %UserName :- https://github.com/SReject/mBeamPro
      _mBeamPro.IRCWrite %Sock :mirc.beam.pro 376 %UserName :End of MOTD
    }
    else {
      sockmark $sockname %AuthToken %UserName %UserId %GotPass %GotNick %GotUser %InCap
    }
  }
  :error
  if ($error || %Error) {
    %Error = $v1
    sockclose $sockname
    _mBeamPro.Debug -e IRC LOGON READ( $+ %Cid $+ )~ $+ %Error
  }
}
on $*:SOCKWRITE:/^mBeamPro_\d+_ClientLogon\d+$/:{
  var %Cid, %Error
  %Cid = $gettok($sockname, 2, 95)
  tokenize 32 $sock($sockname).mark
  if (!$scid(%Cid).cid) {
    _mBeamPro.Cleanup -a %Cid
    %Error = STATUS_CLOSED No matching connection id for client
  }
  elseif ($1- !== CLOSING && $0 !== 7) {
    %Error = INTERNAL_ERROR Login information lost
  }
  elseif ($sockerr) {
    %Error = SOCK_ERROR SockWrite error:  $sock($sockname).wsmsg
  }
  elseif ($1- == CLOSING && !$sock($sockname).sq) {
    sockclose $sockname
  }
  :error
  if ($error || %Error) {
    %Error = $v1
    sockclose $sockname
    _mBeamPro.Debug -e IRC LOGON WRITE( $+ %Cid $+ )~ $+ %Error
  }
}
on $*:SOCKCLOSE:/^mBeamPro_\d+_ClientLogon\d+$/:{
  var %Cid = $gettok($sockname, 2, 95), %Error
  if (!$scid(%Cid).cid) {
    _mBeamPro.Cleanup -a %Cid
    %Error = STATUS_CLOSED No matching connection for the client
  }
  elseif ($sockerr) {
    %Error = SockRead error: $sock($sockname).wsmsg
  }
  else {
    _mBeamPro.Debug -i2 IRC LOGON CLOSE( $+ %Cid $+ )~Client closed the connection.
  }
  :error
  if ($error || %Error) {
    %Error = $v1
    _mBeamPro.Debug -e IRC LOGON CLOSE( $+ %Cid $+ )~ $+ %Error
  }
}
on $*:SOCKLISTEN:/^mBeamPro_\d+_IRCListen$/:{
  var %Cid, %Error, %Sock
  %Cid = $gettok($sockname, 2, 95)
  tokenize 32 $sock($sockname).mark
  _mBeamPro.Debug -i IRC LISTEN( $+ %Cid $+ )~Incoming connection
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
    %Sock = mBeamPro_ $+ %Cid $+ _Tmp
    sockaccept %Sock
    if ($sock(%Sock).ip !== 127.0.0.1) {
      _mBeamPro.Debug -w IRC LISTEN( $+ %Cid $+ )~Incoming connection was from a remote host( $+ $v1 $+ ); Closing
      sockclose %Sock
    }
    else {
      %Sock = $_mBeamPro.GetLogonSock(%Cid)
      sockrename $+(mBeamPro_, %Cid, _Tmp) %Sock
      sockmark %Sock $1-3 $false $false $false $false
      $+(.timer, %Sock, _Timeout) -oi 1 30 _mBeamPro.LogonTimeout %Sock
      _mBeamPro.Debug -i2 IRC LISTEN( $+ %Cid $+ )~Accepted connection from $sock(%sock).ip
    }
  }
  :error
  if ($error || %Error) {
    %Error = $v1
    sockclose $sockname
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
alias -l _mBeamPro.GetLogonSock {
  var %Sock = $ticks $+ 000
  while ($sock($+(mBeamPro_, $1, _ClientLogon $+ %Sock))) {
    inc %Sock
  }
  return $+(mBeamPro_, $1, _ClientLogon, %Sock)
}
alias -l _mBeamPro.LogonTimeout {
  if ($sock($1)) {
    var %Cid = $gettok($1, 2, 95)
    _mBeamPro.Debug -w IRC LOGON( $+ %Cid $+ )~Client failed to logon within 30 seconds after connecting; Closing
    sockclose $1
  }
}
on *:START:{
  var %Error
  if (!$isalias(JSONVersion)) {
    %Error = JSONForMirc.mrc is required to be loaded: https://github.com/SReject/mBeamPro/res/
  }
  elseif (!$isalias(mWebSockVer)) {
    %Error = mWebSocket.mrc is required to be loaded: https://github.com/SReject/mBeamPro/res/
  }
  elseif ($_mBeamPro.Debug) {
    window -nk0z @mBeamProDebug
  }
  :error
  if ($error || %Error) {
    echo $color(info) -sg [mBeamPro] $v1
    .unload -rs $qt($script)
  }
}
on *:CLOSE:Status Window:{
  _mBeamPro.Cleanup -a $cid Status window closed
}
on *:UNLOAD:{
  scon -a _mBeamPro.cleanup -a $!cid
  if ($window(@mBeamProDebug)) {
    close -@ @mBeamProDebug
  }
}
alias vote {
  var %Chan, %Option
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
    %Option = $($ $+ $0, 2)
    if (%Option !isnum 0- || . isin %Option) {
      echo $color(info) -age * /vote: Invalid option specified
    }
    else {
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
alias -l _mBeamPro.JoinChat {
  if (!$isid) {
    return
  }
  var %Error, %Sock, %Name, %JSON, %ChanId, %AuthKey, %EndPoints, %EndPoint
  tokenize 32 $1 $iif(#?* iswm $2, $2, #$2) $3-
  %Sock = mBeamPro_ $+ $1 $+ _ClientAuthed
  %Name = mBeamPro_ $+ $1 $+ _Chat $+ $2
  if ($0 !== 3) {
    %Error = INTERNAL_ERROR Invalid parameters: $1-
  }
  elseif (!$scid($1).cid) {
    %Error = STATE_ERROR connection id does not exist
  }
  elseif ($scid($1).status !== connected) {
    %Error = STATE_ERROR Connection id is not connected
  }
  elseif (!$sock(%Sock)) {
    %Error = STATE_ERROR Socket does not exist
  }
  elseif ($WebSock(%Name)) {
    %Error = INTERNAL_ERROR WebSock name in use: $v1
  }
  else {
    %JSON = mBeamProGetChannelId
    JSONOpen -u %JSON https://beam.pro/api/v1/channels/ $+ $_mBeamPro.URLEncode($mid($2, 2))
    if ($JSONError) {
      %Error = LOOKUP_ERROR Channel doesn't exist
    }
    elseif (!$len($JSON(%JSON, id))) {
      %Error = LOOKUP_ERROR No channel id was returned for the specified channel
    }
    else {
      %ChanId = $JSON(%JSON, id)
      JSONClose %JSON
      %JSON = mBeamProGetChatAuth
      JSONOpen -uw %JSON https://beam.pro/api/v1/chats/ $+ %ChanId
      JSONUrlHeader %JSON Authorization Bearer $3
      JSONGet %JSON
      if ($JSONError) {
        %Error = JSON_ERROR Unable to retrieve endpoint/authkey for $2
      }
      else {
        %AuthKey = $JSON(%JSON, authkey)
        %EndPoints = $JSON(%JSON, endpoints, length)
        if (!%EndPoints) {
          %Error = JSON_ERROR No endpoints were returned
        }
        elseif (!%AuthKey) {
          %Error = JSON_ERROR A chat authorization key was not returned
        }
        else {
          %EndPoint = $JSON(%JSON, endpoints, $r(0, $calc(%EndPoints -1)))
          JSONClose %JSON
          _mBeamPro.Debug -i JOIN CHAT( $+ $1 - $2 $+ )~Attempting to connect to %EndPoint
          WebSockOpen %Name %EndPoint
          %Name = _WebSocket_ $+ %Name
          hadd %Name BeamPro_ChanName $2
          hadd %Name BeamPro_ChanId   %ChanId
          hadd %Name BeamPro_UserName $hget(%Sock, BeamPro_UserName)
          hadd %Name BeamPro_UserId   $hget(%Sock, BeamPro_UserId)
          hadd %Name BeamPro_AuthKey  %AuthKey
          hadd %Name BeamPro_OAuth    $3
        }
      }
    }
  }
  :error
  if ($error || %Error) {
    %Error = $v1
    reseterror
    JSONClose %JSON
    _mBeamPro.Debug -e $!_mBeamPro.JoinChat~ $+ %Error
    return %Error
  }
}
alias -l _mBeamPro.WebSockSend {
  if (!$isid) {
    return
  }
  var %Id = 0, %Ws = $1, %Sock, %Chan, %Hash, %Id, %Index, %Args
  %Sock = mBeamPro_ $+ $gettok(%Ws, 2, 95) $+ _ClientAuthed
  %Chan = $hget(%Ws, BeamPro_ChanName)
  %Hash = _WebSocket_ $+ %Ws
  if ($prop) {
    %Id = $calc($iif($hget(%Hash, BeamPro_CallBackId), $v1, 0) +1)
    hadd %Hash BeamPro_CallBackId %id
    hadd %Hash BeamPro_Callback $+ %id $prop
  }
  %Index = 4
  while (%Index <= $0) {
    %args = $addtok(%Args, $_mBeamPro.JSONEncode($($+($,%Index), 2)), 44)
    inc %Index
  }
  WebSockWrite %Ws {"type":"method","method": $+ $qt($2) $+ ,"id": $+ $_mBeamPro.JSONEncode(%id) $+ ,"arguments":[ $+ %args $+ ]}
}
alias -l _mBeamPro.JSONEncode {
  if ($1 isnum)     return $1
  if ($1 == $true)  return true
  if ($1 == $false) return false
  if ($1 == null)   return null
  return " $+ $regsubex($1, /([^\x20\x21\x23-\x2E\x30-\x5B\x5D-7F])/g, $_mBeamPro.JSONEsc(\t)) $+ "
}
alias -l _mBeamPro.JSONEsc {
  if ($1 == \)        return \\
  if ($1 == /)        return \/
  if ($1 == ")        return \"
  if ($1 == $cr)      return \r
  if ($1 == $lf)      return \n
  if ($1 == $chr(8))  return \b
  if ($1 == $chr(9))  return \t
  if ($1 == $chr(12)) return \f
  return \u $+ $base($asc($1), 10, 16, 4)
}
alias -l _mBeamPro.OnChatAuth {
  var %Ws, %ReplyJSON, %Cid, %Hash, %Chan, %ChanId, %UserName, %UserId, %Sock
  %Ws        = $1
  %ReplyJSON = $2
  %Cid       = $gettok(%Ws, 2, 95)
  %Hash      = _WebSocket_ $+ %Ws
  %Chan      = $hget(%Hash, BeamPro_ChanName)
  %ChanId    = $hget(%Hash, BeamPro_ChanId)
  %UserName  = $hget(%Hash, BeamPro_UserName)
  %UserId    = $hget(%Hash, BeamPro_UserId)
  %Sock      = mBeamPro_ $+ %Cid $+ _ClientAuthed
  if (!$JSON(%ReplyJSON, error)) {
    var %Topic, %BaseMsg, %Names, %Index, %End, %User, %Index2, %End2, %Role, %IsStaff, %IsOwner, %IsSub, %IsMod
    bset -tc &mBeamPro_JoinMsg 1 $+(:, %UserName, !u, %UserId, @, %UserName, .user.beam.pro JOIN :, %Chan, $crlf)
    %JSON = mBeamPro_ChanState
    JSONOpen -ud %JSON https://beam.pro/api/v1/channels/ $+ %ChanId
    if ($JSONError) {
      %Topic = Error - $v1
    }
    elseif ($JSON(%JSON, online)) {
      %Topic = Online - $JSON(%JSON, type, name) - $JSON(%JSON, name)
    }
    else {
      %Topic = Offline - $JSON(%JSON, name)
    }
    JSONClose %JSON
    bset -t &mBeamPro_JoinMsg $calc($bvar(&mBeamPro_JoinMsg, 0) +1) :mirc.beam.pro 332 %Username %Chan : $+ %Topic $+ $crlf
    bset -t &mBeamPro_JoinMsg $calc($bvar(&mBeamPro_JoinMsg, 0) +1) :mirc.beam.pro 324 %UserName %Chan +nt $+ $crlf
    %JSON = mBeamPro_ChatUserList
    JSONOpen -u %JSON https://beam.pro/api/v1/chats/ $+ %ChanId $+ /users
    if ($JSONError) {
      bset -t &mBeamPro_JoinMsg $calc($nvar(&mbeamPro_JoinMsg, 0) +1) :mirc.beam.pro NOTICE %Chan :Unable to get user list for %Chan
      bset -t &mBeamPro_JoinMsg $calc($bvar(&mBeamPro_JoinMsg, 0) +1) :mirc.beam.pro 353 %Username = %Chan $+(:,%UserName, !u, %UserId, @, %UserName, .user.beam.pro)
    }
    else {
      %BaseMsg = :mirc.beam.pro 353 %UserName = %Chan :
      %End     = $JSON(%JSON, length)
      %Index   = 0
      while (%Index < %End) {
        %User = $JSON(%JSON, %Index, userName)
        %User = %User $+ !u $+ $JSON(%JSON, %Index, userId) $+ @ $+ %User $+ .user.beam.pro
        %isStaff = $false
        %isOwner = $false
        %isSub   = $false
        %isMod   = $false
        %End2    = $JSON(%JSON, %Index, userRoles, length)
        %Index2  = 0
        while (%index2 < %End2) {
          %Role = $JSON(%JSON, %Index, userRoles, %Index2)
          if (%Role == Founder)    %IsStaff = $true
          if (%Role == Staff)      %IsStaff = $true
          if (%Role == Owner)      %IsOwner = $true
          if (%Role == Mod)        %IsMod   = $true
          if (%Role == Subscriber) %IsSub   = $true
          inc %Index2
        }
        if (%IsSub)   %User = % $+ %User
        if (%IsMod)   %User = @ $+ %User
        if (%IsStaff) %User = & $+ %User
        if (%IsOwner) %User = ~ $+ %User
        if ($len(%BaseMsg $+ $addtok(%Names, %User, 32)) > 510) {
          bset -t &mBeamPro_JoinMsg $calc($bvar(&mBeamPro_JoinMsg, 0) +1) %BaseMsg $+ %Names $+ $crlf
          %Names = %User
        }
        else {
          %Names = $addtok(%Names, %User, 32)
        }
        inc %Index
      }
      if (%Names) {
        bset -t &mBeamPro_JoinMsg $calc($bvar(&mBeamPro_JoinMsg, 0) +1) %BaseMsg $+ %Names $+ $crlf
      }
      JSONClose %JSON
    }
    bset -t &mBeamPro_JoinMsg $calc($bvar(&mBeamPro_JoinMsg, 0) +1) :mirc.beam.pro 366 %UserName %Chan :End of /NAMES $+ $crlf
    _mBeamPro.IRCWrite %Sock &mBeamPro_JoinMsg
    bunset &mBeamPro_JoinMsg
    hadd %Ws BeamBeamPro_Joined $true
  }
  else {
    _mBeamPro.Cleanup -a %Cid
    _mBeamPro.Debug -e CHAT LOGON( $+ %Cid $+ )~Auth token is invalid
  }
}
on $*:SIGNAL:/^WebSocket_READY_mBeamPro_\d+_Chat#\S+$/:{
  var %Ws, %Cid, %Hash, %Chan, %ChanId, %UserName, %UserId, %OAuth, %AuthKey, %Sock, %Error
  %Ws       = $WebSock
  %Cid      = $gettok(%Ws, 2, 95)
  %Hash     = _WebSocket_ $+ %Ws
  %Chan     = $hget(%Hash, BeamPro_ChanName)
  %ChanId   = $hget(%Hash, BeamPro_ChanId)
  %UserName = $hget(%Hash, BeamPro_UserName)
  %UserId   = $hget(%Hash, BeamPro_UserId)
  %OAuth    = $hget(%Hash, BeamPro_OAuth)
  %AuthKey  = $hget(%Hash, BeamPro_AuthKey)
  %Sock     = mBeamPro_ $+ %Cid $+ _ClientAuthed
  if (!$scid(%Cid).cid) {
    _mBeamPro.Cleanup -a %Cid
    _mBeamPro.Debug -w WEBSOCK READY( $+ %Cid - %Chan $+ )~IRC Connection no longer exists
  }
  elseif ($scid(%Cid).status !== connected) {
    _mBeamPro.Cleanup -A %Cid
    _mBeamPro.Debug -w WEBSOCK READY( $+ %Cid - %Chan $+ )~IRC Connection not established
  }
  elseif (!$sock(%Sock)) {
    _mBeamPro.Cleanup -A %Cid
    _mBeamPro.Debug -w WEBSOCK READY( $+ %Cid - %Chan $+ )~IRC Connection does not exist
  }
  elseif (!$len(%Chan)) {
    %Error = Websock state lost (Missing Channel name)
  }
  elseif (!$len(%ChanId)) {
    %Error = Websock state lost (Missing Channel Id)
  }
  elseif (!$len(%UserName)) {
    %Error = Websock state lost (Missing User Name)
  }
  elseif (!$len(%UserId)) {
    %Error = Websock state lost (Missing User Id)
  }
  elseif (!$len(%OAuth)) {
    %Error = Websock state lost (Missing Chat Auth Key)
  }
  elseif (!$len(%AuthKey)) {
    %Error = Websock state lost (Missing Chat Auth Key)
  }
  else {
    noop $_mBeamPro.WebSockSend(%Ws, auth, 1, %ChanId, %UserId, %AuthKey)._mBeamPro.OnChatAuth
  }
  :error
  if ($error || %Error) {
    %Error = $v1
    reseterror
    WebSockClose -f %Ws
    _mBeamPro.Debug -e WEBSOCK READY( $+ %Cid - %Chan $+ )~ $+ %Error
    _mBeamPro.IRCWrite %Sock :mirc.beam.pro NOTICE * :WebSock Error: %Error
  }
}
on $*:SIGNAL:/^WebSocket_DATA_mBeamPro_\d+_Chat#\S+$/:{
  var %Ws, %Cid, %Hash, %Chan, %ChanId, %UserName, %UserId, %OAuth, %Sock, %Host, %Error, %Warn, %UserHost, %JSON, %Id, %Event
  %Ws       = $WebSock
  %Cid      = $gettok(%Ws, 2, 95)
  %Hash     = _WebSocket_ $+ %Ws
  %Chan     = $hget(%Hash, BeamPro_ChanName)
  %ChanId   = $hget(%Hash, BeamPro_ChanId)
  %UserName = $hget(%Hash, BeamPro_UserName)
  %UserId   = $hget(%Hash, BeamPro_UserId)
  %OAuth    = $hget(%Hash, BeamPro_OAuth)
  %Sock     = mBeamPro_ $+ %Cid $+ _ClientAuthed
  %Host     = $+(%UserName, !u, %UserId, @, %UserName, .user.beam.pro)
  if (!$scid(%Cid).cid) {
    _mBeamPro.Cleanup -a %Cid
    _mBeamPro.Debug -w WEBSOCK DATA( $+ %Cid - %Chan $+ )~IRC Connection no longer exists
  }
  elseif ($scid(%Cid).status !== connected) {
    _mBeamPro.Cleanup -A %Cid
    _mBeamPro.Debug -w WEBSOCK DATA( $+ %Cid - %Chan $+ )~IRC Connection not established
  }
  elseif (!$sock(%Sock)) {
    _mBeamPro.Cleanup -A %Cid
    _mBeamPro.Debug -w WEBSOCK DATA( $+ %Cid - %Chan $+ )~IRC Connection does not exist
  }
  elseif (!$len(%Chan)) {
    %Error = Websock state lost (Missing Channel name)
  }
  elseif (!$len(%ChanId)) {
    %Error = Websock state lost (Missing Channel Id)
  }
  elseif (!$len(%UserName)) {
    %Error = Websock state lost (Missing User Name)
  }
  elseif (!$len(%UserId)) {
    %Error = Websock state lost (Missing User Id)
  }
  elseif (!$len(%OAuth)) {
    %Error = Websock state lost (Missing Chat Auth Key)
  }
  elseif ($WebSockFrame(TypeText) !== TEXT) {
    %Warn = Non-text frame recieved
  }
  else {
    scid %Cid
    bunset &_mBeamPro_DataFrameJSON
    noop $WebSockFrame(&_mBeamPro_DataFrameJSON)
    %JSON = mBeamPro_DataFrameJSON
    JSONOpen -b %JSON &_mBeamPro_DataFrameJSON
    if ($JSONError) {
      %Warn = Unable to parse frame
    }
    elseif ($JSON(%JSON, type) == reply) {
      %Id = $JSON(%JSON, id)
      if ($hget(%Hash, BeamPro_CallBack $+ %Id)) {
        hdel %Sock BeamPro_CallBack $+ %Id
        $v1 %Ws %JSON
      }
    }
    elseif ($JSON(%JSON, type) == event) {
      var %_UserName, %_UserHost, %_Index = 0, %_End
      %Event     = $JSON(%JSON, event)
      if (%Event == UserJoin) {
        var %_Role, %_Modes
        %_UserName = $JSON(%JSON, username)
        if ($len(%_UserName) && %_UserName !== %UserName) {
          %_UserHost = $+(%_UserName, !u, $JSON(%JSON, id), @, %_UserName, .user.beam.pro)
          _mBeamPro.IRCWrite %Sock : $+ %_UserHost JOIN : $+ %Chan
          %_End = $JSON(%JSON, data, roles, length)
          while (%_Index < %_End) {
            %_Role = $JSON(%JSON, data, roles, %_Index)
            if (%_Role == Founder    && a !isincs %_Modes) { %_Modes = %_Modes $+ a }
            if (%_Role == Owner      && q !isincs %_Modes) { %_Modes = %_Modes $+ q }
            if (%_Role == Mod        && o !isincs %_Modes) { %_Modes = %_Modes $+ o }
            if (%_Role == Subscriber && h !isincs %_Modes) { %_Modes = %_Modes $+ h }
            inc %_Index
          }
          if (%_Modes) {
            _mBeamPro.IRCWrite %Sock :mirc.beam.pro MODE %Chan + $+ %_Modes $str(%_UserName $+ $chr(32), $len(%_Modes))
          }
        }
      }
      elseif (%Event == UserLeave) {
        %_UserName = $JSON(%JSON, username)
        if ($len(%_UserName)) {
          %_UserHost = $+(%_UserName, !u, $JSON(%JSON, id), @, %_UserName, .user.beam.pro)
          _mBeamPro.IRCWrite %Sock : $+ %_UserHost PART %Chan :leaving
        }
      }
      elseif (%Event == ChatMessage) {
        var %_Msg, %_isAction, %_isWhisper
        %_UserName = $JSON(%JSON, data, user_name)
        %_UserHost = $+(%_UserName, !u, $JSON(%JSON, data, user_id), @, %_UserName, .user.beam.pro)
        if (%_UserName !== %UserName) {
          %_IsAction  = $JSON(%JSON, data, message, meta, me)
          %_IsWhisper = $JSON(%JSON, data, message, meta, whisper)
          %_Index = 0
          %_End = $JSON(%JSON, data, message, message, length)
          while (%_Index < %_End) {
            if ($JSON(%JSON, data, message, message, %_Index, type) == text) {
              %_Msg = %_Msg $+ $JSON(%JSON, data, message, message, %_Index, data)
            }
            elseif ($v1 == emoticon) {
              %_Msg = %_Msg $+ $JSON(%JSON, data, message, message, %_Index, text)
            }
            elseif ($v1 == link) {
              %_Msg = %_Msg $JSON(%JSON, data, message, message, %_Index, url) $+ $chr(32)
            }
            inc %_Index
          }
          %_Msg = $regsubex($replace(%_Msg, $cr, $chr(32), $lf, $chr(32)), /(?:^\x20*$)|(?:\x20(?=\x20))/g, )
          if (%_Msg) {
            if (%_IsWhisper) {
              _mBeamPro.IRCWrite %Sock : $+ %_UserHost NOTICE %Chan :(Whisper) %_Msg
            }
            elseif (%_IsAction) {
              _mBeamPro.IRCWrite %Sock : $+ %_UserHost PRIVMSG %Chan : $+ $chr(1) $+ ACTION %_Msg $+ $chr(1)
            }
            else {
              _mBeamPro.IRCWrite %Sock : $+ %_UserHost PRIVMSG %Chan : $+ %_Msg
            }
          }
        }
      }
      elseif ($JSON(%JSON, type) !== DeleteMessage) {
        scid %Cid
        echo -s >> Unknown even frame
        echo -s >> $WebSockFrame
      }
    }
  }
  :error
  JSONClose %JSON
  if ($error || %Error) {
    %Error = $v1
    reseterror
    _mBeamPro.Debug -e WEBSOCK DATA( $+ %Cid - %Chan $+ )~ $+ %Error
    WebSockClose -f %Ws
    _mBeamPro.IRCWrite %Sock :mirc.beam.pro NOTICE * :WebSock failure: %Error
  }
  else if (%Warn) {
    _mBeamPro.Debug -w WEBSOCK DATA( $+ %Cid - %Chan $+ )~ $+ %Warn
    _mBeamPro.IRCWrite %Sock :mirc.beam.pro NOTICE * :WebSock Warning: %Warn
  }
}
alias mBeamProVer {
  return 00000.0001
}