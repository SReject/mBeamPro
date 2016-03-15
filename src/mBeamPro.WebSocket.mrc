;; $_mBeamPro.WebSock(cid, channelname, authtoken)
;;   Attempts to open a websocket connection for the specified channel's chat
;;
;;  cid - (required)
;;    connection id
;;
;;  channelname - (required)
;;    The channel name of the chat to connect to
;;
;;  authtoken - (required)
;;    The user's authtoken
alias -l _mBeamPro.JoinChat {
  if (!$isid) {
    return
  }
  var %Error, %Sock, %Name, %JSON, %ChanId, %AuthKey, %EndPoints, %EndPoint
  tokenize 32 $1 $iif(#?* iswm $2, $2, #$2) $3-

  %Sock = mBeamPro_ $+ $1 $+ _ClientAuthed
  %Name = mBeamPro_ $+ $1 $+ _Chat $+ $2

  ;; Validate inputs
  if ($0 !== 3) {
    %Error = INTERNAL_ERROR Invalid parameters: $1-
  }

  ;; Validate states
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

    ;; Attempt to get the channel's id from channel name
    %JSON = mBeamProGetChannelId
    JSONOpen -u %JSON https://beam.pro/api/v1/channels/ $+ $_mBeamPro.URLEncode($mid($2, 2))

    if ($JSONError) {
      %Error = LOOKUP_ERROR Channel doesn't exist
    }
    elseif (!$len($JSON(%JSON, id))) {
      %Error = LOOKUP_ERROR No channel id was returned for the specified channel
    }
    else {

      ;; Store channel id
      %ChanId = $JSON(%JSON, id)
      JSONClose %JSON

      ;; Attempt to get endpoints and authkey
      %JSON = mBeamProGetChatAuth
      JSONOpen -uw %JSON https://beam.pro/api/v1/chats/ $+ %ChanId
      JSONUrlHeader %JSON Authorization Bearer $3
      JSONGet %JSON

      if ($JSONError) {
        %Error = JSON_ERROR Unable to retrieve endpoint/authkey for $2
      }
      else {

        ;; Validate authkey and endpoints
        %AuthKey = $JSON(%JSON, authkey)
        %EndPoints = $JSON(%JSON, endpoints, length)
        if (!%EndPoints) {
          %Error = JSON_ERROR No endpoints were returned
        }
        elseif (!%AuthKey) {
          %Error = JSON_ERROR A chat authorization key was not returned
        }
        else {

          ;; Get end point
          %EndPoint = $JSON(%JSON, endpoints, $r(0, $calc(%EndPoints -1)))
          JSONClose %JSON

          ;; Open Websock
          WebSockOpen %Name %EndPoint

          ;; Store required info
          hadd %Name BeamPro_ChanName $mid($2, 2)
          hadd %Name BeamPro_ChanId   %ChanId
          hadd %Name BeamPro_UserName $hget(%Sock, BeamPro_UserName)
          hadd %Name BeamPro_UserId   $hget(%Sock, BeamPro_UserId)
          hadd %Name BeamPro_AuthKey  %AuthKey
          hadd %Name BeamPro_OAuth    $3
        }
      }
    }
  }

  ;; Handle errors
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
  var %Id = 0, %Ws = $1, %Sock, %Chan, %Id, %Index, %Args

  %Sock = mBeamPro_ $+ $gettok(%WS, 2, 95) $+ _ClientAuthed
  %Chan = $hget(%Ws, BeamPro_ChanName)

  ;; If a callback alias has been specified as the prop, get the next id
  ;; to use then store the id and callback alias
  if ($prop) {
    %Id = $calc($iif($hget(%ws, BeamPro_CallBackId), $v1, 0) +1)
    hadd %Ws BeamPro_CallBackId %id
    hadd %Ws BeamPro_Callback $+ %id $prop
  }

  ;; Format the message arguments to be valid json
  %Index = 4
  while (%Index <= $0) {
    %args = $addtok(%Args, $_mBeamPro.JSONEncode($($+($,%Index), 2)), 44)
    inc %Index
  }

  ;; fill the rest of the message parameters and write it to the websocket
  WebSockWrite %Ws {"type":"method","method": $+ $qt($2) $+ "id": $+ $_mBeamPro.JSONEncode(%id),"arguments":[ $+ %args $+ ]}
}

;; $_mBeamPro.JSONEncode(input)
;;   Converts the input to valid json
;;
;;   input - required
;;     Data to convert
alias -l _mBeamPro.JSONEncode {
  ;; if numerical, boolean, or null, return the JSON equivulant
  if ($1 isnum)     return $1
  if ($1 == $true)  return true
  if ($1 == $false) return false
  if ($1 == null)   return null

  ;; Otherwise, escape it as though its text
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
  var %Ws, %ReplyJSON, %Cid, %Chan, %ChanId, %UserName, %UserId, %Sock

  %Ws        = $1
  %ReplyJSON = $2
  %Cid       = $gettok(%Ws, 2, 95)
  %Chan      = $hget(%Ws, BeamPro_ChanName)
  %ChanId    = $hget(%Ws, BeamPro_ChanId)
  %UserName  = $hget(%Ws, BeamPro_UserName)
  %UserId    = $hget(%Ws, BeamPro_UserId)
  %Sock      = mBeamPro_ $+ %Cid $+ _ClientAuthed

  ;; If no errors, compile and send join data
  if (!$JSON(%ReplyJSON, error)) {

    ;; :[Username]!u[userid]@[Username].user.beam.pro JOIN :[chan]
    bset -tc &mBeamPro_JoinMsg 1 $+(:, %UserName, !u, %UserId, @, %UserName, .user.beam.pro JOIN :, %Chan, $crlf)

    ;; :mirc.beam.pro 332 [Username] [chan] :[Online?] - [Title]
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

    ;; :mirc.beam.pro 324 [Username] [chan] +nt
    bset -t &mBeamPro_JoinMsg $calc($bvar(&mBeamPro_JoinMsg, 0) +1) :mirc.beam.pro 324 %UserName %Chan +nt $+ $crlf

    ;; :mirc.beam.pro 353 [Username] = [chan] :[...userlist...]
    %JSON = mBeamPro_ChatUserList
    JSONOpen -u %JSON https://beam.pro/api/v1/chats/ $+ %ChanId $+ /users
    if ($JSONError) {
      bset -t &mBeamPro_JoinMsg $calc($nvar(&mbeamPro_JoinMsg, 0) +1) :mirc.beam.pro NOTICE %Chan :Unable to get user list for %Chan
      bset -t &mBeamPro_JoinMsg $calc($bvar(&mBeamPro_JoinMsg, 0) +1) :mirc.beam.pro 353 %Username = %Chan $+(:,%UserName, !u, %UserId, @, %UserName, .user.beam.pro)
    }
    else {
      var %BaseMsg, %Names, %Index, %End, %User, %Index2, %End2, %Role, %IsStaff, %IsOwner, %IsSub, %IsMod, %IsMe

      %BaseMsg = :mirc.beam.pro 353 %UserName = %Chan :
      %End     = $JSON(%JSON, length)
      %Index   = 0
      while (%Index < %End) {

        ;; Build userhost
        %User = $JSON(%JSON, %Index, userName)
        if (%User == %UserName) {
          %IsMe = $true
        }
        %User = %User $+ !u $+ $JSON(%JSON, %Index, userId) $+ @ $+ %User $+ .user.beam.pro

        ;; Loop over userRoles
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

        ;; Append prefixes to the userhost
        if (%IsSub)   %User = % $+ %User
        if (%IsMod)   %User = @ $+ %User
        if (%IsStaff) %User = & $+ %User
        if (%IsOwner) %User = ~ $+ %User

        ;; If, by adding the user, the current NAMES line would exceed 510
        ;; bytes, append the current NAMES line to the join data and add
        ;; the user to the start of a new NAMES line
        if ($len(%BaseMsg $+ $addtok(%Names, %User, 32)) > 510) {
          bset -t &mBeamPro_JoinMsg $calc($bvar(&mBeamPro_JoinMsg, 0) +1) %BaseMsg $+ %Names $+ $crlf
          %Names = %User
        }

        ;; Otherwise, append the user to the names list
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

    ;; :mrc.beam.pro 366 [Username] [Chan] :End of /NAMES
    bset -t &mBeamPro_JoinMsg $calc($bvar(&mBeamPro_JoinMsg, 0) +1) :mirc.beam.pro 366 %UserName %Chan :End of /NAMES $+ $crlf

    ;; Send the join data to the client, cleanup and update the join-state
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
  var %Error, %Ws, %Cid, %Sock, %chan, %ChanId, %UserId, %AuthKey

  %Ws       = $WebSock
  %Cid      = $gettok(%Ws, 2, 95)
  %Chan     = $hget(%Ws, BeamPro_ChanName)
  %ChanId   = $hget(%ws, BeamPro_ChanId)
  %UserName = $hget(%Ws, BeamPro_UserName)
  %UserId   = $hget(%ws, BeamPro_UserId)
  %AuthKey  = $hget(%ws, BeamPro_AuthKey)
  %Sock     = mBeamPro_ $+ %Cid $+ _ClientAuthed

  ;; Validate IRC Connection & Sock state
  if (!$scid(%Cid).cid) {
    _mBeamPro.Cleanup -a %Cid
    _mBeamPro.Debug -w WEBSOCK READY( $+ %Cid - %Chan $+ )~IRC Connection no longer exists
  }
  elseif (!$scid(%Cid).status !== connected) {
    _mBeamPro.Cleanup -A %Cid
    _mBeamPro.Debug -w WEBSOCK READY( $+ %Cid - %Chan $+ )~IRC Connection not established
  }
  elseif (!$sock(%Sock)) {
    _mBeamPro.Cleanup -A %Cid
    _mBeamPro.Debug -w WEBSOCK READY( $+ %Cid - %Chan $+ )~IRC Connection does not exist
  }

  ;; Validate WebSock state
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
  elseif (!$len(%AuthKey)) {
    %Error = Websock state lost (Missing Chat Auth Key)
  }

  ;; Attempt to authorize with beam
  else {
    noop $_mBeamPro.WebSockSend(%Ws, auth, 1, %ChanId, %UserId, %AuthKey)._mBeamPro.OnChatAuth
  }

  ;; Handle Errors
  ;;   Reset any native errors, force close the websock, log the error
  ;;   then output the error to the IRC Client
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
  var %Ws, %Cid, %Chan, %ChanId, %UserName, %UserId, %Sock, %Host, %Error, %Warn, %UserHost, %JSON, %Id, %Event

  %Ws       = $WebSock
  %Cid      = $gettok(%Ws, 2, 95)
  %Chan     = $hget(%ws, BeamPro_ChanName)
  %ChanId   = $hget(%Ws, BeamPro_ChanId)
  %UserName = $hget(%Ws, BeamPro_UserName)
  %UserId   = $hget(%Ws, BeamPro_UserId)
  %Sock     = mBeamPro_ $+ %Cid $+ _ClientAuthed
  %Host     = $+(%UserName, !u, %UserId, @, %UserName, .user.beam.pro)

  ;; Validate IRC Connection & Sock state
  if (!$scid(%Cid).cid) {
    _mBeamPro.Cleanup -a %Cid
    _mBeamPro.Debug -w WEBSOCK READY( $+ %Cid - %Chan $+ )~IRC Connection no longer exists
  }
  elseif (!$scid(%Cid).status !== connected) {
    _mBeamPro.Cleanup -A %Cid
    _mBeamPro.Debug -w WEBSOCK READY( $+ %Cid - %Chan $+ )~IRC Connection not established
  }
  elseif (!$sock(%Sock)) {
    _mBeamPro.Cleanup -A %Cid
    _mBeamPro.Debug -w WEBSOCK READY( $+ %Cid - %Chan $+ )~IRC Connection does not exist
  }

  ;; Validate WebSock state
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
  elseif (!$len(%AuthKey)) {
    %Error = Websock state lost (Missing Chat Auth Key)
  }

  ;; Validate Frame
  elseif ($WebSockFrame(TypeText) !== TEXT) {
    %Warn = Non-text frame recieved
  }

  ;; Begin processing the frame be retreiving its data and parsing it as
  ;; JSON
  else {
    noop $WebSockFrame(&_mBeamPro_DataFrameJSON)
    %JSON = mBeamPro_DataFrameJSON
    JSONOpen -b %JSON &_mBeamPro_DataFrameJSON

    ;; Check for JSON errors
    if ($JSONError) {
      %Warn = Unable to parse frame
    }

    ;; If the frame is a reply, get the id, check if there is a callback,
    ;; delete the item then execute the callback
    elseif ($JSON(%JSON, type) == reply) {
      %Id = $JSON(%JSON, id)
      if ($hget(%Ws, BeamPro_CallBack $+ %Id)) {
        hdel %Sock BeamPro_CallBack $+ %Id
        $v1 %Ws %JSON
      }
    }

    ;; If the frame is an event
    elseif ($JSON(%JSON, type) == event) {
      var %_UserName, %_UserHost, %_Index = 0, %_End

      ;; Get event name and build the userhost string for the user
      %Event     = $JSON(%JSON, event)

      ;; USER JOIN
      ;;    Build userhost string, output join msg to IRC Client, loop
      ;;    over roles to build a mode string, then output mode msg to the
      ;;    IRC Client
      if (%Event == UserJoin) {
        var %_Role, %_Modes

        ;; Build userhost string and output join message to IRC client
        %_UserName = $JSON(%JSON, username)
        %_UserHost = $+(%_UserName, !u, $JSON(%JSON, id), @, %_UserName, .user.beam.pro)
        _mBeamPro.IRCWrite %Sock : $+ %_UserHost JOIN : $+ %Chan

        ;; Loop over the user roles, and build a list of modes to apply to
        ;; the user, then send the a mode message to the IRC Client
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

      ;; USER LEAVE
      ;;   Build userhost string and output part message to IRC Client
      elseif (%Event == UserLeave) {
        %_UserName = $JSON(%JSON, username)
        %_UserHost = $+(%_UserName, !u, $JSON(%JSON, id), @, %_UserName, .user.beam.pro)
        _mBeamPro.IRCWrite %Sock : $+ %_UserHost PART %Chan :leaving
      }

      ;; CHAT MESSAGE
      ;;   Build userhost string, piece the message together, trim
      ;;   whitespace, deduce the message type then output to the IRC
      ;;   client
      elseif (%Event == ChatMessage) {
        var %_Msg, %_isAction, %_isWhisper

        ;; Build userhost string
        %_UserName = $JSON(%JSON, data, user_name)
        %_UserHost = $+(%_UserName, !u, $JSON(%JSON, data, user_id), @, %_UserName, .user.beam.pro)

        ;; Determine if the message is an action or whisper
        %_IsAction  = $JSON(%JSON, data, message, meta, me)
        %_IsWhisper = $JSON(%JSON, data, message, meta, whisper)

        ;; Loop over each message fragement and build a full text-based message
        %_Index = 0
        %_End = $JSON(%JSON, data, message, message, length)
        while (%_Index < %_End) {
          if ($JSON(%JSON, data, message, message, %_Index, type) == text) {
            %_Msg = %_Msg $+ $JSON(%JSON, data, message, message, %_Index, data)
          }
          elseif ($v1 == emoticon) {
            %_Msg = %_Msg $+ $JSON(%JSON, data, message, message, %_Index, text)
          }
          inc %_Index
        }

        ;; replace $cr and $lf with spaces, then trim leading, duplicate and trailing spaces
        %_Msg = $regsubex($replace(%_Msg, $cr, $chr(32), $lf, $chr(32)), /(?:^\x20*$)|(?:\x20(?=\x20))/g, )

        ;; if the message isn't empty, send the compiled message to the IRC Client
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

      ;; Unknown event
      else {
        scid %Cid
        echo -s >> Unknown even frame
        echo -s >> $WebSockFrame
      }
    }
  }

  ;; Handle Errors
  ;;   Reset any native errors, force close the websock, log the error
  ;;   then output the error to the IRC Client
  :error
  JSONClose %JSON
  if ($error || %Error) {
    %Error = $v1
    reseterror
    _mBeamPro.Debug -e WEBSOCK READY( $+ %Cid - %Chan $+ )~ $+ %Error

    WebSockClose -f %Ws
    _mBeamPro.IRCWrite %Sock :mirc.beam.pro NOTICE * :WebSock failure: %Error
  }
}