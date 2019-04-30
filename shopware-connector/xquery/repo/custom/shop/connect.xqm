xquery version "3.0";

module namespace _= "custom/shop/connect";

import module namespace shop = "custom/shop/config";

import module namespace HTTPWrapper = 'de.axxepta.syncrovet.http.HTTPWrapper';

declare function _:get($path) {
    parse-xml(HTTPWrapper:get(shop:publisher-protocol(), 'localhost', shop:publisher-port(), $path, 'admin', 'admin'))
};