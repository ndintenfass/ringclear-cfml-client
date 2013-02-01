component output="false"{
/*
  Copyright (c) 2012, Hotel Delta Holdings LLC

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

  function init(required username,required password){
    variables.instance = duplicate(arguments);
    //prime the service
    refreshService();
    //authenticate the user - if we get a known authentication error throw a special exception, otherwise any error should just pass through
    try{
      instance.accountid = authenticateUser();
    }
    catch("ringclear.soap" err){
      if(err.message == "Invalid user")
        throw(type="#makeExceptionType("authentication")#",message="Error authenticating: #err.message#");
      rethrow;
    }
    catch(any err){
      rethrow;
    }
    return this;
  }

  function exportContacts(groupid=1,accountid=instance.accountid){
    return call("exportContacts",arguments);
  }

  function importContacts(required contactListContents,creatingNewGroup=false,replaceExistingContacts=false,name="",accountid=instance.accountid){
    return call("importContacts",arguments);
  }

  function deleteContacts(required groupID,deleteGroup=false,accountid=instance.accountid){
    return call("deleteContactsFromSystem",arguments);
  }

  function deleteAllContacts(){
    return deleteContacts(1);
  }

  //group type ("standard", "rules", "map").
  //specStr    If a rules or map group, the groupQuerySpecStr or groupMapVerticesStr.
  function createGroup(required name,type="standard",specStr=javaCast("null",""),accountid=instance.accountid){
    arguments.name = cleanGroupName(arguments.name);
    return call("createGroup",arguments);
  }

  function addContactsToGroup(required groupId,required idList,accountId=instance.accountid){
    if(NOT isArray(arguments.idList)) arguments.idList = listToArray(arguments.idList);
    return call("addContactsToGroup",arguments);
  }

  function deleteGroup(required groupID){
    return deleteContacts(arguments.groupID,true);
  }

  function authenticateUser(){
    return call("authenticateUser");
  }

  function exportGroups(includeDynamicGroups=true,accountId=instance.accountid){
    return call("exportGroups",arguments);
  }

  function exportStandardGroups(){
    return exportGroups(false);
  }

  function exportContactFields(accountId=instance.accountid){
    return call("exportContactFields",arguments);
  }

  function echo(input=""){
    return call("echo",arguments);
  }
 
  //this effectively caches an instance of the service in this instance of the client the first time, then just returns that instance all other times - or you can force a refresh by passing "true"
  function getService(forceRefresh=false){
    if(!structKeyExists(instance,"service") OR arguments.forceRefresh){
      try{
        instance.service = createObject("webservice","http://ringclear.rcmds.com/gbmdrc-gbmdrc/RCMDSAPI?WSDL",{username=instance.username,password=instance.password,wsversion="1",refreshWSDL=arguments.forceRefresh});
      }
      //if there is a "wsdl" key in the error that means something went wrong at the web services level, otherwise just rethrow (which shouldn't ever happen)
      catch(any err){
        if(structKeyExists(err,"wsdl")){
          throw(type="#makeExceptionType("soap")#",message="Error retrieving the RingClear web service",detail="WSDL endpoint attempted was: #err.wsdl#. Details of original exception: #err.message# | #err.detail#. ");
        }
        rethrow;
      }
    }
    return instance.service;
  }

  //convience method with better semantics for hard-refreshing the service (including a reload of the WSDL)
  function refreshService(){
    return getService(true);
  }

  function cleanGroupName(name){
    arguments.name = replace(arguments.name, " ", "__", "ALL");
    //this line is here so that if you reclean a cleaned name it will come out the same
    arguments.name = replace(arguments.name, "-", ":", "ALL");
    arguments.name = reReplace(arguments.name, "[^\w]", "-", "ALL");
    arguments.name = replace(arguments.name,"__"," ","ALL");
    return arguments.name;
  }

  // this is the general purpose way to call any method of the web service (private)
  private function call(required methodName,args={}){
    //invoke the given method on the service passing the arguments collection. We'll try/catch here, mostly in case there is a network problem
    try{
      //needed to do this because CF9 doesn't support invoke()  
      //var raw = invoke(getService(),arguments.methodName,arguments.args); 
      var raw = evaluate("getService().#arguments.methodName#(argumentCollection=arguments.args)");  
    }
    catch(any err){
      throw(type="#makeExceptionType("call")#",message="Error calling RingClear web service: #err.message#",detail="#err.detail#");
    }
    //if there is a SOAP error in the result throw an exception
    if(raw.getErrorCode()){
      var message = raw.getErrorMsg();
      throw(type="#makeExceptionType("soap")#",message="#message#",detail="Error in web service call to method #arguments.methodName# with arguments #arguments.args.toString()#")
    }
    //if there is data to return give that back, otherwise send the raw SOAP response back to the caller
    var toReturn = raw.getData();
    return isNull(toReturn) ? getSOAPResponse(getService()) : toReturn;
  }

  //convenience method to make sure all exception types are of the same form
  private function makeExceptionType(type=""){
    var exceptionType = "ringclear";
      if(len(trim(arguments.type)))
        return listAppend(exceptionType,arguments.type,".");
      return exceptionType;
  }

  //THIS IS NOT A COMPLETE IMPLEMENTATION OF ALL POSSIBLE BITMASK VALUES -- ASSUMES ONLY THE NARROW CASE THIS WAS BUILT FOR
  //FOR INSTANCE, this never sets voice preferences and sets the same SMS pref for cell1 and cell2 based on priority
  function makeMessageTypePrefBitMask(cellphone1,cellphone2,email,messagePriority=1){
    /* 
      // Message-priority 1
      mask_prefHomephoneMP1 = 1 << 0;
      mask_prefCellphoneMP1 = 1 << 1;
      mask_prefCellphoneMP1OptIn = 1 << 2;
      mask_prefCellphone2MP1 = 1 << 3;
      mask_prefCellphone2MP1OptIn = 1 << 4;
      mask_prefWorkphoneMP1 = 1 << 5;
      mask_prefWorkphone2MP1 = 1 << 6;
      mask_prefEmailMP1 = 1 << 7;

      // Message-priority 2
      mask_prefHomephoneMP2 = 1 << 8;
      mask_prefCellphoneMP2 = 1 << 9;
      mask_prefCellphoneMP2OptIn = 1 << 10;
      mask_prefCellphone2MP2 = 1 << 11;
      mask_prefCellphone2MP2OptIn = 1 << 12;
      mask_prefWorkphoneMP2 = 1 << 13;
      mask_prefWorkphone2MP2 = 1 << 14;
      mask_prefEmailMP2 = 1 << 15;

      // Message-priority 3
      mask_prefHomephoneMP3 = 1 << 16;
      mask_prefCellphoneMP3 = 1 << 17;
      mask_prefCellphoneMP3OptIn = 1 << 18;
      mask_prefCellphone2MP3 = 1 << 19;
      mask_prefCellphone2MP3OptIn = 1 << 20;
      mask_prefWorkphoneMP3 = 1 << 21;
      mask_prefWorkphone2MP3 = 1 << 22;
      mask_prefEmailMP3 = 1 << 23;
    */
    var mask = 0;
    var priority2 = arguments.messagePriority GT 1;
    if(len(trim(arguments.cellPhone1))){
      mask += bitSHLN(1, 2);
      mask += bitSHLN(priority2,10);
    }
    if(len(trim(arguments.cellPhone2))){
      mask += bitSHLN(1, 4);
      mask += bitSHLN(priority2,12);
    }
    if(len(trim(arguments.email))){
      mask += bitSHLN(1,7);
      mask += bitSHLN(priority2,15);
    }
    return int(mask);  
  }
}