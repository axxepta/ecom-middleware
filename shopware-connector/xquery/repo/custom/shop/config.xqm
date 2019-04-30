xquery version "3.0";

module namespace _= "custom/shop/config";

declare variable $_:PIM-PORT := 8984;
declare variable $_:PIM-PROTOCOL := 'http';
declare variable $_:PUBLISHER-PORT := 9894;
declare variable $_:PUBLISHER-PROTOCOL := 'http';
declare variable $_:PUBLISHER-HOST := "localhost";

declare variable $_:METHOD-GET := 'GET';
declare variable $_:METHOD-PUT := 'PUT';
declare variable $_:METHOD-POST := 'POST';

declare variable $_:KEY := 'shopaccesskey';
declare variable $_:USER := 'user';

declare variable $_:FTP-USER := 'user';
declare variable $_:FTP-PWD := 'pwd';

declare variable $_:FTP-TEST-USER := 'testuser';
declare variable $_:FTP-TEST-PWD := 'pwd';

declare variable $_:HOST := 'shopwarehost.de';
declare variable $_:PROTOCOL := 'https';
declare variable $_:PORT := 443;

declare variable $_:MAIL := "data-alerts@shopwarehost.de";
declare variable $_:MAIL-HOST := "localhost";
declare variable $_:MAIL-PORT := 587;
declare variable $_:MAIL-SSLTLS := false();
declare variable $_:MAIL-USER := "data-alerts";
declare variable $_:MAIL-PWD := "pwd";
declare variable $_:PIM-HOST := "localhost";

declare variable $_:HAZARD-MESSAGE-RECIPIENTS := "wittenberg@axxepta.de;gaerber@axxepta.de";

declare variable $_:PHP-PATH-DOCUMENTS := '/shop/files/externalDocuments/images/';
declare variable $_:PDF-PATH-DOCUMENTS := '/shop/files/externalDocuments/pdf/';

declare variable $_:IMAGE-PATH-DOCUMENTS := '/files/externalDocuments/images/';

declare variable $_:FTP-HOST :=  'localhost';
declare variable $_:FTP-PORT := 21;
declare variable $_:FTP-PROXY-HOST := '';
declare variable $_:FTP-PROXY-PORT := 0;

declare variable $_:FTP-PATH-BILLS := '/var/erp/rechnungen/';
declare variable $_:FTP-PATH-DOCUMENTS := '/files/documents/';
declare variable $_:FTP-PATH-ORDERS := '/var/shop/';

declare variable $_:FTP-TEST-PATH-BILLS := '/var/erp/rechnungen/';
declare variable $_:FTP-TEST-PATH-DOCUMENTS := '/files/documents/';
declare variable $_:FTP-TEST-PATH-ORDERS := '/var/shop/';

declare variable $_:PATH-SHOPS := '/shop/api/shops/';
declare variable $_:PATH-ORDERS := '/shop/api/orders/';
declare variable $_:PATH-TEST-ORDERS := '/testshop/api/orders/';

declare variable $_:PATH-DOCUMENTS := '/shop/api/documents/';
declare variable $_:PATH-ARTICLES := '/shop/api/articles/';
declare variable $_:PATH-VARIANTS := '/shop/api/variants/';
declare variable $_:PATH-MEDIA := '/shop/api/media/';
declare variable $_:PATH-CATEGORIES := '/shop/api/categories/';
declare variable $_:PATH-CACHES := '/shop/api/caches/';
declare variable $_:PATH-CUSTOMERS := '/shop/api/customers/';
declare variable $_:PATH-ADDRESSES := '/shop/api/addresses/';
declare variable $_:PATH-PRICES := '/shop/api/userprices/';
declare variable $_:PATH-GROUPS := '/shop/api/userpricegroups/';
declare variable $_:PATH-PROPERTYGROUPS := '/shop/api/propertyGroups/';
declare variable $_:PATH-CUSTOMERGROUPS := '/shop/api/customerGroups/';

declare variable $_:UPDATEINTERVAL-CUSTOMERS := xs:long(1800000);
declare variable $_:SHOP-CONFIG := "ShopConfig";
declare variable $_:ENUM-UPDATE-INTERVAL := "update-interval";

declare function _:FTP-port() as xs:int {
    xs:int($_:FTP-PORT)
};

declare function _:FTP-proxy-port() as xs:int {
    xs:int($_:FTP-PROXY-PORT)
};

declare function _:port() as xs:int {
    xs:int($_:PORT)
};

declare function _:pim-port() as xs:int {
    xs:int($_:PIM-PORT)
};

declare function _:publisher-port() as xs:int {
    xs:int($_:PUBLISHER-PORT)
};


declare function _:host() as xs:string {
    $_:HOST
};

declare function _:protocol() as xs:string {
    $_:PROTOCOL
};

declare function _:pim-protocol() as xs:string {
    $_:PIM-PROTOCOL
};

declare function _:publisher-protocol() as xs:string {
    $_:PUBLISHER-PROTOCOL
};


declare function _:user() as xs:string {
    $_:USER
};


declare function _:pwd() as xs:string {
    $_:KEY
};