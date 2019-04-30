xquery version "3.1";

module namespace _= "custom/shop/shop-common";

import module namespace Shopware = 'de.axxepta.syncrovet.api.Shopware';
import module namespace FTPWrapper = 'de.axxepta.syncrovet.ftp.FTPWrapper';
import module namespace HTTPWrapper = 'de.axxepta.syncrovet.http.HTTPWrapper';
import module namespace EMail = 'de.axxepta.syncrovet.email.Mail';

import module namespace functx = "http://www.functx.com";
import module namespace conf = "pim/config";
import module namespace shop = "custom/shop/config";

declare variable $_:PIM-PORT := $shop:PIM-PORT;

declare variable $_:CUSTOMERS-LOG-PATH := 'reports/customers.xml';
declare variable $_:CUSTOMERS-LOG := file:resolve-path($_:CUSTOMERS-LOG-PATH);
declare variable $_:CUSTOMERS-REPORT-PATH := 'reports/customers-report.html';
declare variable $_:CUSTOMERS-REPORT := file:resolve-path($_:CUSTOMERS-REPORT-PATH);
declare variable $_:STOCK-LOG := file:resolve-path('reports/stock/stock.xml');
declare variable $_:STOCK-REPORT-PATH := 'reports/stock-report.html';
declare variable $_:STOCK-REPORT := file:resolve-path($_:STOCK-REPORT-PATH);
declare variable $_:USERPRICES-LOG := file:resolve-path('reports/userprices.xml');
declare variable $_:USERPRICEGROUPS-LOG := file:resolve-path('reports/userpricegroups.xml');
declare variable $_:USERPRICES-REPORT := file:resolve-path('reports/userprices-report.html');
declare variable $_:ARTICLES-LOG-PATH := 'reports/articles.xml';
declare variable $_:ARTICLES-LOG := file:resolve-path($_:ARTICLES-LOG-PATH);
declare variable $_:ARTICLES-REPORT-PATH := 'reports/articles-report.html';
declare variable $_:ARTICLES-REPORT := file:resolve-path($_:ARTICLES-REPORT-PATH);
declare variable $_:WEBSHOP-LOG-PATH := 'reports/webshop.xml';
declare variable $_:WEBSHOP-LOG := file:resolve-path($_:WEBSHOP-LOG-PATH);
declare variable $_:ORDERS-LOG := file:resolve-path('reports/orders.xml');
declare variable $_:ORDERS-REPORT-PATH := 'reports/orders-report.html';
declare variable $_:ORDERS-REPORT := file:resolve-path($_:ORDERS-REPORT-PATH);

declare variable $_:ERP := 'process-publisher/shop/';
declare variable $_:ERP-PATH := file:resolve-path($_:ERP);

declare variable $_:ERP-TEST := 'process-publisher/shoptest/';
declare variable $_:ERP-TEST-PATH := file:resolve-path($_:ERP-TEST);

declare variable $_:ERP-XSL := $_:ERP || 'xsl/';
declare variable $_:ERP-XSL-PATH := file:resolve-path($_:ERP-XSL);

declare variable $_:ERP-DB := 'Customer.ERP';
declare variable $_:ERP-DB-FILE := 'ERP_DATA.xml';
declare variable $_:ERP-PRICE-DB := 'Prices.ERP';
declare variable $_:ERP-PRICE-DB-FILE := 'Prices.xml';
declare variable $_:ERP-USERPRICE-DB := 'UserPrices.ERP';
declare variable $_:ERP-USERPRICE-DB-FILE := 'UserPrices.xml';
declare variable $_:ERP-STORE-DB := 'Store.ERP';
declare variable $_:ERP-STORE-DB-FILE := 'Store.xml';
declare variable $_:ERP-ORDERS-DB := 'Orders.ERP';
declare variable $_:ERP-ORDERS-DB-FILE := 'Orders.xml';
declare variable $_:ERP-TRACKING-DB-FILE := 'Tracking.xml';
declare variable $_:ERP-INDEX-DB := 'Index.ERP';
declare variable $_:ERP-INDEX-DB-FILE := 'Index.xml';

declare variable $_:FILE-DUPLICATES := 'erp-orders-pipe/Doubletten.log';

declare variable $_:ERP-ADDRESSES-LOG-PATH := 'reports/erp_addresses.xml';
declare variable $_:ERP-ADDRESSES-LOG := file:resolve-path($_:ERP-ADDRESSES-LOG-PATH);
declare variable $_:ERP-PRICES-LOG-PATH := 'reports/erp_prices.xml';
declare variable $_:ERP-PRICES-LOG := file:resolve-path($_:ERP-PRICES-LOG-PATH);
declare variable $_:ERP-INDEX-LOG-PATH := 'reports/erp_index.xml';
declare variable $_:ERP-INDEX-LOG := file:resolve-path($_:ERP-INDEX-LOG-PATH);
declare variable $_:ERP-STORAGE-LOG-PATH := 'reports/erp_storage.xml';
declare variable $_:ERP-STORAGE-LOG := file:resolve-path($_:ERP-STORAGE-LOG-PATH);
declare variable $_:ERP-USERPRICES-LOG-PATH := 'reports/erp_userprices.xml';
declare variable $_:ERP-USERPRICES-LOG := file:resolve-path($_:ERP-USERPRICES-LOG-PATH);
declare variable $_:ERP-ORDERS-LOG-PATH := 'reports/erp_orders.xml';
declare variable $_:ERP-ORDERS-LOG := file:resolve-path($_:ERP-ORDERS-LOG-PATH);
declare variable $_:ERP-TRACKING-LOG-PATH := 'reports/erp_tracking.xml';
declare variable $_:ERP-TRACKING-LOG := file:resolve-path($_:ERP-TRACKING-LOG-PATH);


declare function _:ftp-get($user as xs:string, $pwd as xs:string, $host as xs:string, $ftp-path as xs:string, $file as xs:string) as item() {
    FTPWrapper:download($user, $pwd, $host, $ftp-path, $file)
};

declare
  %rest:GET
  %rest:path("/erp/ftp-up/{$file}")
function _:ftp-up($file as xs:string) as item() {
    (FTPWrapper:upload($shop:FTP-USER, $shop:FTP-PWD, $shop:FTP-HOST, '/var/shop/' || $file, $_:ERP-PATH || $file),
    admin:write-log('Uploading ' || $file || ' per FTP') )
};

declare
  %rest:GET
  %rest:path("/erp/ftp-up/{$path}/{$file}")
function _:ftp-relative-up($path as xs:string, $file as xs:string) as item() {
    (FTPWrapper:upload($shop:FTP-USER, $shop:FTP-PWD, $shop:FTP-HOST, '/var/shop/' || $file, $_:ERP-PATH || $path || "/" || $file),
    admin:write-log('Uploading ' || $file || ' per FTP') )
};

declare
  %rest:GET
  %rest:path("/erp/ftp-test-up/{$path}/{$file}")
function _:ftp-test-relative-up($path as xs:string, $file as xs:string) as item() {
    (FTPWrapper:upload($shop:FTP-TEST-USER, $shop:FTP-TEST-PWD, $shop:FTP-HOST, '/var/shop/' || $file, $_:ERP-TEST-PATH || $path || "/" || $file),
    admin:write-log('Uploading ' || $file || ' per FTP') )
};


declare function _:FTP-list($user as xs:string, $pwd as xs:string, $host as xs:string, $ftp-path as xs:string) as item() {
   (: FTPWrapper:list($user, $pwd, $host, shop:FTP-port(), $ftp-path, $shop:FTP-PROXY-HOST, shop:FTP-proxy-port()) :) 
    
    let $adjustedPath := if (ends-with($ftp-path, '/')) then (
        substring($ftp-path, 1, string-length($ftp-path) - 1)
    ) else ($ftp-path)
    let $response := FTPWrapper:dir($user, $pwd, $host, $adjustedPath)
    return <ftp path="{$ftp-path}">{
        let $lines := tokenize($response, '\r?\n')
        return $lines ! <file>{(tokenize(., '/'))[2]}</file>
    }</ftp>
};

declare function _:send-mail($recipient as xs:string, $subject as xs:string, $msg as xs:string) {
    EMail:sendMail($shop:MAIL-SSLTLS, $shop:MAIL-HOST, xs:int($shop:MAIL-PORT), $shop:MAIL-USER,
            $shop:MAIL-PWD, $shop:MAIL, $recipient, $subject, $msg)
};

declare function _:send-html-mail($recipient as xs:string, $subject as xs:string, $msg as xs:string, $msgText as xs:string) {
    EMail:sendHTMLMail($shop:MAIL-SSLTLS, $shop:MAIL-HOST, xs:int($shop:MAIL-PORT), $shop:MAIL-USER,
            $shop:MAIL-PWD, $shop:MAIL, $recipient, $subject, $msg, $msgText)
};

declare function _:send-html-mail-with-image($recipient as xs:string, $subject as xs:string, $msg as xs:string, $msgText as xs:string) {
    EMail:sendImageHTMLMail($shop:MAIL-SSLTLS, $shop:MAIL-HOST, xs:int($shop:MAIL-PORT), $shop:MAIL-USER,
            $shop:MAIL-PWD, $shop:MAIL, $recipient, $subject, $msg, $msgText, $shop:PIM-HOST)
};

declare function _:send-hazard-mail($reportFile as xs:string) {
    let $message := <html>Siehe <a href="{$shop:PUBLISHER-HOST || ':' || $shop:PUBLISHER-PORT || $reportFile}">Report</a></html>
    let $x := (# basex:non-deterministic #) {
        _:send-html-mail($shop:HAZARD-MESSAGE-RECIPIENTS, 'Fehler im Shopimport', serialize($message), $reportFile) }
    return ()
};

declare function _:post-request($protocol as xs:string, $host as xs:string, $port as xs:int, $path as xs:string, $content as xs:string) {
    HTTPWrapper:postJSON($protocol, $host, $port, $path, shop:user(), shop:pwd(), json:parse($content))
};

declare function _:put-request($protocol as xs:string, $host as xs:string, $port as xs:int, $path as xs:string, $content as xs:string) {
    HTTPWrapper:putJSON($protocol, $host, $port, $path, shop:user(), shop:pwd(), json:parse($content))
};

declare function _:get-request($protocol as xs:string, $host as xs:string, $port as xs:int, $path as xs:string) as item() {
    let $result := HTTPWrapper:get($protocol, $host, $port, $path, shop:user(), shop:pwd())
    let $response := json:parse($result)
    return if($response/json/success = "false")
        then error(xs:QName("HC0001"), "Unexpected HTTP response, Status code " || $response/json/status || " " || $response/json/error)
        else $response
};

declare function _:get-xml-request($protocol as xs:string, $host as xs:string, $port as xs:int, $path as xs:string) as item() {
    HTTPWrapper:getXmlFromJSON($protocol, $host, $port, $path, shop:user(), shop:pwd())
};

declare function _:get-shopware-request($protocol as xs:string, $host as xs:string, $port as xs:int, $path as xs:string, $file as xs:string, $naming-params) as item() {
    Shopware:getShopwareXml($protocol, shop:host(), $port, $path, shop:user(), shop:pwd(), $file, $naming-params)
};

declare function _:pim-get($path) {
    parse-xml(HTTPWrapper:get(shop:pim-protocol(), 'localhost', shop:pim-port(), $path, 'admin', 'admin'))
};

declare function _:pim-get-server($path) {
    parse-xml(HTTPWrapper:get(shop:pim-protocol(), substring($shop:PIM-HOST, 8), shop:pim-port(), $path, 'admin', 'admin'))
};

declare
  %rest:GET
  %rest:path("/shop/externalDocuments/images")
function _:externalDocuments() as item() {

     _:FTP-list($shop:FTP-USER, $shop:FTP-PWD, $shop:FTP-HOST, $shop:IMAGE-PATH-DOCUMENTS)

};

declare
  %rest:GET
  %rest:path("/shop/shops")
function _:shops() as item() {
    (:_:get-request(shop:protocol(), shop:host(), shop:port(), $shop:PATH-SHOPS):)
    
    try {
        let $shops := _:get-request(shop:protocol(), shop:host(), shop:port(), $shop:PATH-SHOPS)

        return <shops>
            {for $shop in $shops//_ return <shop>
                {$shop/id,
                $shop/categoryId,
                $shop/name,
                $shop/title}
            </shop>}
        </shops>
    } catch * {
        <shops><error>error(xs:QName('err:shop-connection-failed'), 'Error [' || $err:code || ']: ' || $err:description)</error></shops>
    }
};

declare
  %rest:GET
  %rest:path("/shop/shops/json")
  %output:method("json")
  %output:json("format=direct")
function _:shops-json() as item() {
    <json objects='_' arrays='json'>
        {for $shop in _:shops()/shop
            return <_>{$shop/*}</_>}
    </json>
};

declare
  %rest:GET
  %rest:path("/shop/shops/{$id}")
function _:shop($id) as item() {
    _:get-request(shop:protocol(), shop:host(), shop:port(), $shop:PATH-SHOPS || $id)
};

declare function _:fatal-log($file as xs:string, $error as item()*) as element() {
    let $xml-file := file:write($file, <upload><dateTime>{current-dateTime()}</dateTime><fatal>{$error}</fatal></upload>)
    return <fatal>{$error}</fatal>
};

declare function _:stamped-filename($name as xs:string) as xs:string {
    let $date := format-dateTime(current-dateTime(), '_[Y0000]-[M00]-[D00]_[H00]-[m00]')
    return functx:substring-before-last($name, '.') || $date || '.' || functx:substring-after-last($name, '.')
};


declare function _:date-convert($dateString as xs:string, $fallback as xs:dateTime) as xs:dateTime {
    let $components := tokenize($dateString, ' ')
    let $dateComponents := tokenize($components[1], '\.')
    return try{
        dateTime(xs:date(string-join(($dateComponents[3], $dateComponents[2], $dateComponents[1]), '-')),
            xs:time($components[2] || '+01:00'))
    } catch * {
        $fallback
    }
};


declare function _:areaCode-by-countryId($in as xs:string) as xs:string {
    switch ($in)
    case '23' return '43' (:Austria:)
    case '5' return '32' (:Belgien:)
    (:case '' return '86' (:China:):)
    case '33' return '420' (:Tschechien:)
    case '7' return '45' (:Dänemark:)
    case '2' return '49' (:Deutschland:)
    (:case '' return '372' (:Estland:):)
    case '8' return '358' (:Finnland:)
    case '9' return '33' (:Frankreich:)
    case '10' return '30' (:Griechenland:)
    case '31' return '36' (:Ungarn:)
    case '12' return '353' (:Irland:)
    case '14' return '39' (:Italien:)
    (:case '' return '370' (:Litauen:):)
    case '18' return '352' (:Luxembourg:)
    case '21' return '31' (:Niederlande:)
    (:case '' return '92' (:Pakistan:):)
    case '30' return '48' (:Polen:)
    case '24' return '351' (:Portugal:)
    case '34' return '421' (:Slowakei:)
    (:case '' return '386' (:Slowenien:):)
    case '27' return '34' (:Spanien:)
    case '25' return '46' (:Schweden:)
    case '26' return '41' (:Schweiz:)
    case '11' return '44' (:GB:)
    case '28' return '1' (:US:)
    default return '49'
};

declare function _:country-transform($in as xs:string) {
    switch ($in)
    case '40' return '23' (:Austria:)
    case '56' return '5' (:Belgien:)
    (:case '156' return '' (:China:):)
    case '203' return '33' (:Tschechien:)
    case '208' return '7' (:Dänemark:)
    case '212' return '2' (:Deutschland:)
    (:case '233' return '' (:Estland:):)
    case '246' return '8' (:Finnland:)
    case '250' return '9' (:Frankreich:)
    case '276' return '2' (:Deutschland:)
    case '300' return '10' (:Griechenland:)
    case '348' return '31' (:Ungarn:)
    case '372' return '12' (:Irland:)
    case '380' return '14' (:Italien:)
    (:case '440' return '' (:Litauen:):)
    case '442' return '18' (:Luxembourg:)
    case '528' return '21' (:Niederlande:)
    (:case '586' return '' (:Pakistan:):)
    case '616' return '30' (:Polen:)
    case '620' return '24' (:Portugal:)
    case '703' return '34' (:Slowakei:)
    (:case '705' return '' (:Slowenien:):)
    case '724' return '27' (:Spanien:)
    case '752' return '25' (:Schweden:)
    case '756' return '26' (:Schweiz:)
    case '826' return '11' (:GB:)
    case '840' return '28' (:US:)
    case '1000' return '11' (:GB:)
    default return 2
(:    let $countries :=  map{
    '40' : '23',
    '56' : '5',
    '156' : '2',
    '203' : '33',
    '208' : '7',
    '212' : '2',
    '233' : '2',
    '246' : '8',
    '250' : '9',
    '276' : '2',
    '300' : '10',
    '348' : '31',
    '372' : '12',
    '380' : '14',
    '440' : '2',
    '442' : '18',
    '528' : '21',
    '586' : '2',
    '616' : '30',
    '620' : '24',
    '703' : '34',
    '705' : '2',
    '724' : '27',
    '752' : '25',
    '756' : '26',
    '826' : '11',
    '840' : '28',
    '1000' : '11'
    }
    return map:get($countries, $in) :)
};