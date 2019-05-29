xquery version "3.0";

module namespace _= "pim/config";

declare variable $_:CATEGORY_TREE_TITLE := "";
declare variable $_:FEATURE_TYPES := ['String', 'Boolean', 'Select'];
declare variable $_:DEFAULT_LANG := "de";
declare variable $_:DATA_ROOT := "./Syncrovet/Syncrovet3.Data/";

declare variable $_:COLLECTION_TO_TYPE := map{
    "categories"    : "Category",
    "products"      : "ProductInfo",
    "productitems"  : "ProductItem",
    "texts"         : "Text",
    "images"        : "Image",
    "documents"     : "Document",
    "companies"     : "Company",
    "publications"  : "Publication"
};

(: TODO: 'Text' can be used in several places :)
declare variable $_:TYPE_TO_COLLECTION := map{
     "Category" :"categories"  ,
     "ProductInfo" :"products" ,
     "ProductItem" : "products",
     "Text" : "products" ,
     "Image" : "images",
     "Document" : "documents",
     "Company" : "companies",
     "Publication" : "publications" 
};

declare variable $_:COLLECTION_TO_DATAPATH := map{
    "images"        :  $_:DATA_ROOT || "Images/",
    "documents"     : $_:DATA_ROOT || "Documents/"
};

declare function _:lang-or-default($lang as xs:string?){

    if($lang and $lang ne '') then $lang else $_:DEFAULT_LANG
};

declare function _:data-path-for($collection as xs:string, $purpose as xs:string){
  (: let $coll := $_:COLLECTION_TO_DATAPATH :)
  let $path := file:resolve-path($_:COLLECTION_TO_DATAPATH($collection) || $purpose || "/")
  return $path
 
};

declare function _:export-path($folder){
 
  let $path := file:resolve-path($_:DATA_ROOT || "ExportMono/" || $folder || "/")
  return $path
 
};


declare variable $_:PURPOSE_TO_FOLDER := map{
    "prod-raw"        :  "raw",
    "prod-print"      :  "print",
    "design-print"    :  "print",
    "100pro-print"    :  "print",
    "zoom-print"      :  "print"
};

