#!rsc by RouterOS
# RouterOS script: mod/ssh-keys-import
# Copyright (c) 2020-2023 Christian Hesse <mail@eworm.de>
# https://git.eworm.de/cgit/routeros-scripts/about/COPYING.md
#
# import ssh keys for public key authentication
# https://git.eworm.de/cgit/routeros-scripts/about/doc/mod/ssh-keys-import.md

:global SSHKeysImport;
:global SSHKeysImportFile;

# import single key passed as string
:set SSHKeysImport do={
  :local Key  [ :tostr $1 ];
  :local User [ :tostr $2 ];

  :global GetRandom20CharAlNum;
  :global LogPrintExit2;
  :global MkDir;
  :global WaitForFile;

  :if ([ :len $Key ] = 0 || [ :len $User ] = 0) do={
    $LogPrintExit2 warning $0 ("Missing argument(s), please pass key and user!") true;
  }

  :if ([ :len [ /user/find where name=$User ] ] = 0) do={
    $LogPrintExit2 warning $0 ("User '" . $User . "' does not exist.") true;
  }

  :local Type [ :pick $Key 0 [ :find $Key " " ] ];
  :if (!($Type = "ssh-ed25519" || $Type = "ssh-rsa")) do={
    $LogPrintExit2 warning $0 ("SSH key of type '" . $Type . "' is not supported.") true;
  }

  :if ([ $MkDir "tmpfs/ssh-keys-import" ] = false) do={
    $LogPrintExit2 warning $0 ("Creating directory 'tmpfs/ssh-keys-import' failed!") true;
  }

  :local FileName ("tmpfs/ssh-keys-import/key-" . [ $GetRandom20CharAlNum 6 ] . ".pub");
  /file/add name=$FileName contents=$Key;
  $WaitForFile $FileName;

  :do {
    /user/ssh-keys/import public-key-file=$FileName user=$User;
  } on-error={
    $LogPrintExit2 warning $0 ("Failed importing key.") true;
  }
}

# import keys from a file
:set SSHKeysImportFile do={
  :local FileName [ :tostr $1 ];
  :local User     [ :tostr $2 ];

  :global EitherOr;
  :global LogPrintExit2;
  :global ParseKeyValueStore;
  :global SSHKeysImport;

  :if ([ :len $FileName ] = 0 || [ :len $User ] = 0) do={
    $LogPrintExit2 warning $0 ("Missing argument(s), please pass file name and user!") true;
  }

  :local File [ /file/find where name=$FileName ];
  :if ([ :len $File ] = 0) do={
    $LogPrintExit2 warning $0 ("File '" . $FileName . "' does not exist.") true;
  }
  :local Keys ([ /file/get $FileName contents ] . "\n");

  :do {
    :local Continue false;
    :local Line [ :pick $Keys 0 [ :find $Keys "\n" ] ];
    :set Keys [ :pick $Keys ([ :find $Keys "\n" ] + 1) [ :len $Keys ] ];
    :local Type [ :pick $Line 0 [ :find $Line " " ] ];
    :if ($Type = "ssh-ed25519" || $Type = "ssh-rsa") do={
      $SSHKeysImport $Line $User;
      :set Continue true;
    }
    :if ($Continue = false && $Type = "#") do={
      :set User [ $EitherOr ([ $ParseKeyValueStore [ :pick $Line 2 [ :len $Line ] ] ]->"user") $User ];
      :set Continue true;
    }
    :if ($Continue = false && [ :len $Type ] > 0) do={
      $LogPrintExit2 warning $0 ("SSH key of type '" . $Type . "' is not supported.") false;
    }
  } while=([ :len $Keys ] > 0);
}
