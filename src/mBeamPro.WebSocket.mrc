;; $_mBeamPro.WebSock(name, channelname, authtoken)
;;   Attempts to open a websocket connection for the specified channel's chat
;;
;;  websockname - (required)
;;    The name to use for the websock
;;
;;  channelname - (required)
;;    The channel name of the chat to connect to
;;
;;  authtoken - (required)
;;    The user's authtoken
alias -l _mBeamPro.WebSock {
  if (!$isid) {
    return
  }
  var %Error, %JSON, %ChanId, %EndPoints, %AuthKey
  tokenize 32 $1-
  
  ;; Validate inputs
  if ($0 !== 3) {
    %Error = INTERNAL_ERROR Invalid parameters: $1-
  }
  elseif ($WebSock($1)) {
    %Error = INTERNAL_ERROR WebSock name in use: $1
  }
  else {
  
    ;; Attempt to get the channel's id from channel name
    %JSON = mBeamProGetChannelId
    JSONOpen -u %JSON https://beam.pro/api/v1/channels/ $+ $_mBeamPro.URLEncode($2)
    
    if ($JSONError) {
      %Error = LOOKUP_ERROR Channel doesn't exist
    }
    elseif (!$len($JSON(%JSON, id))) {
      %Error = LOOKUP_ERROR No channel id was returned for the specified channel
    }
    else {

      ;; store channel id
      %ChanId = $JSON(%JSON, id)
      JSONClose %JSON

      ;; attempt to get endpoints and authkey
      %JSON = mBeamProGetChatAuth
      JSONOpen -uw %JSON https://beam.pro/api/v1/chat/ $+ %ChanId
      JSONUrlHeader %JSON Authorization Bearer $3
      JSONGet %JSON
        
      if ($JSONError) {
        %Error = JSON_ERROR Unable to retrieve endpoint/authkey for $2
      }
      else {
      
        ;; Validate endpoints and authkey
        %EndPoints = $JSON(%JSON, endpoints, length)
        %AuthKey = $JSON(%JSON, authkey)
        if (!%EndPoints) {
          %Error = JSON_ERROR No endpoints were returned
        }
        elseif (!%AuthKey) {
          %Error = JSON_ERROR A chat authorization key was not returned
        }
        else {

          ;; Open the websock, store the chat authkey, close the json
          ;; handler and return to indicate success
          WebSockOpen $1 $JSON(%JSON, endpoints, $r(0, %EndPoints))
          JSONClose %JSON
          return S_OK %ChanId %AuthKey
        }
      }
    }
  }
  
  ;; Handle errors
  :error
  JSONClose %JSON
  if ($error || %Error) {
    %Error = $v1
    reseterror
    _mBeamPro.Debug -e $!_mBeamPro.WebSocket~ $+ $v1
    return %Error
  }
}

on $*:SIGNAL:/^WebSocket_READY_mBeamPro_\d+_#\S+$/:{
  var %Error, %Ws, %Cid, %Sock, %chan, %ChanId, %UserId, %AuthKey

  %Ws = $WebSock
  %Cid = $gettok($signal, 4, 95)
  %Sock = mBeamPro_ $+ %Cid $+ _ClientAuthed
  %Chan = $gettok($signal, 5-, 95)
  
  %ChanId = $hget(%Sock, CHATWS_ChanId_ $+ %Chan)
  %UserId = $hget(%Sock, BeamPro_UserId)
  %AuthKey = $hget(%Sock, CHATWS_AuthKey_ $+ %Chan)
  
  if (!$scid(%Cid).cid) {
    ;; cleanup all connections
  }
  elseif (!$sock(%Sock)) {
    ;; cleanup all client connections
  }
  elseif (!$len(%UserId)) {
    ;; state lost
  }
  elseif (!$len(%ChanId)) {
    ;; state lost
  }
  elseif (!$len(%AuthKey)) {
    ;; State lost
  }
  else {
    noop $_mBeamPro.WebSockSend(%Ws, 1, auth, %ChanId, %UserId, %AuthKey)
  }
  
  :error
  if ($error || %Error) {
    %Error = $v1
    ;; ----------------
  }
}

on $*:SIGNAL:/^WebSocket_DATA_mBeamPro_\d+_#\S+$/:{
  var %Error, %Ws, %Cid, %Sock, %chan, %UserName, %UserId, %OAuth, %ChanId, %JSON

  %Ws = $WebSock
  %Cid = $gettok($signal, 4, 95)
  %Sock = mBeamPro_ $+ %Cid $+ _ClientAuthed
  %Chan = $gettok($signal, 5-, 95)

  %UserName = $hget(%Sock, BeamPro_UserName)
  %UserId = $hget(%Sock, BeamPro_UserId)
  %OAuth = $hget(%Sock, BeamPro_AuthToken)
  %ChanId   = $hget(%Sock, CHATWS_ChanId_ $+ %Chan)
  
  %UserHost = $+(%UserName, !u, %UserId, @, %UserName, .user.beam.pro)

  %JSON = mBeamPro_DataFrameJSON
  
  if (!$scid(%Cid).cid) {
    ;; cleanup all connections
  }
  elseif (!$sock(%Sock)) {
    ;; cleanup all client connections
  }
  elseif (!$len(%UserId)) {
    ;; state lost
  }
  elseif (!$len(%ChanId)) {
    ;; state lost
  }
  elseif (!$len(%AuthKey)) {
    ;; State lost
  }
  elseif ($WebSockFrame(TypeType) == TEXT) {
    bunset &_mBeamPro_DataFrameJSON
    noop $WebSockFrame(&_mBeamPro_DataFrameJSON)
    JSONOpen -b %JSON &_mBeamPro_DataFrameJSON
    
    if ($JSONError) {
      ;; handle error
    }
    elseif ($JSON(%JSON, type) == reply) {

      ;; Auth reply recieved
      if ($JSON(%JSON, id) == 1) {

        ;; send JOIN event for the user
        _mBeamPro.IRCWrite $+(:, %UserHost) JOIN %Chan
      
        ;; Get stream status, title, etc
        ;; start building user list
        
        
        ;; get follower list
        
      }
      
      ;; Other reply; maybe track?
      else {
        
      }
    }
    elseif ($JSON(%JSON, type) == event) {
      %event = $v1
      if (%Event == UserJoin) {
      
      }
      elseif (%Event == UserLeave) {
      
      }
      elseif (%Event == ChatMessage) {
      
      }
      elseif (%Event == PollStart) {
      
      }
      elseif (%Event == PollEnd) {
      
      }
      
      ;; unknown event
      else {
      
      }
    }
    elseif ($JSON(%JSON, type) == ) {
    }



  }
  ;; Bad frame; should just be TEXT
  else {
  
  }
  
  
  
  :error
  JSONClose %JSON
  if ($error || %Error) {
    %Error = $v1
    ;; ----------------
  }
}