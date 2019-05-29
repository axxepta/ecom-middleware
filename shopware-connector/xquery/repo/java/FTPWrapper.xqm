module namespace FTPWrapper = 'de.axxepta.syncrovet.ftp.FTPWrapper';

declare function FTPWrapper:download($user, $pwd, $host, $ftp-path, $file)
{
  'download'
};

declare function FTPWrapper:upload($user, $pwd, $host, $filename, $source)
{
  'upload'
};

declare function FTPWrapper:dir($user, $pwd, $host, $adjustedPath)
{
  'dir'
};