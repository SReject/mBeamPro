on $*:SOCKREAD:/^mBeamPro_\d+_ClientLogon\d+$/:{

  var %Cid, %Error, %Data, %AuthToken, %UserName, %UserId, %UserHost, %GotPass, %GotNick, %GotUser, %InCap, %Sock

  %Cid = $gettok($sockname, 2, 95)
  tokenize 32 $sock($sockname).mark

  ;; Check for state errors
  if (!$scid(%Cid).cid) {
    _mBeamPro.Cleanup -a %Cid
    %Error = STATUS_CLOSED No matching connection id for client
  }
  elseif ($0 !== 7 && $1- !== CLOSING) {
    %Error = INTERNAL_ERROR Login information lost
  }

  ;; check for socket errors
  elseif ($sockerr) {
    %Error = SOCK_ERROR $sock($sockname).wsmsg
  }

  ;; Process the incoming data
  elseif ($1- !== CLOSING) {

    %AuthToken = $1
    %Username = $2
    %UserId = $3

    %GotPass = $4
    %GotNick = $5
    %GotUser = $6

    %InCap = $7

    while ($sock($sockname).mark !== CLOSING && (!%GotPass || !%GotNick || !%GotUser || %InCap)) {

      ;; Read the next line in the buffer; if there isn't a complete line
      ;; to read exit the loop
      sockread %Data
      if (!$sockbr) {
        break
      }

      ;; Trim leading and trailing whitespace, if there's no data left,
      ;; continue at the top of the loop
      if ($regsubex(%Data, /(?:^\s+)|(?:\s+$)/g, ) == $null) {
        continue
      }

      ;; Tokenize the trimmed data and process it
      tokenize 32 $v1

      ;; Handle CAP LS request
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

      ;; Cap negociations not started, as such the client should be be
      ;; making CAP requests
      elseif ($1 == CAP && !%InCap) {
        sockwrite -n $sockname :m.beam.pro NOTICE * :Not in CAP negociations
        sockmark $sockname CLOSING
        _mBeamPro.Debug -w IRC CLIENT( $+ %Cid $+ )~Cap command specified while not in negociates
      }

      ;; If the client requests certain modules, ack the request
      elseif ($1-2 == CAP REQ) {
        sockwrite -n $sockname :m.beam.pro CAP * ACK $3-
        _mBeamPro.Debug -i IRC CLIENT( $+ %Cid $+ )~Cap ACK recieved; acknowledging: $3-
      }

      ;; End cap negociations
      elseif ($1-2 == CAP END) {
        %InCap = $false
        _mBeamPro.Debug -i IRC CLIENT( $+ %Cid $+ )~CAP negociates done( %GotPass %GotNick %GotUser )
      }

      ;; If any other CAP request is made, raise an error
      elseif ($1 == CAP) {
        sockwrite -n $sockname :m.beam.pro NOTICE * :Unknown CAP command
        sockmark $sockname CLOSING
        _mBeamPro.Debug -i IRC CLIENT( $+ %Cid $+ )~Unknown CAP command received
      }

      ;; Close the connection at the request of the client
      elseif ($1 == QUIT) {
        _mBeamPro.Debug -i IRC CLIENT( $+ %Cid $+ )~Client sent a QUIT command; closing connection
        sockclose $sockname
        return
      }

      elseif ($1 == PASS) {
        ;; If a PASS command is received more than once, this connection
        ;; is most likely not a native mIRC connection so close it
        if (%GotPass) {
           _mBeamPro.Debug -w IRC CLIENT( $+ %Cid $+ )~Client sent an auth token twice; closing connection
           sockwrite -n $sockname :m.beam.pro NOTICE * :You may not attempt to authorize multiple times
           sockmark $sockname CLOSING
        }

        ;; If the specified pass does not match the stored auth token
        ;; close the client's connection
        elseif ($2- !== %AuthToken) {
          _mBeamPro.Debug -w IRC CLIENT( $+ %Cid $+ )~Client sent an invalid auth token; closing connection
          sockwrite -n $sockname :m.beam.pro NOTICE * :Invalid auth token
          sockmark $sockname CLOSING
        }

        ;; Update status variable to indicate a valid authtoken has been
        ;; recieved
        else {
          %GotPass = $true
        }
      }

      ;; If a pass has not been recieved then the client has failed to
      ;; authorize in the correct order; Inform the client of such, output
      ;; a debug message and schedule the connection to be closed
      elseif (!%GotPass) {
        _mBeamPro.Debug -w IRC CLIENT( $+ %Cid $+ )~Client failed to send an auth token as the first command
        sockwrite -n $sockname :m.beam.pro NOTICE * :Auth token not recieved
        sockmark $sockname CLOSING
      }

      elseif ($1 == NICK) {
        ;; If a NICK command is received more than once, this connection
        ;; is most likely not a native mIRC connection so close it
        if (%GotNick) {
           _mBeamPro.Debug -w IRC CLIENT( $+ %Cid $+ )~Client sent a username twice; closing connection.
           sockwrite -n $sockname :m.beam.pro NOTICE * :You may not attempt to authorize multiple times
           sockmark $sockname CLOSING
        }

        ;; If the specified username does not match the stored username
        ;; close the connection
        elseif ($2- !== %Username) {
          _mBeamPro.Debug -w IRC CLIENT( $+ %Cid $+ )~Client sent an invalid username; closing connection.
          sockwrite -n $sockname :m.beam.pro NOTICE * :Invalid username
          sockmark $sockname CLOSING
        }

        ;; Update status variable to indicate a valid username has been
        ;; received
        else {
          %GotNick = $true
        }
      }

      ;; If a nick has not been recieved then the client has failed to
      ;; authorize in the correct order; Inform the client of such, output
      ;; a debug message and schedule the connection to be closed
      elseif (!%GotNick) {
        _mBeamPro.Debug -w IRC CLIENT( $+ %Cid $+ )~Client failed to send a username as the second command; closing connection.
        sockwrite -n $sockname :m.beam.pro NOTICE * :Username not recieved
        sockmark $sockname CLOSING
      }

      elseif ($1 == USER) {
        ;; If a USER command is received more than once, this connection
        ;; is most likely not a native mIRC connection so close it
        if (%GotUser) {
           _mBeamPro.Debug -w IRC CLIENT( $+ %Cid $+ )~Client sent a userid twice; closing connection.
           sockwrite -n $sockname :m.beam.pro NOTICE * :You may not attempt to authorize multiple times
           sockmark $sockname CLOSING
        }

        ;; If the specified userid does not match the stored userid close
        ;; the connection
        elseif (!$regex(userid, $2-, /^\S+ . . :(\d+)$/i) || $regml(userid, 1) !== %UserId) {
          _mBeamPro.Debug -w IRC CLIENT( $+ %Cid $+ )~Client sent an invalid userid; closing connection.
          sockwrite -n $sockname :m.beam.pro NOTICE * :Invalid userid
          sockmark $sockname CLOSING
        }

        ;; Update status variable to indicate a valid userid has been
        ;; received
        else {
          %GotUser = $true
        }
      }

      ;; If a userid has not been recieved then the client has failed to
      ;; authorize in the correct order; Inform the client of such, output
      ;; a debug message and schedule the connection to be closed
      elseif (!%GotUser) {
        _mBeamPro.Debug -w IRC CLIENT( $+ %Cid $+ )~Client failed to send a userid as the third command
        sockwrite -n $sockname :mirc.beam.pro NOTICE * :userid not received
        sockmark $sockname CLOSING
      }

      ;; The client sent an unknown command so is most likely not a native
      ;; mIRC connection; Inform the client of such, output a debug
      ;; message, and schedule the connection to be closed
      else {
        _mBeamPro.Debug -w IRC CLIENT( $+ %Cid $+ )~Client sent an unknown command; closing connection
        sockwrite -n $sockname :m.beam.pro NOTICE * :Unknown command recieved
        sockmark $sockname CLOSING
      }
    }

    ;; If the client is closing, stop reading from the socket
    if ($sock($sockname).mark === CLOSING) {
      sockpause $sockname
    }

    ;; If all creditentials have been given and validated
    elseif (%GotPass && %GotNick && %GotUser && !%InCap) {

      ;; Output debug message
      _mBeamPro.Debug -s IRC CLIENT( $+ %Cid $+ )~Client has successfully authorized.

      ;; Cleanup all connections spawned for an authorized client on the
      ;; current connection id
      _mBeamPro.Cleanup -A %Cid

      ;; Rename the socket connection to indicate that it is fully
      ;; authorized.
      %Sock = $+(mBeamPro_, %Cid, _ClientAuthed)
      sockrename $sockname %Sock

      ;; Store variables that will be required when interacting with
      ;; beam then clear the sock's mark
      hadd -m $sockname BeamPro_AuthToken %AuthToken
      hadd $sockname BeamPro_Username %UserName
      hadd $sockname BeamPro_Userid %UserId
      sockmark $sockname

      ;; Send initial messages indicating configuration to the client
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

    ;; if authorization details are missing, update the sockmark and
    ;; wait for the next SockRead event to trigger
    else {
      sockmark $sockname %AuthToken %UserName %UserId %GotPass %GotNick %GotUser %InCap
    }
  }

  ;; Handle errors
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

  ;; Validate socket state
  if (!$scid(%Cid).cid) {
    _mBeamPro.Cleanup -a %Cid
    %Error = STATUS_CLOSED No matching connection id for client
  }
  elseif ($1- !== CLOSING && $0 !== 7) {
    %Error = INTERNAL_ERROR Login information lost
  }

  ;; Check for socket error
  elseif ($sockerr) {
    %Error = SOCK_ERROR SockWrite error:  $sock($sockname).wsmsg
  }

  ;; Close the connection if its scheduled to be closed once all data is sent
  elseif ($1- == CLOSING && !$sock($sockname).sq) {
    sockclose $sockname
  }

  ;; Handle errors
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