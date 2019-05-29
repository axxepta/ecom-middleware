module namespace HTTPWrapper = 'de.axxepta.syncrovet.http.HTTPWrapper';

declare function HTTPWrapper:delete
  ($protocol, $host, $port, $path, $user, $pwd)
{
  'delete'
};

declare function HTTPWrapper:delete
  ($protocol, $host, $port, $path, $user, $pwd, $json)
{
  'delete'
};

declare function HTTPWrapper:putJSON
  ($protocol, $host, $port, $path, $user, $pwd, $json)
{
  'putJSON'
};

declare function HTTPWrapper:postJSON
  ($protocol, $host, $port, $path, $user, $pwd, $json)
{
  map{'fun': 'postJSON'}
};

declare function HTTPWrapper:get($protocol, $host, $port, $path, $user, $pwd) as item()
{
  map {
    'data': [],
    'total' : 1,
    'success' : fn:true()
  }
};

declare function HTTPWrapper:getXmlFromJSON($protocol, $host, $port, $path, $user, $pwd)
{
  <getXmlFromJSON/>
};