xquery version "3.0";

module namespace _= "custom/shop/connect";

import module namespace shop = "custom/shop/config" at "config.xqm";

import module namespace HTTPWrapper = 'de.axxepta.syncrovet.http.HTTPWrapper' at '../../java/HTTPWrapper.xqm';

declare function _:get($path) {
  HTTPWrapper:get(shop:publisher-protocol(), 'localhost', shop:publisher-port(), $path, 'admin', 'admin')
};