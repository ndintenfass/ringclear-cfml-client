component output="false"{

  function init(){
    return this;
  }

  //Thanks is due to Ben Nadel, as this is largely based on code from his blog.
  function csvToQuery(required csv,delimiter=",",textqualifier="""",trim=true,hasColumnNames=true){
    //remove trailing new lines if we're trimming (can't use trim() because we don't want to kill tabs and spaces)
    if(arguments.trim)
      arguments.csv = reReplace(arguments.csv,"[\r\n]+$","","all");
    if(len(arguments.delimiter) neq 1)
      throw(message="DELIMITER argument to csvToQuery must be a single character. You passed: #arguments.delimiter#");
    local.escapedDelimiter = regExSafe(arguments.delimiter);
    if(len(arguments.textqualifier) neq 1)
      throw(message="TEXTQUALIFIER argument to csvToQuery must be a single character. You passed: #arguments.textqualifier#");
    local.escapedTextqualifier = regExSafe(arguments.textqualifier);
    local.regex = "\G(?:#local.escapedTextqualifier#([^#local.escapedTextqualifier#]*+(?>#local.escapedTextqualifier##local.escapedTextqualifier#[^#local.escapedTextqualifier#]*+)*)#local.escapedTextqualifier#|([^#local.escapedTextqualifier##local.escapedDelimiter#\r\n]*+))(#local.escapedDelimiter#|\r\n?|\n|$)";
    local.pattern = createObject("java","java.util.regex.Pattern").compile(javaCast( "string", local.regEx ));
    local.matcher = local.pattern.matcher(javaCast( "string", arguments.csv ));
    local.csvDataQuery = queryNew("");
    local.queryColumnNames = [];
    local.firstRow = true;
    local.currentRow = 1;
    local.currentColNum = 0;
    /*  Here's where the magic is taking place; we are going to use
      the Java pattern matcher to iterate over each of the CSV data
      fields using the regular expression we defined above.
       
      Each match will have at least the field value and possibly an
      optional trailing delimiter.
    */
    while(local.matcher.find()){
      local.currentColNum++;
      //try to get the qualified field value. If the field was not qualified, this value will be null.
      local.fieldValue = local.matcher.group(javaCast( "int", 1 ));
      //Check to see if the value exists in the local scope. If it doesn't exist, then we want the non-qualified field. If it does exist, then we want to replace any escaped, embedded quotes.
      if(!isNull(local.fieldValue)){ //structKeyExists( local, "fieldValue" )
        local.fieldValue = replace( local.fieldValue,
                                    "#arguments.textqualifier##arguments.textqualifier#",
                                    arguments.textqualifier,
                                    "all"
                                  );
      }
      else{
        //No qualified field value was found; as such, let's use the non-qualified field value.
        local.fieldValue = local.matcher.group(javaCast( "int", 2 ));
      }
      //Now that we have our parsed field value, let's add it to the most recently created CSV row collection.
      if(local.firstRow){
        if(arguments.hasColumnNames){
          if(len(trim(local.fieldValue))){
            arrayAppend(local.queryColumnNames, replace(local.fieldValue," ","_","ALL"));
          }
          else{
            arrayAppend(local.queryColumnNames, "no-column-name");
          }
          local.currentRow = 0;
        }
        else{
          arrayAppend(local.queryColumnNames, "col#local.currentColNum#");
          if(NOT local.csvDataQuery.recordcount){
            queryAddRow(local.csvDataQuery);
          }
        }
        local.tempArray = arguments.hasColumnNames ? [] : [""];
        queryAddColumn(local.csvDataQuery, local.queryColumnNames[local.currentColNum], "varchar", local.tempArray );
        local.queryColumnCount = local.currentColNum;
      }

      if(local.currentRow neq 0){
        //in case the amount of columns in a line exceeds the current column count, add a column
        if( local.currentColNum gt local.queryColumnCount){
          arrayAppend(local.queryColumnNames, "col#local.currentColNum#");
          //create an aray with empty strings to fill the new query column
          local.tempArray = [];
          for(local.i = 1; local.i LTE local.csvDataQuery.recordCount;i++){
            local.tempArray[local.i] = "";
          }
          queryAddColumn(local.csvDataQuery, local.queryColumnNames[local.currentColNum], "varchar", local.tempArray );
          local.queryColumnCount = local.currentColNum;
        }
        querySetCell(local.csvDataQuery, local.queryColumnNames[local.currentColNum], local.fieldValue);
      }
      //Get the delimiter. We know that the delimiter will always be matched, but in the case that it matched the end of the CSV string, it will not have a length.
      local.delimiter = local.matcher.group(javaCast( "int", 3 ));
      //Check to see if we found a delimiter that is not the field delimiter (end-of-file delimiter will not have a length). If this is the case, then our delimiter is the line delimiter. Add a new data array to the CSV data collection. --->
      if( len( local.delimiter ) && (local.delimiter NEQ arguments.delimiter)){
        local.firstRow = false;
        local.currentRow = local.currentRow + 1;
        local.currentColNum = 0;
        queryAddRow(local.csvDataQuery);
      }
      else if(!len( local.delimiter )){
        //If our delimiter has no length, it means that we reached the end of the CSV data. Let's explicitly break out of the loop otherwise we'll get an extra empty space.
        break;
      } 
    }
    return local.csvDataQuery;
  }
  //Used by the CSVToQuery function. Conveniently, this will cache the strings in this instance, preventing lots of duplication of effort
  function regExSafe(str){
    param variables.regexSafeTranslations = {};
    if(NOT structKeyExists(variables.regexSafeTranslations, arguments.str)){
      variables.regexSafeTranslations[arguments.str] = rereplace(arguments.str, "(?=[\[\]\\^$.|?*+()])", "\", "all");
    }
    return variables.regexSafeTranslations[arguments.str];
  }

  function qualifyString(str,qualifier=""""){
    return qualifier & replace(arguments.str,arguments.qualifier,arguments.qualifier & arguments.qualifier,"ALL") & qualifier;
  }

}
