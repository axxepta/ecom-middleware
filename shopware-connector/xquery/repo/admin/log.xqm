module namespace _= "admin/log";

declare namespace xqerl = "http://xqerl.org/xquery";

declare %private function _:LOG()
{
  let $now   := fn:current-date()
  let $year  := fn:year-from-date($now)  => format-number('0000')
  let $month := fn:month-from-date($now) => format-number('00')
  let $day   := fn:day-from-date($now)   => format-number('00')
  return
    ``[`{$year}`-`{$month}`-`{$day}`-shop.log]``
  
};

declare 
  %xqerl:non-deterministic
function _:write-log($values as xs:string+) as empty-sequence()
{
  (# basex:non-deterministic #){
    file:append-text-lines(_:LOG(), $values)
  }
};

declare 
  %xqerl:non-deterministic
function _:write-log($values as xs:string+, $level) as empty-sequence()
{
  (# basex:non-deterministic #){
    file:append-text-lines(_:LOG(), $values ! ($level || ': ' || .) )
  }
};
