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