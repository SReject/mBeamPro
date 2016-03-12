;; /mBeamPro -m auth_token [port]
;;   Creates an IRC connection listener on the specified port then
;;   to have mIRC's native IRC connection handling connect to the listener
;;
;;   -m: Creates a new server window
;;
;;   auth_token - (required)
;;     The authtoken generated from https://sreject.github.io/mBeamPro/auth
;;
;;   port - (optional)
;;     The port the listener should use if a new listener is required. If
;;     there is already an IRC listener for the current status window it
;;     will be used instead of creating a new socket listener. If the port
;;     is not specified, a random port will attempt to be choosen
alias mBeamPro {
  if ($isid) {
    return
  }
  var %Switches, %Error, %Port, %Username, %UserId, %Sock

  ;; Output debug message
  _mBeamPro.Debug Calling~/mBeamPro $1-

  ;; Seperate switches from parameters
  if (-* iswm $1) {
    %Switches = $mid($1, 2-)
    tokenize 32 $2-
  }

  ;; Validate switches
  if ($regex(%Switches, /([^m])/)) {
    %Error = Unknown switch specified: $regml(1)
  }
  elseif ($regex(%Switches, /([m]).*?\1/)) {
    %Error = Duplicate switch specified: $regml(1)
  }

  ;; Validate parameters
  elseif ($0 < 1) {
    %Error = Missing parameters.
  }
  elseif ($0 > 2) {
    %Error = Excessive parameters
  }
  else {

    ;; If we need to create a new listener, resolve a port to use
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

    ;; Attempt to validate the OAuth token
    JSONOpen -uw mBeamPro_Auth https://beam.pro/api/v1/users/current
    JSONUrlHeader mBeamPro_Auth Authorization Bearer $1
    JSONGet mBeamPro_Auth

    if ($JSONError) {
      %Error = Unable to validate OAuth Token due to a JSON error: $v1
    }
    else {

      ;; retrieve username and user id from json data
      %Username = $JSON(mBeamPro_Auth, username)
      %UserId   = $JSON(mBeamPro_Auth, id)
      if (!$len(%Username) || %Userid !isnum) {
        %Error = Unable to retrieve Username and UserID for oauth token(incorrect?)
      }
      else {

        ;; if m isin switches, create a new status window
        if (m isincs %Switches) {
          server -n
          scid $activecid
        }

        %Sock = $+(mBeamPro_, $cid, _IRCListen)

        ;; Create listener socket if need be
        if (!$Sock(%Sock)) {
          socklisten -p 127.0.0.1 %Sock %Port
          _mBeamPro.Debug -s IRC~Now listening for local connections on port $2.
        }

        ;; Update the socket's mark, output debug message and attempt to connect to the listening socket
        sockmark %Sock $1 %Username %UserId
        _mBeamPro.Debug -i IRC~Attempting to connect to localhost: $+ $sock(%Sock).port as %Username
        server localhost: $+ $sock(%Sock).port $1 -i %Username %Username _ %Userid
      }
    }
    JSONClose mBeamPro_Auth
  }

  ;; Handle errors
  :error
  if ($error || %Error) {
    %Error = $v1
    reseterror
    _mBeamPro.Debug -e /mBeamPro~ $+ %Error
    echo $color(info) -s * /mBeamPro: %Error
    halt
  }
}

;; $_mBeamPro.RandPort([attempts])
;;   Attempts to find a random free-to-use port and returns it
;;
;;   attempts - (optional)
;;     if specified, the script will try n times to find a free port;
;;     otherwise it will default to 10 attempts
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

;; /_mBeamPro.Cleanup [-aAc cid]|sockname
;;   Frees all resources for an mBeamPro connection
;;
;;   -a: Cleans up all connections for the specified cid
;;   -A: Cleans up all authed connections for the specified cid
;;   -c: Cleans up all client connections for the specified cid
;;
;;   cid - (required*)
;;     The connection id($cid) to cleanup for. required if switches are
;;     used.
;;
;;   sockname
;;     The sockname to cleanup after if no switches have been specified
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
  
  ;; Cleanup all connections for the specified cid
  elseif (a isincs %Switches) {
    %Name = mBeamPro_ $+ $1 $+ _*
    WebSockClose -fw %name
    sockclose %Name
    hfree -w %Name
    $+(.timer, %Name) off
    
    _mBeamPro.Debug -s /mBeamPro.Cleanup~All resources freed for $1 $iif($0 > 1, $+($chr(40), $2-, $chr(41)))
  }
  
  ;; Cleanup all authed connections for the specified cid
  elseif (A isincs %Switches) {
    WebSockClose -fw mBeamPro_ $+ $1 $+ _*
    %Name = mBeamPro_ $+ $1 $+ _ClientAuthed
    sockclose %Name
    hfree -w %Name
    $+(.timer, %Name) off
    
    _mBeamPro.Debug -s /mBeamPro.Cleanup~All authorized-client resources freed for $1 $iif($0 > 1, $+($chr(40), $2-, $chr(41)))
  }
  
  ;; Cleanup all client connections for the specified cid
  elseif (c isincs %Switches) {
    WebSockClose -fw mBeamPro_ $+ $1 $+ _*
    %Name = mBeamPro_ $+ $1 $+ _Client*
    sockclose %Name
    hfree -w %Name
    $+(.timer, %Name) off
    
    _mBeamPro.Debug -s /mBeamPro.Cleanup~All client resources freed for $1 $iif($0 > 1, $+($chr(40), $2-, $chr(41)))
  }
  
  ;; cleanup the specified connection
  else {
    sockclose $1
    hfree -w $1
    $+(.timer, %Name, _?*) off
    
    _mBeamPro.Debug -s /mBeamPro.Cleanup~All resources freed for $1 $iif($0 > 1, $+($chr(40), $2-, $chr(41)))
  }
  
  ;; Handle Errors
  :error
  if ($error || %Error) {
    %Error = $v1
    _mBeamPro.Debug -e /mBeamPro.Cleanup~ $+ %Error
    echo $color(info) -sge * /_mBeamPro.Cleanup: %Error
  }
}
