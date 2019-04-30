module namespace _= "custom/shop/shop-articles";

import module namespace functx = "http://www.functx.com";
import module namespace conf = "pim/config";
import module namespace shop = "custom/shop/config";

import module namespace shop-customers = "custom/shop/shop-customers" at "shop-customers.xqm";
import module namespace common = "custom/shop/shop-common" at "shop-common.xqm";

import module namespace HTTPWrapper = 'de.axxepta.syncrovet.http.HTTPWrapper';

declare variable $_:NO_SHIPPING := 'Defekt';

declare
  %rest:GET
  %rest:path("/shop/caches")
function _:clear-caches() as element()* {
    let $delete := HTTPWrapper:delete(shop:protocol(), shop:host(), shop:port(), $shop:PATH-CACHES, shop:user(), shop:pwd())
    return try {
        <cache>{json:parse($delete)}</cache>
    } catch * {
        <failed>{$delete}</failed>
    }
};

declare
  %rest:GET
  %rest:path("/shop/articles")
function _:articles() as item() {
    common:get-request(shop:protocol(), shop:host(), shop:port(), concat($shop:PATH-ARTICLES, '?limit=500000'))
};

declare function _:articles($params as xs:string) as item() {
    common:get-request(shop:protocol(), shop:host(), shop:port(), concat($shop:PATH-ARTICLES, '?limit=500000&amp;', $params))
};

declare
  %rest:GET
  %rest:path("/shop/variants")
function _:variants() as item() {
    let $limit := 2000
    let $number := common:get-request(shop:protocol(), shop:host(), shop:port(), concat($shop:PATH-VARIANTS, '?limit=1'))/json/total/string()
    return <json type="object"><data type="array">{
        for $looper in (1 to xs:int(ceiling(xs:int($number) div $limit)))
        return common:get-request(shop:protocol(), shop:host(), shop:port(), concat($shop:PATH-VARIANTS, '?limit=' || $limit || '&amp;start=' || ($looper - 1) * $limit ))/json/data/_
    }</data></json>
};

declare function _:variants($params as xs:string) as item() {
    common:get-request(shop:protocol(), shop:host(), shop:port(), concat($shop:PATH-VARIANTS, '?limit=500000&amp;', $params))
};

declare
  %rest:GET
  %rest:path("/shop/media")
function _:media() as item() {
    common:get-request(shop:protocol(), shop:host(), shop:port(), concat($shop:PATH-MEDIA, '?limit=500000'))
};

declare function _:media-album($filter as xs:string) as item() {
    let $limit := 2000
    let $number := common:get-request(shop:protocol(), shop:host(), shop:port(), $shop:PATH-MEDIA || '?limit=1&amp;' || $filter)/json/total/string()
    return <json type="object"><data type="array">{
        for $looper in (1 to xs:int(ceiling(xs:int($number) div $limit)))
        return common:get-request(shop:protocol(), shop:host(), shop:port(), $shop:PATH-MEDIA || '?' || $filter || '&amp;limit=' || $limit || '&amp;start=' || ($looper - 1) * $limit)/json/data/_
    }</data></json>
};

declare
  %rest:GET
  %rest:path("/shop/categories")
function _:categories() as item() {
    common:get-request(shop:protocol(), shop:host(), shop:port(), concat($shop:PATH-CATEGORIES, '?limit=500000'))
};

declare
  %rest:GET
  %rest:path("/shop/categories/{$id}")
function _:category($id) as item() {
    common:get-request(shop:protocol(), shop:host(), shop:port(), $shop:PATH-CATEGORIES || $id)
};

declare
  %rest:GET
  %rest:path("/shop/categories/{$name}/{$parent-id}")
function _:new-category($name as xs:string, $parent-id as xs:string) as item() {
    let $content := '{ "parentId" : ' || $parent-id || ', "name" : "' || $name || '"}'       
    return common:post-request(shop:protocol(), shop:host(), shop:port(), $shop:PATH-CATEGORIES, $content)/json/data/id/text()
};

declare
  %rest:GET
  %rest:path("/shop/propertyGroups")
function _:propertyGroups() as item() {
    common:get-request(shop:protocol(), shop:host(), shop:port(), $shop:PATH-PROPERTYGROUPS)
};

declare
  %rest:GET
  %rest:path("/shop/articles/delete")
function _:delete-articles() {
    let $articles := _:articles()
    let $articleDelete := <json arrays="json" objects="_">{
        for $article in $articles//data/_
        return <_>{$article/id}</_>
    }</json>
    let $ids := string-join($articleDelete/_/id/text(), ',')
    let $json := json:serialize($articleDelete)
    let $upload := HTTPWrapper:delete(shop:protocol(), shop:host(), xs:int(shop:port()), $shop:PATH-ARTICLES, shop:user(), shop:pwd(), $json)
    return try {
        json:parse($upload)
    } catch * {
        <failed>{$upload}</failed>
    }
};


declare function _:filter-get($f as function(xs:string) as item(),
        $numbers as xs:string*,
        $useNumberAsId as xs:boolean,
        $filterProperty as xs:string
) as element()* {
    let $size := 75
    for $batch in 1 to xs:integer(ceiling(count($numbers) div $size))
    let $filterValues := for $number at $pos in subsequence($numbers, $size * ($batch - 1) + 1, $size)
        return concat('filter[0][value][', $pos - 1, ']=', $number)
    let $queryString := concat( (if ($useNumberAsId) then ('useNumberAsId=true&amp;') else ()) ,
        'filter[0][property]=', $filterProperty, '&amp;',
        string-join($filterValues, '&amp;')
    )
    (: return concat($queryString, '&#10;') :)
    return ($f($queryString))//_
};


declare
  %rest:GET
  %rest:path("/shop/articles/deletesection/{$id}")
function _:delete-section-articles($id as xs:integer) {
    let $sections := common:pim-get( '/pim/api/publications/' || encode-for-uri('Webshop.xml') || '/sections' )/Sections/Section
    let $section := $sections[$id]
    let $articles := common:pim-get( '/pim/api/publications/' || $section/@Guid || '?pub-type=' || encode-for-uri('Webshop') )
    let $oldVariants := _:filter-get(_:variants(?), $articles/ProductInfo/ProductItem/SupplierArticleId/text(), true(), 'number')
    let $oldArticles := _:filter-get(_:articles(?), $articles/ProductInfo/ProductItem/SupplierArticleId/text(), true(), 'mainDetail.number')
    let $oldArticleIds := distinct-values(($oldVariants/articleId/text(), $oldArticles/id/text()))
    let $articleDelete := <json arrays="json" objects="_">{
        for $oldId in $oldArticleIds
        return <_><id>{$oldId}</id></_>
    }</json>
    let $ids := string-join($articleDelete/_/id/text(), ',')
    let $json := json:serialize($articleDelete)
    let $upload := HTTPWrapper:delete(shop:protocol(), shop:host(), xs:int(shop:port()), $shop:PATH-ARTICLES, shop:user(), shop:pwd(), $json)
    return try {
        json:parse($upload)
    } catch * {
        <failed>{$upload}</failed>
    }
};


declare
  %rest:GET
  %rest:path("/shop/articles/upload")
function _:upload-articles() {

 _:upload-articles-by-section(())
};


declare
  %rest:GET
  %rest:path("/shop/articles/uploadsection/{$id}")
  %rest:single
function _:upload-articles-by-section($id as xs:string?) {
    let $test-run := false()
    
    let $delete-media-assignments := false() (: remove all media assignments from articles :)
    
    let $log := admin:write-log('START ARTICLES UPLOAD')
        
    return try {
        
        let $media := _:media-album(_:image-filter())//data/_
        let $downloads := _:media-album(_:download-filter())//data/_
        
        let $restrictedGroupId := <id>9</id> (:shop-customers:customerGroups()/json/data/_[key = 'IK']/id :)
        
        let $shopCategories := doc('../../../data/shop/categories.xml')/json/data (: _:categories()/json/data/_ :)
        let $praxisId := '5'
        let $petShopId := '24'
        let $pflegeHygieneId := '145'
        let $diaetErgaenzungId := '30'
        let $qualitaetId := '210'
        (: categories visible for IK customers :)
        let $unrestrictedCategoryIds := ($shopCategories[parentId = ($shopCategories[parentId = $praxisId]/id/text())]/id/text(),
                                    $shopCategories[parentId = $petShopId]/id/text(), 
                                    $shopCategories[parentId = $pflegeHygieneId]/id/text(),
                                    $shopCategories[parentId = $diaetErgaenzungId]/id/text(),
                                    $shopCategories[parentId = $qualitaetId]/id/text()
                                    )
        
        let $propertyDef := doc('../../../data/shop/properties.xml') (:  _:properties() :)
        
        let $log1 := admin:write-log('article upload started')
        
        let $all-sections := doc('../../../data/articles/webshop.xml')/Sections/Section (: common:pim-get( '/pim/api/publications/' || encode-for-uri('Webshop.xml') || '/sections' )/Sections/Section :)

        let $sections := if(empty($id)) then $all-sections else $all-sections[@Guid = $id]
        
        let $l-s0 :=  admin:write-log('sections: ' || string-join($sections/Title, ', '))
    
        let $category-map := map:merge(
            for $a in $all-sections//ProductItem
            let $guid := $a/@Guid
            group by $guid
            return map:entry($guid, 
                <categories>{
                    for $s in $a/parent::*/parent::Section
                    where $s/ShopCategoryId/text() = $shopCategories/id/text()
                    return <_><id>{$s/ShopCategoryId/text()}</id></_>
                }</categories>
            )
        )
        
        let $categoryStatus := <webshopCategories>{
            for $c in $all-sections
            where not($c/ShopCategoryId/text() = $shopCategories/id/text())
            return <notValid>{($c/Title, $c/ShopCategoryId)}</notValid>
        }</webshopCategories>
        let $webshop-file := file:write($common:WEBSHOP-LOG, $categoryStatus)
        
        let $prices := db:open($common:ERP-PRICE-DB, $common:ERP-PRICE-DB-FILE)/prices/pricing
        let $prices-map := map:merge(
            for $p in $prices
            return map:entry($p/articlenumber/text(), $p)
        )
        
        let $store := db:open($common:ERP-STORE-DB, $common:ERP-STORE-DB-FILE)//article
        let $store-map := map:merge(
            for $s in $store
            return map:entry($s/number/text(), $s)
        )
        
        let $index := db:open($common:ERP-INDEX-DB, $common:ERP-INDEX-DB-FILE)//article
        let $index-map := map:merge(
            for $i in $index
            return map:entry($i/number/text(), $i/reboSortIndex)
        )
        
        
        let $articlesUpload := <upload>{
        (   
        
            let $log2 := admin:write-log('maps created')
            
            for $section at $sPos in $sections
            
            where $section/ProductInfo
            
            let $articles := doc('../../../data/articles/section_7a905858-4d33-445f-ae3c-9a96201a5a26.xml')/articles/*  (: common:pim-get( '/pim/api/publications/' || $section/@Guid || '/transformed?pub-type=' || encode-for-uri('Shop') )/articles/* :)
            
            return <section title="{string($section/Title)}">{
            
                let $articleUpload := <json objects="article mainDetail configuratorSet attribute propertyGroup option _" booleans="active isMain notification lastStock"
                    arrays="json categories prices variants configuratorOptions groups options images customerGroups propertyValues" numbers="id mediaId tax from price inStock">{
                    
                    let $oldVariants := _:filter-get(_:variants(?), $articles/ProductInfo/ProductItem/SupplierArticleId/text(), true(), 'number')
                    let $oldArticles := _:filter-get(_:articles(?), $articles/ProductInfo/ProductItem/SupplierArticleId/text(), true(), 'mainDetail.number')
                    
                    for $article in $articles/ProductInfo
                    let $l-a0 :=  admin:write-log('product: ' || $article/ProductName || ' - '  || $article/@Guid)
                        
                    let $singleItem := (count($article//ProductItem) = 0)
    
                    return for $item at $pos in $article//ProductItem
                        
                    let $category := map:get($category-map, $item/@Guid)
                   (: Any unrestricted works :)
                    let $unrestrictedCategory := ($category/_/id/text() = $unrestrictedCategoryIds)
            
                    return if (empty($category/_) or (empty($id) and ($category/_[1]/id/text() != $section/ShopCategoryId/text()))) then () else (
                           
                        let $oldArticleIds := distinct-values(($oldVariants[number = $item/SupplierArticleId/text()]/articleId/text(),
                            $oldArticles[mainDetailId = $item/SupplierArticleId/text()]/id/text()))
                        let $oldArticleId := if (empty($oldArticleIds)) then () else (<id>{$oldArticleIds[1]}</id>)
                        
                        let $pric := map:get($prices-map, $item/SupplierArticleId/text())
                        let $priceDeactivate := empty($pric) or empty($pric//price[1]/text()) or (number(($pric//price)[1]/text()) <= 0)
                        let $tax := if (empty($item/Feature[@Key = 'Steuerschlüssel'])) then '19' else 
                            let $tax-val := tokenize($item/Feature[@Key = 'Steuerschlüssel']/text(), ' ')
                            return substring($tax-val[count($tax-val)], 1, string-length($tax-val[count($tax-val)]) - 1)
                        
                        let $log := if(empty($pric)) then admin:write-log('empty price for  ' || $item/SupplierArticleId/text() || ' ' || string-join($pric//text(), ' '), 'WARNING') else ()
                        let $pricing := _:transform-price( if(empty($pric)) then _:empty-pricing($item/SupplierArticleId/text()) else $pric)
                        
                        let $shipping := map:get($store-map, $item/SupplierArticleId/text())                     
    
                        let $imageNames := _:file-names(($item/Image, $article/Image))
                        let $images := if ($delete-media-assignments) then _:clear-images() else _:images($imageNames, $media, empty($oldArticleId))
                        
                        (:
                        let $downloadNames := _:file-names(($item/Document, $article/Document))
                        
                        let $download := if (empty($downloadNames)) then () else (
                            _:downloads($downloadNames, $downloads[name = $downloadNames])
                        )
                        :)
                        
                        let $mainDetail := _:detail($article, $pos, $pricing, $priceDeactivate, $shipping, $oldArticles[id = $oldArticleId]/mainDetailId)
                        let $newArticle := _:transform-article($article, $oldArticleId, $pos, true(), $mainDetail, $tax,
                                    $category, $images, (), (: $download,:)  $unrestrictedCategory, $restrictedGroupId, (), (), map:get($index-map, $item/SupplierArticleId/text()), $propertyDef)
    
                        return $newArticle
                    )
                
                }</json>
                
                (: return $articleUpload :)
                (: return $json :)
                
                return try {
                
                    let $xml-log :=  file:write($common:ARTICLES-LOG || "-" || $section/ShopCategoryId || ".xml", $articleUpload) 
                    let $json := json:serialize($articleUpload)
                    let $json-log :=  file:write($common:ARTICLES-LOG || "-" || $section/ShopCategoryId || ".json", $json) 
                    let $log4 :=    admin:write-log(concat('section serialized ', $section/Title/text()))
                    let $upload := if ($test-run)
                        then ()
                        else HTTPWrapper:putJSON(shop:protocol(), shop:host(), shop:port(), $shop:PATH-ARTICLES, shop:user(), shop:pwd(), $json)
                    let $log5 :=    admin:write-log(concat('section uploaded ', $section/Title/text()))
                    
                    return try {
                        json:parse($upload)
                    } catch * {
                        <failed>{$upload}</failed>
                    }
                
                } catch * {
                    <fatal>
                        <description>{$err:description}</description>
                        <module>{$err:module}</module>
                        <line>{$err:line-number}</line>
                        <trace>{$err:additional}</trace>
                        {$articleUpload}
                    </fatal>
                }
                
            }</section>
         ,
           (# basex:non-deterministic #) { <clearCache>{_:clear-caches()}</clearCache> }
           
        )
        }</upload>
        
        let $xml-file := file:write($common:ARTICLES-LOG, $articlesUpload update {insert node <dateTime>{current-dateTime()}</dateTime> into .})
        
        return  (<upload><success>{$common:ARTICLES-LOG-PATH}</success></upload>,
                admin:write-log('FINISHED ARTICLES UPLOAD'))
    
    } catch * {
        (common:fatal-log($common:ARTICLES-LOG, (<description>{$err:description}</description>, <module>{$err:module}</module>,
            <line>{$err:line-number}</line>, <trace>{$err:additional}</trace>)),
            admin:write-log('FATAL ERROR ARTICLES UPLOAD'))
    }
};

(: Notizen:
   api/variants  ('Shopware\Models\Article\Detail')
   
   api/articles  (\Shopware\Models\Article\Article::class)
   * "lastStock": false/true        (nicht verkaufbar bei amount <= 0)
   * "notification": true/false     (E-Mail Erinnerung anbieten)

:) 
declare
  %rest:GET
  %rest:path("/shop/articles/stockupdate")
function _:update-article-stock() {
    try {
        let $log := admin:write-log('START STOCK UPLOAD')
        
        (: get all variants from shop :)
        let $variants := _:variants()//data/_
        (: open stock info :)
        let $store := db:open($common:ERP-STORE-DB, $common:ERP-STORE-DB-FILE)
        
        let $storeMap := map:merge(
            for $article in $store/store/article
            return map:entry($article/number/text(), $article)
        )
        
        let $stockUpdate := <json objects="_" arrays="json" numbers="id inStock" booleans="active notification">{
            for $variant in $variants
            let $shipping := map:get($storeMap, $variant/number/text())
            
            let $shippingTime := _:shipping-time($shipping)
            let $active := if($shipping/inactive/text() = 'TRUE') then 'false' else 'true'
            let $amount :=  if($shippingTime = $_:NO_SHIPPING) then '0' else '1000' (: $shipping/amount/text() :)
            
            (: only update if any of active, shippingTime or inStock changed :)
            
            (: and $amount = $variant/inStock/text() :)
            return if ($shippingTime = $variant/shippingTime/text() and $active = $variant/active/text()) then () else (
                <_>{(
                $variant/id,
                <active>{$active}</active>,
                <inStock>0</inStock>,
                <shippingTime>{$shippingTime}</shippingTime>
                )}</_>
            )
        }</json>
        
        let $json := json:serialize($stockUpdate)
        let $upload := HTTPWrapper:putJSON(shop:protocol(), shop:host(), shop:port(), $shop:PATH-VARIANTS, shop:user(), shop:pwd(), $json)
        
        let $stockUpload := try {
            let $response := json:parse($upload)
            return <upload><dateTime>{current-dateTime()}</dateTime>{$response}</upload>
        } catch * {
            <upload><dateTime>{current-dateTime()}</dateTime><fatal>{$upload}</fatal></upload>
        }
        let $xml-file := file:write($common:STOCK-LOG, $stockUpload)
        return ($stockUpload,
                admin:write-log('FINISHED STOCK UPLOAD'))
    } catch * {
        (common:fatal-log($common:STOCK-LOG, (<description>{$err:description}</description>, <module>{$err:module}</module>,
            <line>{$err:line-number}</line>, <trace>{$err:additional}</trace>)),
            admin:write-log('FATAL ERROR STOCK UPLOAD'))
    }
};


declare function _:configurator-set($article as item()) as element() {
    <configuratorSet>
        <groups>
            <_>
                <name>Varianten</name>
                <options>{
                    for $item in $article//ProductItem
                    return <_>{
                        <name>{_:variant-name($item)}</name>
                    }</_>
                }</options>
            </_>
        </groups>
    </configuratorSet>
};

(: toDo: if activated again, adjust active status :)
declare function _:build-variants(
    $article as item(),
    $prices-map as map(*),
    $store-map as map(*),
    $oldVariants as item()*
) as element() {
    <variants>{
        for $item at $pos in $article//ProductItem
        let $pric := map:get($prices-map, $item/SupplierArticleId/text())
        let $shipping := map:get($store-map, $item/SupplierArticleId/text())
        let $pricing := if (empty($pric)) then (<prices></prices>) else (_:transform-price($pric))
        let $textItem := $item/Text[Key/text() = 'Beschreibung']/xhtml
        return <_>
            <isMain>{if ($pos = 1) then ("true") else ("false")}</isMain>
            <active>true</active>
            {(
                let $oldVariant := $oldVariants[number = $item/SupplierArticleId/text()]
                return if (empty($oldVariant)) then () else ($oldVariant/id)
            ,
                if (empty($shipping)) then () else ($shipping[1]/shippingTime)
            ,
                if (empty($textItem)) then () else (<additionalText>{serialize($textItem/*)}</additionalText>)
            ,
                $pricing
            )}
            <number>{$item/SupplierArticleId/text()}</number>
            <configuratorOptions>
                <_>
                    <group>Varianten</group>
                    <option>{_:variant-name($item)}</option>
                </_>
            </configuratorOptions>
        </_>
    }</variants>
};

declare function _:variant-name($item as item()*) as xs:string {
    concat($item/Name/text(), ' (', $item/SupplierArticleId/text(), ')')
};

declare function _:identify-category($cat as element()*, $categories as element()) as element() {
    <categories>{
        if (empty($cat)) then () else (
            let $revCat := reverse($cat)
            let $category := <_><id>{$categories//_[name = $revCat[1]/text()]/id/text()}</id></_>
            return if (empty($category/id/text())) then () else (
                $category
            )
        )
    }</categories>
};


declare function _:file-names($file-elements as element()*) as xs:string* {
    if (empty($file-elements)) then () else (
        for $el in $file-elements
        return tokenize(string($el/@Source), '\.')[1]
    )
};


declare function _:images($imageNames as xs:string*, $media as element()*, $newArticle as xs:boolean) as element()* {
    let $oldImages := for $img in $imageNames 
                      return ($media[starts-with(name, $img)])[1]
                      
    return (
        <____options__images type="object"><replace type="boolean">true</replace></____options__images>,
        <images>{
            for $image in $imageNames
            let $oldImage := ($oldImages[starts-with(name, $image)])[1]
            
            return if (empty($oldImage)) then (
                <_><link>file://{ $shop:PHP-PATH-DOCUMENTS || $image}.jpg</link></_>
            ) else (
                <_><mediaId>{$oldImage/id/text()}</mediaId></_>
            )
        }</images>
    )
};

(: replace image variable with this to erase all image assignments :)
declare function _:clear-images() as element()* {
    (<____options__images type="object"><replace type="boolean">true</replace></____options__images>,<images><_/></images>)
};

declare function _:downloads($downloadNames as xs:string*, $oldFiles as element()*) as element()* {
    <downloads>{
        for $file in $downloadNames
        let $oldFile := ($oldFiles[name = $file])
        return if (empty($oldFile)) then (
            <_><link>file://{ $shop:PDF-PATH-DOCUMENTS || $file}.pdf</link></_>
        ) else (
            <_>
                {$oldFile/name}
                <file>media/pdf/{ $oldFile/name/text() }.pdf</file>
                <size>{$oldFile/fileSize/text()}</size>
            </_>
        )
    }</downloads>
};


(: if($shippingTime = $_:NO_SHIPPING) then '0' else '1000'  :)
declare function _:detail($article as item(),
                          $index as xs:integer,
                          $prices as element(),
                          $priceDeactivate as xs:boolean,
                          $shipping as item()*, $oldMainDetailId as node()*)
{
  let $shippingTime := _:shipping-time($shipping)
  let $amount := $shipping/amount/text()
  return
    <mainDetail>
        <active>{
            if ($priceDeactivate or ($shipping/inactive/text() = 'TRUE')) then (
                'false', admin:write-log(concat('ARTICLE DEACTIVATED ', $article/ProductItem[$index]/SupplierArticleId/text()), 'INFO')
            ) else 'true'
        }</active>

          <shippingTime>{$shippingTime}</shippingTime> 
          <inStock>0</inStock>
        {(
            if (empty($oldMainDetailId)) then () else (<id>{$oldMainDetailId[1]/text()}</id>)
        ,
            $prices
        )}
        <number>{$article/ProductItem[$index]/SupplierArticleId/text()}</number>
    </mainDetail>
};


declare function _:shipping-time($shipping as item()*) {

        if (empty($shipping)) then 'auf Anfrage' else (
            if ($shipping/locked/text() = 'TRUE') then $_:NO_SHIPPING else (
                if (empty($shipping/amount/text()) or (xs:int($shipping/amount/text()) <= 1)) then (
                    if (empty($shipping/shippingTime/text())) then 'auf Anfrage' 
                    (: translate e.g. 2-3 to 4-5 :)
                    else translate($shipping/shippingTime/text(), '01234567', '23456789')
                ) else '1-2 Tage'
            )
        )
};


declare function _:transform-article($article as element(),
                                     $oldId as xs:string?,
                                     $index as xs:integer,
                                     $isVariant as xs:boolean,
                                     $detail as element(),
                                     $tax as xs:string,
                                     $categories as element(),
                                     $images as element()*,
                                     $downloads as element()?,
                                     $unrestrictedArticle as xs:boolean,         (: articles sorted not in praxis have to be hidden for customer Group IK:)
                                     $restrictedGroupId as element(),
                                     $configuratorSet,
                                     $variants,
                                     $reboSortIndex as element()?,
                                     $propertyDef as map(*))
{
    (: item or product feature :)
    let $producer := ($article/ProductItem[$index]/Feature[@Key = 'Firmenbezeichnung'], $article/Feature[@Key = 'Firmenbezeichnung'])[1]/text()
    let $company := ($article/ProductItem[$index]/Feature[@Key = 'Pharmaz. Unternehmer'], $article/Feature[@Key = 'Pharmaz. Unternehmer'])[1]/text()
    let $pzn := ($article/ProductItem[$index]/Feature[@Key = 'PZN'], $article/Feature[@Key = 'PZN'])[1]/text()
    let $substances := ($article/ProductItem[$index]/Feature[@Key = 'Wirkstoffe'], $article/Feature[@Key = 'Wirkstoffe'])[1]/text()
    let $pharmaceuticalForm := ($article/ProductItem[$index]/Feature[@Key = 'Darreichungsform'], $article/Feature[@Key = 'Darreichungsform'])[1]/text()
    let $wk := string-join($article/WK, ' ')
    let $name-token := if ($isVariant) then tokenize($article/ProductItem[$index]/Name, ' ') else tokenize($article/ProductName, ' ')
    let $name-token2 := if(string-length($name-token[1]) < 5) then $name-token[1] || ' ' || $name-token[2] else substring($name-token[1], 1, 4)
    let $name-token3 := if(string-length($name-token[1]) > 7) then substring($name-token[1], 1, 6) else ''
    let $name-token4 := if(string-length($name-token[1]) > 9) then substring($name-token[1], 1, 8) else ''
    
    let $keywords :=  $name-token[1] || ' ' || $name-token2 || ' ' || $name-token3 || ' ' || $name-token4 || ' '  || $wk || ' ' || $substances || ' ' || $pzn
    
    let $text1 := ($article/ProductItem[$index]/Text[@Key = 'Beschreibung'], $article/Text[@Key = 'Beschreibung'])[1]
    let $text2 := ($article/ProductItem[$index]/Text[@Key = 'Technische Daten'], $article/Text[@Key = 'Technische Daten'])[1]
    
    let $lastStock-and-notify := if($detail/shippingTime/text() = $_:NO_SHIPPING) then 'true' else 'false'
    return
    <_>
        <name>{if ($isVariant) then (
            $article/ProductItem[$index]/Name/text()
        ) else (
            $article/ProductName/text()
        )
        }</name>
        <active>{
            if($detail/active/text()) then $detail/active/text() else 'true'
           (: if ((contains(lower-case($article/Feature[@Key = 'Gesperrt']), 'true')) or (contains(lower-case($article/ProductItem[$index]/Feature[@Key = 'Gesperrt']), 'true'))) then 'false' else 'true' :)
        }</active>
        <keywords>{$keywords}</keywords>
        <tax>{$tax}</tax>
        <supplier>{if ($producer != '') then $producer else if ($company != '') then $company else 'Sonstiges'}</supplier>
        <description>{
            if ($isVariant) then (
                $article/ProductName/text()
            ) else (
                $article/ProductItem[$index]/Name/text()
            )
        }</description>
        <lastStock>{$lastStock-and-notify}</lastStock>
        <notification>{$lastStock-and-notify}</notification>
        <attribute>{(
            $reboSortIndex
            ,
            <axxCoolingRequ>{if (not(empty($article/ProductItem[$index]/Feature[@Key = 'Temperatur Eigenschaften'])) and contains($article/ProductItem[$index]/Feature[@Key = 'Temperatur Eigenschaften'], 'Kühlkette')) then '1' else '0'}</axxCoolingRequ>
        )}</attribute>
        {(
            if (empty($oldId)) then () else (<id>{$oldId}</id>)
            ,
            let $textMain := $article/Text[Key/text() = 'Beschreibung']/xhtml
            let $textItem := $article/ProductItem[$index]/Text[Key/text() = 'Beschreibung']/xhtml
            return if (empty($textMain) and empty($textItem)) then () else (
                <descriptionLong>{(
                  serialize($text1/xhtml/node()),
                   serialize($text2/xhtml/node())
                (: if (empty($textMain)) then () else (serialize($textMain/*)),
                if (empty($textItem) and not($isVariant)) then () else (serialize($textItem/*)) :)
                
                )}</descriptionLong>
            ),
           if ((not(empty($substances)) and ($substances != '')) or (not(empty($pharmaceuticalForm)) and ($pharmaceuticalForm != ''))) then (
                let $propertyGroup :=map:get($propertyDef, 'Medikamente')
                where not(empty($propertyGroup))
                return (<filterGroupId>{$propertyGroup/id/text()}</filterGroupId>,
                <propertyValues>{(
                    if (not(empty($substances)) and ($substances != '')) then (
                         let $substanceSeq := tokenize($substances, ', ') 
                         for $substance in distinct-values($substanceSeq)
                         return 
                         (: NOTE: cannot have multiple identical values AND not exceed 255 chars :)
                            <_>
                                <option><name>Wirkstoff</name></option>
                                <value>{substring($substance, 1, 254)}</value>
                            </_>
                    ) else ()
                    ,
                    if (not(empty($pharmaceuticalForm)) and ($pharmaceuticalForm != '')) then (
                        <_>
                            <option><name>Darreichungsform</name></option>
                            <value>{substring($pharmaceuticalForm, 1, 254)}</value>
                        </_> 
                     ) else ()
                
                )}</propertyValues>)
            ) else ()
            , 
            if ($unrestrictedArticle) then (
                <customerGroups></customerGroups>
            ) else (
                <customerGroups><_>{$restrictedGroupId}</_></customerGroups>
            ),
            $categories,
            $images,
            $downloads,
            $detail,
            $configuratorSet,
            $variants
        )}
    </_>
};


declare function _:properties() {
    let $propertyGroups := _:propertyGroups()//data/_
    return map:merge(
        for $group in $propertyGroups
        for $option in $group/options
        return map:entry($group/name/text(), $group)
    )
};

declare function _:transform-price($price as element()) {
    let $customerGroups := ('EK', 'IK', 'GK', 'GSK')
    return <prices>{
        for $group in (0 to 0)
        let $groupName := concat('group', string($group))
        let $p := _:transform-price-group($price/*[name()=$groupName], $price/articlenumber/text())
        let $count := count($p/price)
        return for $step at $pos in $p/price
            return if ($pos = $count)
                then (<_>
                        <customerGroupKey>{$customerGroups[$group + 1]}</customerGroupKey>
                        <from>{$step/amount/text()}</from>
                        <to>beliebig</to>
                        <price>{_:price-replace($step/value/text())}</price>
                        {$step/pseudoPrice}
                    </_>)
                else (<_>
                        <customerGroupKey>{$customerGroups[$group + 1]}</customerGroupKey>
                        <from>{$step/amount/text()}</from>
                        <to>{string(number($p/price[$pos + 1]/amount/text()) - 1)}</to>
                        <price>{_:price-replace($step/value/text())}</price>
                        {$step/pseudoPrice}
                    </_>)
    }</prices>
};

declare function _:price-replace($price as xs:string) {
    replace(replace($price, '\.', ''), ',', '.')
};


declare function _:transform-price-group($priceGroup as element(), $number as xs:string) as element() {
    let $specialPrice := _:special-price(
        $priceGroup/specialPriceFrom,
        $priceGroup/specialPriceUntil,
        $priceGroup/specialPrice
    )
    let $p := <_>{
        (
            if (empty($priceGroup/price/text()) and empty($specialPrice/text())) then () else (
                <price>
                    <amount>1</amount>
                    <value>{
                        if (empty($specialPrice/text()))
                            then ($priceGroup/price/text())
                            else ($specialPrice/text())
                    }</value>
                    <pseudoPrice>{
                        if (empty($specialPrice/text()))
                            then (0)
                            else ($priceGroup/price/text())
                    }</pseudoPrice>
                </price>
            )
            ,
            if (empty($specialPrice/text())) then ( 
                let $values := $priceGroup/pricestep/value
                for $item at $pos in $priceGroup/pricestep/amount
                return if (empty($item/text()) or empty($values[$pos]/text())) then () else (
                    if ((number($item/text()) < 1) or (number($values[$pos]/text()) <= 0)) then (
                        admin:write-log(concat('Invalid price step in article ', $number), 'ERROR')
                    ) else (
                        <price>{$item, $values[$pos]}</price>
                    )
                )
            ) else () 
        )
    }</_>
    return $p
};


declare function _:special-price($specialStartDate as element(), $specialEndDate as element(), $price as element()) as element() {
    if (empty($specialStartDate/text()) or empty($price/text())) then (
        <specialPrice></specialPrice>
    ) else (
        let $date := current-date() (: + xs:dayTimeDuration('P1D') :)
        let $specialEnDate := if (empty($specialEndDate/text())) then (
            string-join((day-from-date($date), month-from-date($date), year-from-date($date)), '/')
        ) else ($specialEndDate)
        return <specialPrice>{
            let $start := tokenize($specialStartDate/text(), '/')
            let $end := tokenize($specialEndDate/text(), '/')
            let $startDate := try{
                functx:date(concat('20', $start[3]), $start[1], $start[2])
            } catch * {
                xs:date('2015-12-31')
            }
            let $endDate := try {
                functx:date(concat('20', $end[3]), $end[1], $end[2])
            } catch * {
                xs:date('2015-12-31')
            }
            return if (($startDate <= $date) and ($endDate >= $date))
                then ($price/text()) else ()
        }</specialPrice>
    )
};


declare
  %rest:GET
  %rest:path("/shop/articles/categoryassignment")
function _:category-assignment() {
    let $sections :=
    for $feat in common:pim-get( '/pim/api/shop-features' )//Feature
(:    for $feat in db:open('ProductInfo')//Feature[@Key  ='Kategorie Onlineshop'] :)
    let $val := $feat/Value[1]
    group by $val
    return 
    <Section Guid="{random:uuid()}">
    <Title>{$val}</Title>
    {
      for $feat2 in $feat
      let $val2 := $feat2/Value[2]
      group by $val2
      return
      <Section Guid="{random:uuid()}">
         <Title>{ $val2 }</Title>
         {(
              for $feat3 at $pos3 in $feat2
              let $val3 := $feat3/Value[3]
              group by $val3
              return
              <Section Guid="{random:uuid()}">
               <Title>{ if($val3 = '') then 'Section' || $pos3 else $val3 }</Title>
                {
                  $feat3/parent::*/parent::* ! <ProductInfo Guid="{./@Guid}">
                    {
                     for $item in ./ProductItemList/ProductItem
                     return
                      <ProductItem Guid="{$item/@Guid}"/>
                    }
                  </ProductInfo>
                }
              </Section>
              ,
              let $level2products := $feat2/parent::*/parent::*[Data/Feature/@Key = 'Kategorie Onlineshop'][count(Data/Feature/Value) = 2]
              return if (empty($level2products)) then () else
              <Section Guid="{random:uuid()}">
               <Title>{ $val2 }</Title>
                {
                  $level2products ! <ProductInfo Guid="{./@Guid}">
                    {
                     for $item in ./ProductItemList/ProductItem
                     return
                      <ProductItem Guid="{$item/@Guid}"/>
                    }
                  </ProductInfo>
                }
              </Section>
          )}
      </Section>
    }
    </Section>
    return <Publication>{$sections}</Publication>
};

declare function _:image-filter() {
    'filter[0][property]=media.albumId&amp;filter[0][value]=-1'
};

declare function _:download-filter() {
    'filter[0][property]=media.albumId&amp;filter[0][value]=-6'
};

declare
  %rest:GET
  %rest:path("/shop/articles/update-images")
function _:update-images() {
    let $path-images := file:resolve-path($conf:COLLECTION_TO_DATAPATH("images"))
    let $changed := (
        doc($path-images || "md5list-jpg.xml")//changed,
        doc($path-images || "md5list-tiff.xml")//changed,
        doc($path-images || "md5list-tif.xml")//changed,
        doc($path-images || "md5list-eps.xml")//changed,
        doc($path-images || "md5list-jpeg.xml")//changed,
        doc($path-images || "md5list-png.xml")//changed,
        doc($path-images || "md5list-svg.xml")//changed
    )
    let $media := _:media-album(_:image-filter())//data/_
    return <upload>{
        for $img in $changed/text()
        let $image := tokenize(tokenize($img, '\\')[last()], '\.')[1]
        let $id := $media[name = $image]/id/text()
        return if (empty($id)) then () else
        let $update := <json objects="json"><file>file://{$shop:PHP-PATH-DOCUMENTS || $image}.jpg</file></json>
        let $json := json:serialize($update)
        return try {
            json:parse(
                HTTPWrapper:putJSON(shop:protocol(), shop:host(), shop:port(), $shop:PATH-MEDIA || $id, shop:user(), shop:pwd(), $json)
            )
        } catch * {
            (admin:write-log("SHOP IMAGE UPDATE FAILED", "ERROR"),
            <failed>{$err:description}</failed>)
        }
    }</upload>
};

declare
  %rest:GET
  %rest:path("/shop/stock/run")
function _:run-stockupdate() {
    let $stock := (# basex:non-deterministic #) { http:send-request(<http:request method='get'/>, 'http://localhost:' || $shop:PUBLISHER-PORT || '/erp/storage')//db/fatal }
    let $a := if (empty($stock)) then (
        (# basex:non-deterministic #) { _:update-article-stock() }
    ) else (
        common:fatal-log($common:STOCK-LOG, 'not executed, possible database inconsistency')
    )
    let $report := _:create-stock-report()
    let $xml-file := file:write($common:STOCK-REPORT, $report)
    return $report
};

declare
  %rest:GET
  %rest:path("/shop/articles/save-report")
function _:save-articles-report() {
    let $report := _:create-articles-report()
    let $xml-file := file:write($common:ARTICLES-REPORT, $report)
    return file:write(common:stamped-filename($common:ARTICLES-REPORT), $report)
};

declare
  %rest:GET
  %rest:path("/shop/articles/report")
  %output:method("xhtml")
  %output:html-version("5.0")
function _:create-articles-report() {
<html>
</html>
};

declare
  %rest:GET
  %rest:path("/shop/stock/save-report")
function _:save-stock-report() {
    let $report := _:create-stock-report()
    let $xml-file := file:write($common:STOCK-REPORT, $report)
    return file:write(common:stamped-filename($common:STOCK-REPORT), $report)
};

declare
  %rest:GET
  %rest:path("/shop/stock/report")
  %output:method("xhtml")
  %output:html-version("5.0")
function _:create-stock-report() {
<html>
</html>
};


declare function _:empty-article() {
    <article numbers="taxId supplierId" objects="mainDetail">
        <name></name>
        <taxId></taxId>
        <mainDetail>
            <number></number>
            <supplierNumber></supplierNumber>
            <additionalText></additionalText>
            <weight></weight>
            <width></width>
            <len></len>
            <height></height>
            <ean></ean>
            <purchaseUnit></purchaseUnit>
            <descriptionLong></descriptionLong>
            <referenceUnit></referenceUnit>
            <packUnit></packUnit>
            <shippingTime></shippingTime>
        </mainDetail>
        <supplierId></supplierId>
        <description></description>
        <descriptionLong></descriptionLong>
    </article>
};


declare function _:empty-detail() {
    <detail>
        <number></number>
        <supplierNumber></supplierNumber>
        <additionalText></additionalText>
        <weight></weight>
        <width></width>
        <len></len>
        <height></height>
        <ean></ean>
        <purchaseUnit></purchaseUnit>
        <descriptionLong></descriptionLong>
        <referenceUnit></referenceUnit>
        <packUnit></packUnit>
        <shippingTime></shippingTime>
    </detail>
};

declare function _:empty-price() {
    <_>
        <from>1</from>
        <to>beliebig</to>
        <price>0.00</price>
    </_>
};

declare function _:empty-pricing($number as xs:string) {
    <pricing>
        <articlenumber>{$number}</articlenumber>
        <group0>
          <price>0,0</price>
          <specialPriceFrom/>
          <specialPriceUntil/>
          <specialPrice/>
        </group0>
    </pricing>
};