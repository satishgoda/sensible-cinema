@rem NB that you can call it like go --debug, except you can't since there's no gems in a jruby-complete jar...
@rem call java -jar vendor\jruby-complete.jar %* bin\sensible-cinema  --online-player-mode --go
call j --debug  %* bin\sensible-cinema  --online-player-mode --advanced
