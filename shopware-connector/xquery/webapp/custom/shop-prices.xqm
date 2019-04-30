module namespace _= "custom/shop/shop-prices";

import module namespace functx = "http://www.functx.com";
import module namespace conf = "pim/config";
import module namespace shop = "custom/shop/config";

import module namespace shop-customers = "custom/shop/shop-customers" at "shop-customers.xqm";
import module namespace shop-articles = "custom/shop/shop-articles" at "shop-articles.xqm";
import module namespace common = "custom/shop/shop-common" at "shop-common.xqm";

import module namespace HTTPWrapper = 'de.axxepta.syncrovet.http.HTTPWrapper';

declare variable $_:SPECIAL_VK_GROUPS := ('Vk1', 'Vk3', 'Vk6');
declare variable $_:SPECIAL_VK_NUMBERS := $_:SPECIAL_VK_GROUPS ! substring(., 3, 1);


declare
  %rest:GET
  %rest:path("/shop/userprices")
function _:prices() as item() {
    common:get-request(shop:protocol(), shop:host(), shop:port(), concat($shop:PATH-PRICES, '?limit=5000000'))
};

declare
  %rest:GET
  %rest:path("/shop/userpricegroups")
function _:groups() as item() {
    common:get-request(shop:protocol(), shop:host(), shop:port(), concat($shop:PATH-GROUPS, '?limit=500000'))
};

declare
  %rest:GET
  %rest:path("/shop/userprices/delete")
function _:delete-prices() as item() {
    let $prices := common:get-request(shop:protocol(), shop:host(), shop:port(), concat($shop:PATH-PRICES, '?limit=20000'))
    let $del := <json  objects="_" arrays="json" numbers="id">{
        for $price in $prices//data/_
        return <_>{$price/id}</_>
    }</json>
    let $json := json:serialize($del)
    let $upload := HTTPWrapper:delete(shop:protocol(), shop:host(), shop:port(), $shop:PATH-PRICES, shop:user(), shop:pwd(), $json)
    return if (empty($del//id)) then (
            try {
            json:parse($upload)
        } catch * {
            <failed>{$upload}</failed>
        }
    ) else (
        _:delete-prices()
    )
};

declare
  %rest:GET
  %rest:path("/shop/userprices/{$id}")
function _:userprice($id) as item() {
    common:get-request(shop:protocol(), shop:host(), shop:port(), $shop:PATH-PRICES || $id)
};

declare
  %rest:GET
  %rest:path("/shop/userpricegroups/{$id}")
function _:group($id) as item() {
    common:get-request(shop:protocol(), shop:host(), shop:port(), $shop:PATH-GROUPS || $id)
};


(: creates non-existent price groups
   side effect: for new groups the corresponding customers are assigned to these group:)
declare
  %rest:GET
  %rest:path("/shop/userprices/groupupdate")
function _:upload-groups() {
    let $test-run := false()
    return try {
    
        let $groups := _:groups()
        let $prices := db:open($common:ERP-USERPRICE-DB, $common:ERP-USERPRICE-DB-FILE)
        
        let $customers := (# basex:non-deterministic #) {
            (shop-customers:customers(),
            admin:write-log("USERPRICEGROUPS UPDATE STARTED"))
        }
        let $customersMap := map:merge(
            for $c at $pos in $customers/json/data/_
            where (not(empty($c/number/text())))
            return map:entry($c/number/text(), $c)
        )
        
        let $groupNames := distinct-values($prices//userprice/addressnumber/text())
        let $noneZeroCustomers := db:open($common:ERP-DB, $common:ERP-DB-FILE)/customers/customer[priceGroupId != '0 Endkunden']
        let $modifiedGroupNames := ($_:SPECIAL_VK_GROUPS,
            for $g in $groupNames
            where not(empty(map:get($customersMap, $g)))
            return _:groupName-by-addressNumber($g, $noneZeroCustomers[billing/attribute/addressNumber = $g])
        )
        
        (: Artikelpreisgruppe for all customers not in Vk0 and without special prices :)
        let $articlesPriceGroups := <customers>{
            for $key in map:keys($customersMap)
            let $c := map:get($customersMap, $key)
            let $erpCustomer := $noneZeroCustomers[billing/attribute/addressNumber = $key]
            where not(empty($erpCustomer)) and not($erpCustomer/billing/attribute/addressNumber = $groupNames)
            return <customer>
                <number>{$key}</number>
                {$erpCustomer[1]/priceGroupId}
            </customer>
        }</customers>
        
        (: new price groups :)
        let $groupUpload := (# basex:non-deterministic #) { <json objects="_" arrays="json" numbers="gross active">{
            for $groupName in $modifiedGroupNames
            let $refGroup := $groups//_[name = $groupName]
            where empty($refGroup)
            return <_>
                <name>{$groupName}</name>
                <gross>0</gross>
                <active>1</active>
            </_>
        }</json> }
        
        
        (: price groups formerly existent but not any more :)
        let $groupDelete := (# basex:non-deterministic #) { <json objects="_" arrays="json" numbers="id">{
            for $oldGroup in $groups//_
            where not($oldGroup/name/text() = $modifiedGroupNames)
            return <_>{($oldGroup/name, $oldGroup/id)}</_>
        }</json> }
        
        
        let $jsonG := json:serialize($groupUpload)
        let $uploadedGroups := <groupUpload>{
            let $response := if ($test-run)
                then file:write($common:ERP-PATH || 'groupUploadTest.xml', $groupUpload)
                else HTTPWrapper:putJSON(shop:protocol(), shop:host(), shop:port(), $shop:PATH-GROUPS, shop:user(), shop:pwd(), $jsonG)
            return try {
                json:parse($response)
            } catch * {
                <failed></failed>
            }
        }</groupUpload>
        
    (:    
        (: delete groups not needed any more :)
        let $jsonD := json:serialize($groupDelete)
        let $deletedGroups := (# basex:non-deterministic #) { <groupDelete>{
            let $response := HTTPWrapper:delete(shop:host(), xs:int(shop:port()), $shop:PATH-GROUPS, shop:user(), shop:pwd(), $jsonD)
            return try {
                json:parse($response)
            } catch * {
                <failed></failed>
            }
        }</groupDelete> }
    
        
        (: set customers which had special prices, but not any more, back to their Vk group :)
        let $customerReset := (# basex:non-deterministic #) {
            for $group in $groupDelete/_
            return if (starts-with($group/name/text(), 'Vk')) then (        (: not Vk0 customers :)
                let $groupNo := substring($group/name/text(), 1, 3)
                let $customerNo := substring($group/name/text(), 5)
                let $customer := <customer>
                    <number>{$customerNo}</number>
                    <attribute><swagPricegroup>{
                        let $oldBaseGroupId := $groups//_[name = concat('Vk', $groupNo)]/id
                        let $newBaseGroupId := $uploadedGroups//json/data/_[success = 'true']/data[name = concat('Vk', $groupNo)]/id
                        return if (empty($oldBaseGroupId)) then (
                            if (empty($newBaseGroupId)) then () else ($newBaseGroupId/text())
                        ) else ($oldBaseGroupId/text())
                    }</swagPricegroup></attribute>
                </customer>
                let $customerId := map:get($customersMap, $customerNo)/id
                return shop-customers:change-customer($customer, $customerId/text(), false())
            ) else (        (: Vk0 customers :)
                let $customerId := map:get($customersMap, _:addressNumber-by-groupName($group/name/text()))/id
                let $customer := <customer>
                    <number>{$group/name/text()}</number>
                    <attribute><swagPricegroup></swagPricegroup></attribute>
                </customer>
                where not(empty($customerId))
     (: toDo JSON string mit null :)           return shop-customers:change-customer($customer, $customerId/text(), false())
            )
        }
    :)    
        
        let $groupAssign := (# basex:non-deterministic #) { <customers>{
            for $group in $uploadedGroups//json/data/_[success = 'true']/data
            return <group>
                <customer>
                    <number>{_:addressNumber-by-groupName($group/name/text())}</number>
                    <attribute><swagPricegroup>{$group/id/text()}</swagPricegroup></attribute>
                </customer>
                {$group/name}
            </group>
        }</customers> }
    
    
        let $customerChange := (# basex:non-deterministic #) {
            for $customer in $groupAssign//group
            return if (string-length($customer/name/text()) < 5) then (
                let $groupNo := substring($customer/name/text(), 3, 1)
                let $vkCustomers := $articlesPriceGroups//customer[starts-with(priceGroupId, $groupNo)]
                return for $vkC in $vkCustomers
                    let $c := <customer>
                        {( $vkC/number,
                        $customer/customer/attribute )}
                    </customer>
                    let $customerId := map:get($customersMap, $vkC/number/text())/id
                    return shop-customers:change-customer($c, $customerId/text(), false(), $test-run)
            ) else (
                let $customerId := map:get($customersMap, _:addressNumber-by-groupName($customer/name/text()))/id
                return if (empty($customerId)) then () else (
                    shop-customers:change-customer($customer/customer, $customerId/text(), false(), $test-run)
                )
            )
        }
        
        let $xml-file := file:write($common:USERPRICEGROUPS-LOG,
            <upload>
                <dateTime>{current-dateTime()}</dateTime>
                {((:<customerReset>{$customerReset}</customerReset>, $deletedGroups,:) $uploadedGroups, $customerChange)}
            </upload>)
        
        return (<customerSwagPricegroupChange>{$customerChange}</customerSwagPricegroupChange>,
                admin:write-log("USERPRICEGROUPS UPDATE FINISHED"))
        (: ToDo: customers formerly with special prices :)


    } catch * {
        common:fatal-log($common:USERPRICEGROUPS-LOG, (<description>{$err:description}</description>, <module>{$err:module}</module>,
            <line>{$err:line-number}</line>, <trace>{$err:additional}</trace>))
    }
};

declare function _:get-groups() {
    let $x := (# basex:non-deterministic #) { _:upload-groups() }
    return if($x)
        then (_:groups(), admin:write-log("USERPRICES UPDATE - DOWNLOADING GROUPS"))
        else admin:write-log("ERROR IN UPLOAD GROUPS: " || serialize($x))
};


declare
  %rest:GET
  %rest:path("/shop/userprices/store-variants")
function _:store-variants() {
    let $variants := shop-articles:variants()
    return file:write($common:ERP-PATH || 'variants.xml', $variants)
};

(: :)
declare
  %rest:GET
  %rest:path("/shop/userprices/upload")
function _:upload-prices() {
    let $test-run := false()
    return try {
        let $log0 := admin:write-log('START USERPRICES UPLOAD')
        
        let $groups := if ($test-run) then _:groups() else _:get-groups()
        (: ToDo: set attribute/swagPricegroup in customer :)
        let $group-map := map:merge(
            for $g in $groups//_
            return map:entry($g/name/text(), $g)
        )
        
        let $price-delete := (# basex:non-deterministic #) { if ($test-run) then () else _:delete-prices() }
        let $log := admin:write-log('old prices deleted', 'INFO')
        
        let $prices := db:open($common:ERP-USERPRICE-DB, $common:ERP-USERPRICE-DB-FILE)
        let $prices-map := map:merge(
            for $p at $pos in $prices//userprice
            return if (empty($p/addressnumber/text()) or empty($p/articlenumber/text()) or empty($p/deviation/text())) then (
                admin:write-log('Missing entry in line ' || $pos || ' of user specific prices', 'WARNING')
            ) else (
                map:entry($pos, $p)
            )
        )
        let $customers := db:open($common:ERP-DB, $common:ERP-DB-FILE)
        let $noneZeroCustomers := $customers/customers/customer[priceGroupId != '0 Endkunden']
    
        let $variants := shop-articles:variants()
        let $variants-map := map:merge(
            for $v in $variants//data/_
            return map:entry($v/number/text(), <_>{($v/number, $v/articleId, $v/id)}</_>)
        )
        
(: start upload of prices for all customers with special prices and without special price group:)        
        let $specificPriceUpload := <json objects="_" arrays="json" numbers="priceGroupId articleId articleDetailsId">{
             (: specfic prices :)
            for $key in map:keys($prices-map)
            let $price := map:get($prices-map, $key)
            
            let $variant := map:get($variants-map, $price/articlenumber/text())
            return if (empty($variant)) then (admin:write-log('No article found for price ' || $price/articlenumber/text(), 'WARNING')) else (
                let $pgId := map:get($group-map, _:groupName-by-addressNumber( $price/addressnumber/text(), $noneZeroCustomers[billing/attribute/addressNumber = $price/adressnumber/text()] ))/id/text()
                
                return if (empty($pgId)) then () else (
                    _:price-from-specialPrices($pgId, $price, $variant)
                )
            )
        }</json>
        let $pricesJson := json:serialize($specificPriceUpload)
        let $pricesResult := _:wrap-specialprices-upload($pricesJson, 'specific', $test-run)
(: end upload of prices for all (none VkX, X>0) customers with special prices:)   
        
        
(: prices for price groups (VkX, X>0), with or without special prices :)

        let $articlePrices := db:open($common:ERP-PRICE-DB, $common:ERP-PRICE-DB-FILE)
        let $articlePrices-map := map:merge(
            for $p in $articlePrices//pricing
            return map:entry($p/articlenumber/text(), $p)
        )
(: numbers of customers with special prices :)
        let $groupNames := distinct-values($prices//userprice/addressnumber/text())
(: select customer numbers of customers with special prices and price group Vk1/Vk3/Vk6  -- possibly to be changed if more special price groups are defined :)
        let $specialCustomers := $noneZeroCustomers[some $VkN in $_:SPECIAL_VK_NUMBERS satisfies starts-with(priceGroupId, $VkN)][billing/attribute/addressNumber = $groupNames]/billing/attribute/addressNumber/text()
(: number of defined special price groups :)
        let $nVkGroups := count($_:SPECIAL_VK_GROUPS)
(: get all special group names, VkX (x!=0), VkX_customerNumber for all special customers :)
        let $specialGroupNames := ($_:SPECIAL_VK_GROUPS,
            for $g in $specialCustomers
            return _:groupName-by-addressNumber($g, $noneZeroCustomers[billing/attribute/addressNumber = $g])
        )
        let $price-userMap := map:merge(
            for $user in $specialCustomers
            return map:entry($user, $prices//userprice[addressnumber = $user])
        )
        
        let $groupsResult := for $sg at $pos in $specialGroupNames
        
            let $specialGroupVk := substring($sg, 3, 1)
(: for special customers select the numbers of articles with special prices :)
            let $specialGroupArticles := if ($pos <= $nVkGroups) then () else (
                map:get($price-userMap, $specialCustomers[$pos - $nVkGroups])/articlenumber/text()
            )
            let $pgId := map:get($group-map, $sg)/id/text()
            return if(empty($pgId)) then admin:write-log('No priceGroupId for group ' || $sg, 'WARNING') else
            
                let $specialGroupPriceUpload := <json objects="_" arrays="json" numbers="priceGroupId articleId articleDetailsId">{
                    for $variantNumber in map:keys($variants-map)
                    let $variant := map:get($variants-map, $variantNumber)
                    let $groupPrice := map:get($articlePrices-map, $variantNumber)/*[name() = concat('group', $specialGroupVk)]
                    return if (empty($groupPrice) and not($variantNumber = $specialGroupArticles))
                        then admin:write-log('No price for article number ' || $variantNumber || ' in group ' || $sg, 'WARNING') else (
                            
    (: special price:)      if ($variantNumber = $specialGroupArticles) then (
                                let $price := map:get($price-userMap, $specialCustomers[$pos - $nVkGroups])[articlenumber = $variantNumber]
                                return _:price-from-specialPrices($pgId, $price, $variant)
    (: group price :)       ) else (
                                let $vkPrices := shop-articles:transform-price-group($groupPrice, $variantNumber)
                                for $vkPrice at $pPos in $vkPrices/price
                                return <_>
                                    <priceGroupId>{$pgId}</priceGroupId>
                                    <from>{$vkPrice/amount/text()}</from>
                                    <to>{if ($pPos = count($vkPrices/price)) then ('beliebig') else (number($vkPrices/price[$pPos + 1]/amount/text()) - 1)}</to>
                                    <articleId>{$variant/articleId/text()}</articleId>
                                    <articleDetailsId>{$variant/id/text()}</articleDetailsId>
                                    <price>{shop-articles:price-replace($vkPrice/value/text())}</price>
                                </_>
                            )
                        )
                }</json>
                
                let $groupsJson := json:serialize($specialGroupPriceUpload)
                return _:wrap-specialprices-upload($groupsJson, $sg, $test-run)
        
        let $clearCache := (# basex:non-deterministic #) { <clearCache>{shop-articles:clear-caches()}</clearCache> }
        
        let $xml-file := file:write($common:USERPRICES-LOG, <upload><dateTime>{current-dateTime()}</dateTime>{($pricesResult, $groupsResult)}</upload>)
        return (<upload>{($pricesResult, $groupsResult)}</upload>,
                admin:write-log('FINISHED USERPRICES UPLOAD'))
    
    } catch * {
        (common:fatal-log($common:USERPRICES-LOG, (<description>{$err:description}</description>, <module>{$err:module}</module>,
            <line>{$err:line-number}</line>, <trace>{$err:additional}</trace>)),
            admin:write-log('FATAL ERROR USERPRICES UPLOAD'))
    }
};


declare function _:wrap-specialprices-upload($json, $group, $test-run as xs:boolean) {
    let $upload := if ($test-run)
        then file:write-text($common:ERP-PATH || 'pricesUploadTest_' || $group || '.xml', $json)
        else HTTPWrapper:putJSON(shop:protocol(), shop:host(), shop:port(), $shop:PATH-PRICES, shop:user(), shop:pwd(), $json)
    return try {
        json:parse($upload)
    } catch * {
        <failed>{$upload}</failed>
    }
};


declare function _:price-from-specialPrices($priceGroupId as xs:string, $price as element(), $variant as element()) as item()* {
    let $multiPrice := _:multi-price($price)

    return if (empty($multiPrice/pricestep) or (count($multiPrice/pricestep) = 1) or ($price/discountable/text() = 'FALSE')) then (
        <_>
            <priceGroupId>{$priceGroupId}</priceGroupId>
            <from>1</from>
            <to>beliebig</to>
            <articleId>{$variant/articleId/text()}</articleId>
            <articleDetailsId>{$variant/id/text()}</articleDetailsId>
            <price>{
            replace(
                if (($price/discountable/text() = 'FALSE') or (empty($multiPrice/pricestep))) then ($price/deviation/text()) else ($multiPrice/pricestep/price/text()), ',', '.')
            }</price>
        </_>
    ) else (
        (
            if ($multiPrice/pricestep[1]/amount/text() = 1) then () else (
                <_>
                    <priceGroupId>{$priceGroupId}</priceGroupId>
                    <from>1</from>
                    <to>{number($multiPrice/pricestep[1]/amount/text()) - 1}</to>
                    <articleId>{$variant/articleId/text()}</articleId>
                    <articleDetailsId>{$variant/id/text()}</articleDetailsId>
                    <price>{replace($price/deviation/text(), ',', '.')}</price>
                </_>
            )
        ,
            for $step at $pos in $multiPrice/pricestep
            return 
            <_>
                <priceGroupId>{$priceGroupId}</priceGroupId>
                <from>{$step/amount/text()}</from>
                <to>{if ($pos = count($multiPrice/pricestep)) then ('beliebig') else (number($multiPrice/pricestep[$pos + 1]/amount/text()) - 1)}</to>
                <articleId>{$variant/articleId/text()}</articleId>
                <articleDetailsId>{$variant/id/text()}</articleDetailsId>
                <price>{replace($step/price/text(), ',', '.')}</price>
            </_>
        )
    )
};

declare function _:multi-price($price as element()) as item() {
    let $amounts := $price//amount[text() != '']
    let $prices := $price//price[text() != '']
    return if ((empty($amounts)) or (count($amounts) != count($prices))) then (<groups></groups>) else (
        <groups>{
            for $amount at $pos in $amounts
            return <pricestep>
                {($amount, $prices[$pos])}
            </pricestep>
        }</groups>
    )
};


declare function _:groupName-by-addressNumber($addressNumber, $noneZeroCustomer as element()* ) as xs:string {
    if (empty($noneZeroCustomer)) then (
        $addressNumber
    ) else (    (: customers with special prices and price group != Vk0 get extra number :)
        if (some $VkN in $_:SPECIAL_VK_NUMBERS satisfies starts-with($noneZeroCustomer/priceGroupId, $VkN)) then (
            'Vk' || substring($noneZeroCustomer/priceGroupId, 1, 1) || '_' || $addressNumber
        (:)
        if (starts-with($noneZeroCustomer/priceGroupId, '1')) then (
            concat('Vk1_', $addressNumber)
        ) else if (starts-with($noneZeroCustomer/priceGroupId, '6')) then (
            concat('Vk6_', $addressNumber):)
        ) else (
            $addressNumber
        )
    )
};


declare function _:addressNumber-by-groupName($groupName as xs:string) as xs:string {
    if (starts-with($groupName, 'Vk')) then (
        if (string-length($groupName) < 5) then ('') else substring($groupName, 5)
    ) else (
        $groupName
    )
};


declare
  %rest:GET
  %rest:path("/shop/userprices/report")
  %output:method("xhtml")
  %output:html-version("5.0")
function _:create-userprices-report() {
<html>
</html>
};

declare
  %rest:GET
  %rest:path("/shop/userprices/test-multiprice")
function _:test-multi-price() {
    let $price := <userprice>
        <addressnumber>21392</addressnumber>
        <articlenumber>123413</articlenumber>
        <deviation>0,51</deviation>
        <discountable>TRUE</discountable>
        <group0><amount/><rate/><price/></group0>
        <group1><amount/><rate/><price/></group1>
        <group2><amount/><rate/><price/></group2>
        <group3><amount/><price/></group3>
    </userprice>
    return _:multi-price($price)
};