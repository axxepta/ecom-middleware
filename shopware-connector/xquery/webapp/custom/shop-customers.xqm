module namespace _= "custom/shop/shop-customers";

import module namespace functx = "http://www.functx.com" at "../../repo/functx/functx-1.0-nodoc-2007-01.xq";
import module namespace conf = "pim/config" at "../../repo/pim/config.xqm";
import module namespace shop = "custom/shop/config" at "../../repo/custom/shop/config.xqm";

import module namespace common = "custom/shop/shop-common" at "shop-common.xqm";

import module namespace HTTPWrapper = 'de.axxepta.syncrovet.http.HTTPWrapper' at "../../repo/java/HTTPWrapper.xqm";

import module namespace admin = "admin/log" at "../../repo/admin/log.xqm";

declare variable $_:FILE-CUSTOMERS := file:resolve-path($conf:DATA_ROOT ||'/External/Shopware/customers.xml');
declare variable $_:FILE-ADDRESSES := file:resolve-path($conf:DATA_ROOT ||'/External/Shopware/addresses.xml');
declare variable $_:FOLDER-ADDRESS := file:resolve-path($conf:DATA_ROOT ||'/External/Shopware/address/');


declare 
  %rest:GET
  %rest:path("/shop/bonus-customers")
  (:
  %output:method("text")
  %output:media-type("text/plain")
  :)
function _:get-bonus-customers(){

    let $x0 := admin:write-log('START BONUS CUSTOMERS DOWNLOAD')

    let $date := current-date() - xs:dayTimeDuration('P1D')
    let $date-filter := _:recent-login-filter(year-from-date($date) || '-' || month-from-date($date) || '-' || day-from-date($date))
    let $customers-list := parse-xml-fragment(common:get-xml-request(shop:protocol(), shop:host(), shop:port(), $shop:PATH-CUSTOMERS || '?' || $date-filter ))

    let $bonus-customers := 
        for $cust in $customers-list/response/data
        return let $recent-customer := parse-xml-fragment(common:get-xml-request(shop:protocol(), shop:host(), shop:port(), $shop:PATH-CUSTOMERS || $cust/id))
            return
                if (not(empty($recent-customer/response/data/attribute/sfxBonusProgram)) and
                    $recent-customer/response/data/attribute/sfxBonusProgram = '1'
                    and not(ends-with($recent-customer/response/data/groupKey, 'BO')))
                        then $recent-customer/response/data/number || ';WAHR' else ()

    let $csv := string-join($bonus-customers, "&#13;&#10;") || "&#13;&#10;"

    let $csv-file := file:write-text($common:ERP-PATH || 'customers\new-bonus-customers.csv', $csv, "CP1252")
    
    (: put new to ftp :)
    return common:ftp-relative-up('customers', 'new-bonus-customers.csv')
};



(: ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        znd, COMMENTED OUT, USES XSLT
   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

declare 
  %rest:GET
  %rest:path("/shop/new-customers")
  (:
  %output:method("text")
  %output:media-type("text/plain")
  :)
function _:get-new-customers(){

  let $mapping-customer := file:read-text($common:ERP-XSL-PATH || 'new-customer-transform.txt')
  let $lines := tokenize($mapping-customer, '\r?\n')
  
  let $xsl := <xsl:stylesheet version="2.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" >
                <xsl:output method="text"/>

                <xsl:template match="/*">
                
                <!--   <xsl:text>
                  {  let $header := 
                     for $line in $lines
                     let $tokens :=  tokenize($line, '\t')
                     return $tokens[1]
                     return string-join($header, ';')
                 }</xsl:text><xsl:text>&#13;&#10;</xsl:text> -->
                
                  <xsl:apply-templates/>
                  
                </xsl:template>
                
                <xsl:template match="*">
                     <xsl:apply-templates/>
                </xsl:template>
                
               <xsl:template match="text()">
     
                </xsl:template>
               
                <xsl:template match="customers/customer">
                   <!-- keep order -->
                   {
                     let $count := count($lines)
                     return
                     for $line at $pos in $lines
                     let $tokens :=  tokenize($line, '\t')
                     let $value := if($tokens[2] != '') then replace($tokens[2], "customer/", "./") else "'null'"
                     let $is-last := ($pos = $count)
                     return
                     <xsl:call-template name="field">
                       <xsl:with-param name="token" select="{$value}"/>
                        <xsl:with-param name="head" select="'{$tokens[1]}'"/>
                        <xsl:with-param name="is-last" select="'{$is-last}'"/>
                     </xsl:call-template>
                   }
                  <xsl:text>&#13;&#10;</xsl:text>
                </xsl:template>

                     <xsl:template name="field">
                       <xsl:param name="token"/>
                       <xsl:param name="head"/>
                       <xsl:param name="is-last"/>
                       <xsl:choose>
                         <xsl:when test="$token eq 'true'">
                            <xsl:text>WAHR</xsl:text>
                         </xsl:when>
                          <xsl:when test="$token eq 'false'">
                             <xsl:text>FALSCH</xsl:text>
                         </xsl:when>
                         <xsl:when test="$token eq 'null'">
                            <!-- <xsl:value-of select="$head"/> -->
                         </xsl:when>
                         <xsl:when test="$token eq 'DEU'">
                             <xsl:text>276</xsl:text>
                         </xsl:when>
                         <xsl:otherwise>
                              <xsl:value-of select="translate($token, ';', ' ')"/>
                         </xsl:otherwise>
                       </xsl:choose>
                       <xsl:if test="$is-last = 'false'"><xsl:text>;</xsl:text></xsl:if>
                      
                     </xsl:template>
       
  </xsl:stylesheet>
 
  (: get all adresses :)
  (: let $get-all := _:download-addresses()
  let $addresses := doc($_:FILE-ADDRESSES)/*  :)
  
  (:let $addresses :=  parse-xml-fragment(common:get-xml-request(shop:protocol(), shop:host(), shop:port(), $shop:PATH-ADDRESSES)) :)
  (: get without mainNumber :)
  (: let $new-addr :=
  for $addr in $addresses/response/data :)
  (: limit to addresses without main number :)
  (: where $addr/attribute/mainNumber eq 'null'
  return  parse-xml-fragment(common:get-xml-request(shop:protocol(), shop:host(), shop:port(), $shop:PATH-ADDRESSES || $addr/id)) :)
  
   (: let $new-customers-raw :=
  for $addr-full in $new-addr
  return  parse-xml-fragment(common:get-xml-request(shop:protocol(), shop:host(), shop:port(), $shop:PATH-CUSTOMERS || $addr-full/response/data/customer/id))
  :)
  
  let $customers-list := parse-xml-fragment(common:get-xml-request(shop:protocol(), shop:host(), shop:port(), $shop:PATH-CUSTOMERS || '?filter[0][property]=groupKey&amp;filter[0][value][0]=IK'))
  
  let $new-customers-raw := for $cust in $customers-list/response/data
  where $cust/number > '40100'
  return  parse-xml-fragment(common:get-xml-request(shop:protocol(), shop:host(), shop:port(), $shop:PATH-CUSTOMERS || $cust/id))
   
  let $new-customers := <customers>{
      for $data in $new-customers-raw/response/data
      let $id := $data/id
      group by $id
      return <customer>
                {for $node in $data[1]/node() except($data[1]/defaultShippingAddress, $data[1]/defaultBillingAddress)
                  return $node
                }
                <priceGroupId></priceGroupId>
                <status>Interessent</status>
                <billing>
                 {$data[1]/defaultBillingAddress/node() except($data[1]/defaultBillingAddress/country)}
                 <country>{$data[1]/defaultBillingAddress/country/iso3/string()}</country>
                </billing>
                <shipping>
                 {$data[1]/defaultShippingAddress/node() except($data[1]/defaultShippingAddress/country)}
                 <country>{$data[1]/defaultShippingAddress/country/iso3/string()}</country>
                </shipping>
                <oneAddress>{$data[1]/defaultShippingAddress/id/number() eq $data[1]/defaultBillingAddress/id/number()}</oneAddress>
             </customer>
  }
  </customers>
  (: convert to csv :)
  
  let $xsl-file := file:write($common:ERP-XSL-PATH  || 'new-customers.xsl', $xsl)
  (: let $xml-addr-all := file:write($common:ERP-PATH || 'customers\all-addresses.xml', $addresses)
  let $xml-addr := file:write($common:ERP-PATH || 'customers\new-addresses.xml', $new-addr)
  :)
  let $xml-file := file:write($common:ERP-PATH || 'customers\new-customers.xml', $new-customers)
  let $csv := xslt:transform-text($new-customers, $xsl)
  let $csv-file := file:write-text($common:ERP-PATH || 'customers\new-customers.csv', $csv, "CP1252")
  
  (: put new to ftp :)
   return common:ftp-relative-up('customers', 'new-customers.csv')
}; :)

declare
  %rest:GET
  %rest:path("/shop/customerGroups")
function _:customerGroups() as item() {
    common:get-request(shop:protocol(), shop:host(), shop:port(), $shop:PATH-CUSTOMERGROUPS)
};

declare
  %rest:GET
  %rest:path("/shop/customers/download")
function _:download-customers() as item() {
    common:get-shopware-request(shop:protocol(), shop:host(), shop:port(), concat($shop:PATH-CUSTOMERS, '?limit=500000'), $_:FILE-CUSTOMERS, ('customer', 'customers') )
};

declare
  %rest:GET
  %rest:path("/shop/customers")
function _:customers() as item() {
    common:get-request(shop:protocol(), shop:host(), shop:port(), concat($shop:PATH-CUSTOMERS, '?limit=500000'))
};

declare
  %rest:GET
  %rest:path("/shop/customers/{$id}")
function _:customer($id as xs:string) as item() {
    common:get-request(shop:protocol(), shop:host(), shop:port(), $shop:PATH-CUSTOMERS || $id)
};

declare
  %rest:GET
  %rest:path("/shop/customers/validity")
function _:check-customer-validity() {
    let $customers := _:customers()
    return <unvalid>{
        for $customer at $pos in $customers/json/data/_
        (:where $pos lt 10:)
        let $c := _:customer($customer/id/text())
        return if ($c/json/data/number != $c/json/data/defaultBillingAddress/attribute/mainNumber)
            then <customer>{($c/json/data/number, $c/json/data/defaultBillingAddress/attribute/mainNumber)}</customer> else ()
    }</unvalid>
};

declare
  %rest:GET
  %rest:path("/shop/customers/update")
  %rest:query-param("number", "{$number}", "")
  (: %rest:single :)
function _:update-customers($number) {
    let $test-run := false()
    
    let $x0 := admin:write-log('START CUSTOMER UPLOAD')
    
    return try {
    
    let $forceUpdate := false()
    
    let $customers := fn:doc($common:ERP-DB || '/' || $common:ERP-DB-FILE)
    let $oldCustomers := (# basex:non-deterministic #) { _:customers()/json/data/_ }
    
    let $specialPrices := fn:doc($common:ERP-USERPRICE-DB || '/' || $common:ERP-USERPRICE-DB-FILE)
    let $specialPriceCustomers := (# basex:non-deterministic #) { distinct-values($specialPrices//userprice/addressnumber/text()) }
    
    let $priceGroups := _:price-groups()
    let $groupMap := map:merge(
        for $ind in (1 to 9)
        let $group := $priceGroups//_[name = concat('Vk', $ind)]
        return if (empty($group)) then () else map:entry(string($ind), $group/id/text())
    )
    
    (: customer range for testing :)
    let $startIndex1 := if ($number != '') then $number else '20000'
    let $endIndex1 := if ($number != '') then $number else '50000'
    (: let $startIndex2 := '20000'
    let $endIndex2 := '50000'
    :)
    
    (: the newCustomers don't contain information about whether it's a primary customer or secondary, 
        so the original ones still has to be evaluated further down, efficient assignment via ./billing/attribute/addressnumber
    :)
    let $customersMap := map:merge(
        for $customer in $customers/customers/customer
        where (_:is-valid-customer($customer)  (: Excel Status = 'Kunde' and  'Webshop Adresse Kennzeichen = 'WAHR' :)
                and ((($customer/billing/attribute/addressNumber/text() >= $startIndex1) and ($customer/billing/attribute/addressNumber/text() <= $endIndex1))
                or (($customer/billing/attribute/mainNumber/text() >= $startIndex1) and ($customer/billing/attribute/mainNumber/text() <= $endIndex1))) )
               (: addressNumber :)
        return map:entry($customer/billing/attribute/addressNumber/text(), $customer)
    )    
    
    (: for valid customers create data set to be uploaded :)
    let $newCustomers := (# basex:non-deterministic #) { <newCustomers>{
        (: addressNumber :)
        for $key in map:keys($customersMap)
        let $customer := map:get($customersMap, $key)
        
   
        (: mainNumber column mostly is empty if main address, but also could contain the main number, don't count twice! :)
        let $singleAddress := <sfxHideAddressDropdown>{
            let $mainNumber := _:identify-main-number($customer/number, $customer/billing/attribute/addressNumber/text())
            return if ((count($customers/customers/customer[number/text() = $mainNumber])
               + count($customers/customers/customer[billing/attribute/addressNumber/text() = $mainNumber])
               - count($customer[number = $mainNumber][billing/attribute/addressNumber/text() = $mainNumber])) > 1) then (0) else (1)
        }</sfxHideAddressDropdown>
        
        return _:build-customer($customer, $singleAddress)
    }</newCustomers> }
    let $x1 := admin:write-log('customer maps created')

    
    (: update customers already in shop:)
    let $updateCustomers := (# basex:non-deterministic #) { <updateCustomers>{
        
        (: all customers from erp (one per addressNumber) :)
        for $newCustomer in $newCustomers/customer
        (: number can be empty :)
        let $oldSparseCustomer := $oldCustomers[number = $newCustomer/number/text()]
       (:  let $x1-2 := admin:write-log("Customer (new/old): " || $newCustomer/number || " "  || $oldSparseCustomer/id, "INFO") :)
        let $customer := map:get($customersMap, $newCustomer/billing/attribute/addressNumber/text())
        where _:is-main-customer($customer) and not(empty($oldSparseCustomer)) and 
            (_:recently-updated(common:date-convert($customer/lastChange/text(), current-dateTime()))
                or (_:hash-customer($oldSparseCustomer[1], false()) != _:hash-customer($newCustomer, $forceUpdate)) )
        return _:change-customer($newCustomer transform with { insert node _:determine-specialPriceGroup($customer/priceGroupId, $groupMap) into ./attribute },
                                    $oldSparseCustomer/id/text(), true(), $test-run)
            
    }</updateCustomers> }
    let $x2 := admin:write-log('customers updated')
    
    let $addresses := (# basex:non-deterministic #) {  _:addresses()/json/data/_ }
    
    
    (: update addresses (also secondary) of customers already in shop :)
    let $updateAddresses := (# basex:non-deterministic #) { <updateAddresses>{
    
        for $newCustomer in $newCustomers/customer
        let $customer := map:get($customersMap, $newCustomer/billing/attribute/addressNumber/text())
        let $oldAddresses := $addresses[attribute/addressNumber = $newCustomer/billing/attribute/addressNumber/text()]
        
        let $billingHash := _:hash-address($newCustomer/billing)
        let $shippingHash := _:hash-address($newCustomer/shipping)
        
        where (not(empty($oldAddresses)) and ((count($oldAddresses) = 1)
                or ($oldAddresses[1]/attribute/hash/text() != $billingHash)
                    or ($oldAddresses[2]/attribute/hash/text() != $shippingHash)))
        return
            (: unfortunately, customerId is not returned with batch get of addresses,
                attribute/mainNumber is not set after creation of customer in shop :)
            let $customerId := if (empty($oldAddresses[1]/attribute/mainNumber/text())) then (
                let $oldCustomer := common:get-request(shop:protocol(), shop:host(), shop:port(), concat($shop:PATH-CUSTOMERS || $newCustomer/number, '?useNumberAsId=true'))
                return <customer>{$oldCustomer/json/data/id/text()}</customer>
            ) else (
                <customer>{$oldCustomers[number = $oldAddresses[1]/attribute/mainNumber/text()]/id/text()}</customer>
            )
            return (
                (: assignment of old addresses to data sets addresses is billing = 1, shipping = 2,
                    based on the assumption that addresses in customer are created in order billing/shipping
                    and are returned in order of id :)
                if ($oldAddresses[1]/attribute/hash/text() != $billingHash) then (
                    let $jsonBill := _:build-new-json-address($newCustomer/billing, $customerId, $billingHash)
                    return _:change-address($jsonBill, $oldAddresses[1]/id/text(), 'billing', $newCustomer/billing/attribute/addressNumber, $test-run)
                ) else ()
            ,
                if (count($oldAddresses) = 2) then (
                    if ($oldAddresses[2]/attribute/hash/text() != $shippingHash) then (
                        let $jsonShipp := _:build-new-json-address($newCustomer/shipping, $customerId, $shippingHash)
                        return _:change-address($jsonShipp, $oldAddresses[2]/id/text(), 'shipping', $newCustomer/shipping/attribute/addressNumber, $test-run)
                    ) else ()
                ) else ( (: customer could be created in shop with one address, but always will get a second from ERP  :)
                    let $jsonShipp := _:build-new-json-address($newCustomer/shipping, $customerId, $shippingHash)
                    return _:upload-address($jsonShipp, 'shipping', $newCustomer/shipping/attribute/addressNumber, $test-run)
                )        
            )
            
    }</updateAddresses> }
    let $x3 := admin:write-log('addresses updated')
    
    
    (: import new customers :)
    let $importCustomer := (# basex:non-deterministic #) { <uploadCustomers>{
    
        (: iterate (again) over erp customer per addressNumber :)
        for $newCustomer in $newCustomers/customer
        let $customer := map:get($customersMap, $newCustomer/billing/attribute/addressNumber/text())
        where _:is-main-customer($customer)
        return
            let $oldAddresses := $addresses[attribute/addressNumber = $newCustomer/number/text()]
             let $x3-1 := admin:write-log("Customer (new / old addr empty): " || $newCustomer/number || " / "  || empty($oldAddresses), "INFO")
            where empty($oldAddresses)
            return 
            let $newCustomer1 := (
              copy $newCustomer1 := $newCustomer
              modify insert node _:determine-specialPriceGroup($customer/priceGroupId, $groupMap) into newCustomer1/attribute
              return
              $newCustomer1
            )
            return
            _:upload-customer($newCustomer1, $test-run)
            
    }</uploadCustomers> }
    let $x4 := admin:write-log('new customers uploaded')
    
    
    (: import secondary addresses :)
    let $importAddresses := (# basex:non-deterministic #) { <uploadAddresses>{
    (: checken: muss sfxHideAddressDropDown geändert werden?! beim Nachträglichen hinzufügen einer zweiten Adresse :)
        for $newCustomer in $newCustomers/customer
        let $customer := map:get($customersMap, $newCustomer/billing/attribute/addressNumber/text())
        where not(_:is-main-customer($customer))
        return
            let $oldAddresses := $addresses[attribute/addressNumber/text() = $newCustomer/billing/attribute/addressNumber/text()]
            let $x4-1 := admin:write-log("Customer secondary (new / old addr empty): " || $newCustomer/number || " / "  || empty($oldAddresses), "INFO")
            where empty($oldAddresses)
            return _:upload-secondary-addresses($newCustomer, $importCustomer//newCustomer[@mainNumber=$newCustomer/number/text()]/id,
                $oldCustomers[number = $customer/number/text()]/id,
                $updateCustomers/customer[@number = $newCustomer/number/text()][success]/id,
                $test-run)
            
    }</uploadAddresses> }
    let $x5 := admin:write-log('secondary addreses uploaded')
    
    let $xml-file := file:write($common:CUSTOMERS-LOG, 
        <upload><dateTime>{current-dateTime()}</dateTime>{($updateCustomers, $updateAddresses, $importCustomer, $importAddresses)}</upload>)
    return (<upload>{($updateCustomers, $updateAddresses, $importCustomer, $importAddresses)}</upload>,
            admin:write-log('FINISHED CUSTOMER UPLOAD'))
    
    } catch * {
        (common:fatal-log($common:CUSTOMERS-LOG, (<description>{$err:description}</description>, <module>{$err:module}</module>,
            <line>{$err:line-number}</line>, <trace>{$err:additional}</trace>)),
            admin:write-log('FATAL ERROR CUSTOMER UPLOAD'))
    }
};


declare function _:change-customer($newCustomer as element(), $id as xs:string, $insertHashes as xs:boolean, $test-run as xs:boolean) as element() {
    <customer number="{$newCustomer/number/text()}">{
        try {
            let $json := _:build-new-json-customer($newCustomer, $insertHashes)
            let $updateResult := if ($test-run)
                then file:write-text($common:ERP-PATH || 'customer_change_' || $newCustomer/number || '.json', $json)
                else HTTPWrapper:putJSON(shop:protocol(), shop:host(), shop:port(), concat($shop:PATH-CUSTOMERS || $newCustomer/number, '?useNumberAsId=true'), shop:user(), shop:pwd(), $json)
            return try {
                let $newUpload := $updateResult
                return
                    (<success>{$newUpload/success/text()}</success>,
                    <id>{$newUpload//id/text()}</id>)
            } catch * {
                (<failed>{$updateResult}</failed>,
                <id>{$id}</id>)
            }
        } catch * {
            (<fatal>Could not create JSON change data for customer</fatal>,
            <id>{$id}</id>)
        }
    }</customer>
};


declare function _:customer-number-addresses($customer as element()) as xs:integer {
    if ($customer/oneAddress/text() = 'FALSE') then (2) else (1)
};


declare function _:upload-customer($newCustomer as element(), $test-run as xs:boolean) as element() {
    <newCustomer mainNumber="{$newCustomer/number/text()}">{
        try {
            let $json := _:build-new-json-customer($newCustomer, true())
            let $uploadResult :=  if ($test-run)
                then file:write-text($common:ERP-PATH || 'customer_upload_' || $newCustomer/number || '.json', $json)
                else HTTPWrapper:postJSON(shop:protocol(), shop:host(), shop:port(), $shop:PATH-CUSTOMERS, shop:user(), shop:pwd(), $json)
            return try {
                let $newUpload := $uploadResult
                return (<success>{$newUpload/success/text()}</success>,
                        $newUpload//id)
            } catch * {
                <failed>{$uploadResult}</failed>
            }
        } catch * {
            <fatal>Could not create JSON upload data for customer</fatal>
        }
    }</newCustomer>
};


declare function _:upload-secondary-addresses(
        $newCustomer as element(),
        $uploadCustomerId as element()*,
        $oldCustomersId as element()*,
        $updatedCustomersId as element()*,
        $test-run as xs:boolean
) as element() {
    let $customerIdNode := if (empty($uploadCustomerId/text()))
        then ($oldCustomersId)
        else ($uploadCustomerId)
    
    return if (empty($customerIdNode/text())) then (
        <newAddress addressNumber="{$newCustomer/shipping/attribute/addressNumber/text()}">
            <failed customerId="{$newCustomer/number/text()}">no such customerId</failed>
        </newAddress>
    ) else (
        let $customerId := <customer>{$customerIdNode/text()}</customer>
        let $jsonBilling := _:build-new-json-address($newCustomer/billing, $customerId, _:hash-address($newCustomer/billing))
        let $jsonShipping := _:build-new-json-address($newCustomer/shipping, $customerId, _:hash-address($newCustomer/shipping))
        return <newAddress addressNumber="{$newCustomer/shipping/attribute/addressNumber/text()}">{(
                (
                    _:upload-address($jsonBilling, 'billing', $newCustomer/billing/attribute/addressNumber, $test-run)
                ,
                    _:upload-address($jsonShipping, 'shipping', $newCustomer/shipping/attribute/addressNumber, $test-run)
                )
        ,
            (: corresponding customer not created or updated during this process :)
            if (not(empty($oldCustomersId)) and empty($updatedCustomersId)) then (
                _:change-customer(<customer><attribute><sfxHideAddressDropdown>0</sfxHideAddressDropdown></attribute></customer>,
                    $oldCustomersId/text(), false(), $test-run)
            ) else ()
        )}</newAddress>
    )
};


declare function _:upload-address($json as xs:string, $type as xs:string, $number as xs:string, $test-run as xs:boolean) as element() {
    let $addressUpResponse :=  if ($test-run)
        then ('test-run', file:write-text($common:ERP-PATH || 'address_upload_' || $number || '.json', $json))
        else HTTPWrapper:postJSON(shop:protocol(), shop:host(), shop:port(), $shop:PATH-ADDRESSES, shop:user(), shop:pwd(), $json)
    return _:wrap-address-response($addressUpResponse, $type, $number)
};


declare function _:change-address($newAddress as xs:string, $id as xs:string, $type as xs:string, $number as xs:string, $test-run as xs:boolean) as element() {
    <change>{
        let $addressChangeResponse :=  if ($test-run)
            then ('test-run',  file:write-text($common:ERP-PATH || 'address_change_' || $number || '.json', $newAddress))
            else HTTPWrapper:putJSON(shop:protocol(), shop:host(), shop:port(), $shop:PATH-ADDRESSES || $id, shop:user(), shop:pwd(), $newAddress)
        return _:wrap-address-response($addressChangeResponse, $type, $number)
    }</change>
};


declare function _:wrap-address-response($response as xs:string, $type as xs:string, $number as xs:string) as element() {
    <address type="{$type}">{
        try {
            let $xmlResponse := fn:parse-json($response)
            return (<success>{$xmlResponse//success/text()}</success>,
                <id>{$xmlResponse//id/text()}</id>)
        } catch * {
            (<failed>{$response}</failed>,
            <number>{$number}</number>)
        }
    }</address>
};


declare function _:build-new-json-address($address as element(), $customerId as element(), $hash as xs:string) as xs:string {
    copy $newAddress := $address
    modify (
      insert node <hash>{$hash}</hash> into $newAddress/attribute,
      insert node $customerId into $newAddress
    )
    return 
      try{ fn:serialize(<json numbers="mainNumber country customer axxIsShipping" objects="json attribute">{$newAddress/*}</json>, map{'method':'json'}) } 
      catch * {  
        let $err := 'JSON address failed for ' || $newAddress || ' details: ' || $err:description
        let $msg := admin:write-log('JSON address failed for ' || $newAddress || ' details: ' || $err:description, 'ERROR')
        return error(xs:QName('error'), $err)
      }
};


(: build json from erp data for upload to shopware :)
declare function _:build-new-json-customer($newCustomer as element(), $insertHashes as xs:boolean) as xs:string {
  copy $custom := $newCustomer
  modify (
    if ($insertHashes) then 
      (
        insert node <hash>{_:hash-address($custom/billing)}</hash> into $custom/billing/attribute,
        insert node <hash>{_:hash-address($custom/shipping)}</hash> into $custom/shipping/attribute
      )
    else
      $custom
  )
    return 
    
       try { fn:serialize(<json booleans="active" numbers="mainNumber sfxHideAddressDropdown country paymentId axxIsShipping swagPricegroup" objects="json shipping billing attribute">{$custom/*}</json>, map{'method':'json'}) }
        catch * {  admin:write-log('JSON customer failed for ' || $newCustomer || ' details: ' || $err:description, 'ERROR') }
};  

declare function _:is-valid-customer($customer as element()) {
    (upper-case($customer/status/text()) = 'KUNDE') and (not(empty($customer/oneAddress/text())) and ($customer/shopAddress/text() = 'TRUE'))
};

declare function _:is-main-customer($customer as element()) {
    empty($customer/number/text()) or ($customer/number/text() = $customer/shipping/attribute/addressNumber/text())
};
 

declare function _:build-customer($customer as element(), $singleAddress as element()) as element() {
    let $mainNumber := _:identify-main-number($customer/number, $customer/billing/attribute/addressNumber/text())
    return
    copy $o := $customer
    modify
    (
       replace value of node $o/number with $mainNumber
      ,replace value of node $o/email with _:fill-email($o/email, $mainNumber)
      ,delete node $o/priceGroupId
      ,delete node $o/status
      ,delete node $o/lastChange
      ,delete node $o/shopAddress
      ,delete node $o/oneAddress
      ,insert node <groupKey>{_:determine-group($o/pharmacyCertificate, $o/wholesaleAllowance, $o/tradeLicence, $o/competencyCertificate, $o/attribute/sfxBonusProgram)}</groupKey> into $o
      ,if (empty($o/attribute/sfxBonusProgram)) then () else delete node $o/attribute/sfxBonusProgram
      ,insert node $singleAddress into $o/attribute
      ,delete node $o/pharmacyCertificate
      ,delete node $o/wholesaleAllowance
      ,delete node $o/tradeLicence
      ,delete node $o/competencyCertificate
      ,replace value of node $o/paymentId with _:determine-payment($o/paymentId)
      ,replace value of node $o/active with _:resolve-active-status($o/active)
      ,replace value of node $o/salutation with _:extract-salutation($o/salutation, false())
      ,replace value of node $o/firstname with _:empty-replacement($o/firstname)
      ,replace value of node $o/lastname with _:empty-replacement($o/lastname)
      ,replace value of node $o/shipping/country with common:country-transform($o/shipping/country)
      ,replace value of node $o/billing/country with common:country-transform($o/billing/country)
      ,replace value of node $o/shipping/salutation with _:extract-salutation($o/shipping/salutation, true())
      ,replace value of node $o/billing/salutation with _:extract-salutation($o/billing/salutation, true())
      ,replace value of node $o/shipping/firstname with _:empty-replacement($o/shipping/firstname)
      ,replace value of node $o/shipping/lastname with _:empty-replacement($o/shipping/lastname)
      ,replace value of node $o/billing/firstname with _:empty-replacement($o/billing/firstname)
      ,replace value of node $o/billing/lastname with _:empty-replacement($o/billing/lastname)
      ,replace value of node $o/billing/phone with _:empty-replacement($o/billing/phone)
      ,replace value of node $o/shipping/phone with _:empty-replacement($o/shipping/phone)
      ,replace value of node $o/billing/attribute/mainNumber with $mainNumber
      ,replace value of node $o/shipping/attribute/mainNumber with $mainNumber
      ,insert node <axxIsShipping>0</axxIsShipping> into $o/billing/attribute
      ,insert node <axxIsShipping>1</axxIsShipping> into $o/shipping/attribute
    )
    return
    $o
};

declare function _:hash-address($address as element()) as xs:string {
  '1'
    (: string(hash:sha1(concat($address/salutation, $address/firstname, $address/lastname,
        $address/street ,$address/zipCode, $address/city, $address/phone,
        $address/attribute/mainNumber, $address/attribute/addressNumber, $address/attribute/axxIsShipping))) :)
};

declare function _:hash-customer($customer as element(), $force as xs:boolean) as xs:string {
    (: random:uuid() :) (: force update :)
    if ($force) then '0' else (    '1'
        (: string(hash:sha1(concat( $customer/active/text(), $customer/email, $customer/salutation,
        $customer/title, $customer/firstname, $customer/lastname, $customer/groupKey, $customer/paymentId))) :)
    )
};

declare function _:recently-updated($date as xs:dateTime) as xs:boolean {
    let $current := current-dateTime()
    return (day-from-dateTime($current) = day-from-dateTime($date)) and (month-from-dateTime($current) = month-from-dateTime($date))
        and (year-from-dateTime($current) = year-from-dateTime($date))
};

declare function _:empty-replacement($node as element()) as xs:string {
    if (empty($node/text()) or ($node/text() = '')) then (
        '---'
    ) else (
        $node/text()
    )
};

declare function _:determine-payment($pay as element()) as xs:string {
    if (empty($pay/text())) then ('5') else (
        switch (substring(normalize-space($pay/text()), 1, 1))
        case 'B' return '7'
        case 'Z' return '4'
        case 'V' return '5'
        default return '5'
    )
};

declare function _:determine-specialPriceGroup($priceGroup as element(), $groupIds as map(*)) as element()* {
    if (empty($priceGroup/text())) then () else (
        let $group := substring($priceGroup/text(), 1, 1)
        let $id := map:get($groupIds, $group)
        return if (empty($id)) then () else <swagPricegroup>{$id}</swagPricegroup>
    )
};

declare function _:determine-group($pharmacy as element(), $wholesale as element(), $trade as element(), $competency as element(), $bonus as element()?) {
    let $p := _:excel-bool($pharmacy)
    let $w := _:excel-bool($wholesale)
    let $t := _:excel-bool($trade)
    let $c := _:excel-bool($competency)
    let $b := _:excel-bool($bonus)
    return if ($p or $w or $c or $t) then (
        if ($p) then (
            if ($b) then 'EKBO' else 'EK'
        ) else (
            if ($c) then (
                if ($b) then 'GSKBO' else 'GSK'
            ) else (
                if ($b) then 'GKBO' else 'GK'
            )
        )
    ) else (
        'IK'
    )
};

declare function _:excel-bool($e as element()?) as xs:boolean {
    if (empty($e) or empty($e/text()) or ($e/text() != 'TRUE'))
        then false()
        else true()
};

declare
  %rest:GET
  %rest:path("/shop/customers/check")
function _:check-customers-addresses() {
    let $data := fn:doc($common:ERP-DB || '/' || $common:ERP-DB-FILE)
    return <addequl>{
    for $c in $data//customer
    return if( ((empty($c/shipping/firstname/text()) and empty($c/billing/firstname/text())) or ($c/shipping/firstname/text() = $c/billing/firstname/text()))
            and ((empty($c/shipping/lastname/text()) and empty($c/billing/lastname/text())) or ($c/shipping/lastname/text() = $c/billing/lastname/text()))
            and ((empty($c/shipping/salutation/text()) and empty($c/billing/salutation/text())) or ($c/shipping/salutation/text() = $c/billing/salutation/text()))
            and ((empty($c/shipping/street/text()) and empty($c/billing/street/text())) or ($c/shipping/street/text() = $c/billing/street/text()))
        )
        then (<true></true>) else (<false><shipping>{($c/shipping/salutation, $c/shipping/firstname, $c/shipping/lastname)}</shipping>
                                    <billing>{($c/billing/salutation, $c/billing/firstname, $c/billing/lastname)}</billing></false>)
    }</addequl>
};

declare function _:identify-main-number($main as element(), $address as xs:string) as xs:string {
    if (empty($main/text()) or ($main/text() = $address))
        then ($address)
        else ($main/text())
};

(:~
  active is set by field 'Ist Gesperrt' -> inverted logic
:)
declare function _:resolve-active-status($active as element()) {
    if ($active/text() = 'TRUE')
        then ('false')
        else ('true')
};

declare function _:extract-salutation($salutationCol as element(), $forAddress as xs:boolean) {
    if (empty($salutationCol/text()) or not(contains($salutationCol/text(), 'Frau')))
        then (
            if ($forAddress) then ('mr') else ('Herr')
        ) else (
            if ($forAddress) then ('ms') else ('Frau')
        )
};

declare function _:transform-date($dateStr as xs:string) {
    let $cd := functx:reverse-string(functx:replace-first(functx:reverse-string(string(current-dateTime())), ':', ''))
    return concat(substring($cd, 1, 18), substring($cd, 23))
};

declare function _:fill-email($node as element(), $customerNumber) {  
    if (empty($node/text()) or  ($node/text() = '')) then (
        concat('wittenberg+', $customerNumber, '@axxepta.de')
    ) else (
        $node/text()
    )
};

declare
  %rest:GET
  %rest:path("/shop/addresses")
function _:addresses() (:as item():) {
    common:get-request(shop:protocol(), shop:host(), shop:port(), concat($shop:PATH-ADDRESSES, '?limit=500000'))
};

declare function _:recent-login-filter($date-after) as xs:string {
    'filter[0][property]=lastLogin&amp;filter[0][value]=' || $date-after || '&amp;filter[0][expression]=%3E'
};

declare
  %rest:GET
  %rest:path("/shop/customers/save-report")
function _:save-customers-report() {
    let $report := _:create-customers-report()
    let $xml-file := file:write($common:CUSTOMERS-REPORT, $report)
    return file:write(common:stamped-filename($common:CUSTOMERS-REPORT), $report)
};

declare
  %rest:GET
  %rest:path("/shop/customers/report")
  %output:method("xhtml")
  %output:html-version("5.0")
function _:create-customers-report() {
<html>
</html>
};

(: Copied from shop-prices.xqm to avoid cyclic import :)
declare function _:price-groups() as item() {
    common:get-request(shop:protocol(), shop:host(), shop:port(), concat($shop:PATH-GROUPS, '?limit=500000'))
};
